// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {NudgeCampaignFactory} from "../campaign/NudgeCampaignFactory.sol";
import {NudgeCampaign} from "../campaign/NudgeCampaign.sol";
import {INudgeCampaign} from "../campaign/interfaces/INudgeCampaign.sol";
import {INudgeCampaignFactory} from "../campaign/interfaces/INudgeCampaignFactory.sol";
import {TestERC20} from "../mocks/TestERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import {console} from "forge-std/console.sol";

contract NudgeCampaignFactoryTest is Test {
    NudgeCampaignFactory factory;
    TestERC20 targetToken;
    TestERC20 rewardToken;

    address admin = address(1);
    address operator = address(2);
    address swapCaller = address(3);
    address treasury = address(4);
    address campaignAdmin = address(5);
    address endUserOne = address(6);

    uint16 DEFAULT_FEE_BPS = 1000;

    uint256 uuidOne = 1;
    uint256 randomUUID = 12_345;

    uint32 holdingPeriod = 7 days;
    uint256 constant REWARD_PPQ = 1e14;
    uint256 startTimestamp = block.timestamp + 1;
    address withdrawalAddress = address(0);

    bytes32 operatorRole;

    function setUp() public {
        targetToken = new TestERC20("Target Token", "TGT");
        rewardToken = new TestERC20("Reward Token", "RWD");
        factory = new NudgeCampaignFactory(treasury, admin, operator, swapCaller);
        operatorRole = factory.NUDGE_OPERATOR_ROLE();
    }

    function simulateReallocation(address campaign, uint256 toAmount, uint256 uuid) public {
        NudgeCampaign campaignInstance = NudgeCampaign(payable(campaign));

        targetToken.mintTo(toAmount, swapCaller);

        vm.prank(swapCaller);
        targetToken.approve(address(campaign), 1_000_000e18);

        vm.prank(swapCaller);
        campaignInstance.handleReallocation(uuid, endUserOne, address(targetToken), toAmount, "");
    }

    function test_Constructor() public view {
        // Test successful construction (already happens in setUp())
        assertEq(factory.nudgeTreasuryAddress(), treasury);
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.NUDGE_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), operator));
        assertTrue(factory.hasRole(factory.SWAP_CALLER_ROLE(), swapCaller));
    }

    function test_ConstructorZeroTreasury() public {
        vm.expectRevert(INudgeCampaignFactory.InvalidTreasuryAddress.selector);
        new NudgeCampaignFactory(
            address(0), // treasury
            admin,
            operator,
            swapCaller
        );
    }

    function test_ConstructorZeroAdmin() public {
        vm.expectRevert(INudgeCampaignFactory.ZeroAddress.selector);
        new NudgeCampaignFactory(
            treasury,
            address(0), // admin
            operator,
            swapCaller
        );
    }

    function test_ConstructorZeroOperator() public {
        vm.expectRevert(INudgeCampaignFactory.ZeroAddress.selector);
        new NudgeCampaignFactory(
            treasury,
            admin,
            address(0), // operator
            swapCaller
        );
    }

    function test_ConstructorZeroSwapCaller() public {
        vm.expectRevert(INudgeCampaignFactory.ZeroAddress.selector);
        new NudgeCampaignFactory(
            treasury,
            admin,
            operator,
            address(0) // swapCaller
        );
    }

    function test_DeploymentValidation() public {
        vm.expectRevert(); // Zero address for campaign admin
        factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            address(0),
            startTimestamp,
            withdrawalAddress,
            uuidOne
        );

        vm.expectRevert(); // Zero address for target token
        factory.deployCampaign(
            holdingPeriod,
            address(0),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            1
        );

        vm.expectRevert(); // Zero holding period
        factory.deployCampaign(
            0,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            1
        );

        vm.expectRevert(); // Zero address for campaign admin
        factory.deployAndFundCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            address(0),
            startTimestamp,
            withdrawalAddress,
            0, // initialRewardAmount
            uuidOne
        );

        vm.expectRevert(); // Zero address for target token
        factory.deployAndFundCampaign(
            holdingPeriod,
            address(0),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            0, // initialRewardAmount
            uuidOne
        );

        vm.expectRevert(); // Zero holding period
        factory.deployAndFundCampaign(
            0,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            0, // initialRewardAmount
            uuidOne
        );
    }

    function test_PredictAndDeployCampaign() public {
        address predicted = factory.getCampaignAddress(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            DEFAULT_FEE_BPS,
            withdrawalAddress,
            randomUUID
        );

        address deployed = factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            randomUUID
        );

        assertEq(predicted, deployed, "Predicted address should match deployed address");
        assertTrue(factory.isCampaign(deployed), "Address should be tracked as campaign");
    }

    function test_GetCampaignAddressAfterFeeUpdate() public {
        address campaignOne = factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            randomUUID
        );

        // Update fee
        uint16 newFeeBps = DEFAULT_FEE_BPS * 2;
        vm.prank(admin);
        factory.updateFeeSetting(newFeeBps);

        address campaignTwo = factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            randomUUID
        );

        address campaignOnePredicted = factory.getCampaignAddress(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            DEFAULT_FEE_BPS,
            withdrawalAddress,
            randomUUID
        );

        address campaignTwoPredicted = factory.getCampaignAddress(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            newFeeBps,
            withdrawalAddress,
            randomUUID
        );

        assertEq(campaignOne, campaignOnePredicted, "Campaign 1 address should match predicted address");
        assertEq(campaignTwo, campaignTwoPredicted, "Campaign 2 address should match predicted address");
    }

    function test_UpdateFeeSetting_Event() public {
        uint16 newFeeBps = 2000; // 20%

        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit INudgeCampaignFactory.FeeUpdated(DEFAULT_FEE_BPS, newFeeBps);
        factory.updateFeeSetting(newFeeBps);

        assertEq(factory.FEE_BPS(), newFeeBps, "Fee should be updated");
    }

    function test_UniqueAddressesWithDifferentParameters() public {
        // Deploy first campaign
        address campaign1 = factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            uuidOne
        );

        // Deploy second campaign with different holding period
        address campaign2 = factory.deployCampaign(
            holdingPeriod * 2,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            uuidOne
        );

        assertTrue(campaign1 != campaign2, "Campaigns with different parameters should have different addresses");
    }

    function test_DeploymentConsistency() public {
        // First deployment
        factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            randomUUID
        );

        // Try deploying with same parameters - should revert due to CREATE2 collision
        vm.expectRevert();
        factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            randomUUID
        );
    }

    function test_DeploymentWithMaxValues() public {
        // Test deployment with maximum values
        address campaign = factory.deployCampaign(
            type(uint32).max,
            address(targetToken),
            address(rewardToken),
            type(uint256).max,
            campaignAdmin,
            type(uint256).max,
            withdrawalAddress,
            type(uint256).max
        );

        assertTrue(factory.isCampaign(campaign), "Campaign with max values should be tracked");

        {
            (
                uint32 _holdingPeriod,
                address _targetToken,
                address _rewardToken,
                uint256 _rewardPPQ,
                uint256 _startTimestamp,
                bool isCampaignActive,
                uint256 pendingRewards,
                uint256 totalReallocatedAmount,
                uint256 distributedRewards,
                uint256 claimableRewards
            ) = NudgeCampaign(payable(campaign)).getCampaignInfo();
            assertEq(_holdingPeriod, type(uint32).max, "Holding period should match max value");
            assertEq(_targetToken, address(targetToken), "Target token should match");
            assertEq(_rewardToken, address(rewardToken), "Reward token should match");
            assertEq(_rewardPPQ, type(uint256).max, "Reward PPQ should match");
            assertEq(_startTimestamp, type(uint256).max, "Start timestamp should match max value");
            //campaign should not be active since start date is in the future
            assertFalse(isCampaignActive, "Campaign should be inactive when start time is in the future");
            assertEq(pendingRewards, 0, "Pending rewards should be 0");
            assertEq(totalReallocatedAmount, 0, "Total reallocated amount should be 0");
            assertEq(distributedRewards, 0, "Distributed rewards should be 0");
            assertEq(claimableRewards, 0, "Claimable rewards should be 0");
        }
    }

    function test_CampaignAddressesArray() public {
        // Test campaign addresses array maintenance
        uint256 initialCount = factory.getCampaignCount();

        // Deploy multiple campaigns
        uint256 numCampaigns = 3;
        address[] memory deployedCampaigns = new address[](numCampaigns);

        for (uint256 i = 0; i < numCampaigns; i++) {
            deployedCampaigns[i] = factory.deployCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                startTimestamp,
                withdrawalAddress,
                i + 1
            );
        }

        // Verify array length
        assertEq(factory.getCampaignCount(), initialCount + numCampaigns, "Campaign count should increase correctly");

        // Verify array contents
        for (uint256 i = 0; i < numCampaigns; i++) {
            assertEq(
                factory.campaignAddresses(initialCount + i),
                deployedCampaigns[i],
                "Campaign address should be stored in correct order"
            );
            assertTrue(factory.isCampaign(deployedCampaigns[i]), "Campaign should be marked as valid");
        }
    }

    function test_DeployAndFundWithERC20() public {
        uint256 initialReward = 10_000e18;

        rewardToken.mintTo(initialReward, address(this));
        rewardToken.approve(address(factory), initialReward);

        address campaign = factory.deployAndFundCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            initialReward,
            randomUUID
        );

        assertEq(IERC20(rewardToken).balanceOf(campaign), initialReward, "Campaign should be funded with ERC20");

        //call getCampaignInfo
        (
            uint32 _holdingPeriod,
            address _targetToken,
            address _rewardToken,
            uint256 _rewardPPQ,
            uint256 _startTimestamp,
            bool isCampaignActive,
            uint256 pendingRewards,
            uint256 totalReallocatedAmount,
            uint256 distributedRewards,
            uint256 claimableRewards
        ) = NudgeCampaign(payable(campaign)).getCampaignInfo();
        assertEq(_holdingPeriod, holdingPeriod, "Holding period should match");
        assertEq(_targetToken, address(targetToken), "Target token should match");
        assertEq(_rewardToken, address(rewardToken), "Reward token should match");
        assertEq(_rewardPPQ, REWARD_PPQ, "Reward PPQ should match");
        assertEq(_startTimestamp, startTimestamp, "Start timestamp should be equal to initial reward");
        assertEq(
            isCampaignActive,
            startTimestamp <= block.timestamp,
            "Campaign should be active only if start time is now or in the past"
        );
        assertEq(pendingRewards, 0, "Pending rewards should be 0");
        assertEq(totalReallocatedAmount, 0, "Total reallocated amount should be 0");
        assertEq(distributedRewards, 0, "Distributed rewards should be 0");
        assertEq(claimableRewards, initialReward, "Claimable rewards should be equal to initial reward");
    }

    function test_DeployAndFundWithERC20_ExtraNativeTokenSentReverts() public {
        uint256 initialReward = 10_000e18;

        rewardToken.mintTo(initialReward, address(this));
        rewardToken.approve(address(factory), initialReward);

        address campaign = factory.deployAndFundCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            initialReward,
            randomUUID
        );

        // Try sending extra native token
        vm.expectRevert(INudgeCampaignFactory.IncorrectEtherAmount.selector);
        factory.deployAndFundCampaign{value: 1 ether}(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            initialReward,
            randomUUID + 1
        );
    }

    function test_DeployAndFundWithNative() public {
        uint256 initialReward = 1 ether;

        address campaign = factory.deployAndFundCampaign{value: initialReward}(
            holdingPeriod,
            address(targetToken),
            factory.NATIVE_TOKEN(),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            initialReward,
            randomUUID
        );

        assertEq(address(campaign).balance, initialReward, "Campaign should be funded with native token");

        //call getCampaignInfo
        (
            uint32 _holdingPeriod,
            address _targetToken,
            address _rewardToken,
            uint256 _rewardPPQ,
            uint256 _startTimestamp,
            bool isCampaignActive,
            uint256 pendingRewards,
            uint256 totalReallocatedAmount,
            uint256 distributedRewards,
            uint256 claimableRewards
        ) = NudgeCampaign(payable(campaign)).getCampaignInfo();
        assertEq(_holdingPeriod, holdingPeriod, "Holding period should match");
        assertEq(_targetToken, address(targetToken), "Target token should match");
        assertEq(_rewardToken, factory.NATIVE_TOKEN(), "Reward token should match");
        assertEq(_rewardPPQ, REWARD_PPQ, "Reward BPS should match");
        assertEq(_startTimestamp, startTimestamp, "Start timestamp should be equal to initial reward");
        assertEq(
            isCampaignActive,
            startTimestamp <= block.timestamp,
            "Campaign should be active only if start time is now or in the past"
        );
        assertEq(pendingRewards, 0, "Pending rewards should be 0");
        assertEq(totalReallocatedAmount, 0, "Total reallocated amount sould be 0");
        assertEq(distributedRewards, 0, "Distributed rewards should be 0");
        assertEq(claimableRewards, initialReward, "Claimable rewards should be equal to initial reward");
    }

    function test_IncorrectNativeAmount() public {
        uint256 initialReward = 1 ether;
        address nativeToken = factory.NATIVE_TOKEN();

        // Test underpayment
        vm.expectRevert(INudgeCampaignFactory.IncorrectEtherAmount.selector);
        factory.deployAndFundCampaign{value: initialReward - 1}(
            holdingPeriod,
            address(targetToken),
            nativeToken,
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            initialReward,
            randomUUID
        );

        assertEq(address(factory).balance, 0, "Factory balance should be 0");
    }
    // Test overpayment
    function test_IncorrectGreaterNativeAmount() public {
        uint256 initialReward = 1 ether;
        address nativeToken = factory.NATIVE_TOKEN();

        vm.expectRevert(INudgeCampaignFactory.IncorrectEtherAmount.selector);
        factory.deployAndFundCampaign{value: initialReward + 1 ether}(
            holdingPeriod,
            address(targetToken),
            nativeToken,
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            initialReward,
            randomUUID
        );

        assertEq(address(factory).balance, 0, "Factory balance should be 0");
    }

    function test_DeployAndFundWithZeroAmount() public {
        // Test with ERC20
        address campaignERC20 = factory.deployAndFundCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            0, // zero initial reward
            randomUUID
        );

        assertEq(IERC20(rewardToken).balanceOf(campaignERC20), 0, "Campaign should have zero ERC20 balance");

        // Test with Native token
        address campaignNative = factory.deployAndFundCampaign{value: 0}(
            holdingPeriod,
            address(targetToken),
            factory.NATIVE_TOKEN(),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            0, // zero initial reward
            randomUUID + 1
        );

        assertEq(address(campaignNative).balance, 0, "Campaign should have zero ETH balance");
    }

    function test_CollectFees() public {
        // Deploy and fund 2 campaigns
        uint256 initialReward = 10_000e18;

        rewardToken.mintTo(initialReward * 2, address(this));
        rewardToken.approve(address(factory), initialReward * 2);

        address payable campaignOne = payable(
            factory.deployAndFundCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                0,
                withdrawalAddress,
                initialReward,
                1
            )
        );

        address payable campaignTwo = payable(
            factory.deployAndFundCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                0,
                withdrawalAddress,
                initialReward,
                2
            )
        );

        // Generate fees
        uint256 toAmount = 100e18;
        // 10% are granted in rewards, so rewardAmount = 10e18
        // 10% of the reward amount is collected as fees, so the total for 2 reallocations is 1e18 * 2;
        uint256 totalExpectedFees = 1e18 * 2;

        simulateReallocation(campaignOne, toAmount, 1);
        simulateReallocation(campaignTwo, toAmount, 2);

        uint256 treasuryBalanceBefore = rewardToken.balanceOf(treasury);

        // Collect fees
        address[] memory campaigns = new address[](2);
        campaigns[0] = campaignOne;
        campaigns[1] = campaignTwo;

        vm.prank(operator);
        vm.expectEmit(true, true, true, true);
        emit INudgeCampaignFactory.FeesCollected(campaigns, totalExpectedFees);
        factory.collectFeesFromCampaigns(campaigns);

        uint256 treasuryBalanceAfter = rewardToken.balanceOf(treasury);

        assertTrue(treasuryBalanceAfter > treasuryBalanceBefore, "Treasury balance should be higher");
        assertEq(treasuryBalanceAfter, totalExpectedFees, "Treasury balance should match total fees collected");

        assertEq(NudgeCampaign(campaignOne).accumulatedFees(), 0, "Accumulated fees should be 0 after collecting");
        assertEq(NudgeCampaign(campaignTwo).accumulatedFees(), 0, "Accumulated fees should be 0 after collecting");
    }

    function test_CollectFees_NativeTokenRewards() public {
        // Deploy and fund 2 campaigns
        uint256 campaignOneRewards = 100 ether;
        uint256 campaignTwoRewards = 200 ether;

        rewardToken.mintTo(campaignTwoRewards, address(this));
        rewardToken.approve(address(factory), campaignTwoRewards);

        // Campaign 1: NATIVE TOKEN for rewards
        address payable campaignOne = payable(
            factory.deployAndFundCampaign{value: campaignOneRewards}(
                holdingPeriod,
                address(targetToken),
                factory.NATIVE_TOKEN(),
                REWARD_PPQ,
                campaignAdmin,
                0,
                withdrawalAddress,
                campaignOneRewards,
                1
            )
        );

        // Campaign 2: ERC20 Token for rewards
        address payable campaignTwo = payable(
            factory.deployAndFundCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                0,
                withdrawalAddress,
                campaignTwoRewards,
                2
            )
        );

        // Generate fees
        uint256 toAmount = 100e18;
        uint256 expectedFeesCampaignOne = 1e18; // 10% commission of 10% rewards
        uint256 expectedFeesCampaignTwo = 1e18; // 10% commission of 10% rewards

        simulateReallocation(campaignOne, toAmount, 1);
        simulateReallocation(campaignTwo, toAmount, 2);

        uint256 treasuryBalanceBeforeInRewardToken = rewardToken.balanceOf(treasury);
        uint256 treasuryBalanceBeforeInEther = address(treasury).balance;
        uint256 campaignOneBalanceBeforeInEth = address(campaignOne).balance;
        uint256 campaignTwoBalanceBeforeInRewardToken = rewardToken.balanceOf(campaignTwo);

        // Collect fees
        address[] memory campaigns = new address[](2);
        campaigns[0] = campaignOne;
        campaigns[1] = campaignTwo;

        vm.prank(operator);
        factory.collectFeesFromCampaigns(campaigns);

        uint256 treasuryBalanceAfterInRewardToken = rewardToken.balanceOf(treasury);
        uint256 treasuryBalanceAfterInEther = address(treasury).balance;
        uint256 campaignOneBalanceAfterInEth = address(campaignOne).balance;
        uint256 campaignTwoBalanceAfterInRewardToken = rewardToken.balanceOf(campaignTwo);

        assertEq(treasuryBalanceAfterInEther, treasuryBalanceBeforeInEther + expectedFeesCampaignOne);
        assertEq(treasuryBalanceAfterInRewardToken, treasuryBalanceBeforeInRewardToken + expectedFeesCampaignTwo);
        assertEq(campaignOneBalanceAfterInEth, campaignOneBalanceBeforeInEth - expectedFeesCampaignOne);
        assertEq(campaignTwoBalanceAfterInRewardToken, campaignTwoBalanceBeforeInRewardToken - expectedFeesCampaignTwo);
    }

    function test_CollectFeesFromCampaigns_InvalidCampaign() public {
        uint256 initialReward = 10_000e18;
        rewardToken.mintTo(initialReward, address(this));
        rewardToken.approve(address(factory), initialReward);

        address payable campaignOne = payable(
            factory.deployAndFundCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                0,
                withdrawalAddress,
                initialReward,
                uuidOne
            )
        );

        address[] memory campaigns = new address[](2);
        campaigns[0] = campaignOne;
        campaigns[1] = address(0x123); // Random non-existent address

        vm.prank(operator);
        vm.expectRevert(INudgeCampaignFactory.InvalidCampaign.selector);
        factory.collectFeesFromCampaigns(campaigns);
    }

    function test_PauseAndUnpauseCampaigns() public {
        address campaign = factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            uuidOne
        );

        address[] memory campaigns = new address[](1);
        campaigns[0] = campaign;

        vm.prank(admin);
        factory.pauseCampaigns(campaigns);
        assertTrue(factory.isCampaignPaused(campaign), "Campaign should be paused");

        vm.prank(admin);
        factory.unpauseCampaigns(campaigns);
        assertFalse(factory.isCampaignPaused(campaign), "Campaign should be unpaused");
    }

    function test_PausePausedCampaign() public {
        // First deploy and pause a campaign
        address campaign = factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            uuidOne
        );

        address[] memory campaigns = new address[](1);
        campaigns[0] = campaign;

        vm.prank(admin);
        factory.pauseCampaigns(campaigns);

        // Try to pause it again
        vm.prank(admin);
        vm.expectRevert(INudgeCampaignFactory.CampaignAlreadyPaused.selector);
        factory.pauseCampaigns(campaigns);
    }

    function test_PauseNonExistentCampaign() public {
        address[] memory campaigns = new address[](1);
        campaigns[0] = address(0x123); // Random non-existent address

        vm.prank(admin);
        vm.expectRevert(INudgeCampaignFactory.InvalidCampaign.selector);
        factory.pauseCampaigns(campaigns);
    }

    function test_PauseMultipleCampaigns() public {
        // Deploy 3 campaigns
        address[] memory campaigns = new address[](3);

        for (uint256 i = 0; i < 3; i++) {
            campaigns[i] = factory.deployCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                startTimestamp,
                withdrawalAddress,
                i + 1
            );
        }

        // Pause all 3 campaigns
        vm.prank(admin);
        factory.pauseCampaigns(campaigns);

        for (uint256 i = 0; i < 3; i++) {
            assertTrue(factory.isCampaignPaused(campaigns[i]), "Campaign should be paused");
        }
    }

    function test_UnpauseMultipleCampaigns() public {
        // Deploy 3 campaigns
        address[] memory campaigns = new address[](3);

        for (uint256 i = 0; i < 3; i++) {
            campaigns[i] = factory.deployCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                startTimestamp,
                withdrawalAddress,
                i + 1
            );
        }

        // Pause all 3 campaigns
        vm.prank(admin);
        factory.pauseCampaigns(campaigns);

        // Unpause all 3 campaigns
        vm.prank(admin);
        factory.unpauseCampaigns(campaigns);

        for (uint256 i = 0; i < 3; i++) {
            assertFalse(factory.isCampaignPaused(campaigns[i]), "Campaign should be unpaused");
        }
    }

    function test_UnpauseNonExistentCampaign() public {
        address[] memory campaigns = new address[](1);
        campaigns[0] = address(0x123); // Random non-existent address

        vm.prank(admin);
        vm.expectRevert(INudgeCampaignFactory.InvalidCampaign.selector);
        factory.unpauseCampaigns(campaigns);
    }

    function test_UnpauseAlreadyUnpausedCampaign() public {
        address campaign = factory.deployCampaign(
            holdingPeriod,
            address(targetToken),
            address(rewardToken),
            REWARD_PPQ,
            campaignAdmin,
            startTimestamp,
            withdrawalAddress,
            uuidOne
        );

        address[] memory campaigns = new address[](1);
        campaigns[0] = campaign;

        // Try to unpause it without pausing it first
        vm.prank(admin);
        vm.expectRevert(INudgeCampaignFactory.CampaignNotPaused.selector);
        factory.unpauseCampaigns(campaigns);
    }

    function test_UpdateTreasuryAddress() public {
        address newTreasury = address(0x999);

        // Should revert if called by non-admin
        vm.prank(operator);
        vm.expectRevert();
        factory.updateTreasuryAddress(newTreasury);

        // Should revert if new address is zero
        vm.prank(admin);
        vm.expectRevert(INudgeCampaignFactory.InvalidTreasuryAddress.selector);
        factory.updateTreasuryAddress(address(0));

        // Should succeed with valid parameters
        vm.prank(admin);
        factory.updateTreasuryAddress(newTreasury);
        assertEq(factory.nudgeTreasuryAddress(), newTreasury);
    }

    function test_GetCampaignCount() public {
        // Initial count should be 0
        assertEq(factory.getCampaignCount(), 0);

        // Deploy some campaigns
        address[] memory deployedCampaigns = new address[](3);

        for (uint256 i = 0; i < 3; i++) {
            deployedCampaigns[i] = factory.deployCampaign(
                holdingPeriod,
                address(targetToken),
                address(rewardToken),
                REWARD_PPQ,
                campaignAdmin,
                startTimestamp,
                withdrawalAddress,
                i + 1 // Different UUID for each campaign
            );
        }

        // Check count is 3
        assertEq(factory.getCampaignCount(), 3);

        // Verify each campaign address matches what's stored in the array
        for (uint256 i = 0; i < 3; i++) {
            assertEq(factory.campaignAddresses(i), deployedCampaigns[i]);
            assertTrue(factory.isCampaign(deployedCampaigns[i]));
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      RBAC                              
    //////////////////////////////////////////////////////////////////////////*/

    // DEFAULT_ADMIN_ROLE is the admin role for all roles
    function test_AdminRoles() public view {
        assertEq(factory.DEFAULT_ADMIN_ROLE(), factory.getRoleAdmin(factory.SWAP_CALLER_ROLE()));
        assertEq(factory.DEFAULT_ADMIN_ROLE(), factory.getRoleAdmin(factory.NUDGE_ADMIN_ROLE()));
        assertEq(factory.DEFAULT_ADMIN_ROLE(), factory.getRoleAdmin(factory.NUDGE_OPERATOR_ROLE()));
    }

    function test_GrantRole_Success() public {
        address operator2 = makeAddr("operator2");

        vm.prank(admin);
        factory.grantRole(operatorRole, operator2);

        assertTrue(factory.hasRole(operatorRole, operator));
        assertTrue(factory.hasRole(operatorRole, operator2));
    }

    function test_GrantRoleUnauthorized_Reverts() public {
        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                operator,
                factory.DEFAULT_ADMIN_ROLE()
            )
        );
        factory.grantRole(operatorRole, endUserOne);
        vm.stopPrank();

        assertFalse(factory.hasRole(operatorRole, endUserOne));
    }

    function test_RevokeRole_Success() public {
        assertTrue(factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), operator));

        vm.startPrank(admin);
        factory.revokeRole(factory.NUDGE_OPERATOR_ROLE(), operator);
        vm.stopPrank();

        assertFalse(factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), operator));
    }

    function test_RevokeRoleUnauthorized_Reverts() public {
        assertTrue(factory.hasRole(operatorRole, operator));

        vm.startPrank(endUserOne);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                endUserOne,
                factory.DEFAULT_ADMIN_ROLE()
            )
        );
        factory.revokeRole(operatorRole, operator);
        vm.stopPrank();

        assertTrue(factory.hasRole(operatorRole, operator));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   FEE SETTING                              
    //////////////////////////////////////////////////////////////////////////*/

    function test_UpdateFeeSetting_Success() public {
        uint16 newFeeBps = 500; // 5%

        vm.prank(admin);
        factory.updateFeeSetting(newFeeBps);

        assertEq(factory.FEE_BPS(), newFeeBps);
    }

    function test_UpdateFeeSetting_Unauthorized_Reverts() public {
        uint16 newFeeBps = 500; // 5%

        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                operator,
                factory.NUDGE_ADMIN_ROLE()
            )
        );
        factory.updateFeeSetting(newFeeBps);
        vm.stopPrank();

        assertEq(factory.FEE_BPS(), DEFAULT_FEE_BPS);
    }

    function test_UpdateFeeSetting_InvalidFee_Reverts() public {
        uint16 newFeeBps = 10_000 + 1; // 100.01%

        vm.prank(admin);
        vm.expectRevert(INudgeCampaignFactory.InvalidFeeSetting.selector);
        factory.updateFeeSetting(newFeeBps);

        assertEq(factory.FEE_BPS(), DEFAULT_FEE_BPS);
    }
}
