// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../diamond/interfaces/ITrading.sol";
import "../diamond/interfaces/ITradingChecker.sol";
import {CloseInfo} from "../diamond/interfaces/ITradingClose.sol";

interface IAPXCallback {

    function afterMarketExecuted(bytes32 tradeHash, ITrading.OpenTrade memory ot) external;

    function afterMarketRefund(bytes32 tradeHash, ITradingChecker.Refund refund) external;

    function afterClose(bytes32 tradeHash, CloseInfo memory info) external;
}