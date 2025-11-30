// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHandler {
    function getTotalBorrowed() external view returns (uint256 totalBorrowed);
    function getTotalBorrowedFromRegistry() external view returns (uint256 totalBorrowed);
    function getTotalCollateral() external view returns (uint256 totalCollateral);
    function getTotalCollateralFromRegistry() external view returns (uint256 totalCollateral);
}
