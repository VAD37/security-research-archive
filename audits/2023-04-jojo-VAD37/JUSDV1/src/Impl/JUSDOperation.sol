/*
    Copyright 2022 JOJO Exchange
    SPDX-License-Identifier: BUSL-1.1*/

pragma solidity 0.8.9;

import "./JUSDBankStorage.sol";
import "../utils/JUSDError.sol";
import "../lib/JOJOConstant.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";

/// @notice Owner-only functions
abstract contract JUSDOperation is JUSDBankStorage {
    using DecimalMath for uint256;

    // ========== event ==========
    event UpdateInsurance(address oldInsurance, address newInsurance);
    event UpdateJOJODealer(address oldJOJODealer, address newJOJODealer);
    event SetOperator(
        address indexed client,
        address indexed operator,
        bool isOperator
    );
    event UpdateOracle(address collateral, address newOracle);
    event UpdateBorrowFeeRate(
        uint256 newBorrowFeeRate,
        uint256 newT0Rate,
        uint32 lastUpdateTimestamp
    );
    event UpdateMaxReservesAmount(
        uint256 maxReservesAmount,
        uint256 newMaxReservesAmount
    );
    event RemoveReserve(address indexed collateral);
    event ReRegisterReserve(address indexed collateral);
    event UpdateReserveRiskParam(
        address indexed collateral,
        uint256 liquidationMortgageRate,
        uint256 liquidationPriceOff,
        uint256 insuranceFeeRate
    );
    event UpdatePrimaryAsset(
        address indexed usedPrimary,
        address indexed newPrimary
    );
    event UpdateReserveParam(
        address indexed collateral,
        uint256 initialMortgageRate,
        uint256 maxTotalDepositAmount,
        uint256 maxDepositAmountPerAccount,
        uint256 maxBorrowValue
    );
    event UpdateMaxBorrowAmount(
        uint256 maxPerAccountBorrowAmount,
        uint256 maxTotalBorrowAmount
    );

    /// @notice initial the param of each reserve
    function initReserve(
        address _collateral,//BTC or ETH
        uint256 _initialMortgageRate,//0.7e18 for BTC. 0.8e18 for ETH
        uint256 _maxTotalDepositAmount,//300e8 or 30,000e6 BTC. 4000e18 ETH
        uint256 _maxDepositAmountPerAccount,//210e8 or 21k. 2030e18 ETH
        uint256 _maxColBorrowPerAccount,//100000e6 for both
        uint256 _liquidationMortgageRate,//0.8e18 BTC. 0.825e18 ETH
        uint256 _liquidationPriceOff,//0.05e18 for both
        uint256 _insuranceFeeRate,//0.1e18 for both
        address _oracle//JOJOOracleAdaptor usdcPrice. 10 decimal for BTC . 20 decimals for ETH
    ) external onlyOwner {
        require(
            JOJOConstant.ONE - _liquidationMortgageRate >//0.2e18
                _liquidationPriceOff +//0.05e18
                    (JOJOConstant.ONE - _liquidationPriceOff).decimalMul(//0.95e18 *0.1e18 /1e18 =0.095e18
                        _insuranceFeeRate
                    ),
            JUSDErrors.RESERVE_PARAM_ERROR//0.2 > 0.145 . Or 0.055e18 different
        );//@audit H when does the require check for insurance incorrect?
        reserveInfo[_collateral].initialMortgageRate = _initialMortgageRate;
        reserveInfo[_collateral].maxTotalDepositAmount = _maxTotalDepositAmount;
        reserveInfo[_collateral]
            .maxDepositAmountPerAccount = _maxDepositAmountPerAccount;
        reserveInfo[_collateral]
            .maxColBorrowPerAccount = _maxColBorrowPerAccount;
        reserveInfo[_collateral]
            .liquidationMortgageRate = _liquidationMortgageRate;
        reserveInfo[_collateral].liquidationPriceOff = _liquidationPriceOff;
        reserveInfo[_collateral].insuranceFeeRate = _insuranceFeeRate;
        reserveInfo[_collateral].isDepositAllowed = true;
        reserveInfo[_collateral].isBorrowAllowed = true;
        reserveInfo[_collateral].oracle = _oracle;
        _addReserve(_collateral);
    }

    function _addReserve(address collateral) private {
        require(
            reservesNum <= maxReservesNum,
            JUSDErrors.NO_MORE_RESERVE_ALLOWED
        );
        reservesList.push(collateral);
        reservesNum += 1;
    }

    /// @notice update the max borrow amount of total and per account
    function updateMaxBorrowAmount(
        uint256 _maxBorrowAmountPerAccount,
        uint256 _maxTotalBorrowAmount
    ) external onlyOwner {
        maxTotalBorrowAmount = _maxTotalBorrowAmount;
        maxPerAccountBorrowAmount = _maxBorrowAmountPerAccount;
        emit UpdateMaxBorrowAmount(
            maxPerAccountBorrowAmount,
            maxTotalBorrowAmount
        );
    }

    /// @notice update the insurance account
    function updateInsurance(address newInsurance) external onlyOwner {
        emit UpdateInsurance(insurance, newInsurance);
        insurance = newInsurance;
    }

    /// @notice update JOJODealer address
    function updateJOJODealer(address newJOJODealer) external onlyOwner {
        emit UpdateJOJODealer(JOJODealer, newJOJODealer);
        JOJODealer = newJOJODealer;
    }

    function liquidatorWhitelistOpen() external onlyOwner {
        isLiquidatorWhitelistOpen = true;
    }

    function liquidatorWhitelistClose() external onlyOwner {
        isLiquidatorWhitelistOpen = false;
    }

    function addLiquidator(address liquidator) external onlyOwner {
        isLiquidatorWhiteList[liquidator] = true;
    }

    function removeLiquidator(address liquidator) external onlyOwner {
        isLiquidatorWhiteList[liquidator] = false;
    }

    /// @notice update collateral oracle
    function updateOracle(
        address collateral,
        address newOracle
    ) external onlyOwner {
        DataTypes.ReserveInfo storage reserve = reserveInfo[collateral];
        reserve.oracle = newOracle;
        emit UpdateOracle(collateral, newOracle);
    }

    function updateMaxReservesAmount(
        uint256 newMaxReservesAmount
    ) external onlyOwner {
        emit UpdateMaxReservesAmount(maxReservesNum, newMaxReservesAmount);
        maxReservesNum = newMaxReservesAmount;
    }

    function updatePrimaryAsset(address newPrimary) external onlyOwner {
        emit UpdatePrimaryAsset(primaryAsset, newPrimary);
        primaryAsset = newPrimary;
    }

    /// @notice update the borrow fee rate
    // t0Rate and lastUpdateTimestamp will be updated according to the borrow fee rate
    function updateBorrowFeeRate(uint256 _borrowFeeRate) external onlyOwner {//@audit M each time update borrow fee rate. borrow fee become 0 for a few second. This seem exploitable
        t0Rate = getTRate();
        lastUpdateTimestamp = uint32(block.timestamp);
        borrowFeeRate = _borrowFeeRate;//@audit-ok No cap for borrow feeRate by owner
        emit UpdateBorrowFeeRate(_borrowFeeRate, t0Rate, lastUpdateTimestamp);
    }

    /// @notice update the reserve risk params
    function updateRiskParam(
        address collateral,
        uint256 _liquidationMortgageRate,
        uint256 _liquidationPriceOff,
        uint256 _insuranceFeeRate
    ) external onlyOwner {
        require(
            JOJOConstant.ONE - _liquidationMortgageRate >
                _liquidationPriceOff +
                    ((JOJOConstant.ONE - _liquidationPriceOff) *//@note update different from init code but correct logic.
                        _insuranceFeeRate) /
                    JOJOConstant.ONE,
            JUSDErrors.RESERVE_PARAM_ERROR
        );
        reserveInfo[collateral]
            .liquidationMortgageRate = _liquidationMortgageRate;
        reserveInfo[collateral].liquidationPriceOff = _liquidationPriceOff;
        reserveInfo[collateral].insuranceFeeRate = _insuranceFeeRate;
        emit UpdateReserveRiskParam(
            collateral,
            _liquidationMortgageRate,
            _liquidationPriceOff,
            _insuranceFeeRate
        );
    }

    /// @notice update the reserve basic params
    function updateReserveParam(
        address collateral,
        uint256 _initialMortgageRate,
        uint256 _maxTotalDepositAmount,
        uint256 _maxDepositAmountPerAccount,
        uint256 _maxColBorrowPerAccount
    ) external onlyOwner {
        reserveInfo[collateral].initialMortgageRate = _initialMortgageRate;
        reserveInfo[collateral].maxTotalDepositAmount = _maxTotalDepositAmount;
        reserveInfo[collateral]
            .maxDepositAmountPerAccount = _maxDepositAmountPerAccount;
        reserveInfo[collateral]
            .maxColBorrowPerAccount = _maxColBorrowPerAccount;
        emit UpdateReserveParam(
            collateral,
            _initialMortgageRate,
            _maxTotalDepositAmount,
            _maxDepositAmountPerAccount,
            _maxColBorrowPerAccount
        );
    }

    /// @notice remove the reserve, need to modify the market status
    /// which means this reserve is delist
    function delistReserve(address collateral) external onlyOwner {
        DataTypes.ReserveInfo storage reserve = reserveInfo[collateral];
        reserve.isBorrowAllowed = false;
        reserve.isDepositAllowed = false;
        reserve.isFinalLiquidation = true;
        emit RemoveReserve(collateral);
    }

    /// @notice relist the delist reserve
    function relistReserve(address collateral) external onlyOwner {
        DataTypes.ReserveInfo storage reserve = reserveInfo[collateral];
        reserve.isBorrowAllowed = true;
        reserve.isDepositAllowed = true;
        reserve.isFinalLiquidation = false;
        emit ReRegisterReserve(collateral);
    }

    /// @notice Update the sub account
    function setOperator(address operator, bool isOperator) external {
        operatorRegistry[msg.sender][operator] = isOperator;//@audit-ok can multicall setOperator self?
        emit SetOperator(msg.sender, operator, isOperator);
    }
}
