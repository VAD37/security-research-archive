// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.17;

import {Perp} from "./Perp.sol";

library DataType {
    struct PairStatus {
        uint256 id; //4
        address quoteToken; //source token
        address poolOwner; // caller or operator //modified by poolOwner
        Perp.AssetPoolStatus quotePool; //source token pool //new contract easy to pre exploit
        Perp.AssetPoolStatus basePool; //target pool //child struct can be modified
        Perp.AssetRiskParams riskParams; //user risk params //modified by poolOwner
        Perp.SqrtPerpAssetStatus sqrtAssetStatus; //generated, fixed lower,upper tick, mostly empty,
        address priceFeed; //user //modified by poolOwner
        bool isQuoteZero; //true , false depend on uniswapPool, only for external call. This does not affect quote,base order in this contract
        bool allowlistEnabled; //true
        uint8 feeRatio; //user input < 20 //modified by poolOwner
        uint256 lastUpdateTimestamp; //block.timestamp
    }

    struct Vault {
        uint256 id;
        address quoteToken;
        address owner;
        address recipient;
        int256 margin;
        Perp.UserStatus openPosition;
    }

    struct RebalanceFeeGrowthCache {
        int256 stableGrowth;
        int256 underlyingGrowth;
    }

    struct FeeAmount {
        int256 feeAmountBase;
        int256 feeAmountQuote;
    }
}
