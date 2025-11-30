// SPDX-License-Identifier: gpl-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../libraries/Precision.sol";

import "../../interfaces/IExtraInterestBearingToken.sol";

import "./InterestRateUtils.sol";
import "../types/DataTypes.sol";
import "../helpers/Errors.sol";
import "../Constants.sol";
import {console} from "forge-std/console.sol";
library ReserveLogic {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @dev Get the total liquidity and borrowed out portion,
     * where the total liquidity is the sum of available liquidity and borrowed out portion.
     * @param reserve The Reserve Object
     */
    function totalLiquidityAndBorrows(DataTypes.ReserveData storage reserve)
        internal
        view
        returns (uint256 total, uint256 borrows)
    {
        borrows = borrowedLiquidity(reserve);//@total debt with current timestamp and interest rate
        total = availableLiquidity(reserve).add(borrows);//@exact borrows increase when underlying transferred away
    }

    /**
     * @dev Get the available liquidity not borrowed out.
     * @param reserve The Reserve Object
     * @return liquidity
     */
    function availableLiquidity(DataTypes.ReserveData storage reserve) internal view returns (uint256 liquidity) {
        liquidity = IERC20(reserve.underlyingTokenAddress).balanceOf(reserve.eTokenAddress);
    }

    /**
     * @dev Get the liquidity borrowed out.
     * @param reserve The Reserve Object
     * @return liquidity
     */
    function borrowedLiquidity(DataTypes.ReserveData storage reserve) internal view returns (uint256 liquidity) {
        liquidity = latestBorrowingIndex(reserve).mul(reserve.totalBorrows).div(reserve.borrowingIndex);        
    }

    /**
     * @dev Get the utilization of the reserve.
     * @param reserve The Reserve Object
     * @return rate
     */
    function utilizationRate(DataTypes.ReserveData storage reserve) internal view returns (uint256 rate) {
        (uint256 total, uint256 borrows) = totalLiquidityAndBorrows(reserve);

        if (total > 0) {
            rate = borrows.mul(Precision.FACTOR1E18).div(total);
        }//@audit-ok I not mathematic possible.utilization rate > 100%. does this happen with liquidation? It obviously increase more debt than maximum

        return rate;
    }

    /**
     * @dev Get the borrowing interest rate of the reserve.
     * @param reserve The Reserve Object
     * @return rate
     */
    function borrowingRate(DataTypes.ReserveData storage reserve) internal view returns (uint256 rate) {
        rate = InterestRateUtils.calculateBorrowingRate(reserve.borrowingRateConfig, utilizationRate(reserve));
    }

    /**
     * @dev Exchange Rate from reserve liquidity to eToken
     * @param reserve The Reserve Object
     * @return The Exchange Rate
     */
    function reserveToETokenExchangeRate(DataTypes.ReserveData storage reserve) internal view returns (uint256) {
        (uint256 totalLiquidity,) = totalLiquidityAndBorrows(reserve);
        uint256 totalETokens = IERC20(reserve.eTokenAddress).totalSupply();

        if (totalETokens == 0 || totalLiquidity == 0) {
            return Precision.FACTOR1E18;
        }
        return totalETokens.mul(Precision.FACTOR1E18).div(totalLiquidity);
    }

    /**
     * @dev Exchange Rate from eToken to reserve liquidity
     * @param reserve The Reserve Object
     * @return The Exchange Rate
     */
    function eTokenToReserveExchangeRate(DataTypes.ReserveData storage reserve) external view returns (uint256) {
        (uint256 totalLiquidity,) = totalLiquidityAndBorrows(reserve);
        uint256 totalETokens = IERC20(reserve.eTokenAddress).totalSupply();

        if (totalETokens == 0 || totalLiquidity == 0) {
            return Precision.FACTOR1E18;
        }
        return totalLiquidity.mul(Precision.FACTOR1E18).div(totalETokens);
    }

    /**
     * @dev Returns the borrowing index for the reserve
     * @param reserve The reserve object
     * @return The borrowing index.
     *
     */
    function latestBorrowingIndex(DataTypes.ReserveData storage reserve) internal view returns (uint256) {
        if (reserve.lastUpdateTimestamp == uint128(block.timestamp)) {
            //if the index was updated in the same block, no need to perform any calculation
            return reserve.borrowingIndex;
        }

        return reserve.borrowingIndex.mul(
            InterestRateUtils.calculateCompoundedInterest(reserve.currentBorrowingRate, reserve.lastUpdateTimestamp)
        ).div(Precision.FACTOR1E18);
    }

    function checkCapacity(DataTypes.ReserveData storage reserve, uint256 depositAmount) internal view {
        (uint256 totalLiquidity,) = totalLiquidityAndBorrows(reserve);

        require(totalLiquidity.add(depositAmount) <= reserve.reserveCapacity, Errors.VL_OUT_OF_CAPACITY);
    }

    /**
     * @dev Updates the the variable borrow index.
     * @param reserve the reserve object
     *
     */
    function updateState(DataTypes.ReserveData storage reserve, address treasury) internal {
        uint256 previousDebt = reserve.totalBorrows;
        _updateIndexes(reserve);

        _mintToTreasury(reserve, previousDebt, reserve.totalBorrows, treasury);
    }//@reserve.totalBorrows must > previousDebt

    /**
     * @dev Updates the interest rate of the reserve pool.
     * @param reserve the reserve object
     *
     */
    function updateInterestRates(DataTypes.ReserveData storage reserve) internal {
        reserve.currentBorrowingRate =
            InterestRateUtils.calculateBorrowingRate(reserve.borrowingRateConfig, utilizationRate(reserve));
    }

    /**
     * @dev Updates the reserve indexes and the timestamp of the update
     * @param reserve The reserve object
     *
     */
    function _updateIndexes(DataTypes.ReserveData storage reserve) internal {
        uint256 newBorrowingIndex = reserve.borrowingIndex;
        uint256 newTotalBorrows = reserve.totalBorrows;

        if (reserve.totalBorrows > 0) {
            newBorrowingIndex = latestBorrowingIndex(reserve);
            newTotalBorrows = newBorrowingIndex.mul(reserve.totalBorrows).div(reserve.borrowingIndex);
//@audit-ok not mathematics possible .M if newTotalBorrows < previous totalBorrows. This will brick the contracts. How can this happen? It can if someone manipulate borrow with very specific numbers
            require(newBorrowingIndex <= type(uint128).max, Errors.LP_BORROW_INDEX_OVERFLOW);

            reserve.borrowingIndex = newBorrowingIndex;
            reserve.totalBorrows = newTotalBorrows;
            reserve.lastUpdateTimestamp = uint128(block.timestamp);
        }
    }

    /**
     * @dev Mints part of the repaid interest to the reserve treasury as a function of the reserveFactor for the
     * specific asset.
     * @param reserve The reserve reserve to be updated
     * @param previousDebt The previous debt
     * @param currentDebt The current debt
     *
     */
    function _mintToTreasury(
        DataTypes.ReserveData storage reserve,
        uint256 previousDebt,
        uint256 currentDebt,
        address treasury
    ) internal {
        uint256 feeRate = reserve.reserveFeeRate;// 15.00%

        if (feeRate == 0) {
            return;
        }

        //debt accrued is the current debt minus the debt at the last update
        uint256 totalDebtAccrued = currentDebt.sub(previousDebt);//e6 token rounded down too much
        uint256 reserveValueAccrued = totalDebtAccrued.mul(feeRate).div(Constants.PERCENT_100);// =*1500 / 10000
        // reserve value to eTokens
        uint256 exchangeRate = reserveToETokenExchangeRate(reserve);//this rate < 1 . also depend on asset/token decimals
        uint256 feeInEToken = reserveValueAccrued.mul(exchangeRate).div(Precision.FACTOR1E18);//@audit LM 10 seconds seem still have tiny eToken L check if USDC or other type of token rounded so much that no fee is generated if called too fast.
    
        if (feeInEToken != 0) {
            IExtraInterestBearingToken(reserve.eTokenAddress).mintToTreasury(treasury, feeInEToken);
        }//@audit-ok H03 minting fee seem like fee take from user seem like not correct.
    }//@audit-ok H mint 15% fee to treasury does not dilute share price of lendingPool. leading to situtation where everyone withdraw. treasury take money 15% from user. and 15% interest not exist

    /**
     * @dev Sets the active state of the reserve
     * @param reserve The reserve
     * @param state The true or false state
     *
     */
    function setActive(DataTypes.ReserveData storage reserve, bool state) internal {
        reserve.flags.isActive = state;
    }

    /**
     * @dev Gets the active state of the reserve
     * @param reserve The reserve
     * @return The true or false state
     *
     */
    function getActive(DataTypes.ReserveData storage reserve) internal view returns (bool) {
        return reserve.flags.isActive;
    }

    /**
     * @dev Sets the frozen state of the reserve
     * @param reserve The reserve
     * @param state The true or false state
     *
     */
    function setFrozen(DataTypes.ReserveData storage reserve, bool state) internal {
        reserve.flags.frozen = state;
    }

    /**
     * @dev Gets the frozen state of the reserve
     * @param reserve The reserve
     * @return The true or false state
     *
     */
    function getFrozen(DataTypes.ReserveData storage reserve) internal view returns (bool) {
        return reserve.flags.frozen;
    }

    /**
     * @dev Sets the borrowing enable state of the reserve
     * @param reserve The reserve
     * @param state The true or false state
     *
     */
    function setBorrowingEnabled(DataTypes.ReserveData storage reserve, bool state) internal {
        reserve.flags.borrowingEnabled = state;
    }

    /**
     * @dev Gets the borrowing enable state of the reserve
     * @param reserve The reserve
     * @return The true or false state
     *
     */
    function getBorrowingEnabled(DataTypes.ReserveData storage reserve) internal view returns (bool) {
        return reserve.flags.borrowingEnabled;
    }
}
