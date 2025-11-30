# H Emergency Liquidation Exploit in `JUSDBank.delistReserve()`

## Summary

During emergency situations when `JUSDBank.delistReserve()` is called, the function disables deposits directly and borrow indirectly, but it also enables free liquidation.

The issue arises because `reserve.isFinalLiquidation` is enabled along with disabling `reserve.isBorrowAllowed` in `delistReserve()`.
This allows anyone to buy the entire collateral of a user at a discount during the time of delistReserve, regardless of the user's debt, even if it's minimal and hasn't reached the liquidation limit.

Because of an exploit in the liquidation logic, attackers do not have to return the user's collateral value (USDC) that was not part of the debt.

## Vulnerability Detail

`JUSDBank.sol` support **partial** liquidation and **full** liquidation of user if their debt outweight their collateral value.

[Partial liquidation](https://github.com/sherlock-audit/2023-04-jojo-VAD37/blob/dc6d310fbabec7d4c870e87117bcd10b5a406a77/JUSDV1/src/Impl/JUSDBank.sol#L410-L419) only allow liquidate part of user collateral worth of debt + interest + discount share for liquidator.
[Full liquidation](https://github.com/sherlock-audit/2023-04-jojo-VAD37/blob/dc6d310fbabec7d4c870e87117bcd10b5a406a77/JUSDV1/src/Impl/JUSDBank.sol#L419-L434) allow liquidate entire collateral user balance, require liquidator settle debt and return user/liquidated collateral value that was not part of debt in USDC.
<details>
  <summary>Code Expand!</summary>

```js
    if (liquidateAmount <= JUSDBorrowed) { //partial liquidation in JUSD converted. 
        console.log("partial liquidation %se6 %se6", liquidateAmount/1e6, JUSDBorrowed/1e6);
        liquidateData.actualCollateral = amount;
        liquidateData.insuranceFee = amount.decimalMul(priceOff).decimalMul(
            reserve.insuranceFeeRate
        );//insuranceFee =amount * 0.95e18/1e18 * 0.1e18 / 1e18 = 0.095 * amount
        liquidateData.actualLiquidatedT0 = liquidateAmount.decimalDiv(
            tRate
        );//actualT0 = amount * 0.855 / tRate 
        liquidateData.actualLiquidated = liquidateAmount;//actualLiquidated = 0.855
    } else {
        //            actualJUSD = actualCollateral * priceOff
        //            = JUSDBorrowed * priceOff / priceOff * (1-insuranceFeeRate)
        //            = JUSDBorrowed / (1-insuranceFeeRate)
        //            insuranceFee = actualJUSD * insuranceFeeRate
        //            = actualCollateral * priceOff * insuranceFeeRate
        //            = JUSDBorrowed * insuranceFeeRate / (1- insuranceFeeRate)
        console.log("full   liquidation %s %s", liquidateAmount, JUSDBorrowed);
        liquidateData.actualCollateral = JUSDBorrowed//JUSDBorrowed = deposit* new/oldtRate 
            .decimalDiv(priceOff) //@ok JUSDBorrowed == liquidateAmount
            .decimalDiv(JOJOConstant.ONE - reserve.insuranceFeeRate);
        liquidateData.insuranceFee = JUSDBorrowed//insuranceFee = 0.1 *0.9 * amount
            .decimalMul(reserve.insuranceFeeRate)//insuranceFee = 0.09* amount
            .decimalDiv(JOJOConstant.ONE - reserve.insuranceFeeRate);
        liquidateData.actualLiquidatedT0 = liquidatedInfo.t0BorrowBalance;
        liquidateData.actualLiquidated = JUSDBorrowed;//actualT0 =deposit /tRate
    }
    
    liquidateData.liquidatedRemainUSDC = (amount -
        liquidateData.actualCollateral).decimalMul(price);
```

</details>

Liquidation triggered by `_isStartLiquidation()` function when `collateral value < debt with interest`.
<details>
  <summary>Code Expand!</summary>

```js
    function _isStartLiquidation(
        DataTypes.UserInfo storage liquidatedTraderInfo,
        uint256 tRate
    ) internal view returns (bool) {
        uint256 JUSDBorrow = (liquidatedTraderInfo.t0BorrowBalance).decimalMul(
            tRate
        );
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
                reserve.liquidationMortgageRate
            );
        }
        return liquidationMaxMintAmount < JUSDBorrow;
    }
```

</details>

If `collateral value` evaluation suddenly reach 0, any user can call full liquidation to buy 99.9% of collateral with discount.
And only have to repay user debt which could be really small. Pocketing the rest of collateral value that was supposed return to user/liquidated.

This can only happen during emergency, if `delistReserve()` was called by owner/admin.

`delistReserve()` disable deposit directly, but not borrow, and also enable free liquidation.

Borrow was disabled through math calculation internally. Through `_maxMintAmount()` and `_maxMintAmountBorrow()`. By skipping evaluation of borrow if disabled.
If admin set borrow to false, all collateral value worth will be 0 which prevent anyuser from borrow more JUSD.

Liquidation collateral value check was done through `_isStartLiquidation()`.
Free liquidation, or buy entire collateral and repay user debt
Which skip evaluation if `reserve.isFinalLiquidation` is enable.

Because `reserve.isFinalLiquidation` also enable along with disabling `reserve.isBorrowAllowed` in `delistReserve()` function call.
This effectively allow anyone

## Impact

During the time of `delistReserve`, anyone can buy entire collateral of user with discount regardless of debt even if user have only really small debt amount and their debt never reach liquidation limit.

## Code Snippet

## Tool used

Manual Review

## Recommendation

For this emergency function `delistReserve()` specifically, it make more sense to detach it into 2 separate function.
One for emergency disable borrow, deposit. Still allow user repay and withdraw.
Another for full liquidation.
