// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {NudgeCampaign} from "../campaign/NudgeCampaign.sol";
import {NudgeCampaignFactory} from "../campaign/NudgeCampaignFactory.sol";
import {INudgeCampaign, IBaseNudgeCampaign} from "../campaign/interfaces/INudgeCampaign.sol";
import "../mocks/TestERC20.sol";
import {console} from "forge-std/console.sol";

contract NudgeCampaignReallocationTest is Test {
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

    uint16 constant DEFAULT_FEE_BPS = 1000; // 10%
    uint32 constant HOLDING_PERIOD = 7 days;
    uint256 constant REWARD_PPQ = 2e13;
    uint256 constant INITIAL_FUNDING = 100_000e18;
    uint256 constant PPQ_DENOMINATOR = 1e15;
    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        // Deploy tokens
        targetToken = new TestERC20("Target Token", "TT");
        rewardToken = new TestERC20("Reward Token", "RT");

        // Deploy factory with roles
        factory = new NudgeCampaignFactory(treasury, nudgeAdmin, operator, swapCaller);

        // Fund test contract and approve factory
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

    function test_HandleReallocation_Success() public {
        uint256 toAmount = 100e18;
        bytes memory data = "";

        deal(address(targetToken), swapCaller, toAmount);
        vm.startPrank(swapCaller);
        targetToken.approve(address(campaign), toAmount);

        uint256 expectedPID = campaign.pID() + 1;
        uint256 expectedRewardAmount = campaign.getRewardAmountIncludingFees(toAmount);
        (uint256 expectedUserRewards, uint256 expectedFees) = campaign.calculateUserRewardsAndFees(
            expectedRewardAmount
        );

        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(
            1,
            alice,
            expectedPID,
            toAmount,
            expectedUserRewards,
            expectedFees,
            data
        );

        uint256 expectedStartTimestamp = block.timestamp;
        uint256 expectedBlockNumber = block.number;

        campaign.handleReallocation(1, alice, address(targetToken), toAmount, data);
        vm.stopPrank();

        // Verify participation details against Participation struct construction
        (
            IBaseNudgeCampaign.ParticipationStatus status,
            address participantAddr,
            uint256 amount,
            uint256 rewardAmount,
            uint256 startTs,
            uint256 blockNum
        ) = campaign.participations(expectedPID);

        // Verify each field matches the Participation struct assignment
        assertEq(uint256(status), uint256(IBaseNudgeCampaign.ParticipationStatus.PARTICIPATING));
        assertEq(participantAddr, alice); // userAddress in struct
        assertEq(amount, toAmount); // amountReceived in struct
        assertEq(rewardAmount, expectedUserRewards); // userRewards in struct
        assertEq(startTs, expectedStartTimestamp); // block.timestamp in struct
        assertEq(blockNum, expectedBlockNumber); // block.number in struct
    }

    function test_HandleReallocation_WithNativeToken_Success() public {
        // Deploy campaign with ETH as target token
        rewardToken.mintTo(INITIAL_FUNDING, address(this));
        rewardToken.approve(address(factory), INITIAL_FUNDING);

        NudgeCampaign nativeCampaign = NudgeCampaign(
            payable(
                factory.deployAndFundCampaign(
                    HOLDING_PERIOD,
                    NATIVE_TOKEN,
                    address(rewardToken),
                    REWARD_PPQ,
                    campaignAdmin,
                    0,
                    alternativeWithdrawalAddress,
                    INITIAL_FUNDING,
                    2
                )
            )
        );

        uint256 toAmount = 1 ether;
        bytes memory data = "";

        // Fund swapCaller with ETH
        vm.deal(swapCaller, toAmount);

        uint256 expectedPID = nativeCampaign.pID() + 1;
        uint256 expectedRewardAmount = nativeCampaign.getRewardAmountIncludingFees(toAmount);
        (uint256 expectedUserRewards, uint256 expectedFees) = campaign.calculateUserRewardsAndFees(
            expectedRewardAmount
        );

        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(
            2,
            alice,
            expectedPID,
            toAmount,
            expectedUserRewards,
            expectedFees,
            data
        );

        uint256 expectedStartTimestamp = block.timestamp;
        uint256 expectedBlockNumber = block.number;

        // Execute reallocation with ETH
        vm.prank(swapCaller);
        nativeCampaign.handleReallocation{value: toAmount}(2, alice, NATIVE_TOKEN, toAmount, data);

        // Verify participation details against Participation struct construction
        (
            IBaseNudgeCampaign.ParticipationStatus status,
            address participantAddr,
            uint256 amount,
            uint256 rewardAmount,
            uint256 startTs,
            uint256 blockNum
        ) = nativeCampaign.participations(expectedPID);

        // Verify each field matches the Participation struct assignment
        assertEq(uint256(status), uint256(IBaseNudgeCampaign.ParticipationStatus.PARTICIPATING));
        assertEq(participantAddr, alice); // userAddress in struct
        assertEq(amount, toAmount); // amountReceived in struct
        assertEq(rewardAmount, expectedUserRewards); // userRewards in struct
        assertEq(startTs, expectedStartTimestamp); // block.timestamp in struct
        assertEq(blockNum, expectedBlockNumber); // block.number in struct

        assertEq(alice.balance, toAmount); // Verify ETH was transferred to alice
    }

    function test_HandleReallocation_WithNativeTokenNativeRewards_Success() public {
        // Deploy campaign with ETH as target token and reward token
        vm.deal(address(this), INITIAL_FUNDING);
        NudgeCampaign nativeCampaign = NudgeCampaign(
            payable(
                factory.deployAndFundCampaign{value: INITIAL_FUNDING}(
                    HOLDING_PERIOD,
                    NATIVE_TOKEN,
                    NATIVE_TOKEN,
                    REWARD_PPQ,
                    campaignAdmin,
                    0,
                    alternativeWithdrawalAddress,
                    INITIAL_FUNDING,
                    2
                )
            )
        );

        uint256 toAmount = 1 ether;
        bytes memory data = "";

        // Fund swapCaller with ETH
        vm.deal(swapCaller, toAmount);

        uint256 expectedPID = nativeCampaign.pID() + 1;
        uint256 expectedRewardAmount = nativeCampaign.getRewardAmountIncludingFees(toAmount);
        (uint256 expectedUserRewards, uint256 expectedFees) = campaign.calculateUserRewardsAndFees(
            expectedRewardAmount
        );

        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(
            2,
            alice,
            expectedPID,
            toAmount,
            expectedUserRewards,
            expectedFees,
            data
        );

        uint256 expectedStartTimestamp = block.timestamp;
        uint256 expectedBlockNumber = block.number;

        // Execute reallocation with ETH
        vm.prank(swapCaller);
        nativeCampaign.handleReallocation{value: toAmount}(2, alice, NATIVE_TOKEN, toAmount, data);

        // Verify participation details against Participation struct construction
        (
            IBaseNudgeCampaign.ParticipationStatus status,
            address participantAddr,
            uint256 amount,
            uint256 rewardAmount,
            uint256 startTs,
            uint256 blockNum
        ) = nativeCampaign.participations(expectedPID);

        // Verify each field matches the Participation struct assignment
        assertEq(uint256(status), uint256(IBaseNudgeCampaign.ParticipationStatus.PARTICIPATING));
        assertEq(participantAddr, alice); // userAddress in struct
        assertEq(amount, toAmount); // amountReceived in struct
        assertEq(rewardAmount, expectedUserRewards); // userRewards in struct
        assertEq(startTs, expectedStartTimestamp); // block.timestamp in struct
        assertEq(blockNum, expectedBlockNumber); // block.number in struct

        assertEq(alice.balance, toAmount); // Verify ETH was transferred to alice
    }

    function test_RevertHandleReallocation_UnauthorizedSwapCaller() public {
        vm.prank(alice);
        vm.expectRevert(IBaseNudgeCampaign.UnauthorizedSwapCaller.selector);
        campaign.handleReallocation(1, alice, address(targetToken), 100e18, "");
    }

    function test_RevertHandleReallocation_InactiveCampaign() public {
        // Deactivate campaign
        vm.prank(nudgeAdmin);
        campaign.setIsCampaignActive(false);

        vm.prank(swapCaller);
        vm.expectRevert(INudgeCampaign.InactiveCampaign.selector);
        campaign.handleReallocation(1, alice, address(targetToken), 100e18, "");
    }

    function test_RevertHandleReallocation_PausedCampaign() public {
        address[] memory campaigns = new address[](1);
        campaigns[0] = address(campaign);

        vm.prank(nudgeAdmin);
        factory.pauseCampaigns(campaigns);

        vm.prank(swapCaller);
        vm.expectRevert(IBaseNudgeCampaign.CampaignPaused.selector);
        campaign.handleReallocation(1, alice, address(targetToken), 100e18, "");
    }

    function test_RevertHandleReallocation_InvalidToken() public {
        TestERC20 invalidToken = new TestERC20("Invalid Token", "IT");

        vm.prank(swapCaller);
        vm.expectRevert(
            abi.encodeWithSelector(IBaseNudgeCampaign.InvalidToTokenReceived.selector, address(invalidToken))
        );
        campaign.handleReallocation(1, alice, address(invalidToken), 100e18, "");
    }

    function test_HandleReallocation_ExtraNativeTokensSentReverts() public {
        uint256 toAmount = 100 ether;
        address nativeToken = campaign.NATIVE_TOKEN();
        vm.deal(swapCaller, 1 ether);

        vm.startPrank(swapCaller);
        vm.expectRevert(abi.encodeWithSelector(IBaseNudgeCampaign.InvalidToTokenReceived.selector, nativeToken));
        campaign.handleReallocation{value: 1 ether}(1, alice, address(targetToken), toAmount, "");
        vm.stopPrank();
    }

    function test_RevertHandleReallocation_InsufficientAmount() public {
        uint256 toAmount = 100e18;
        uint256 transferAmount = toAmount - 1; // Transfer less than specified

        deal(address(targetToken), swapCaller, transferAmount);
        vm.startPrank(swapCaller);
        targetToken.approve(address(campaign), transferAmount);

        vm.expectRevert(IBaseNudgeCampaign.InsufficientAmountReceived.selector);
        campaign.handleReallocation(1, alice, address(targetToken), toAmount, "");
        vm.stopPrank();
    }

    function test_RevertHandleReallocation_InsufficientNativeToken() public {
        // Deploy campaign with ETH as target token
        rewardToken.mintTo(INITIAL_FUNDING, address(this));
        rewardToken.approve(address(factory), INITIAL_FUNDING);

        NudgeCampaign nativeCampaign = NudgeCampaign(
            payable(
                factory.deployAndFundCampaign(
                    HOLDING_PERIOD,
                    NATIVE_TOKEN,
                    address(rewardToken),
                    REWARD_PPQ,
                    campaignAdmin,
                    0,
                    alternativeWithdrawalAddress,
                    INITIAL_FUNDING,
                    2
                )
            )
        );

        uint256 toAmount = 1 ether;
        uint256 sentAmount = 0.9 ether; // Send less than required

        // Fund swapCaller with insufficient ETH
        vm.deal(swapCaller, sentAmount);

        vm.prank(swapCaller);
        vm.expectRevert(IBaseNudgeCampaign.InsufficientAmountReceived.selector);
        nativeCampaign.handleReallocation{value: sentAmount}(2, alice, NATIVE_TOKEN, toAmount, "");
    }

    function test_RevertHandleReallocation_NotEnoughRewards() public {
        // Deploy campaign with minimal funding
        rewardToken.mintTo(1e18, address(this));
        rewardToken.approve(address(factory), 1e18);
        NudgeCampaign lowFundedCampaign = NudgeCampaign(
            payable(
                factory.deployAndFundCampaign(
                    HOLDING_PERIOD,
                    address(targetToken),
                    address(rewardToken),
                    REWARD_PPQ,
                    campaignAdmin,
                    0,
                    alternativeWithdrawalAddress,
                    1e18,
                    2
                )
            )
        );

        // Try to reallocate large amount that would require more rewards than available
        uint256 largeAmount = 1000e18;
        deal(address(targetToken), swapCaller, largeAmount);
        vm.startPrank(swapCaller);
        targetToken.approve(address(lowFundedCampaign), largeAmount);

        vm.expectRevert(INudgeCampaign.NotEnoughRewardsAvailable.selector);
        lowFundedCampaign.handleReallocation(2, alice, address(targetToken), largeAmount, "");
        vm.stopPrank();
    }

    function test_HandleReallocation_MultipleTimes() public {
        uint256 toAmount = 100e18;
        bytes memory data = "";

        // First reallocation
        deal(address(targetToken), swapCaller, toAmount);
        vm.prank(swapCaller);
        campaign.handleReallocation(1, alice, address(targetToken), toAmount, data);

        uint256 firstPID = campaign.pID();

        // Second reallocation
        deal(address(targetToken), swapCaller, toAmount);
        vm.prank(swapCaller);
        campaign.handleReallocation(1, bob, address(targetToken), toAmount, data);

        uint256 secondPID = campaign.pID();

        assertEq(secondPID, firstPID + 1);
        assertEq(campaign.totalReallocatedAmount(), toAmount * 2);
    }

    //Test separated to avoid stack too deep error
    function test_HandleReallocation_EventEmission() public {
        uint256 toAmount = 100e18;
        bytes memory data = "";

        deal(address(targetToken), swapCaller, toAmount);
        vm.startPrank(swapCaller);
        targetToken.approve(address(campaign), toAmount);

        uint256 expectedPID = campaign.pID() + 1;
        uint256 expectedRewardAmount = campaign.getRewardAmountIncludingFees(toAmount);
        (uint256 expectedUserRewards, uint256 expectedFees) = campaign.calculateUserRewardsAndFees(
            expectedRewardAmount
        );

        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(
            1, // campaignId
            alice, // userAddress
            expectedPID, // pID
            toAmount, // amountReceived
            expectedUserRewards, // userRewards
            expectedFees, // fees
            data // data
        );

        campaign.handleReallocation(1, alice, address(targetToken), toAmount, data);
        vm.stopPrank();
    }

    //Test separated to avoid stack too deep error
    function test_HandleReallocation_WithNativeToken_EventEmission() public {
        rewardToken.mintTo(INITIAL_FUNDING, address(this));
        rewardToken.approve(address(factory), INITIAL_FUNDING);

        NudgeCampaign nativeCampaign = NudgeCampaign(
            payable(
                factory.deployAndFundCampaign(
                    HOLDING_PERIOD,
                    NATIVE_TOKEN,
                    address(rewardToken),
                    REWARD_PPQ,
                    campaignAdmin,
                    0,
                    alternativeWithdrawalAddress,
                    INITIAL_FUNDING,
                    2
                )
            )
        );

        uint256 toAmount = 1 ether;
        bytes memory data = "";
        vm.deal(swapCaller, toAmount);

        uint256 expectedPID = nativeCampaign.pID() + 1;
        uint256 expectedRewardAmount = nativeCampaign.getRewardAmountIncludingFees(toAmount);
        (uint256 expectedUserRewards, uint256 expectedFees) = campaign.calculateUserRewardsAndFees(
            expectedRewardAmount
        );

        vm.expectEmit(true, true, true, true);
        emit IBaseNudgeCampaign.NewParticipation(
            2, // campaignId
            alice, // userAddress
            expectedPID, // pID
            toAmount, // amountReceived
            expectedUserRewards, // userRewards
            expectedFees, // fees
            data // data
        );

        vm.prank(swapCaller);
        nativeCampaign.handleReallocation{value: toAmount}(2, alice, NATIVE_TOKEN, toAmount, data);
    }
}
