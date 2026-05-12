// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Test } from "forge-std/Test.sol";
import { AthlCoin } from "../contracts/AthlCoin.sol";
import { AthlVestingWallet } from "../contracts/AthlVestingWallet.sol";

contract AthlVestingWalletTest is Test {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------
    uint64 constant START    = 365 days;  // 1-year cliff
    uint64 constant DURATION = 3 * uint64(365 days); // 3-year linear

    uint256 constant ALICE_ALLOC = 600_000_000 * 10 ** 18; // 60 %
    uint256 constant BOB_ALLOC   = 400_000_000 * 10 ** 18; // 40 %
    uint256 constant TOTAL_POOL  = ALICE_ALLOC + BOB_ALLOC;

    // -------------------------------------------------------------------------
    // Actors
    // -------------------------------------------------------------------------
    address revoker = makeAddr("revoker");
    address alice   = makeAddr("alice");
    address bob     = makeAddr("bob");
    address charlie = makeAddr("charlie");

    // -------------------------------------------------------------------------
    // Contracts under test
    // -------------------------------------------------------------------------
    AthlCoin token;
    AthlVestingWallet wallet;

    uint64 deployTime;

    function setUp() public {
        deployTime = uint64(block.timestamp);

        // Deploy token, fund revoker
        token = new AthlCoin(revoker);

        // Deploy wallet with 1-year cliff + 3-year linear schedule
        vm.startPrank(revoker);
        wallet = new AthlVestingWallet(
            address(token),
            revoker,
            deployTime + START,
            DURATION
        );
        // Fund the wallet with the total pool
        token.transfer(address(wallet), TOTAL_POOL);
        // Register both beneficiaries
        wallet.addBeneficiary(alice, ALICE_ALLOC);
        wallet.addBeneficiary(bob, BOB_ALLOC);
        vm.stopPrank();
    }

    // =========================================================================
    // Construction
    // =========================================================================

    function test_TokenAddress() public view {
        assertEq(address(wallet.token()), address(token));
    }

    function test_RevokerAddress() public view {
        assertEq(wallet.revoker(), revoker);
    }

    function test_StartTimestamp() public view {
        assertEq(wallet.start(), deployTime + START);
    }

    function test_Duration() public view {
        assertEq(wallet.duration(), DURATION);
    }

    function test_RevertWhen_ConstructWithZeroToken() public {
        vm.expectRevert(AthlVestingWallet.ZeroAddress.selector);
        new AthlVestingWallet(address(0), revoker, deployTime + START, DURATION);
    }

    function test_RevertWhen_ConstructWithZeroRevoker() public {
        vm.expectRevert(AthlVestingWallet.ZeroAddress.selector);
        new AthlVestingWallet(address(token), address(0), deployTime + START, DURATION);
    }

    // =========================================================================
    // addBeneficiary
    // =========================================================================

    function test_AddBeneficiary_StoresAllocation() public view {
        AthlVestingWallet.BeneficiaryInfo memory info = wallet.beneficiaryInfo(alice);
        assertEq(info.allocation, ALICE_ALLOC);
        assertFalse(info.revoked);
        assertEq(info.released, 0);
    }

    function test_AddBeneficiary_EmitsEvent() public {
        address newMember = makeAddr("newMember");
        vm.expectEmit(true, false, false, true);
        emit AthlVestingWallet.BeneficiaryAdded(newMember, 100 ether);
        vm.prank(revoker);
        wallet.addBeneficiary(newMember, 100 ether);
    }

    function test_RevertWhen_AddBeneficiary_NotRevoker() public {
        vm.prank(alice);
        vm.expectRevert(AthlVestingWallet.NotRevoker.selector);
        wallet.addBeneficiary(charlie, 1 ether);
    }

    function test_RevertWhen_AddBeneficiary_ZeroAddress() public {
        vm.prank(revoker);
        vm.expectRevert(AthlVestingWallet.ZeroAddress.selector);
        wallet.addBeneficiary(address(0), 1 ether);
    }

    function test_RevertWhen_AddBeneficiary_ZeroAllocation() public {
        vm.prank(revoker);
        vm.expectRevert(AthlVestingWallet.ZeroAllocation.selector);
        wallet.addBeneficiary(charlie, 0);
    }

    function test_RevertWhen_AddBeneficiary_AlreadyAdded() public {
        vm.prank(revoker);
        vm.expectRevert(abi.encodeWithSelector(AthlVestingWallet.AlreadyAdded.selector, alice));
        wallet.addBeneficiary(alice, 1 ether);
    }

    // =========================================================================
    // vestedAmount — schedule shape
    // =========================================================================

    function test_VestedAmount_ZeroDuringCliff() public view {
        assertEq(wallet.vestedAmount(alice, deployTime), 0);
        assertEq(wallet.vestedAmount(alice, deployTime + START - 1), 0);
    }

    function test_VestedAmount_ZeroAtCliffBoundary() public view {
        // At exactly start, (timestamp - start) == 0 → still 0
        assertEq(wallet.vestedAmount(alice, deployTime + START), 0);
    }

    function test_VestedAmount_LinearMidway() public view {
        uint64 midway = deployTime + START + DURATION / 2;
        uint256 vested = wallet.vestedAmount(alice, midway);
        assertApproxEqRel(vested, ALICE_ALLOC / 2, 0.001e18);
    }

    function test_VestedAmount_FullAtEnd() public view {
        uint64 end = deployTime + START + DURATION;
        assertEq(wallet.vestedAmount(alice, end), ALICE_ALLOC);
    }

    function test_VestedAmount_FullBeyondEnd() public view {
        uint64 beyond = deployTime + START + DURATION + 365 days;
        assertEq(wallet.vestedAmount(alice, beyond), ALICE_ALLOC);
    }

    function test_VestedAmount_ProportionalToAllocation() public view {
        uint64 midway = deployTime + START + DURATION / 2;
        uint256 aliceVested = wallet.vestedAmount(alice, midway);
        uint256 bobVested   = wallet.vestedAmount(bob,   midway);
        // Alice gets 60%, Bob 40% → ratio should hold
        assertApproxEqRel(aliceVested * 40, bobVested * 60, 0.001e18);
    }

    function testFuzz_VestedAmount_NeverExceedsAllocation(uint64 timestamp) public view {
        assertLe(wallet.vestedAmount(alice, timestamp), ALICE_ALLOC);
        assertLe(wallet.vestedAmount(bob,   timestamp), BOB_ALLOC);
    }

    // =========================================================================
    // releasable
    // =========================================================================

    function test_Releasable_ZeroDuringCliff() public view {
        assertEq(wallet.releasable(alice), 0);
    }

    function test_Releasable_DecreasesAfterRelease() public {
        vm.warp(deployTime + START + DURATION / 2);
        uint256 before = wallet.releasable(alice);
        vm.prank(alice);
        wallet.release();
        assertEq(wallet.releasable(alice), 0);
        // Tokens actually moved
        assertEq(token.balanceOf(alice), before);
    }

    // =========================================================================
    // release (single beneficiary)
    // =========================================================================

    function test_Release_TransfersCorrectAmount() public {
        vm.warp(deployTime + START + DURATION);
        vm.prank(alice);
        wallet.release();
        assertEq(token.balanceOf(alice), ALICE_ALLOC);
    }

    function test_Release_UpdatesReleasedField() public {
        vm.warp(deployTime + START + DURATION);
        vm.prank(alice);
        wallet.release();
        assertEq(wallet.beneficiaryInfo(alice).released, ALICE_ALLOC);
    }

    function test_Release_EmitsEvent() public {
        vm.warp(deployTime + START + DURATION);
        vm.expectEmit(true, false, false, true);
        emit AthlVestingWallet.TokensReleased(alice, ALICE_ALLOC);
        vm.prank(alice);
        wallet.release();
    }

    function test_RevertWhen_Release_NothingToRelease() public {
        // Before cliff
        vm.prank(alice);
        vm.expectRevert(AthlVestingWallet.NothingToRelease.selector);
        wallet.release();
    }

    function test_RevertWhen_Release_CalledTwiceWithNoNewVesting() public {
        vm.warp(deployTime + START + DURATION);
        vm.startPrank(alice);
        wallet.release();
        vm.expectRevert(AthlVestingWallet.NothingToRelease.selector);
        wallet.release();
        vm.stopPrank();
    }

    // =========================================================================
    // Multi-beneficiary independence
    // =========================================================================

    function test_MultiBeneficiary_IndependentRelease() public {
        vm.warp(deployTime + START + DURATION);

        vm.prank(alice);
        wallet.release();

        vm.prank(bob);
        wallet.release();

        assertEq(token.balanceOf(alice), ALICE_ALLOC);
        assertEq(token.balanceOf(bob),   BOB_ALLOC);
        assertEq(token.balanceOf(address(wallet)), 0);
    }

    function test_MultiBeneficiary_OneReleaseDoesNotAffectOther() public {
        vm.warp(deployTime + START + DURATION);

        vm.prank(alice);
        wallet.release();

        // Bob's releasable should be unchanged
        assertEq(wallet.releasable(bob), BOB_ALLOC);
        assertEq(wallet.beneficiaryInfo(bob).released, 0);
    }

    function test_MultiBeneficiary_PartialAtDifferentTimes() public {
        // Alice claims at 25% through vesting
        vm.warp(deployTime + START + DURATION / 4);
        vm.prank(alice);
        wallet.release();
        uint256 alicePart1 = token.balanceOf(alice);

        // Bob claims at 75% through vesting
        vm.warp(deployTime + START + (DURATION * 3) / 4);
        vm.prank(bob);
        wallet.release();
        uint256 bobPart1 = token.balanceOf(bob);

        assertApproxEqRel(alicePart1, ALICE_ALLOC / 4, 0.001e18);
        assertApproxEqRel(bobPart1,   BOB_ALLOC  * 3 / 4, 0.001e18);
    }

    function test_MultiBeneficiary_TotalNeverExceedsPool() public {
        vm.warp(deployTime + START + DURATION);
        vm.prank(alice); wallet.release();
        vm.prank(bob);   wallet.release();
        assertEq(token.balanceOf(alice) + token.balanceOf(bob), TOTAL_POOL);
    }

    // =========================================================================
    // Revocation
    // =========================================================================

    function test_Revoke_DuringCliff_ReturnsFullAllocation() public {
        // Nothing vested during cliff — entire allocation returned to revoker
        uint256 revokerBefore = token.balanceOf(revoker);
        vm.prank(revoker);
        wallet.revoke(alice);

        assertEq(token.balanceOf(revoker) - revokerBefore, ALICE_ALLOC);
        assertEq(wallet.releasable(alice), 0);
    }

    function test_Revoke_MidVesting_SplitsCorrectly() public {
        vm.warp(deployTime + START + DURATION / 2);

        uint256 revokerBefore = token.balanceOf(revoker);
        vm.prank(revoker);
        wallet.revoke(alice);

        uint256 returned = token.balanceOf(revoker) - revokerBefore;
        // ~50% of allocation should return to revoker (unvested half)
        assertApproxEqRel(returned, ALICE_ALLOC / 2, 0.001e18);
    }

    function test_Revoke_PreservesAlreadyVestedAmount() public {
        vm.warp(deployTime + START + DURATION / 2);
        vm.prank(revoker);
        wallet.revoke(alice);

        // Alice can still claim her vested-at-revoke portion
        uint256 claimable = wallet.releasable(alice);
        assertApproxEqRel(claimable, ALICE_ALLOC / 2, 0.001e18);

        vm.prank(alice);
        wallet.release();
        assertApproxEqRel(token.balanceOf(alice), ALICE_ALLOC / 2, 0.001e18);
    }

    function test_Revoke_FrozenAfterRevoke() public {
        vm.warp(deployTime + START + DURATION / 4);
        vm.prank(revoker);
        wallet.revoke(alice);

        uint256 claimableAtRevoke = wallet.releasable(alice);

        // Fast-forward to fully vested — amount must not increase
        vm.warp(deployTime + START + DURATION);
        assertEq(wallet.releasable(alice), claimableAtRevoke);
    }

    function test_Revoke_EmitsEvent() public {
        vm.warp(deployTime + START + DURATION / 2);
        uint256 vested   = wallet.vestedAmount(alice, uint64(block.timestamp));
        uint256 unvested = ALICE_ALLOC - vested;

        vm.expectEmit(true, false, false, true);
        emit AthlVestingWallet.BeneficiaryRevoked(alice, vested, unvested);
        vm.prank(revoker);
        wallet.revoke(alice);
    }

    function test_Revoke_DoesNotAffectOtherBeneficiaries() public {
        vm.warp(deployTime + START + DURATION / 2);
        vm.prank(revoker);
        wallet.revoke(alice);

        // Bob's schedule is completely unaffected
        assertApproxEqRel(wallet.releasable(bob), BOB_ALLOC / 2, 0.001e18);
    }

    function test_RevertWhen_Revoke_NotRevoker() public {
        vm.prank(alice);
        vm.expectRevert(AthlVestingWallet.NotRevoker.selector);
        wallet.revoke(bob);
    }

    function test_RevertWhen_Revoke_NotABeneficiary() public {
        vm.prank(revoker);
        vm.expectRevert(abi.encodeWithSelector(AthlVestingWallet.NotABeneficiary.selector, charlie));
        wallet.revoke(charlie);
    }

    function test_RevertWhen_Revoke_AlreadyRevoked() public {
        vm.prank(revoker);
        wallet.revoke(alice);

        vm.prank(revoker);
        vm.expectRevert(abi.encodeWithSelector(AthlVestingWallet.AlreadyRevoked.selector, alice));
        wallet.revoke(alice);
    }

    function test_Revoke_AtFullVest_ReturnsNothing() public {
        // All tokens already vested — nothing to return
        vm.warp(deployTime + START + DURATION);
        uint256 revokerBefore = token.balanceOf(revoker);
        vm.prank(revoker);
        wallet.revoke(alice);
        assertEq(token.balanceOf(revoker), revokerBefore);
        // Alice can still claim
        assertEq(wallet.releasable(alice), ALICE_ALLOC);
    }
}
