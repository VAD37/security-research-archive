// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IAave } from "../../interfaces/strategies/IAave.sol";
import { BaseStrategy, SafeERC20, IERC20 } from "../../BaseStrategy.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";

contract AaveStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    constructor (address _brinkVault, address _asset, address _reserve) BaseStrategy(_brinkVault, _asset, _reserve) {
        address[] memory reserves_ = IAave(_reserve).getReservesList();
        bool reserveExists = false;
        for (uint256 i = 0; i < reserves_.length; i++) {
            if (reserves_[i] == _asset) {
                reserveExists = true;
                break;
            }
        }
        if (!reserveExists) revert ErrorsLib.ASSET_MISMATCH();

        IERC20(_asset).safeIncreaseAllowance(_brinkVault, type(uint256).max);
    }

    function balance() external override view returns (uint256) {
        address sharesAddress = IAave(reserve).getReserveAToken(asset);
        return IERC20(sharesAddress).balanceOf(address(this));
    }

    function supply(uint256 _assetAmount) external override onlyBV {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _assetAmount);
        IERC20(asset).safeIncreaseAllowance(reserve, _assetAmount);

        IAave(reserve).supply(asset, _assetAmount, address(this), 0);
    }

    function withdraw(uint256 _assetAmount) external override onlyBV {
        address sharesAddress = IAave(reserve).getReserveAToken(asset);
        IERC20(sharesAddress).safeIncreaseAllowance(reserve, _assetAmount);

        IAave(reserve).withdraw(asset, _assetAmount, msg.sender);
    }

    function harvest() external override {
        // TODO: investigate harvest
    }
}