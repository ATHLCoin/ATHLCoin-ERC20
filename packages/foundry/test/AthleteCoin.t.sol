// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { AthleteCoin } from "../contracts/AthleteCoin.sol";
import { AthlVestingWallet } from "../contracts/AthlVestingWallet.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract AthleteCoinTest is Test {
    // -------------------------------------------------------------------------
    // Constants mirrored from the contract / deploy script
    // -------------------------------------------------------------------------
    uint256 constant TOTAL_SUPPLY        = 10_000_000_000 * 10 ** 18;
    uint256 constant TEAM_ALLOCATION     = 2_000_000_000 * 10 ** 18;
    uint256 constant INVESTOR_ALLOCATION = 1_500_000_000 * 10 ** 18;
    uint256 constant TREASURY_BALANCE    = TOTAL_SUPPLY - TEAM_ALLOCATION - INVESTOR_ALLOCATION;

    uint64 constant ONE_YEAR       = 365 days;
    uint64 constant SIX_MONTHS     = ONE_YEAR / 2;
    uint64 constant THREE_YEARS    = 3 * ONE_YEAR;
    uint64 constant EIGHTEEN_MONTHS = 3 * SIX_MONTHS;

    // -------------------------------------------------------------------------
    // Actors
    // -------------------------------------------------------------------------
    address deployer  = makeAddr("deployer");
    address team      = makeAddr("team");
    address investors = makeAddr("investors");
    address alice     = makeAddr("alice");
    address bob       = makeAddr("bob");

    // -------------------------------------------------------------------------
    // Contracts under test
    // -------------------------------------------------------------------------
    AthleteCoin athl;
    AthlVestingWallet teamVesting;
    AthlVestingWallet investorVesting;

    uint64 deployTime;

    function setUp() public {
        deployTime = uint64(block.timestamp);

        vm.startPrank(deployer);

        // Deploy token — all 10B to deployer
        athl = new AthleteCoin(deployer);

        // Team vesting: 1-year cliff + 3-year linear
        teamVesting = new AthlVestingWallet(
            address(athl), deployer, deployTime + ONE_YEAR, THREE_YEARS
        );
        athl.transfer(address(teamVesting), TEAM_ALLOCATION);
        teamVesting.addBeneficiary(team, TEAM_ALLOCATION);

        // Investor vesting: 6-month cliff + 18-month linear
        investorVesting = new AthlVestingWallet(
            address(athl), deployer, deployTime + SIX_MONTHS, EIGHTEEN_MONTHS
        );
        athl.transfer(address(investorVesting), INVESTOR_ALLOCATION);
        investorVesting.addBeneficiary(investors, INVESTOR_ALLOCATION);

        vm.stopPrank();
    }

    // =========================================================================
    // Token metadata
    // =========================================================================

    function test_Name() public view {
        assertEq(athl.name(), "AthleteCoin");
    }

    function test_Symbol() public view {
        assertEq(athl.symbol(), "ATHL");
    }

    function test_Decimals() public view {
        assertEq(athl.decimals(), 18);
    }

    // =========================================================================
    // Fixed supply
    // =========================================================================

    function test_TotalSupply() public view {
        assertEq(athl.totalSupply(), TOTAL_SUPPLY);
    }

    function test_TotalSupplyMatchesConstant() public view {
        assertEq(athl.TOTAL_SUPPLY(), TOTAL_SUPPLY);
    }

    function test_TotalSupplyUnchangedAfterTransfers() public {
        vm.prank(deployer);
        athl.transfer(alice, 1_000 * 10 ** 18);
        assertEq(athl.totalSupply(), TOTAL_SUPPLY);
    }

    // =========================================================================
    // Initial distribution
    // =========================================================================

    function test_DeployerReceivesFullSupplyInitially() public {
        // Before setUp transfers, a freshly minted token gives all to recipient
        AthleteCoin fresh = new AthleteCoin(alice);
        assertEq(fresh.balanceOf(alice), TOTAL_SUPPLY);
    }

    function test_TreasuryBalanceAfterDistribution() public view {
        assertEq(athl.balanceOf(deployer), TREASURY_BALANCE);
    }

    function test_TeamVestingWalletReceivedAllocation() public view {
        assertEq(athl.balanceOf(address(teamVesting)), TEAM_ALLOCATION);
    }

    function test_InvestorVestingWalletReceivedAllocation() public view {
        assertEq(athl.balanceOf(address(investorVesting)), INVESTOR_ALLOCATION);
    }

    function test_AllTokensAccountedFor() public view {
        uint256 total = athl.balanceOf(deployer)
            + athl.balanceOf(address(teamVesting))
            + athl.balanceOf(address(investorVesting));
        assertEq(total, TOTAL_SUPPLY);
    }

    // =========================================================================
    // No minting
    // =========================================================================

    function test_RevertWhen_MintCalledDirectly() public {
        // AthleteCoin exposes no public mint function — calling a non-existent
        // selector should revert.
        (bool success,) = address(athl).call(
            abi.encodeWithSignature("mint(address,uint256)", alice, 1 ether)
        );
        assertFalse(success, "mint() should not exist");
    }

    // =========================================================================
    // No burning
    // =========================================================================

    function test_RevertWhen_BurnCalledDirectly() public {
        (bool success,) = address(athl).call(
            abi.encodeWithSignature("burn(uint256)", 1 ether)
        );
        assertFalse(success, "burn() should not exist");
    }

    // =========================================================================
    // ERC-20 transfers
    // =========================================================================

    function test_Transfer() public {
        uint256 amount = 500 * 10 ** 18;
        vm.prank(deployer);
        athl.transfer(alice, amount);
        assertEq(athl.balanceOf(alice), amount);
        assertEq(athl.balanceOf(deployer), TREASURY_BALANCE - amount);
    }

    function test_RevertWhen_TransferExceedsBalance() public {
        vm.prank(alice); // alice has zero tokens
        vm.expectRevert();
        athl.transfer(bob, 1);
    }

    function test_Approve_And_TransferFrom() public {
        uint256 amount = 1_000 * 10 ** 18;
        vm.prank(deployer);
        athl.approve(alice, amount);
        assertEq(athl.allowance(deployer, alice), amount);

        vm.prank(alice);
        athl.transferFrom(deployer, bob, amount);
        assertEq(athl.balanceOf(bob), amount);
        assertEq(athl.allowance(deployer, alice), 0);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, TREASURY_BALANCE);
        vm.prank(deployer);
        athl.transfer(alice, amount);
        assertEq(athl.balanceOf(alice), amount);
        assertEq(athl.totalSupply(), TOTAL_SUPPLY);
    }

    // =========================================================================
    // Team vesting schedule (smoke tests — full coverage in AthlVestingWallet.t.sol)
    // =========================================================================

    function test_TeamVesting_NothingReleasableDuringCliff() public view {
        assertEq(teamVesting.releasable(team), 0);
    }

    function test_TeamVesting_NothingReleasableAtCliffEnd() public {
        vm.warp(deployTime + ONE_YEAR);
        assertEq(teamVesting.releasable(team), 0);
    }

    function test_TeamVesting_PartialReleaseAfterCliff() public {
        vm.warp(deployTime + ONE_YEAR + THREE_YEARS / 2);
        assertApproxEqRel(teamVesting.releasable(team), TEAM_ALLOCATION / 2, 0.001e18);
    }

    function test_TeamVesting_FullyVestedAtEnd() public {
        vm.warp(deployTime + ONE_YEAR + THREE_YEARS);
        assertEq(teamVesting.releasable(team), TEAM_ALLOCATION);
    }

    function test_TeamVesting_Release() public {
        vm.warp(deployTime + ONE_YEAR + THREE_YEARS);
        vm.prank(team);
        teamVesting.release();
        assertEq(athl.balanceOf(team), TEAM_ALLOCATION);
        assertEq(athl.balanceOf(address(teamVesting)), 0);
    }

    function test_TeamVesting_RevokerIsDeployer() public view {
        assertEq(teamVesting.revoker(), deployer);
    }

    // =========================================================================
    // Investor vesting schedule (smoke tests — full coverage in AthlVestingWallet.t.sol)
    // =========================================================================

    function test_InvestorVesting_NothingReleasableDuringCliff() public view {
        assertEq(investorVesting.releasable(investors), 0);
    }

    function test_InvestorVesting_PartialReleaseAfterCliff() public {
        vm.warp(deployTime + SIX_MONTHS + EIGHTEEN_MONTHS / 2);
        assertApproxEqRel(investorVesting.releasable(investors), INVESTOR_ALLOCATION / 2, 0.001e18);
    }

    function test_InvestorVesting_FullyVestedAtEnd() public {
        vm.warp(deployTime + SIX_MONTHS + EIGHTEEN_MONTHS);
        assertEq(investorVesting.releasable(investors), INVESTOR_ALLOCATION);
    }

    function test_InvestorVesting_Release() public {
        vm.warp(deployTime + SIX_MONTHS + EIGHTEEN_MONTHS);
        vm.prank(investors);
        investorVesting.release();
        assertEq(athl.balanceOf(investors), INVESTOR_ALLOCATION);
        assertEq(athl.balanceOf(address(investorVesting)), 0);
    }

    function test_InvestorVesting_RevokerIsDeployer() public view {
        assertEq(investorVesting.revoker(), deployer);
    }

    // =========================================================================
    // ERC-2612 permit
    // =========================================================================

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 value = 1_000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;

        // Mint some tokens to the signer so the allowance is meaningful
        vm.prank(deployer);
        athl.transfer(owner, value);

        bytes32 domainSeparator = athl.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                value,
                athl.nonces(owner),
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        athl.permit(owner, bob, value, deadline, v, r, s);

        assertEq(athl.allowance(owner, bob), value);
        assertEq(athl.nonces(owner), 1);
    }

    function test_RevertWhen_PermitExpired() public {
        uint256 privateKey = 0xB0B;
        address owner = vm.addr(privateKey);
        uint256 deadline = block.timestamp - 1; // already expired

        bytes32 domainSeparator = athl.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                1000,
                athl.nonces(owner),
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert();
        athl.permit(owner, bob, 1000, deadline, v, r, s);
    }
}
