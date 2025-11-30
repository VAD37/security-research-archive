/*
    Copyright 2022 JOJO Exchange
    SPDX-License-Identifier: BUSL-1.1
*/

pragma solidity 0.8.9;

import "../../lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "@JOJO/contracts/adaptor/emergencyOracle.sol";
import "@mean-finance/solidity/interfaces/IStaticOracle.sol";


contract UniswapPriceAdaptor is Ownable{

    IStaticOracle public immutable UNISWAP_V3_ORACLE;
    uint8 public immutable decimal;
    address public immutable baseToken;
    address public immutable quoteToken;
    // query period
    uint32 public period;
    address public priceFeedOracle;
    uint256 public impact;


    event UpdatePools(address[] oldPools, address[] newPools);
    event UpdatePeriod(uint32 oldPeriod, uint32 newPeriod);
    event UpdateImpact(uint256 oldImpact, uint256 newImpact);            
            
    constructor(
        address _uniswapAdaptor,
        uint8 _decimal,//18
        address _baseToken,//BTC
        address _quoteToken,//USDC
        uint32 _period,//600
        address _priceFeedOracle,//
        uint256 _impact//50000000000000000
    ) {
        UNISWAP_V3_ORACLE = IStaticOracle(_uniswapAdaptor);
        decimal = _decimal;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        period = _period;
        priceFeedOracle = _priceFeedOracle;
        impact = _impact;
    }

    function getAssetPrice() external view returns (uint256) {
        (uint256 uniswapPriceFeed,) = IStaticOracle(UNISWAP_V3_ORACLE).quoteAllAvailablePoolsWithTimePeriod(uint128(10**decimal), baseToken, quoteToken, period);
        uint256 JOJOPriceFeed = EmergencyOracle(priceFeedOracle).getMarkPrice();
        uint256 diff = JOJOPriceFeed >= uniswapPriceFeed ? JOJOPriceFeed - uniswapPriceFeed : uniswapPriceFeed - JOJOPriceFeed;
        //JOJOPriceFeed(1 - impact) <= uniswapPriceFeed <= JOJOPriceFeed(1 + impact)
        require(diff * 1e18 / JOJOPriceFeed <= impact, "deviation is too big");//0.05e18
        return uniswapPriceFeed;
    }

    function updatePeriod(uint32 newPeriod) external onlyOwner {
        emit UpdatePeriod(period, newPeriod);
        period = newPeriod;
    }

    function updateImpact(uint32 newImpact) external onlyOwner {
        emit UpdateImpact(impact, newImpact);
        impact = newImpact;
    }
}
