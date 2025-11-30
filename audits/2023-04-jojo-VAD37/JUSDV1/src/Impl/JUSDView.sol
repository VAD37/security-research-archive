/*
    Copyright 2022 JOJO Exchange
    SPDX-License-Identifier: BUSL-1.1*/
pragma solidity ^0.8.9;

import "./JUSDBankStorage.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";
import "../Interface/IJUSDBank.sol";
import {IPriceChainLink} from "../Interface/IPriceChainLink.sol";
abstract contract JUSDView is JUSDBankStorage, IJUSDBank {
    using DecimalMath for uint256;

    function getReservesList() external view returns (address[] memory) {
        return reservesList;
    }

    function getDepositMaxMintAmount(
        address user
    ) external view returns (uint256) {
        DataTypes.UserInfo storage userInfo = userInfo[user];
        return _maxMintAmountBorrow(userInfo);
    }

    function getCollateralMaxMintAmount(
        address collateral,
        uint256 amount
    ) external view returns (uint256 maxAmount) {
        DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
        return _getMintAmountBorrow(reserve, amount);
    }

    function getMaxWithdrawAmount(
        address collateral,
        address user
    ) external view returns (uint256 maxAmount) {
        DataTypes.UserInfo storage userInfo = userInfo[user];
        uint256 JUSDBorrow = userInfo.t0BorrowBalance.decimalMul(getTRate());
        if (JUSDBorrow == 0) {
            return userInfo.depositBalance[collateral];
        }
        uint256 maxMintAmount = _maxMintAmount(userInfo);
        if (maxMintAmount <= JUSDBorrow) {
            maxAmount = 0;
        } else {
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            uint256 remainAmount = (maxMintAmount - JUSDBorrow).decimalDiv(
                reserve.initialMortgageRate.decimalMul(
                    IPriceChainLink(reserve.oracle).getAssetPrice()
                )
            );
            remainAmount >= userInfo.depositBalance[collateral]
                ? maxAmount = userInfo.depositBalance[collateral]
                : maxAmount = remainAmount;
        }
    }

    function isAccountSafe(address user) external view returns (bool) {
        DataTypes.UserInfo storage userInfo = userInfo[user];
        return !_isStartLiquidation(userInfo, getTRate());
    }

    function getCollateralPrice(
        address collateral
    ) external view returns (uint256) {
        return IPriceChainLink(reserveInfo[collateral].oracle).getAssetPrice();
    }

    function getIfHasCollateral(
        address from,
        address collateral
    ) external view returns (bool) {
        return userInfo[from].hasCollateral[collateral];
    }

    function getDepositBalance(
        address collateral,
        address from
    ) external view returns (uint256) {
        return userInfo[from].depositBalance[collateral];
    }

    function getBorrowBalance(address from) external view returns (uint256) {
        return (userInfo[from].t0BorrowBalance * getTRate()) / 1e18;
    }

    function getUserCollateralList(
        address from
    ) external view returns (address[] memory) {
        return userInfo[from].collateralList;
    }

    /// @notice get the JUSD mint amount
    function _getMintAmount(
        uint256 balance,// JUSD collateral balance 1e8 for BTC, 1e18 for ETH
        address oracle,//jojo oracle
        uint256 rate//1.00001e18
    ) internal view returns (uint256) {
        return
            IPriceChainLink(oracle)//adapter return 6 decimals price for WETH ?
                .getAssetPrice()//WBTC:  20000e8 *1e18/1e10
                .decimalMul(balance) // price * balance /1e18 //@audit-ok balance might not be in 1e18. Does oracle take in consideration for this?
                .decimalMul(rate); // * 1.00001e18 / 1e18
    }// WBTC: 20000e16 * e8 /1e18 * 1.00001e18 / 1e18 == JUSD 6 decimals
    //WETH: 2000e6 * e18 /1e18 * 1.00001e18 / 1e18
    function _getMintAmountBorrow(
        DataTypes.ReserveInfo memory reserve,
        uint256 amount//depositBalance
    ) internal view returns (uint256) {
        uint256 depositAmount = IPriceChainLink(reserve.oracle)//20000e6 * amount_e8 / 1e18
            .getAssetPrice()//JUSD 6 decimals.
            .decimalMul(amount)//@audit-ok H divide fixed with 1e18 when token use 1e6
            .decimalMul(reserve.initialMortgageRate); // * 0.8e18 / 1e18. 0.7 for BTC
        if (depositAmount >= reserve.maxColBorrowPerAccount) {
            depositAmount = reserve.maxColBorrowPerAccount;//@audit-ok why deposit limit here is overrided?
        }// WBTC: 20000e8 * amount_e18 / 1e18 * 0.8e18 / 1e18
        return depositAmount;
    }

    /// @notice according to the initialMortgageRate to judge whether the user's account is safe after borrow, withdraw, flashloan
    /// If the collateral is not allowed to be borrowed. When calculating max mint JUSD amount, treat the value of collateral as 0
    /// maxMintAmount = sum(collateral amount * price * initialMortgageRate)
    function _isAccountSafe(
        DataTypes.UserInfo storage user,
        uint256 tRate
    ) internal view returns (bool) {//t0BorrowBalance= deposit * 1e18 /old_tRate * new_tRate/1e18
        return user.t0BorrowBalance.decimalMul(tRate) <= _maxMintAmount(user);
    }

    function _isAccountSafeAfterBorrow(
        DataTypes.UserInfo storage user,
        uint256 tRate
    ) internal view returns (bool) {//@audit the borrowRate use new/old rate instead of time_delta * rate like compound. Does any other place use different rate logic?        
        return//t0BorrowBalance= deposit * 1e18 /old_tRate * new_tRate/1e18
            user.t0BorrowBalance.decimalMul(tRate) <= //this is basically deposit < maxMint
            _maxMintAmountBorrow(user); //maxMint in JUSD. price * original_deposit * 80%
    }

    function _maxMintAmount(
        DataTypes.UserInfo storage user
    ) internal view returns (uint256) {
        address[] memory collaterals = user.collateralList;
        uint256 maxMintAmount;
        for (uint256 i; i < collaterals.length; i = i + 1) {
            address collateral = collaterals[i];
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            if (!reserve.isBorrowAllowed) {
                continue;
            }
            maxMintAmount += _getMintAmount(    
                user.depositBalance[collateral],//WETH: 2000e6 * e18 /1e18 * 1.00001e18 / 1e18
                reserve.oracle,// WBTC: 20000e16 * e8 /1e18 * 1.00001e18 / 1e18
                reserve.initialMortgageRate
            );
        }
        return maxMintAmount;
    }

    function _maxMintAmountBorrow(
        DataTypes.UserInfo storage user
    ) internal view returns (uint256) {
        address[] memory collaterals = user.collateralList;
        uint256 maxMintAmount;
        for (uint256 i; i < collaterals.length; i = i + 1) {
            address collateral = collaterals[i];
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            if (!reserve.isBorrowAllowed) {//@audit when borrow disable. can double borrow if have 2 collateral but only borrow using 1 token
                continue;
            }
            uint256 colMintAmount = _getMintAmountBorrow(
                reserve,
                user.depositBalance[collateral]
            );
            maxMintAmount += colMintAmount;//@audit max mintAmount can be double using 2 collateral
        }
        return maxMintAmount;
    }

    /// @notice Determine whether the account is safe by liquidationMortgageRate
    // If the collateral delisted. When calculating the boundary conditions for collateral to be liquidated, treat the value of collateral as 0
    // liquidationMaxMintAmount = sum(depositAmount * price * liquidationMortgageRate)
    function _isStartLiquidation(//similar to _maxMintAmount
        DataTypes.UserInfo storage liquidatedTraderInfo,
        uint256 tRate
    ) internal view returns (bool) {
        uint256 JUSDBorrow = (liquidatedTraderInfo.t0BorrowBalance).decimalMul(
            tRate
        );//JUSDBorrow= deposit * 1e18 /old_tRate * new_tRate/1e18
        uint256 liquidationMaxMintAmount;
        address[] memory collaterals = liquidatedTraderInfo.collateralList;
        for (uint256 i; i < collaterals.length; i = i + 1) {
            address collateral = collaterals[i];
            DataTypes.ReserveInfo memory reserve = reserveInfo[collateral];
            if (reserve.isFinalLiquidation) {
                continue;
            }
            liquidationMaxMintAmount += _getMintAmount(
                liquidatedTraderInfo.depositBalance[collateral],
                reserve.oracle,
                reserve.liquidationMortgageRate //0.8e18 BTC. 0.825e18 ETH
            ); //initial 0.7e18 for BTC. 0.8e18 for ETH
        }//maxMint = deposit * price * 82%
        return liquidationMaxMintAmount < JUSDBorrow;
    }
}
