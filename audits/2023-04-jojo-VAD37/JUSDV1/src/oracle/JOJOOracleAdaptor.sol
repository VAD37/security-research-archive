/*
    Copyright 2022 JOJO Exchange
    SPDX-License-Identifier: BUSL-1.1*/

pragma solidity 0.8.9;

import "../Interface/IPriceChainLink.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IChainLinkAggregator } from "../Interface/IChainLinkAggregator.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "../lib/JOJOConstant.sol";

contract JOJOOracleAdaptor is IPriceChainLink, Ownable {
    address public immutable chainlink;
    uint256 public immutable decimalsCorrection;
    uint256 public immutable heartbeatInterval;
    address public immutable USDCSource;

    constructor(address _source, uint256 _decimalCorrection, uint256 _heartbeatInterval, address _USDCSource) {
        chainlink = _source;
        decimalsCorrection = 10 ** _decimalCorrection;//20 for ETH or 10 for BTC
        heartbeatInterval = _heartbeatInterval;// 86400
        USDCSource = _USDCSource;
    }
    //https://docs.chain.link/data-feeds/l2-sequencer-feeds
    function getAssetPrice() external view override returns (uint256) {
        /*uint80 roundID*/
        (, int256 price,, uint256 updatedAt,) = IChainLinkAggregator(chainlink).latestRoundData();
        (, int256 USDCPrice,, uint256 USDCUpdatedAt,) = IChainLinkAggregator(USDCSource).latestRoundData();
        //@audit not using standard L2 oracle downtime oracle does not check latest round. Arbitrum can go down and oracle price will be queued in inbox..
        require(block.timestamp - updatedAt <= heartbeatInterval, "ORACLE_HEARTBEAT_FAILED");
        require(block.timestamp - USDCUpdatedAt <= heartbeatInterval, "USDC_ORACLE_HEARTBEAT_FAILED");
        uint256 tokenPrice = (SafeCast.toUint256(price) * 1e8) / SafeCast.toUint256(USDCPrice);//@audit-ok decimal 1e8 here seem wrong. it should be 1e10
        return tokenPrice * JOJOConstant.ONE / decimalsCorrection;//@audit-ok a test file using decimalCorrection 10. value 20 is indeed correct
    }//decimals Correction is 10 for BTC 15k, 20 for ETH 1k
}//JUSD price peg to USDC 
//WBTC: 20000e16
//ETH: 1000e6