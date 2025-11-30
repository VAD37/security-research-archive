/*
    Copyright 2022 JOJO Exchange
    SPDX-License-Identifier: BUSL-1.1*/
pragma solidity 0.8.9;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {DataTypes} from "../lib/DataTypes.sol";
import "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../utils/FlashLoanReentrancyGuard.sol";
import "../lib/JOJOConstant.sol";

abstract contract JUSDBankStorage is
    Ownable,
    ReentrancyGuard,
    FlashLoanReentrancyGuard
{
    // reserve token address ==> reserve info
    mapping(address => DataTypes.ReserveInfo) public reserveInfo;
    // reserve token address ==> user info
    mapping(address => DataTypes.UserInfo) public userInfo;
    //client -> operator -> bool
    mapping(address => mapping(address => bool)) public operatorRegistry;
    // reserves amount
    uint256 public reservesNum;
    // max reserves amount
    uint256 public maxReservesNum;//10
    // max borrow JUSD amount per account
    uint256 public maxPerAccountBorrowAmount;// 100,000e6 or 1,000e8
    // max total borrow JUSD amount
    uint256 public maxTotalBorrowAmount;// 100,000e6 + 1
    // t0 total borrow JUSD amount
    uint256 public t0TotalBorrowAmount;
    // borrow fee rate
    uint256 public borrowFeeRate;//0.02e18
    // t0Rate
    uint256 public t0Rate;//1e18
    // update timestamp
    uint32 public lastUpdateTimestamp;//block.timestamp
    // reserves's list
    address[] public reservesList;
    // insurance account
    address public insurance;// random account
    // JUSD address
    address public JUSD;
    // primary address
    address public primaryAsset;//USDC
    address public JOJODealer;//dealer contract
    bool public isLiquidatorWhitelistOpen;
    mapping(address => bool) isLiquidatorWhiteList;
    //@note lastUpdateTimestamp is fixed as init block.timstamp. Or last time update new borrowRate
    function getTRate() public view returns (uint256) {
        uint256 timeDifference = block.timestamp - uint256(lastUpdateTimestamp);
        return
            t0Rate +
            (borrowFeeRate * timeDifference) /
            JOJOConstant.SECONDS_PER_YEAR;//31536000
    }
}
