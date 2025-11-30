// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IMorpho } from "../../interfaces/strategies/IMorpho.sol";
import { BaseStrategy, SafeERC20, IERC20 } from "../../BaseStrategy.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";
import { SharesMathLib } from "../../libraries/SharesMathLib.sol";
import { UtilsLib } from "../../libraries/UtilsLib.sol";

contract MorphoStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;

    bytes32 public marketId;

    error MARKET_PARAMS_NOT_SET();

    constructor(address _brinkVault, address _asset, address _reserve, bytes32 _marketId) BaseStrategy(_brinkVault, _asset, _reserve) {
        marketId = _marketId;

        IERC20(_asset).safeIncreaseAllowance(_brinkVault, type(uint256).max);
    }

    function balance() public override view returns (uint256 _supplyAssets) {
        IMorpho.Market memory market_ = IMorpho(reserve).market(marketId);
        IMorpho.Position memory position_ = IMorpho(reserve).position(marketId, address(this));
        _supplyAssets = position_.supplyShares.toAssetsDown(market_.totalSupplyAssets, market_.totalSupplyShares);
    }

    function supply(uint256 _assetAmount) external override onlyBV {
        IMorpho.MarketParams memory marketParams_ = getMarketParams();
        if (marketParams_.loanToken == address(0)) revert MARKET_PARAMS_NOT_SET();

        IERC20(asset).safeTransferFrom(msg.sender, address(this), _assetAmount);
        IERC20(asset).safeIncreaseAllowance(reserve, _assetAmount);

        IMorpho(reserve).supply(
            marketParams_,
            _assetAmount,
            0,
            address(this),
            bytes("")
        );

        if (IERC20(asset).allowance(address(this), reserve) > 0) IERC20(asset).forceApprove(reserve, 0);
    }

    function withdraw(uint256 _assetAmount) external override onlyBV {
        IMorpho.MarketParams memory marketParams_ = getMarketParams();
        if (marketParams_.loanToken == address(0)) revert MARKET_PARAMS_NOT_SET();

        IMorpho.Market memory market_ = IMorpho(reserve).market(marketId);
        IMorpho.Position memory position_ = IMorpho(reserve).position(marketId, address(this));

        uint256 supplyAssets = position_.supplyShares.toAssetsDown(market_.totalSupplyAssets, market_.totalSupplyShares);

        uint256 availableLiquidity = UtilsLib.min(
            market_.totalSupplyAssets - market_.totalBorrowAssets, IERC20(asset).balanceOf(reserve)
        );

        uint256 toWithdraw = UtilsLib.min(
            UtilsLib.min(supplyAssets, availableLiquidity), _assetAmount
        );//@audit user deposit a lot of cash, but have strategies switch to morpho 99% later on. cannot withdraw everything, if this morpho position does not have enough cash. This case seem unlikely.
        //@ it not possible for one user withdraw more from morpho than what is the value worth of them.
        IMorpho(reserve).withdraw(
            marketParams_,
            toWithdraw,
            0,
            address(this),
            msg.sender
        );
    }

    function harvest() external override {
        // TODO: investigate harvest
    }

    function getMarketParams() internal view returns (IMorpho.MarketParams memory) {
        return IMorpho(reserve).idToMarketParams(marketId);
    }
}