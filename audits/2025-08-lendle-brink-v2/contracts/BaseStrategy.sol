// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ErrorsLib } from "./libraries/ErrorsLib.sol";
import { IBaseStrategy } from "./interfaces/IBaseStrategy.sol";

abstract contract BaseStrategy is IBaseStrategy {
    using SafeERC20 for IERC20;

    error NOT_AUTHORIZED();

    address public brinkVault;
    address public asset;
    address public reserve;

    modifier onlyBV() {
        if (msg.sender != brinkVault) revert NOT_AUTHORIZED();
        _;
    }

    constructor(address _brinkVault, address _asset, address _reserve) {
        if (_brinkVault == address(0) || _asset == address(0) || _reserve == address(0)) revert ErrorsLib.ZERO_ADDRESS();

        brinkVault = _brinkVault;
        asset = _asset;
        reserve = _reserve;
    }

    function balance() external view virtual returns (uint256) {}

    function supply(uint256 _assetAmount) external virtual {}

    function withdraw(uint256 _assetAmount) external virtual {}

    function harvest() external virtual {}
}
