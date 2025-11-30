// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ITrading.sol";
import "./ITradingChecker.sol";

struct LimitOrderDeal {
    bytes32 orderHash;
    address user;
    uint64 entryPrice;
    address pairBase;
    address tokenIn;
    uint96 margin;
    uint64 stopLoss;
    uint64 takeProfit;
    uint24 broker;
    bool isLong;
    uint96 openFee;
    uint96 executionFee;
    uint80 qty;
}

interface ITradingOpen is ITrading {

    event PendingTradeRefund(address indexed user, bytes32 indexed tradeHash, ITradingChecker.Refund refund);
    event OpenMarketTrade(address indexed user, bytes32 indexed tradeHash, OpenTrade ot);

    function limitOrderDeal(LimitOrderDeal memory, uint256 marketPrice) external;

    function marketTradeCallback(bytes32 tradeHash, uint upperPrice, uint lowerPrice) external;
}