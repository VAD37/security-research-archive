// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console, Test} from "forge-std/Test.sol";
import "./BasicFixture.t.sol";
import {StakingFixture} from "./StakingFixture.t.sol";
import {PublicSaleFixture} from "./PublicSaleFixture.t.sol";
import {Balances, MFDBaseInitializerParams, LockType} from "../src/dependencies/MultiFeeDistribution/MFDDataTypes.sol";
import {MFDBase} from "../src/dependencies/MultiFeeDistribution/MFDBase.sol";
import {EpochParams, EpochStates, MerkleUserDistroInput, StakingParams} from "../src/DefiAppHomeCenter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Debug_test is BasicFixture {
    // MFDBase public mfd;

    // function setUp() public override {
    //     BasicFixture.setUp();

    //     mfd = new MFDBase();

    //     LockType[] memory initLockTypes = new LockType[](4);
    //     initLockTypes[ONE_MONTH_TYPE_INDEX] = LockType({duration: 30 days, multiplier: ONE_MONTH_MULTIPLIER});
    //     initLockTypes[THREE_MONTH_TYPE_INDEX] = LockType({duration: 90 days, multiplier: THREE_MONTH_MULTIPLIER});
    //     initLockTypes[SIX_MONTH_TYPE_INDEX] = LockType({duration: 180 days, multiplier: SIX_MONTH_MULTIPLIER});
    //     initLockTypes[TWELVE_MONTH_TYPE_INDEX] = LockType({duration: 360 days, multiplier: TWELVE_MONTH_MULTIPLIER});

    //     MFDBaseInitializerParams memory params = MFDBaseInitializerParams({
    //         emissionToken: address(homeToken),
    //         stakeToken: address(weth9),
    //         rewardStreamTime: 7 days,
    //         rewardsLookback: 1 days,
    //         initLockTypes: initLockTypes,
    //         defaultLockTypeIndex: ONE_MONTH_TYPE_INDEX,
    //         oracleRouter: address(deploy_mock_oracleRouter(address(homeToken), HOME_USD_PRICE))
    //     });
    //     mfd.initialize(params);
    // }

    // function test_debug() public {
    //     address user = User1.addr;

    //     console.log("user %s", user);

    //     vm.startPrank(user);
    // }
}
