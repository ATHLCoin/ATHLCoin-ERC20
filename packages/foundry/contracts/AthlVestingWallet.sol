// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AthlVestingWallet
 * @notice Multi-beneficiary, revocable vesting pool for ATHL token distributions.
 *
 * Architecture
 * ────────────
 * One instance is deployed per allocation group (e.g. "Team", "Investors"). The
 * revoker funds the contract by transferring the group's total token allocation to
 * it, then registers each member via `addBeneficiary`.
 *
 * Vesting schedule
 * ────────────────
 * Tokens vest linearly from `start` to `start + duration`. No tokens are
 * claimable before `start`, which effectively implements a cliff when `start` is
 * set to `deployTime + cliffPeriod`.
 *
 *   vestedAmount(addr, t):
 *     t < start            → 0
 *     start ≤ t < end      → allocation * (t - start) / duration
 *     t ≥ end              → allocation  (fully vested)
 *
 * Revocability
 * ────────────
 * The revoker (typically a treasury multisig) may call `revoke(beneficiary)` at any
 * time. On revocation the beneficiary's vested-to-date amount is preserved; all
 * unvested tokens are immediately returned to the revoker address.
 *
 * Adding beneficiaries
 * ────────────────────
 * Only the revoker may call `addBeneficiary`. This can happen any time, including
 * after `start`. If added mid-schedule, the beneficiary can immediately claim the
 * already-vested portion of their allocation.
 */
contract AthlVestingWallet {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event BeneficiaryAdded(address indexed beneficiary, uint256 allocation);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event BeneficiaryRevoked(address indexed beneficiary, uint256 vestedAmount, uint256 unvestedAmount);
    event BeneficiaryChanged(address indexed oldBeneficiary, address indexed newBeneficiary);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error NotRevoker();
    error ZeroAddress();
    error ZeroAllocation();
    error ZeroDuration();
    error AlreadyAdded(address beneficiary);
    error NotABeneficiary(address beneficiary);
    error AlreadyRevoked(address beneficiary);
    error NothingToRelease();
    error InsufficientFunds(uint256 totalAllocated, uint256 balance);

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------
    struct BeneficiaryInfo {
        uint256 allocation;     // total tokens assigned to this beneficiary
        uint256 released;       // tokens already claimed
        uint256 vestedAtRevoke; // snapshot of vested amount at the time of revocation
        bool revoked;           // true once revoke() has been called
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice The ERC-20 token managed by this wallet.
    IERC20 public immutable token;

    /// @notice Address authorised to add beneficiaries and revoke vesting.
    ///         Receives unvested tokens on revocation.
    address public immutable revoker;

    /// @notice Timestamp at which linear vesting begins (end of cliff period).
    uint64 public immutable start;

    /// @notice Duration of the linear vesting window in seconds.
    uint64 public immutable duration;

    /// @notice Sum of all active beneficiary allocations.
    ///         Used to guard against over-allocation relative to the funded balance.
    uint256 public totalAllocated;

    mapping(address => BeneficiaryInfo) private _beneficiaries;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param _token    The ATHL token contract address.
     * @param _revoker  Address that can add/revoke beneficiaries (treasury multisig).
     * @param _start    Unix timestamp at which vesting begins (deploy time + cliff).
     * @param _duration Seconds over which tokens vest linearly after `_start`. Must be > 0.
     */
    constructor(address _token, address _revoker, uint64 _start, uint64 _duration) {
        if (_token == address(0) || _revoker == address(0)) revert ZeroAddress();
        if (_duration == 0) revert ZeroDuration();
        token = IERC20(_token);
        revoker = _revoker;
        start = _start;
        duration = _duration;
    }

    // -------------------------------------------------------------------------
    // Revoker-only administration
    // -------------------------------------------------------------------------

    /**
     * @notice Register a beneficiary with a specific token allocation.
     * @dev Reverts if total allocations would exceed the contract's current token balance.
     * @param beneficiary Recipient address.
     * @param allocation  Total tokens (in base units) assigned to this beneficiary.
     */
    function addBeneficiary(address beneficiary, uint256 allocation) external {
        if (msg.sender != revoker) revert NotRevoker();
        if (beneficiary == address(0)) revert ZeroAddress();
        if (allocation == 0) revert ZeroAllocation();
        if (_beneficiaries[beneficiary].allocation != 0) revert AlreadyAdded(beneficiary);

        uint256 newTotal = totalAllocated + allocation;
        if (newTotal > token.balanceOf(address(this))) revert InsufficientFunds(newTotal, token.balanceOf(address(this)));

        totalAllocated = newTotal;
        _beneficiaries[beneficiary].allocation = allocation;
        emit BeneficiaryAdded(beneficiary, allocation);
    }

    /**
     * @notice Revoke a beneficiary's unvested tokens, returning them to the revoker.
     * @dev The beneficiary retains access to their vested-to-date amount.
     * @param beneficiary Address to revoke.
     */
    function revoke(address beneficiary) external {
        if (msg.sender != revoker) revert NotRevoker();
        BeneficiaryInfo storage info = _beneficiaries[beneficiary];
        if (info.allocation == 0) revert NotABeneficiary(beneficiary);
        if (info.revoked) revert AlreadyRevoked(beneficiary);

        uint256 vested = vestedAmount(beneficiary, uint64(block.timestamp));
        uint256 unvested = info.allocation - vested;

        info.revoked = true;
        info.vestedAtRevoke = vested;

        // Reduce totalAllocated by the unvested portion being returned to revoker.
        totalAllocated -= unvested;

        emit BeneficiaryRevoked(beneficiary, vested, unvested);

        if (unvested > 0) {
            token.safeTransfer(revoker, unvested);
        }
    }

    // -------------------------------------------------------------------------
    // Beneficiary actions
    // -------------------------------------------------------------------------

    /**
     * @notice Release all currently claimable tokens to the caller.
     * @dev Reverted beneficiaries can still claim their vested-at-revoke amount.
     */
    function release() external {
        address beneficiary = msg.sender;
        uint256 amount = releasable(beneficiary);
        if (amount == 0) revert NothingToRelease();

        _beneficiaries[beneficiary].released += amount;
        emit TokensReleased(beneficiary, amount);
        token.safeTransfer(beneficiary, amount);
    }

    // -------------------------------------------------------------------------
    // Revoker-only beneficiary management (continued)
    // -------------------------------------------------------------------------

    /**
     * @notice Redirects a beneficiary's allocation to a new address.
     * @dev Only callable by the revoker (e.g. treasury multisig) to handle key-loss recovery.
     *      The new address must not already be a beneficiary. All vesting state is migrated.
     * @param oldBeneficiary The current beneficiary address.
     * @param newBeneficiary The replacement address.
     */
    function changeBeneficiary(address oldBeneficiary, address newBeneficiary) external {
        if (msg.sender != revoker) revert NotRevoker();
        if (newBeneficiary == address(0)) revert ZeroAddress();
        if (_beneficiaries[oldBeneficiary].allocation == 0) revert NotABeneficiary(oldBeneficiary);
        if (_beneficiaries[newBeneficiary].allocation != 0) revert AlreadyAdded(newBeneficiary);

        _beneficiaries[newBeneficiary] = _beneficiaries[oldBeneficiary];
        delete _beneficiaries[oldBeneficiary];

        emit BeneficiaryChanged(oldBeneficiary, newBeneficiary);
    }

    // -------------------------------------------------------------------------
    // View functions
    // -------------------------------------------------------------------------

    /**
     * @notice Returns the stored info for a beneficiary.
     */
    function beneficiaryInfo(address beneficiary) external view returns (BeneficiaryInfo memory) {
        return _beneficiaries[beneficiary];
    }

    /**
     * @notice Calculates tokens vested for `beneficiary` at `timestamp`.
     */
    function vestedAmount(address beneficiary, uint64 timestamp) public view returns (uint256) {
        BeneficiaryInfo storage info = _beneficiaries[beneficiary];
        // After revocation the claimable ceiling is frozen at the revocation snapshot.
        if (info.revoked) return info.vestedAtRevoke;

        uint256 total = info.allocation;
        if (total == 0 || timestamp < start) return 0;
        if (duration == 0) return total;
        if (timestamp >= start + duration) return total;
        return total * (timestamp - start) / duration;
    }

    /**
     * @notice Tokens currently claimable by `beneficiary`.
     */
    function releasable(address beneficiary) public view returns (uint256) {
        return vestedAmount(beneficiary, uint64(block.timestamp)) - _beneficiaries[beneficiary].released;
    }
}
