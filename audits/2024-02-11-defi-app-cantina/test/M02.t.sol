// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {StakingFixture, MockToken} from "./StakingFixture.t.sol";
import {PublicSaleFixture} from "./PublicSaleFixture.t.sol";
import "../src/dependencies/MultiFeeDistribution/MFDDataTypes.sol";
import {EpochParams, EpochStates, MerkleUserDistroInput, StakingParams} from "../src/DefiAppHomeCenter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract M02_test is StakingFixture, PublicSaleFixture {
    MockToken AERO;
    uint256 public constant KNOWN_BLOCK = 100;
    uint256 public constant KNOWN_TIMESTAMP = 1_728_975_600;

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
        vm.prank(Admin.addr);
        center.initializeNextEpoch();

        console.log("currentEpoch %d", center.getCurrentEpoch(), block.number);

        // Can initiate Epoch 2, 1 block before Epoch 1 ends
        EpochParams memory params1 = center.getEpochParams(1);
        vm.roll(params1.endBlock - 1); // one block before
        vm.warp(KNOWN_TIMESTAMP + DEFAULT_EPOCH_DURATION - center.BLOCK_CADENCE());
        center.initializeNextEpoch();
        console.log("currentEpoch %d", center.getCurrentEpoch(), block.number);

        //change epoch duration to minimum 3.5 days. from previous 30 days
        vm.prank(Admin.addr);
        center.setDefaultEpochDuration(7 days / 2 + 1);

        // Skip time to epoch 4. both block.number and timestamp
        EpochParams memory params2 = center.getEpochParams(2);
        vm.roll(params2.endBlock + 8 days);
        vm.warp(KNOWN_TIMESTAMP + DEFAULT_EPOCH_DURATION + 8 days + center.BLOCK_CADENCE());
        center.initializeNextEpoch();

        console.log("currentEpoch %d", center.getCurrentEpoch(), block.number);
    }
}
