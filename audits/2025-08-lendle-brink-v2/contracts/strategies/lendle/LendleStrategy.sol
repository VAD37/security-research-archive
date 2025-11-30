// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ILendle } from "../../interfaces/strategies/ILendle.sol";
import { BaseStrategy, SafeERC20, IERC20 } from "../../BaseStrategy.sol";
import { ErrorsLib } from "../../libraries/ErrorsLib.sol";

contract LendleStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    constructor (address _brinkVault, address _asset, address _reserve) BaseStrategy(_brinkVault, _asset, _reserve) {
        address[] memory reserves_ = ILendle(_reserve).getReservesList();
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
        address sharesAddress = ILendle(reserve).getReserveAToken(asset);//@audit-ok aave return latest index for view
        return IERC20(sharesAddress).balanceOf(address(this));
    }

    function supply(uint256 _assetAmount) external override onlyBV {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _assetAmount);
        IERC20(asset).safeIncreaseAllowance(reserve, _assetAmount);

        ILendle(reserve).supply(asset, _assetAmount, address(this), 0);
    }

    function withdraw(uint256 _assetAmount) external override onlyBV {
        address sharesAddress = ILendle(reserve).getReserveAToken(asset);
        IERC20(sharesAddress).safeIncreaseAllowance(reserve, _assetAmount);

        ILendle(reserve).withdraw(asset, _assetAmount, msg.sender);
    }

    function harvest() external override {}
}