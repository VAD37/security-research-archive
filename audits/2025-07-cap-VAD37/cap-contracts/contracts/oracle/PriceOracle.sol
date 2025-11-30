// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Access } from "../access/Access.sol";
import { IOracleTypes } from "../interfaces/IOracleTypes.sol";
import { IPriceOracle } from "../interfaces/IPriceOracle.sol";
import { PriceOracleStorageUtils } from "../storage/PriceOracleStorageUtils.sol";
import { console } from "forge-std/console.sol";

/// @title Price Oracle
/// @author kexley, Cap Labs
/// @dev Payloads are stored on this contract and calculation logic is hosted on external libraries
abstract contract PriceOracle is IPriceOracle, Access, PriceOracleStorageUtils {
    /// @inheritdoc IPriceOracle
    function setPriceOracleData(address _asset, IOracleTypes.OracleData calldata _oracleData)
        external
        checkAccess(this.setPriceOracleData.selector)
    {
        getPriceOracleStorage().oracleData[_asset] = _oracleData;//cUSD (0xf79e8e7ba2ddb5d0a7d98b1f57fcb8a50436e9aa) with capTokenAdapter libraries. Interesting
        emit SetPriceOracleData(_asset, _oracleData);//stcUSD (0x5349937179f7b7e499fa58c797a27d000156a489) with StakedCapAdapter
    }//USDC 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48, chainlink adapter call USDC / USD  EACaggregatorProxy 0xfb6471acd42c91ff265344ff73e88353521d099f. new version 100 days too. Dual Aggregator? 0xe13fafe4FB769e0f4a1cB69D35D21EF99188EFf7
    //Dual Aggregator?? 0xe13fafe4FB769e0f4a1cB69D35D21EF99188EFf7. This oracle is shared by AAVE Pool V3. https://etherscan.io/tx/0x497d9daa5d17e7b73d9c4d82ca4a16f8f4ccf59f6cf6fcb30204ea84d922cff6
    /// @inheritdoc IPriceOracle
    function setPriceBackupOracleData(address _asset, IOracleTypes.OracleData calldata _oracleData)//Dual Aggregator fix issue of sandwich attack on oracle newRound transaction
        external
        checkAccess(this.setPriceBackupOracleData.selector)
    {
        getPriceOracleStorage().backupOracleData[_asset] = _oracleData;// backup cUSD with capTOkenAdapter
        emit SetPriceBackupOracleData(_asset, _oracleData);//backup stcUSD same
    }//backup USDC same.//@audit-ok I it kinda funny to see admin set oracle backup to USDC contract itself instead of Chainlink

    /// @inheritdoc IPriceOracle
    function setStaleness(address _asset, uint256 _staleness) external checkAccess(this.setStaleness.selector) {
        getPriceOracleStorage().staleness[_asset] = _staleness;//1 days
        emit SetStaleness(_asset, _staleness);//@audit L staleness is default to zero. but it can bypass backup oracle if it call on same block
    }
//USDC, main:0x8fffffd4afb6115b954bd326cbe7b4ba576818f6 AccessControlledOCR2Aggregator ,backup:0xfb6471acd42c91ff265344ff73e88353521d099f DualAggregator
    /// @inheritdoc IPriceOracle
    function getPrice(address _asset) external view returns (uint256 price, uint256 lastUpdated) {//@return chainlink 8 decimals price usdc/usd
        PriceOracleStorage storage $ = getPriceOracleStorage();//@for capUSD and stcUSD, it use special libraries adapter to get price based on aave and current supply.
        IOracleTypes.OracleData memory data = $.oracleData[_asset];

        (price, lastUpdated) = _getPrice(data.adapter, data.payload);

        if (price == 0 || _isStale(_asset, lastUpdated)) {//@always use main chailink oracle 1 days staleness.
            data = $.backupOracleData[_asset];//@ the main oracle is 1 hour heartbeat though
            (price, lastUpdated) = _getPrice(data.adapter, data.payload);//@backup oracle belong to aave. still the same Chainlink aggregator with secondary
            // console.log("Using backup oracle for asset: %e , %e", price,lastUpdated);
            if (price == 0 || _isStale(_asset, lastUpdated)) revert PriceError(_asset);
        }//@audit L one oracle with stale price will affeect capToken price to use backup oracle. if one oracle use 24 hours heartbeat. it can be forced to use backup oracle for single block.
    }

    /// @inheritdoc IPriceOracle
    function priceOracleData(address _asset) external view returns (IOracleTypes.OracleData memory data) {
        data = getPriceOracleStorage().oracleData[_asset];
    }

    /// @inheritdoc IPriceOracle
    function priceBackupOracleData(address _asset) external view returns (IOracleTypes.OracleData memory data) {
        data = getPriceOracleStorage().backupOracleData[_asset];
    }

    /// @inheritdoc IPriceOracle
    function staleness(address _asset) external view returns (uint256 assetStaleness) {
        assetStaleness = getPriceOracleStorage().staleness[_asset];
    }

    /// @dev Initialize the price oracle
    /// @param _accessControl Access control address
    function __PriceOracle_init(address _accessControl) internal onlyInitializing {
        __Access_init(_accessControl);
        __PriceOracle_init_unchained();
    }

    /// @dev Initialize unchained is empty
    function __PriceOracle_init_unchained() internal onlyInitializing { }

    /// @dev Calculate price using an adapter and payload but do not revert on errors
    /// @param _adapter Adapter for calculation logic
    /// @param _payload Encoded call to adapter with all required data
    /// @return price Calculated price
    /// @return lastUpdated Last updated timestamp
    function _getPrice(address _adapter, bytes memory _payload)
        private
        view
        returns (uint256 price, uint256 lastUpdated)
    {
        (bool success, bytes memory returnedData) = _adapter.staticcall(_payload);//static call libraries function? ChainlinkAdapter.price(address source)
        if (success) (price, lastUpdated) = abi.decode(returnedData, (uint256, uint256));// always return 8 decimals price 
    }

    /// @dev Check if a price is stale
    /// @param _asset Asset address
    /// @param _lastUpdated Last updated timestamp
    /// @return isStale True if the price is stale
    function _isStale(address _asset, uint256 _lastUpdated) internal view returns (bool isStale) {
        isStale = block.timestamp - _lastUpdated > getPriceOracleStorage().staleness[_asset];
    }
}
