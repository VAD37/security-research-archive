// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {StakingFixture, MockToken} from "./StakingFixture.t.sol";
import {PublicSaleFixture} from "./PublicSaleFixture.t.sol";
import "../src/dependencies/MultiFeeDistribution/MFDDataTypes.sol";
import {EpochParams, EpochStates, MerkleUserDistroInput, StakingParams} from "../src/DefiAppHomeCenter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract H01_test is StakingFixture, PublicSaleFixture {
    MockToken AERO;
//26798000 302400 (Feb-24-2025 08:22:27 AM +UTC) 
//                (Feb-17-2025 08:22:27 AM +UTC)
    function setUp() public override(StakingFixture, PublicSaleFixture) {
        StakingFixture.setUp();
        PublicSaleFixture.setUp();

        // address[] memory rewardTokens = staker.getRewardTokens();
        // for (uint256 i = 0; i < rewardTokens.length; i++) {
        //     console.log("reward token %s", rewardTokens[i]);
        // }

        AERO = MockToken(gauge.rewardToken()); //@MockVe token (aka AERO VotingEscrow). Ve also part of rewards token beside HOME
        oracleRouter.mock_set_price(gauge.rewardToken(), 0.8e18);
        //sadly MockToken point to 0x400 address. It should be AERO token. Edit MockVe so token() point to MockVe addr
        //Rewards can be received from Gauge or external source like Gov

        //remove AERO token from rewards to prevent issue with testing
        vm.prank(Admin.addr);
        staker.removeReward(address(AERO));
        skip(15 days);
        vm.prank(Admin.addr);
        center.initializeNextEpoch();
    }

    function test_debug() public {
        address user = User1.addr;

        //setup
        skip(10 days);
        vm.startPrank(Admin.addr);
        vAmmPoolHelper.setAllowedZapper(user, true);
        
        deal(address(homeToken), address(staker), 1_000e18);
        deal(address(homeToken), address(center), 100_000e18);
        
        staker.trackUnseenRewards();


        console.log("user %s", user);

        vm.startPrank(user);
        //get pool token
        uint256 wethAmount = 1e18;
        uint256 homeAmount = 10e18;
        deal(address(weth9), user, wethAmount);
        deal(address(homeToken), user, homeAmount);
        weth9.approve(address(vAmmPoolHelper), type(uint256).max);
        homeToken.approve(address(vAmmPoolHelper), type(uint256).max);

        uint256 lpTokens = vAmmPoolHelper.zapWETH(wethAmount);
        console.log("lpTokens %e", lpTokens);
        console.log("zapWETH  %e", wethAmount - weth9.balanceOf(user));

        //stake pool directly instead going through helper
        pool.approve(address(staker), type(uint256).max);

        //refresh rewards
        staker.stake(1, User1.addr, 0);

        uint256 currentEpoch = uint256(center.getCurrentEpoch());
        console.log("currentEpoch %d", currentEpoch, block.number);
        console.log("user balance before: %e", homeToken.balanceOf(user));

        // Can initiate Epoch 2, 1 block before Epoch 1 ends
        EpochParams memory params1 = center.getEpochParams(1);
        vm.roll(params1.endBlock - 1); // one block before
        vm.warp(block.timestamp + DEFAULT_EPOCH_DURATION - center.BLOCK_CADENCE());
        center.initializeNextEpoch();

        console.log("currentEpoch %d", center.getCurrentEpoch(),block.number);


        //claim rewards
        StakingParams memory stakingParams = StakingParams({weth9ToStake: 0, minLpTokens: 0, typeIndex: 0});
        bytes32[] memory distroProof = new bytes32[](1);
        MerkleUserDistroInput memory input = MerkleUserDistroInput({points: 1e23, tokens: 1e23, userId: user});
        //merkle root still zero bytes 0x0.
        center.claim(currentEpoch, input, distroProof, stakingParams);
        console.log("user balance after: %e", homeToken.balanceOf(user));
    }

}
