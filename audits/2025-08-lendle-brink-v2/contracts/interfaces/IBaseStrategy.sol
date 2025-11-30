// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IBaseStrategy {
    function brinkVault() external view returns (address);
    function asset() external view returns (address);
    function reserve() external view returns (address);
    function balance() external view returns (uint256);
    function supply(uint256 assetAmount) external;
    function withdraw(uint256 assetAmount) external;
    function harvest() external;
}
