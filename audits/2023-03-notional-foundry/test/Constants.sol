// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.7.6;
pragma abicoder v2;

import "../src/global/Types.sol";

contract Constants {
//     uint256 public immutable START_TIME = 1609459200;
//     uint256 public immutable SECONDS_IN_DAY = 86400;
//     uint256 public immutable SECONDS_IN_YEAR = SECONDS_IN_DAY * 360;
//     uint256 public immutable SECONDS_IN_QUARTER = SECONDS_IN_DAY * 90;
//     uint256 public immutable SECONDS_IN_MONTH = SECONDS_IN_DAY * 30;
//     uint256 public immutable RATE_PRECISION = 1e9;
//     uint256 public immutable TOKEN_PRECISION = 1e8;
//     uint256 public immutable BASIS_POINT = RATE_PRECISION / 10000;
//     uint256 public immutable NORMALIZED_RATE_TIME = 31104000;
//     uint256 public immutable START_TIME_TREF = START_TIME - START_TIME % (90 * SECONDS_IN_DAY);
//     uint256 public immutable SETTLEMENT_DATE = START_TIME_TREF + (90 * SECONDS_IN_DAY);
//     uint256 public immutable FCASH_ASSET_TYPE = 1;
//     uint256 public immutable REPO_INCENTIVE = 10;
//     uint256 public immutable PRIME_CASH_VAULT_MATURITY = 2 ** 40 - 1;

// // PORTFOLIO_FLAG = HexString("0x8000", "bytes2")
// // BALANCE_FLAG = HexString("0x4000", "bytes2")
// // PORTFOLIO_FLAG_INT = to_int(HexString("0x8000", "bytes2"), "int")
// // BALANCE_FLAG_INT = to_int(HexString("0x4000", "bytes2"), "int")
// // HAS_ASSET_DEBT = "0x01"
// // HAS_CASH_DEBT = "0x02"
// // HAS_BOTH_DEBT = "0x03"
//     bytes2 public immutable PORTFOLIO_FLAG = hex"8000";
//     bytes2 public immutable BALANCE_FLAG = hex"4000";
//     int256 public immutable PORTFOLIO_FLAG_INT = int256(PORTFOLIO_FLAG);
//     int256 public immutable BALANCE_FLAG_INT = int256(BALANCE_FLAG);
//     bytes1 public immutable HAS_ASSET_DEBT = hex"01";
//     bytes1 public immutable HAS_CASH_DEBT = hex"02";
//     bytes1 public immutable HAS_BOTH_DEBT = hex"03";
// // MARKETS = [
// //     START_TIME_TREF + 90 * SECONDS_IN_DAY,
// //     START_TIME_TREF + 180 * SECONDS_IN_DAY,
// //     START_TIME_TREF + SECONDS_IN_YEAR,
// //     START_TIME_TREF + 2 * SECONDS_IN_YEAR,
// //     START_TIME_TREF + 5 * SECONDS_IN_YEAR,
// //     START_TIME_TREF + 10 * SECONDS_IN_YEAR,
// //     START_TIME_TREF + 20 * SECONDS_IN_YEAR,
// // ]
//     uint256[] public immutable MARKETS = [
//         START_TIME_TREF + 90 * SECONDS_IN_DAY,
//         START_TIME_TREF + 180 * SECONDS_IN_DAY,
//         START_TIME_TREF + SECONDS_IN_YEAR,
//         START_TIME_TREF + 2 * SECONDS_IN_YEAR,
//         START_TIME_TREF + 5 * SECONDS_IN_YEAR,
//         START_TIME_TREF + 10 * SECONDS_IN_YEAR,
//         START_TIME_TREF + 20 * SECONDS_IN_YEAR
//     ];
// // in types folder
//     CashGroupSettings public immutable CASH_GROUP_PARAMETERS = CashGroupSettings({
//         maxMarketIndex: 7, // 0: Max Market Index
//         rateOracleTimeWindow5Min : 10, // 1: time window, 10 min
//         totalFeeBPS: 0, // 2: [deprecated] total fee, 30 BPS
//         reserveFeeShare: 30, // 3: reserve fee share, percentage
//         debtBuffer5BPS: 30, // 4: debt buffer 150 bps
//         fCashHaircut5BPS: 30, // 5: fcash haircut 150 bps
//         settlementPenaltyRate5BPS: 40, // 6: settlement penalty 400 bps
//         liquidationfCashHaircut5BPS:20, // 7: liquidation discount 100 bps
//         liquidationDebtBuffer5BPS:20, // 8: liquidation debt buffer
//         liquidityTokenHaircuts: [99, 98, 97, 96, 95, 94, 93], // 9: token haircuts (percentages)
//         rateScalars: [0, 0, 0, 0, 0, 0, 0] // 10: [deprecated] rate scalar
// //     # 10: [deprecated] rate scalar
// //     (0, 0, 0, 0, 0, 0, 0),
// // )
//     });





// CASH_GROUP_PARAMETERS = (
//     7,  # 0: Max Market Index
//     10,  # 1: time window, 10 min
//     0,  # 2: [deprecated] total fee, 30 BPS
//     30,  # 3: reserve fee share, percentage
//     30,  # 4: debt buffer 150 bps
//     30,  # 5: fcash haircut 150 bps
//     40,  # 6: settlement penalty 400 bps
//     20,  # 7: liquidation discount 100 bps
//     20,  # 8: liquidation debt buffer
//     # 9: token haircuts (percentages)
//     (99, 98, 97, 96, 95, 94, 93),
//     # 10: [deprecated] rate scalar
//     (0, 0, 0, 0, 0, 0, 0),
// )

// CURVE_SHAPES = {
//     "flat": {
//         "rates": [
//             r * RATE_PRECISION for r in [0.03, 0.035, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10]
//         ],
//         "proportion": 0.33,
//     },
//     "normal": {
//         "rates": [
//             r * RATE_PRECISION for r in [0.06, 0.065, 0.07, 0.08, 0.09, 0.10, 0.11, 0.12, 0.13]
//         ],
//         "proportion": 0.5,
//     },
//     "high": {
//         "rates": [
//             r * RATE_PRECISION for r in [0.08, 0.09, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16]
//         ],
//         "proportion": 0.8,
//     },
// }

// DEPOSIT_ACTION_TYPE = {
//     "None": 0,
//     "DepositAsset": 1,
//     "DepositUnderlying": 2,
//     "DepositAssetAndMintNToken": 3,
//     "DepositUnderlyingAndMintNToken": 4,
//     "RedeemNToken": 5,
//     "ConvertCashToNToken": 6,
// }

// TRADE_ACTION_TYPE = {
//     "Lend": 0,
//     "Borrow": 1,
//     "AddLiquidity": 2,
//     "RemoveLiquidity": 3,
//     "PurchaseNTokenResidual": 4,
//     "SettleCashDebt": 5,
// }

// ZERO_ADDRESS = HexString(0, type_str="bytes20")

}