// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IAave {
    function getReservesList() external view returns (address[] memory);
    function getReserveAToken(address underlyingAsset) external view returns (address aToken);
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256 assets);
}