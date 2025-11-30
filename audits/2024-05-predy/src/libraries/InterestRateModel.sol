// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.17;

/**
 * @title InterestRateModel
 * @notice This library is used to define the interest rate curve, which determines the interest rate based on utilization.
 */
library InterestRateModel {
    struct IRMParams {
        uint256 baseRate; //ivr: <= 1e18 ,1e16
        uint256 kinkRate; //ivr: <=1e18 ,9e17
        uint256 slope1; //ivr: <= 1e18 , 5e17
        uint256 slope2; //ivr  <= 10e18, 1e18
    }

    uint256 private constant _ONE = 1e18;

    function calculateInterestRate(IRMParams memory irmParams, uint256 utilizationRatio)
        internal
        pure
        returns (uint256)
    {
        uint256 ir = irmParams.baseRate; //0 -> 1e18
        //util max 1e18 . ir average with 50% util = 0.01e18 + 0.5e18 * 0.9e18  / 1e18 = 0.46e18
        if (utilizationRatio <= irmParams.kinkRate) {
            ir += (utilizationRatio * irmParams.slope1) / _ONE; // baseRate + (utilizationRatio * slope1) / 1e18 ;; range 0 -> 2e18
        } else {
            ir += (irmParams.kinkRate * irmParams.slope1) / _ONE;
            ir += (irmParams.slope2 * (utilizationRatio - irmParams.kinkRate)) / _ONE;
        }

        return ir; //11e18 is max rate.
    } //@ok standard interest rate model.
} //normal average rate will have max 56% interest rate. with 90% util, 50% interest rate. 0% util, 1% interest rate.
//   util: 0e0, rate: 1e16
//   util: 1e16, rate: 1.5e16
//   util: 2e16, rate: 2e16
//   util: 3e16, rate: 2.5e16
//   util: 4e16, rate: 3e16
//   util: 5e16, rate: 3.5e16
//   util: 6e16, rate: 4e16
//   util: 7e16, rate: 4.5e16
//   util: 8e16, rate: 5e16
//   util: 9e16, rate: 5.5e16
//   util: 1e17, rate: 6e16
//   util: 1.1e17, rate: 6.5e16
//   util: 1.2e17, rate: 7e16
//   util: 1.3e17, rate: 7.5e16
//   util: 1.4e17, rate: 8e16
//   util: 1.5e17, rate: 8.5e16
//   util: 1.6e17, rate: 9e16
//   util: 1.7e17, rate: 9.5e16
//   util: 1.8e17, rate: 1e17
//   util: 1.9e17, rate: 1.05e17
//   util: 2e17, rate: 1.1e17
//   util: 2.1e17, rate: 1.15e17
//   util: 2.2e17, rate: 1.2e17
//   util: 2.3e17, rate: 1.25e17
//   util: 2.4e17, rate: 1.3e17
//   util: 2.5e17, rate: 1.35e17
//   util: 2.6e17, rate: 1.4e17
//   util: 2.7e17, rate: 1.45e17
//   util: 2.8e17, rate: 1.5e17
//   util: 2.9e17, rate: 1.55e17
//   util: 3e17, rate: 1.6e17
//   util: 3.1e17, rate: 1.65e17
//   util: 3.2e17, rate: 1.7e17
//   util: 3.3e17, rate: 1.75e17
//   util: 3.4e17, rate: 1.8e17
//   util: 3.5e17, rate: 1.85e17
//   util: 3.6e17, rate: 1.9e17
//   util: 3.7e17, rate: 1.95e17
//   util: 3.8e17, rate: 2e17
//   util: 3.9e17, rate: 2.05e17
//   util: 4e17, rate: 2.1e17
//   util: 4.1e17, rate: 2.15e17
//   util: 4.2e17, rate: 2.2e17
//   util: 4.3e17, rate: 2.25e17
//   util: 4.4e17, rate: 2.3e17
//   util: 4.5e17, rate: 2.35e17
//   util: 4.6e17, rate: 2.4e17
//   util: 4.7e17, rate: 2.45e17
//   util: 4.8e17, rate: 2.5e17
//   util: 4.9e17, rate: 2.55e17
//   util: 5e17, rate: 2.6e17
//   util: 5.1e17, rate: 2.65e17
//   util: 5.2e17, rate: 2.7e17
//   util: 5.3e17, rate: 2.75e17
//   util: 5.4e17, rate: 2.8e17
//   util: 5.5e17, rate: 2.85e17
//   util: 5.6e17, rate: 2.9e17
//   util: 5.7e17, rate: 2.95e17
//   util: 5.8e17, rate: 3e17
//   util: 5.9e17, rate: 3.05e17
//   util: 6e17, rate: 3.1e17
//   util: 6.1e17, rate: 3.15e17
//   util: 6.2e17, rate: 3.2e17
//   util: 6.3e17, rate: 3.25e17
//   util: 6.4e17, rate: 3.3e17
//   util: 6.5e17, rate: 3.35e17
//   util: 6.6e17, rate: 3.4e17
//   util: 6.7e17, rate: 3.45e17
//   util: 6.8e17, rate: 3.5e17
//   util: 6.9e17, rate: 3.55e17
//   util: 7e17, rate: 3.6e17
//   util: 7.1e17, rate: 3.65e17
//   util: 7.2e17, rate: 3.7e17
//   util: 7.3e17, rate: 3.75e17
//   util: 7.4e17, rate: 3.8e17
//   util: 7.5e17, rate: 3.85e17
//   util: 7.6e17, rate: 3.9e17
//   util: 7.7e17, rate: 3.95e17
//   util: 7.8e17, rate: 4e17
//   util: 7.9e17, rate: 4.05e17
//   util: 8e17, rate: 4.1e17
//   util: 8.1e17, rate: 4.15e17
//   util: 8.2e17, rate: 4.2e17
//   util: 8.3e17, rate: 4.25e17
//   util: 8.4e17, rate: 4.3e17
//   util: 8.5e17, rate: 4.35e17
//   util: 8.6e17, rate: 4.4e17
//   util: 8.7e17, rate: 4.45e17
//   util: 8.8e17, rate: 4.5e17
//   util: 8.9e17, rate: 4.55e17
//   util: 9e17, rate: 4.6e17
//   util: 9.1e17, rate: 4.7e17
//   util: 9.2e17, rate: 4.8e17
//   util: 9.3e17, rate: 4.9e17
//   util: 9.4e17, rate: 5e17
//   util: 9.5e17, rate: 5.1e17
//   util: 9.6e17, rate: 5.2e17
//   util: 9.7e17, rate: 5.3e17
//   util: 9.8e17, rate: 5.4e17
//   util: 9.9e17, rate: 5.5e17
//   util: 1e18, rate: 5.6e17
