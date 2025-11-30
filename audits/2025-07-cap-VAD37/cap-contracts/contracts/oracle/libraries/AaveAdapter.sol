// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IAaveDataProvider } from "../../interfaces/IAaveDataProvider.sol";

/// @title Aave Adapter
/// @author kexley, Cap Labs
/// @notice Market rates are sourced from Aave
library AaveAdapter {
    /// @notice Fetch borrow rate for an asset from Aave
    /// @param _aaveDataProvider Aave data provider
    /// @param _asset Asset to fetch rate for
    /// @return latestAnswer Latest borrow rate for the asset
    function rate(address _aaveDataProvider, address _asset) external view returns (uint256 latestAnswer) {
        (,,,,,, latestAnswer,,,,,) = IAaveDataProvider(_aaveDataProvider).getReserveData(_asset);//USDC: 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
    }//call aave Pool v3 for USDC data. AaveProtocolDataProvider from https://github.com/aave/aave-v3-core/blob/master/contracts/misc/AaveProtocolDataProvider.sol
}//https://etherscan.io/address/0x497a1994c46d4f6C864904A9f1fac6328Cb7C8a6
        // returns (
        //     uint256 unbacked,
        //     uint256 accruedToTreasuryScaled,
        //     uint256 totalAToken,
        //     uint256 totalStableDebt,
        //     uint256 totalVariableDebt,
        //     uint256 liquidityRate,
        //     uint256 variableBorrowRate, //@this one 49057464096866092391976773
        //     uint256 stableBorrowRate,//@ aave use this weird contract DefaultReserveInterestRateStrategy to get rate 5% why it is 4.9% on raw data
        //     uint256 averageStableBorrowRate,
        //     uint256 liquidityIndex,
        //     uint256 variableBorrowIndex,
        //     uint40 lastUpdateTimestamp
        // );
//   struct ReserveData {
//     //stores the reserve configuration
//     ReserveConfigurationMap configuration;
//     //the liquidity index. Expressed in ray
//     uint128 liquidityIndex;
//     //the current supply rate. Expressed in ray
//     uint128 currentLiquidityRate;
//     //variable borrow index. Expressed in ray
//     uint128 variableBorrowIndex;
//     //the current variable borrow rate. Expressed in ray
//     uint128 currentVariableBorrowRate;
//     /// @notice reused `__deprecatedStableBorrowRate` storage from pre 3.2
//     // the current accumulate deficit in underlying tokens
//     uint128 deficit;
//     //timestamp of last update
//     uint40 lastUpdateTimestamp;
//     //the id of the reserve. Represents the position in the list of the active reserves
//     uint16 id;
//     //timestamp until when liquidations are not allowed on the reserve, if set to past liquidations will be allowed
//     uint40 liquidationGracePeriodUntil;
//     //aToken address
//     address aTokenAddress;
//     // DEPRECATED on v3.2.0
//     address __deprecatedStableDebtTokenAddress;
//     //variableDebtToken address
//     address variableDebtTokenAddress;
//     // DEPRECATED on v3.4.0, should use the `RESERVE_INTEREST_RATE_STRATEGY` variable from the Pool contract
//     address __deprecatedInterestRateStrategyAddress;
//     //the current treasury balance, scaled
//     uint128 accruedToTreasury;
//     // In aave 3.3.0 this storage slot contained the `unbacked`
//     uint128 virtualUnderlyingBalance;
//     //the outstanding debt borrowed against this asset in isolation mode
//     uint128 isolationModeTotalDebt;
//     //the amount of underlying accounted for by the protocol
//     // DEPRECATED on v3.4.0. Moved into the same slot as accruedToTreasury for optimized storage access.
//     uint128 __deprecatedVirtualUnderlyingBalance;
//   }