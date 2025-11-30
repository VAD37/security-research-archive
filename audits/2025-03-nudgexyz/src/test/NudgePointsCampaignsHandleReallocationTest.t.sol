// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../campaign/NudgePointsCampaigns.sol";
import {TestERC20} from "../mocks/TestERC20.sol";
import {INudgePointsCampaign, IBaseNudgeCampaign} from "../campaign/interfaces/INudgePointsCampaign.sol";

contract NudgePointsCampaignsHandleReallocationTest is Test {
    NudgePointsCampaigns public campaigns;
    address public admin;
    address public swapCaller;
    TestERC20 public token1;
    TestERC20 public token2;
    address public token1Address;
    address public token2Address;
    uint256 public constant CAMPAIGN_ID = 1;
    uint256 public constant CAMPAIGN_ID_2 = 2;
    uint32 public constant HOLDING_PERIOD = 7 days;
    address public user;
    address public nonAdmin;
    bytes emptyData = "";

    function setUp() public {
        admin = address(this);
        swapCaller = makeAddr("swapCaller");
        user = makeAddr("user");
        nonAdmin = makeAddr("nonAdmin");

        campaigns = new NudgePointsCampaigns(swapCaller);
        token1 = new TestERC20("Test Token 1", "TT1");
        token2 = new TestERC20("Test Token 2", "TT2");
        token1Address = address(token1);
        token2Address = address(token2);

        // Setup campaign
        campaigns.createPointsCampaign(CAMPAIGN_ID, HOLDING_PERIOD, token1Address);

        // Fund swapCaller
        token1.mintTo(1000 ether, swapCaller);
        vm.deal(swapCaller, 100 ether);
    }

    function test_HandleReallocation_WithERC20() public {
        uint256 amount = 100 ether;

        //balance of token1 before
        uint256 balanceBefore = token1.balanceOf(swapCaller);
        console.log("balanceBefore", balanceBefore);

        //allowance of token1 before
        uint256 allowanceBefore = token1.allowance(swapCaller, address(campaigns));
        console.log("allowanceBefore", allowanceBefore);

        vm.startPrank(swapCaller);
        token1.approve(address(campaigns), type(uint256).max);

        console.log("allowanceAfter", token1.allowance(swapCaller, address(campaigns)));
        console.log("amount", amount);

        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(CAMPAIGN_ID, user, 1, balanceBefore, 0, 0, emptyData);

        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount, emptyData);
        vm.stopPrank();

        // Verify all participation fields
        (
            IBaseNudgeCampaign.ParticipationStatus status,
            address userAddress,
            uint256 toAmount,
            uint256 rewardAmount,
            uint256 startTimestamp,
            uint256 startBlockNumber
        ) = campaigns.participations(CAMPAIGN_ID, 1);

        assertEq(uint8(status), uint8(IBaseNudgeCampaign.ParticipationStatus.HANDLED_OFFCHAIN));
        assertEq(userAddress, user);
        assertGe(toAmount, amount);
        assertEq(rewardAmount, 0);
        assertEq(startTimestamp, block.timestamp);
        assertEq(startBlockNumber, block.number);

        // Verify user received the tokens
        assertGe(token1.balanceOf(user), amount);
    }

    function test_HandleReallocation_WithETH() public {
        uint256 amount = 1 ether;

        // Setup campaign for ETH
        campaigns.createPointsCampaign(CAMPAIGN_ID_2, HOLDING_PERIOD, campaigns.NATIVE_TOKEN());

        uint256 ethBalanceBefore = swapCaller.balance;
        console.log("ethBalanceBefore", ethBalanceBefore);

        vm.startPrank(swapCaller);
        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(CAMPAIGN_ID_2, user, 1, amount, 0, 0, emptyData);

        campaigns.handleReallocation{value: amount}(CAMPAIGN_ID_2, user, campaigns.NATIVE_TOKEN(), amount, emptyData);
        vm.stopPrank();

        // Verify all participation fields
        (
            IBaseNudgeCampaign.ParticipationStatus status,
            address userAddress,
            uint256 toAmount,
            uint256 rewardAmount,
            uint256 startTimestamp,
            uint256 startBlockNumber
        ) = campaigns.participations(CAMPAIGN_ID_2, 1);

        assertEq(uint8(status), uint8(IBaseNudgeCampaign.ParticipationStatus.HANDLED_OFFCHAIN));
        assertEq(userAddress, user);
        assertGe(toAmount, amount);
        assertEq(rewardAmount, 0);
        assertEq(startTimestamp, block.timestamp);
        assertEq(startBlockNumber, block.number);

        // Verify ETH balances
        assertGe(user.balance, amount);
        assertEq(swapCaller.balance, ethBalanceBefore - amount);
    }

    function test_HandleReallocation_InsufficientAmountReverts() public {
        uint256 balance = token1.balanceOf(swapCaller);
        uint256 amount = balance + 1; // Promise more than what we have

        console.log("Balance", balance);
        console.log("Amount requested", amount);

        vm.startPrank(swapCaller);
        token1.approve(address(campaigns), type(uint256).max);
        console.log("Allowance", token1.allowance(swapCaller, address(campaigns)));

        vm.expectRevert(IBaseNudgeCampaign.InsufficientAmountReceived.selector);
        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount, emptyData);
        vm.stopPrank();
    }

    function test_HandleReallocation_UnauthorizedCallerReverts() public {
        uint256 amount = 100 ether;

        vm.startPrank(nonAdmin);
        token1.approve(address(campaigns), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonAdmin,
                campaigns.SWAP_CALLER_ROLE()
            )
        );
        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount, emptyData);
        vm.stopPrank();
    }

    function test_HandleReallocation_WhenPausedReverts() public {
        uint256 amount = 100 ether;

        // Pause campaign
        uint256[] memory campaignIds = new uint256[](1);
        campaignIds[0] = CAMPAIGN_ID;
        campaigns.pauseCampaigns(campaignIds);

        vm.startPrank(swapCaller);
        token1.approve(address(campaigns), type(uint256).max);

        vm.expectRevert(IBaseNudgeCampaign.CampaignPaused.selector);
        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount, emptyData);
        vm.stopPrank();
    }

    function test_HandleReallocation_InvalidTokenReverts() public {
        address wrongToken = makeAddr("wrongToken");
        uint256 amount = 100 ether;

        vm.startPrank(swapCaller);
        vm.expectRevert(abi.encodeWithSelector(IBaseNudgeCampaign.InvalidToTokenReceived.selector, wrongToken));
        campaigns.handleReallocation(CAMPAIGN_ID, user, wrongToken, amount, emptyData);
        vm.stopPrank();
    }

    function test_HandleReallocation_IncrementsPID() public {
        uint256 expectedNewPID = 1;

        vm.startPrank(swapCaller);
        uint256 amount = token1.balanceOf(swapCaller);

        token1.approve(address(campaigns), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(CAMPAIGN_ID, user, expectedNewPID, amount, 0, 0, emptyData);

        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount, emptyData);
        vm.stopPrank();

        // Verify pID is incremented
        (
            IBaseNudgeCampaign.ParticipationStatus status,
            address userAddress,
            uint256 toAmount,
            uint256 rewardAmount,
            uint256 startTimestamp,
            uint256 startBlockNumber
        ) = campaigns.participations(CAMPAIGN_ID, expectedNewPID);

        assertEq(uint8(status), uint8(IBaseNudgeCampaign.ParticipationStatus.HANDLED_OFFCHAIN));
        assertEq(userAddress, user);
        assertGe(toAmount, amount);
        assertEq(rewardAmount, 0);
        assertEq(startTimestamp, block.timestamp);
        assertEq(startBlockNumber, block.number);
    }

    // Two reallocations in a row increments the PID twice
    function test_HandleReallocationIncrementsPIDTwice() public {
        vm.startPrank(swapCaller);
        token1.approve(address(campaigns), type(uint256).max);

        uint256 amount1 = token1.balanceOf(swapCaller);
        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount1, emptyData);

        uint256 amount2 = 18 ether;
        token1.mintTo(amount2, swapCaller);
        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount2, emptyData);

        vm.stopPrank();

        (IBaseNudgeCampaign.ParticipationStatus status, , uint256 toAmount, , , ) = campaigns.participations(
            CAMPAIGN_ID,
            1
        );

        assertEq(uint8(status), uint8(IBaseNudgeCampaign.ParticipationStatus.HANDLED_OFFCHAIN));
        assertEq(toAmount, amount1);

        (status, , toAmount, , , ) = campaigns.participations(CAMPAIGN_ID, 2);

        assertEq(uint8(status), uint8(IBaseNudgeCampaign.ParticipationStatus.HANDLED_OFFCHAIN));
        assertEq(toAmount, amount2);
    }

    function test_HandleReallocation_UpdatesCurrentPID() public {
        // Before any participation, pID should be 0
        (, , uint256 startingPID, ) = campaigns.campaigns(CAMPAIGN_ID);
        assertEq(startingPID, 0);

        vm.startPrank(swapCaller);

        // First reallocation...
        uint256 amount1 = token1.balanceOf(swapCaller);
        token1.approve(address(campaigns), type(uint256).max);

        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount1, emptyData);

        // ... updates the current/latest pID to 1
        (, , uint256 updatedPID, ) = campaigns.campaigns(CAMPAIGN_ID);
        assertEq(updatedPID, 1);

        // Second reallocation...
        uint256 amount2 = 97 ether;
        token1.mintTo(amount2, swapCaller);
        campaigns.handleReallocation(CAMPAIGN_ID, user, token1Address, amount2, emptyData);

        // ... updates the current/latest pID to 2
        (, , uint256 newPID, ) = campaigns.campaigns(CAMPAIGN_ID);
        assertEq(newPID, 2);
    }

    function test_HandleReallocation_ExtraNativeTokensSentReverts() public {
        uint256 amount = 100 ether;
        address nativeToken = campaigns.NATIVE_TOKEN();
        vm.prank(swapCaller);
        vm.expectRevert(abi.encodeWithSelector(IBaseNudgeCampaign.InvalidToTokenReceived.selector, nativeToken));
        campaigns.handleReallocation{value: 1 ether}(CAMPAIGN_ID, user, token1Address, amount, "");
    }
}
