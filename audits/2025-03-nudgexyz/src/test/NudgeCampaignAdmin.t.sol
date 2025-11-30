// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {NudgeCampaign} from "../campaign/NudgeCampaign.sol";
import {NudgeCampaignFactory} from "../campaign/NudgeCampaignFactory.sol";
import {INudgeCampaign, IBaseNudgeCampaign} from "../campaign/interfaces/INudgeCampaign.sol";
import "../mocks/TestERC20.sol";
import {console} from "forge-std/console.sol";

contract NudgeCampaignAdminTest is Test {
    using Math for uint256;

    NudgeCampaign private campaign;
    NudgeCampaignFactory private factory;
    TestERC20 private targetToken;
    TestERC20 private rewardToken;

    address owner = address(1);
    address alice = address(11);
    address bob = address(12);
    address campaignAdmin = address(13);
    address nudgeAdmin = address(14);
    address treasury = address(15);
    address swapCaller = address(16);
    address operator = address(17);
    address alternativeWithdrawalAddress = address(18);

    uint32 constant HOLDING_PERIOD = 7 days;
    uint256 constant REWARD_PPQ = 2e13;
    uint256 constant INITIAL_FUNDING = 100_000e18;
    uint256 constant PPQ_DENOMINATOR = 1e15;

    event ParticipationInvalidated(uint256[] pIDs);
    event RewardsWithdrawn(address indexed to, uint256 amount);
    event FeesCollected(uint256 feesCollected);
    event CampaignStatusChanged(bool isActive);

    function setUp() public {
        // Deploy tokens
        targetToken = new TestERC20("Target Token", "TT");
        rewardToken = new TestERC20("Reward Token", "RT");

        console.log("Target token address: %s", address(targetToken));
        console.log("Reward token address: %s", address(rewardToken));
        // Deploy factory with roles
        factory = new NudgeCampaignFactory(treasury, nudgeAdmin, operator, swapCaller);

        // Fund test contract and approve factory
        // deal(address(rewardToken), address(this), INITIAL_FUNDING);
        rewardToken.mintTo(INITIAL_FUNDING, address(this));
        rewardToken.approve(address(factory), INITIAL_FUNDING);

        // Deploy and fund campaign
        campaign = NudgeCampaign(
            payable(
                factory.deployAndFundCampaign(
                    HOLDING_PERIOD,
                    address(targetToken),
                    address(rewardToken),
                    REWARD_PPQ,
                    campaignAdmin,
                    0, // start immediately
                    alternativeWithdrawalAddress,
                    INITIAL_FUNDING,
                    1 // uuid
                )
            )
        );

        // Setup swapCaller
        deal(address(targetToken), swapCaller, INITIAL_FUNDING);
        vm.prank(swapCaller);
        targetToken.approve(address(campaign), type(uint256).max);
    }

    function createParticipation(address user, uint256 amount) internal returns (uint256 pID) {
        deal(address(targetToken), swapCaller, amount);
        vm.prank(swapCaller);
        targetToken.approve(address(campaign), amount);

        //print token being used
        console.log("Token being used: %s", amount);
        //print balance of target token
        console.log("Balance of target token: %s", targetToken.balanceOf(swapCaller));
        vm.prank(swapCaller);

        campaign.handleReallocation(
            1, // campaignId
            user,
            address(targetToken),
            amount,
            "" // data
        );

        console.log("Campaign pID: %s", campaign.pID());
        console.log("Campaign pending rewards: %s", campaign.pendingRewards());

        return campaign.pID();
    }

    /*//////////////////////////////////////////////////////////////////////////
                              INVALIDATE PARTICIPATIONS                              
    //////////////////////////////////////////////////////////////////////////*/

    function test_InvalidateParticipations_Success() public {
        uint256 toAmount = 100e18;
        uint256 pID1 = createParticipation(alice, toAmount);
        uint256 pID2 = createParticipation(bob, toAmount);

        uint256[] memory pIDs = new uint256[](2);
        pIDs[0] = pID1;
        pIDs[1] = pID2;

        uint256 pendingRewardsBefore = campaign.pendingRewards();

        vm.expectEmit(true, true, true, true);
        emit ParticipationInvalidated(pIDs);

        vm.prank(operator);
        campaign.invalidateParticipations(pIDs);

        // Check participations are invalidated
        (IBaseNudgeCampaign.ParticipationStatus status1, , , , , ) = campaign.participations(pID1);
        (IBaseNudgeCampaign.ParticipationStatus status2, , , , , ) = campaign.participations(pID2);

        assertEq(uint256(status1), uint256(IBaseNudgeCampaign.ParticipationStatus.INVALIDATED));
        assertEq(uint256(status2), uint256(IBaseNudgeCampaign.ParticipationStatus.INVALIDATED));

        // Check pending rewards are reduced
        assertLt(campaign.pendingRewards(), pendingRewardsBefore);
    }

    function test_InvalidateParticipationsAlreadyInvalidated() public {
        uint256 toAmount = 100e18;
        uint256 pID1 = createParticipation(alice, toAmount);
        uint256 pID2 = createParticipation(bob, toAmount);

        uint256 pendingRewardsBefore = campaign.pendingRewards();

        // Invalidate just one participation
        uint256[] memory pIDsWithOne = new uint256[](1);
        pIDsWithOne[0] = pID1;

        vm.prank(operator);
        campaign.invalidateParticipations(pIDsWithOne);

        (IBaseNudgeCampaign.ParticipationStatus status1Before, , , uint256 rewardAmount1, , ) = campaign.participations(
            pID1
        );
        assertEq(uint256(status1Before), uint256(IBaseNudgeCampaign.ParticipationStatus.INVALIDATED));

        // Check pending rewards are reduced
        uint256 pendingRewardsAfterOneInvalidation = campaign.pendingRewards();
        assertEq(pendingRewardsAfterOneInvalidation, pendingRewardsBefore - rewardAmount1);

        // Invalide both participations, including the one already invalidated
        uint256[] memory pIDs = new uint256[](2);
        pIDs[0] = pID1;
        pIDs[1] = pID2;

        vm.prank(operator);
        campaign.invalidateParticipations(pIDs);

        // Check both participations are invalidated
        (IBaseNudgeCampaign.ParticipationStatus status1After, , , , , ) = campaign.participations(pID1);
        (IBaseNudgeCampaign.ParticipationStatus status2, , , uint256 rewardAmount2, , ) = campaign.participations(pID2);

        assertEq(uint256(status1After), uint256(IBaseNudgeCampaign.ParticipationStatus.INVALIDATED));
        assertEq(uint256(status2), uint256(IBaseNudgeCampaign.ParticipationStatus.INVALIDATED));

        // Check pending rewards were deducted correctly
        uint256 pendingRewardsAfterBothInvalidations = campaign.pendingRewards();
        assertEq(pendingRewardsAfterBothInvalidations, pendingRewardsAfterOneInvalidation - rewardAmount2);
    }

    function test_RevertInvalidateParticipations_Unauthorized() public {
        uint256[] memory pIDs = new uint256[](1);
        pIDs[0] = 1;

        vm.prank(alice);
        vm.expectRevert(IBaseNudgeCampaign.Unauthorized.selector);
        campaign.invalidateParticipations(pIDs);
    }

    /*//////////////////////////////////////////////////////////////////////////
                              WITHDRAW REWARDS                              
    //////////////////////////////////////////////////////////////////////////*/

    function test_WithdrawRewards_Success() public {
        uint256 withdrawAmount = 1000e18;
        uint256 balanceBefore = rewardToken.balanceOf(alternativeWithdrawalAddress);

        //vm.expectEmit(true, true, true, true);
        emit RewardsWithdrawn(alternativeWithdrawalAddress, withdrawAmount);

        vm.prank(campaignAdmin);
        campaign.withdrawRewards(withdrawAmount);

        assertEq(rewardToken.balanceOf(alternativeWithdrawalAddress), balanceBefore + withdrawAmount);
    }

    function test_WithdrawRewards_WithNoAlternativeAddress() public {
        // Deploy and fund new campaign without alternative withdrawal address
        vm.startPrank(campaignAdmin);
        rewardToken.mintTo(INITIAL_FUNDING, campaignAdmin);
        rewardToken.approve(address(factory), INITIAL_FUNDING);
        NudgeCampaign campaign2 = NudgeCampaign(
            payable(
                factory.deployAndFundCampaign(
                    HOLDING_PERIOD,
                    address(targetToken),
                    address(rewardToken),
                    REWARD_PPQ,
                    campaignAdmin,
                    0,
                    address(0), // no alternative withdrawal
                    INITIAL_FUNDING,
                    2 // uuid
                )
            )
        );
        vm.stopPrank();

        uint256 withdrawAmount = 1000e18;
        uint256 balanceBefore = rewardToken.balanceOf(campaignAdmin);

        vm.prank(campaignAdmin);
        campaign2.withdrawRewards(withdrawAmount);

        assertEq(rewardToken.balanceOf(campaignAdmin), balanceBefore + withdrawAmount);
    }

    function test_RevertWithdrawRewards_NotEnoughRewardsAvailable() public {
        uint256 toAmount = 100e18;
        createParticipation(alice, toAmount);

        uint256 totalBalance = rewardToken.balanceOf(address(campaign));
        uint256 pendingRewards = campaign.pendingRewards();
        uint256 accumulatedFees = campaign.accumulatedFees();
        uint256 availableForWithdrawal = totalBalance - pendingRewards - accumulatedFees;

        vm.prank(campaignAdmin);
        vm.expectRevert(INudgeCampaign.NotEnoughRewardsAvailable.selector);
        campaign.withdrawRewards(availableForWithdrawal + 1);
    }

    function test_RevertWithdrawRewards_Unauthorized() public {
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                alice,
                campaign.CAMPAIGN_ADMIN_ROLE()
            )
        );
        campaign.withdrawRewards(100e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                COLLECT FEES                              
    //////////////////////////////////////////////////////////////////////////*/

    function test_CollectFees_Success() public {
        uint256 toAmount = 1e18;
        createParticipation(alice, toAmount);

        uint256 expectedFees = campaign.accumulatedFees();
        uint256 treasuryBalanceBefore = rewardToken.balanceOf(treasury);

        vm.expectEmit(true, true, true, true);
        emit FeesCollected(expectedFees);

        vm.prank(nudgeAdmin);
        uint256 collectedFees = campaign.collectFees();

        assertEq(collectedFees, expectedFees);
        assertEq(campaign.accumulatedFees(), 0);
        assertEq(rewardToken.balanceOf(treasury), treasuryBalanceBefore + expectedFees);
    }

    function test_CollectFees_WhenPaused() public {
        uint256 toAmount = 100e18;
        createParticipation(alice, toAmount);

        address[] memory campaigns = new address[](1);
        campaigns[0] = address(campaign);

        vm.prank(nudgeAdmin);
        factory.pauseCampaigns(campaigns);

        uint256 expectedFees = campaign.accumulatedFees();

        vm.prank(nudgeAdmin);
        uint256 collectedFees = campaign.collectFees();

        assertEq(collectedFees, expectedFees);
        assertEq(campaign.accumulatedFees(), 0);
    }

    function test_RevertCollectFees_Unauthorized() public {
        vm.prank(alice);
        vm.expectRevert(IBaseNudgeCampaign.Unauthorized.selector);
        campaign.collectFees();
    }

    /*//////////////////////////////////////////////////////////////////////////
                            SET CAMPAIGN ACTIVE                              
    //////////////////////////////////////////////////////////////////////////*/

    function test_SetIsCampaignActive_Success() public {
        // First verify that the campaign is active by default
        assertTrue(campaign.isCampaignActive());

        // Now set it to inactive
        vm.expectEmit(true, true, true, true);
        emit CampaignStatusChanged(false);

        vm.prank(nudgeAdmin);
        campaign.setIsCampaignActive(false);

        assertFalse(campaign.isCampaignActive());
    }

    function test_RevertSetIsCampaignActive_BeforeStartTimestamp() public {
        deal(address(rewardToken), address(this), INITIAL_FUNDING);
        rewardToken.approve(address(factory), INITIAL_FUNDING);

        // Deploy campaign with future start
        address futureCampaign = factory.deployAndFundCampaign(
            HOLDING_PERIOD,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            block.timestamp + 1 days,
            alternativeWithdrawalAddress,
            INITIAL_FUNDING,
            2 // uuid
        );

        // Campaign should be inactive initially
        assertFalse(NudgeCampaign(payable(futureCampaign)).isCampaignActive());

        // Try to allocate but it should fail
        vm.startPrank(swapCaller);
        targetToken.approve(address(futureCampaign), type(uint256).max);

        vm.expectRevert(INudgeCampaign.StartDateNotReached.selector);
        NudgeCampaign(payable(futureCampaign)).handleReallocation(2, alice, address(targetToken), 100e18, "");
        vm.stopPrank();

        // Fast forward to after the start time
        vm.warp(block.timestamp + 1 days + 1);

        // Now allocation should work and also activate the campaign
        vm.startPrank(swapCaller);
        NudgeCampaign(payable(futureCampaign)).handleReallocation(2, alice, address(targetToken), 100e18, "");
        vm.stopPrank();

        // Verify the campaign is now active
        assertTrue(NudgeCampaign(payable(futureCampaign)).isCampaignActive());
    }

    function test_RevertSetIsCampaignActive_Unauthorized() public {
        vm.prank(address(factory));
        vm.expectRevert(IBaseNudgeCampaign.Unauthorized.selector);
        campaign.setIsCampaignActive(false);
    }

    function test_SetIsCampaignActive_BlocksNewParticipations() public {
        // First make campaign inactive
        vm.prank(nudgeAdmin);
        campaign.setIsCampaignActive(false);

        // Try to create new participation
        vm.prank(swapCaller);
        vm.expectRevert(INudgeCampaign.InactiveCampaign.selector);
        campaign.handleReallocation(1, alice, address(targetToken), 100e18, "");
    }

    /*//////////////////////////////////////////////////////////////////////////
                              RESCUE TOKENS                              
  //////////////////////////////////////////////////////////////////////////*/

    function test_RescueTokens_Success() public {
        // Create a new token to rescue (not the reward token)
        TestERC20 randomToken = new TestERC20("Random Token", "RT");
        uint256 amountToRescue = 1000e18;

        // Send tokens to the campaign contract
        randomToken.mintTo(amountToRescue, address(campaign));

        // Initial admin balance
        uint256 adminBalanceBefore = randomToken.balanceOf(nudgeAdmin);

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit INudgeCampaign.TokensRescued(address(randomToken), amountToRescue);

        // Call rescueTokens as Nudge admin
        vm.prank(nudgeAdmin);
        uint256 rescuedAmount = campaign.rescueTokens(address(randomToken));

        // Verify the amounts - tokens are sent to caller
        assertEq(rescuedAmount, amountToRescue);
        assertEq(randomToken.balanceOf(nudgeAdmin), adminBalanceBefore + amountToRescue);
        assertEq(randomToken.balanceOf(address(campaign)), 0);
    }

    function test_RescueNativeTokens() public {
        // Send ETH to the campaign
        uint256 amountToRescue = 2 ether;
        vm.deal(address(campaign), amountToRescue);

        // Get admin ETH balance before
        uint256 adminBalanceBefore = address(nudgeAdmin).balance;

        // Call rescueTokens as Nudge admin
        vm.startPrank(nudgeAdmin);
        address nativeToken = campaign.NATIVE_TOKEN();
        uint256 rescuedAmount = campaign.rescueTokens(nativeToken);
        vm.stopPrank();

        // Verify ETH was rescued to the admin
        assertEq(rescuedAmount, amountToRescue);
        assertEq(address(nudgeAdmin).balance, adminBalanceBefore + amountToRescue);
        assertEq(address(campaign).balance, 0);
    }

    function test_RevertRescueTokens_RewardToken() public {
        // Try to rescue reward token
        vm.prank(nudgeAdmin);
        vm.expectRevert(INudgeCampaign.CannotRescueRewardToken.selector);
        campaign.rescueTokens(address(rewardToken));
    }

    function test_RevertRescueTokens_Unauthorized() public {
        // Create a new token to rescue
        TestERC20 randomToken = new TestERC20("Random Token 3", "RT3");

        // Try to call rescueTokens as non-admin
        vm.prank(alice);
        vm.expectRevert(IBaseNudgeCampaign.Unauthorized.selector);
        campaign.rescueTokens(address(randomToken));
    }

    function test_RescueTargetToken() public {
        // Send target tokens directly to the campaign
        uint256 amountToRescue = 500e18;
        targetToken.mintTo(amountToRescue, address(campaign));

        // Target token should be allowed to be rescued since it's not the reward token
        uint256 adminBalanceBefore = targetToken.balanceOf(nudgeAdmin);

        vm.prank(nudgeAdmin);
        uint256 rescuedAmount = campaign.rescueTokens(address(targetToken));

        // Verify the target token was rescued to the admin
        assertEq(rescuedAmount, amountToRescue);
        assertEq(targetToken.balanceOf(nudgeAdmin), adminBalanceBefore + amountToRescue);
        assertEq(targetToken.balanceOf(address(campaign)), 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERACTION SCENARIOS                              
    //////////////////////////////////////////////////////////////////////////*/

    function test_AdminInteractions_CompleteScenario() public {
        // 1. Create multiple participations
        uint256 toAmount = 100e18;
        createParticipation(alice, toAmount);
        uint256 pID2 = createParticipation(bob, toAmount);
        createParticipation(alice, toAmount);

        // 2. Invalidate one participation
        uint256[] memory invalidatePIDs = new uint256[](1);
        invalidatePIDs[0] = pID2;

        vm.prank(operator);
        campaign.invalidateParticipations(invalidatePIDs);

        // 3. Collect fees
        uint256 expectedFees = campaign.accumulatedFees();
        assertTrue(expectedFees > 0);
        vm.prank(nudgeAdmin);
        campaign.collectFees();

        assertEq(campaign.accumulatedFees(), 0);

        // 4. Withdraw some rewards
        uint256 withdrawAmount = 1000e18;
        vm.prank(campaignAdmin);
        campaign.withdrawRewards(withdrawAmount);

        // 5. Set campaign inactive
        vm.prank(nudgeAdmin);
        campaign.setIsCampaignActive(false);

        // 6. Verify final state
        assertFalse(campaign.isCampaignActive());
        (IBaseNudgeCampaign.ParticipationStatus status2, , , , , ) = campaign.participations(pID2);
        assertEq(uint256(status2), uint256(IBaseNudgeCampaign.ParticipationStatus.INVALIDATED));
        assertEq(rewardToken.balanceOf(treasury), expectedFees);
        assertEq(rewardToken.balanceOf(alternativeWithdrawalAddress), withdrawAmount);
    }
}
