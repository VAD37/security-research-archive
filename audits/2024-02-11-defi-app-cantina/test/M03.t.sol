// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {StakingFixture, MockToken} from "./StakingFixture.t.sol";
import {PublicSaleFixture} from "./PublicSaleFixture.t.sol";
import "../src/dependencies/MultiFeeDistribution/MFDDataTypes.sol";
import {EpochParams, EpochStates, MerkleUserDistroInput, StakingParams} from "../src/DefiAppHomeCenter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract M3_test is StakingFixture, PublicSaleFixture {
    MockToken AERO;

    function setUp() public override(StakingFixture, PublicSaleFixture) {
        StakingFixture.setUp();
        PublicSaleFixture.setUp();


        AERO = MockToken(gauge.rewardToken()); //@MockVe token (aka AERO VotingEscrow). Ve also part of rewards token beside HOME
        oracleRouter.mock_set_price(gauge.rewardToken(), 0.8e18);
        //sadly MockToken point to 0x400 address. It should be AERO token. Edit MockVe so token() point to MockVe addr
        //Rewards can be received from Gauge or external source like Gov

        //remove AERO token from rewards to prevent issue with testing
        vm.prank(Admin.addr);
        staker.removeReward(address(AERO));
    }

    function test_debug() public {
        address user = User1.addr;

        //setup
        skip(10 days);
        vm.startPrank(Admin.addr);
        vAmmPoolHelper.setAllowedZapper(user, true);
        // give 1000e18 token as rewards
        deal(address(homeToken), address(staker), 1_000e18);
        staker.trackUnseenRewards();
        printRewardData();

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
        staker.stake(1e18, User1.addr, 0);
        printUser(user);
        

        skip(30 days);
        
        //refresh global rewards
        staker.stake(1, User1.addr, 0);
        printUser(user);
        //claim all rewards
        staker.claimAllRewards();
        printRewardData();

        // claimable now empty
        printUser(user);

        console.log("----- RESET REWARDS -----");
        // give next epoch rewards
        deal(address(homeToken), address(staker), 100_000e18);//Lots of rewards due to time reset inflate the amount of token can be received significantly
        console.log("staker HOME balance: %e", homeToken.balanceOf(address(staker)));
        // reset token by remove and add back
        vm.startPrank(Admin.addr);
        staker.removeReward(address(homeToken));
        staker.addReward(address(homeToken));
        staker.trackUnseenRewards();
        printRewardData();


        console.log("----- SECOND USER STAKE -----");
        skip(1 days);
        vm.startPrank(user); //no reward on this user but time do fly
        //transfer 1e19 LP token to user2 for stake for longer period with more points
        pool.transfer(User2.addr, 1e19);
        vm.startPrank(User2.addr);
        pool.approve(address(staker), type(uint256).max);
        staker.stake(1e19, User2.addr, 2);
        printUser(User2.addr);
        printRewardData();


        console.log("----- FIRST USER CLAIM REWARDS AGAIN -----");
        vm.startPrank(user);
        printUser(user);
        // previously, user1 already claim 1e21 token for their stake after 30 days.
        //This user never withdraw this stake now can claim rewards again. Due to global reset 
        staker.claimAllRewards();

        
    }

    function printRewardData() internal {
        console.log("--- GLOBAL Reward Data ---");
        Reward memory r = staker.getRewardData(address(homeToken));
        console.log("rewardPerSecond: %e", r.rewardPerSecond); //@rewardSpeed = 1e18 * amount / 7 days
        console.log("rewardPerTokenStored: %e", r.rewardPerTokenStored);
        console.log("balance: %e", r.balance);
        console.log("periodFinish: ", r.periodFinish);
        console.log("lastUpdateTime: ", r.lastUpdateTime);
    }

    function printUser(address user) internal {
        console.log("--- User %s ---", user);
        console.log("lockedSupply: %e", staker.getLockedSupply());
        console.log("lockedSupplyWithMultiplier: %e", staker.getLockedSupplyWithMultiplier());
        Balances memory ba = staker.getUserBalances(user);
        console.log("total: %e", ba.total);
        console.log("locked: %e", ba.locked);
        console.log("lockedWithMultiplier: %e", ba.lockedWithMultiplier);
        console.log("unlocked: %e", ba.unlocked);

        console.log("claimable HOME: %e", staker.getUserClaimableRewards(user)[0].amount);
    }
}
