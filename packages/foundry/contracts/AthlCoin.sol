// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title AthlCoin (ATHL)
 * @notice Fixed-supply ERC-20 token for the ATHL ecosystem.
 *
 * - Total supply: 10,000,000,000 ATHL (10 billion), minted once to `recipient` at construction.
 * - No further minting or burning is possible.
 * - Includes ERC-2612 permit (gasless approvals via signature).
 *
 * Token distribution is managed off-chain by the deployer and via AthlVestingWallet
 * contracts created in the deploy script.
 */
contract AthlCoin is ERC20, ERC20Permit {
    /// @notice The fixed total supply: 10 billion ATHL (18 decimals).
    uint256 public constant TOTAL_SUPPLY = 10_000_000_000 * 10 ** 18;

    /**
     * @param recipient Address that receives the entire supply at deployment.
     *                  Typically the deployer, which then distributes to vesting contracts.
     */
    constructor(address recipient) ERC20("AthlCoin", "ATHL") ERC20Permit("AthlCoin") {
        _mint(recipient, TOTAL_SUPPLY);
    }
}
