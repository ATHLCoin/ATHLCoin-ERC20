// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { console } from "forge-std/Script.sol";
import "../contracts/AthleteCoin.sol";
import "../contracts/AthlVestingWallet.sol";
import "./DeployHelpers.s.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Deploys AthleteCoin and sets up VestingWallet contracts for team and investor
 *         token distributions.
 *
 * Token allocation (10,000,000,000 ATHL total):
 * ┌──────────────┬────────────────┬────────────────────────────────────────────────┐
 * │ Recipient    │ Amount         │ Schedule                                       │
 * ├──────────────┼────────────────┼────────────────────────────────────────────────┤
 * │ Ecosystem    │  3,650,000,000 │                                                │
 * │ Platform     │  1,950,000,000 │                                                │
 * │ Team         │  1,600,000,000 │                                                │
 * │ Public Sale  │    800,000,000 │                                                │
 * │ Advisors.    │    600,000,000 │                                                │
 * │ Marketing.   │    500,000,000 │                                                │
 * │ Private Sale │    500,000,000 │                                                │
 * │ Seed         │    400,000,000 │                                                │
 * └──────────────┴────────────────┴────────────────────────────────────────────────┘
 *
 * VestingWallet behaviour:
 *   Tokens are locked until `start`, then released linearly over `duration`.
 *   Setting `start` to (deploy time + cliff period) effectively creates a cliff.
 *   Beneficiaries call `vestingWallet.release(athlAddress)` to claim vested tokens.
 *
 * Before deploying to a live network, replace the TEAM_BENEFICIARY and
 * INVESTOR_BENEFICIARY constants below with the real recipient addresses.
 */
contract DeployAthleteCoin is ScaffoldETHDeploy {
    using SafeERC20 for AthleteCoin;
    // -------------------------------------------------------------------------
    // Allocations (in ATHL base units, 18 decimals)
    // -------------------------------------------------------------------------
    uint256 constant TEAM_ALLOCATION     = 1_600_000_000 * 10 ** 18; // 16 %
    uint256 constant ADVISORS_ALLOCATION = 600_000_000 * 10 ** 18; // 6 %
    uint256 constant PLATFORM_ALLOCATION = 1_950_000_000 * 10 ** 18; // 19.5 %
    uint256 constant MARKETING_ALLOCATION = 500_000_000 * 10 ** 18; // 5 %
    uint256 constant SEED_ALLOCATION = 400_000_000 * 10 ** 18; // 4 %
    uint256 constant PRIVATE_SALE_ALLOCATION = 500_000_000 * 10 ** 18; // 5 %
    uint256 constant PUBLIC_SALE_ALLOCATION = 800_000_000 * 10 ** 18; // 8 %
    uint256 constant ECOSYSTEM_ALLOCATION = 3_650_000_000 * 10 ** 18; // 36.5 %

    // -------------------------------------------------------------------------
    // Vesting durations (in seconds)
    // -------------------------------------------------------------------------
    uint64 constant ONE_YEAR       = 365 days;
    uint64 constant SIX_MONTHS     = ONE_YEAR / 2;
    uint64 constant THREE_YEARS    = 3 * ONE_YEAR;
    uint64 constant EIGHTEEN_MONTHS = 3 * SIX_MONTHS;

    // -------------------------------------------------------------------------
    // Team and Advisor beneficiaries — replace with real addresses before mainnet deployment
    // -------------------------------------------------------------------------
    // For local testing, we use the deployer address as a placeholder beneficiary.
    // In production, these should be replaced with the actual team member and advisor addresses.
    // Example:
    // address constant TEAM_BENEFICIARY = [0x123...]; // Replace with real team multisig or individual addresses
    // address constant ADVISOR_BENEFICIARY = [0xabc...]; // Replace with real advisor multisig or individual addresses
    address constant TEAM_BENEFICIARY = deployer; // Placeholder, set to deployer in run()
    address constant ADVISOR_BENEFICIARY = deployer; // Placeholder, set to deployer in run()

    function run() external ScaffoldEthDeployerRunner {
        // 1. Deploy AthleteCoin — entire 10B supply minted to the deployer.
        AthleteCoin athl = new AthleteCoin(deployer);
        console.logString(string.concat("AthleteCoin deployed at:", vm.toString(address(athl))));

        uint64 deployTime = uint64(block.timestamp);

        // 2. Team vesting wallet
        //    Nothing is claimable before (deployTime + 1 year).
        //    After that, tokens unlock linearly over 3 years.
        //    The deployer is the revoker — replace with a treasury multisig before mainnet.
        AthlVestingWallet teamVesting = new AthlVestingWallet(
            address(athl),
            deployer,              // revoker — replace with treasury multisig
            deployTime + ONE_YEAR, // vesting start = end of 1-year cliff
            THREE_YEARS            // linear release over 3 years post-cliff
        );
        athl.safeTransfer(address(teamVesting), TEAM_ALLOCATION);
        console.logString(string.concat("Team AthlVestingWallet at:", vm.toString(address(teamVesting))));

        // TODO: Call teamVesting.addBeneficiary(memberAddress, memberAllocation)
        //       for each team member. Allocations must sum to TEAM_ALLOCATION.
        //       Example (uses deployer as placeholder for local testing):
        teamVesting.addBeneficiary(TEAM_BENEFICIARY, TEAM_ALLOCATION);

        // 3. Advisors vesting wallet
        //    Nothing is claimable before (deployTime + 6 months).
        //    After that, tokens unlock linearly over 18 months.
        AthlVestingWallet advisorsVesting = new AthlVestingWallet(
            address(athl),
            deployer,                // revoker — replace with treasury multisig
            deployTime + SIX_MONTHS, // vesting start = end of 6-month cliff
            EIGHTEEN_MONTHS          // linear release over 18 months post-cliff
        );
        athl.safeTransfer(address(advisorsVesting), ADVISORS_ALLOCATION);
        console.logString(string.concat("Advisors AthlVestingWallet at:", vm.toString(address(advisorsVesting))));

        // TODO: Call advisorsVesting.addBeneficiary(advisorAddress, advisorAllocation)
        //       for each advisor. Allocations must sum to ADVISORS_ALLOCATION.
        //       Example (uses deployer as placeholder for local testing):
        advisorsVesting.addBeneficiary(ADVISOR_BENEFICIARY, ADVISORS_ALLOCATION);

        // platform
        AthlVestingWallet platformVesting = new AthlVestingWallet(
            address(athl),
            deployer,                // revoker — replace with treasury multisig
            deployTime,              // no cliff, start vesting immediately
            0                        // no linear vesting, all tokens claimable at start
        );
        athl.safeTransfer(address(platformVesting), PLATFORM_ALLOCATION);
        console.logString(string.concat("Platform AthlVestingWallet at:", vm.toString(address(platformVesting))));


        // marketing
        AthlVestingWallet marketingVesting = new AthlVestingWallet(
            address(athl),
            deployer,                // revoker — replace with treasury multisig
            deployTime,              // no cliff, start vesting immediately
            0                        // no linear vesting, all tokens claimable at start
        );
        athl.safeTransfer(address(marketingVesting), MARKETING_ALLOCATION);
        console.logString(string.concat("Marketing AthlVestingWallet at:", vm.toString(address(marketingVesting))));


        // seed
        AthlVestingWallet seedVesting = new AthlVestingWallet(
            address(athl),
            deployer,                // revoker — replace with treasury multisig
            deployTime,              // no cliff, start vesting immediately
            0                        // no linear vesting, all tokens claimable at start
        );
        athl.safeTransfer(address(seedVesting), SEED_ALLOCATION);
        console.logString(string.concat("Seed AthlVestingWallet at:   ", vm.toString(address(seedVesting))));

        // private sale
        AthlVestingWallet privateSaleVesting = new AthlVestingWallet(
            address(athl),
            deployer,                // revoker — replace with treasury multisig
            deployTime,              // no cliff, start vesting immediately
            0                        // no linear vesting, all tokens claimable at start
        );
        athl.safeTransfer(address(privateSaleVesting), PRIVATE_SALE_ALLOCATION);
        console.logString(string.concat("Private Sale AthlVestingWallet at:   ", vm.toString(address(privateSaleVesting))));    

        // public sale
        AthlVestingWallet publicSaleVesting = new AthlVestingWallet(
            address(athl),
            deployer,                // revoker — replace with treasury multisig
            deployTime,              // no cliff, start vesting immediately             
            0                        // no linear vesting, all tokens claimable at start
        );
        athl.safeTransfer(address(publicSaleVesting), PUBLIC_SALE_ALLOCATION);
        console.logString(string.concat("Public Sale AthlVestingWallet at:   ", vm.toString(address(publicSaleVesting))));  

        // ecosystem
        AthlVestingWallet ecosystemVesting = new AthlVestingWallet(
            address(athl),
            deployer,                // revoker — replace with treasury multisig               
            deployTime,              // no cliff, start vesting immediately         
            0                        // no linear vesting, all tokens claimable at start
        );
        athl.safeTransfer(address(ecosystemVesting), ECOSYSTEM_ALLOCATION);
        console.logString(string.concat("Ecosystem AthlVestingWallet at:   ", vm.toString(address(ecosystemVesting)))); 


        // Remaining 6.5B ATHL stays with the deployer for treasury / ecosystem / liquidity.
        console.logString(
            string.concat(
                "Deployer treasury balance: ",
                vm.toString(athl.balanceOf(deployer) / 10 ** 18),
                " ATHL"
            )
        );
    }
}
