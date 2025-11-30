// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./pool/Setup.t.sol";
import "src/libraries/InterestRateModel.sol";

contract TestPredyDebug is TestPool {
    function setUp() public override {
        TestPool.setUp();
    }

    function testSetNewConfig() public {
        InterestRateModel.IRMParams memory irmParams = InterestRateModel.IRMParams(1e16, 9 * 1e17, 5 * 1e17, 1e18);

        address quoteToken = address(currency0);
        address poolOwner = address(this);
        address newuniswapPool = address(uniswapPool);
        address priceFeed;
        bool allowlistEnabled;
        uint8 fee;
        uint256 id = predyPool.registerPair(
            AddPairLogic.AddPairParams(
                quoteToken,
                poolOwner,
                newuniswapPool,
                // set up oracle
                priceFeed,
                allowlistEnabled,
                fee,
                Perp.AssetRiskParams(RISK_RATIO, BASE_MIN_COLLATERAL_WITH_DEBT, 1000, 500, 1005000, 1050000),
                irmParams,
                irmParams
            )
        );
        console.log("pool id: ", id);
    }

    // function testPrint() public {
    //     uint256 baseRate = 0.01e18;
    //     uint256 kink = 0.9e18;
    //     uint256 slope1 = 0.5e18;
    //     uint256 slope2 = 1e18;

    //     InterestRateModel.IRMParams memory irmParams = InterestRateModel.IRMParams(baseRate, kink, slope1, slope2);
    //     //loop through all possible utilization ratios, from 0-1e18
    //     for (uint256 i = 0; i <= 1e18; i += 1e16) {
    //         uint256 rate = InterestRateModel.calculateInterestRate(irmParams, i);
    //         console.log("util: %e, rate: %e", i, rate);
    //     }
    // }

    // function testPrint2() public {
    //     uint256 baseRate = 1e18;
    //     uint256 kink = 0.3e18;
    //     uint256 slope1 = 1e18;
    //     uint256 slope2 = 10e18;

    //     InterestRateModel.IRMParams memory irmParams = InterestRateModel.IRMParams(baseRate, kink, slope1, slope2);
    //     //loop through all possible utilization ratios, from 0-1e18
    //     for (uint256 i = 0; i <= 1e18; i += 5e16) {
    //         uint256 rate = InterestRateModel.calculateInterestRate(irmParams, i);
    //         console.log("util: %e, rate: %e", i, rate);
    //     }
    // }

    // function testPrint3() public {
    //     uint256 baseRate = 1e18;
    //     uint256 kink = 0e18;
    //     uint256 slope1 = 1e18;
    //     uint256 slope2 = 10e18;

    //     InterestRateModel.IRMParams memory irmParams = InterestRateModel.IRMParams(baseRate, kink, slope1, slope2);
    //     //loop through all possible utilization ratios, from 0-1e18
    //     for (uint256 i = 0; i <= 1e18; i += 1e16) {
    //         uint256 rate = InterestRateModel.calculateInterestRate(irmParams, i);
    //         console.log("util: %e, rate: %e", i, rate);
    //     }
    // }

    // function _testZero() public {
    //     InterestRateModel.IRMParams memory irmParams = InterestRateModel.IRMParams(1e16, 9 * 1e17, 5 * 1e17, 1e18);

    //     address quoteToken;
    //     address poolOwner = address(this);
    //     address newuniswapPool = address(0);
    //     address priceFeed;
    //     bool allowlistEnabled;
    //     uint8 fee;
    //     // Perp.AssetRiskParams assetRiskParams;
    //     // InterestRateModel.IRMParams quoteIrmParams;
    //     // InterestRateModel.IRMParams baseIrmParams;
    //     uint256 id = predyPool.registerPair(
    //         AddPairLogic.AddPairParams(
    //             quoteToken,
    //             poolOwner,
    //             newuniswapPool,
    //             // set up oracle
    //             priceFeed,
    //             allowlistEnabled,
    //             fee,
    //             Perp.AssetRiskParams(RISK_RATIO, BASE_MIN_COLLATERAL_WITH_DEBT, 1000, 500, 1005000, 1050000),
    //             irmParams,
    //             irmParams
    //         )
    //     );
    //     console.log("pool id: ", id);
    // }
}
