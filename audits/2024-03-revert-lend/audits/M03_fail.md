# Admin can prevent old loan from repaying if loan exist before admin change new `CollateralValueLimit`

Project use this value `tokenConfig[token].collateralValueLimitFactorX32` to prevent certain token from being used as too much collateral.
For example a WETH config with `collateralValueLimitFactorX32` value of 40% * Q32 mean prevent Vault from holding 40% share worth of uniswap pair position WETH/DAI , WETH/USDC as collateral.

If the current WETH collateral already worth more than 40% of the loan, this also backfire to current loan borrower. As function validate `_updateAndCheckCollateral` also exist in repayment function. This prevent user from repay old loan if admin change `collateralValueLimitFactorX32` to lower value.

## Impact

User cannot repay loan if admin decided that there was too much collateral of certain kind of token.

## Proof of Concept
https://github.com/code-423n4/2024-03-revert-lend/blob/435b054f9ad2404173f36f0f74a5096c894b12b7/src/V3Vault.sol#L1204-L1243C10
Look at `_updateAndCheckCollateral()` function safety check if there are too much collateral of certain token.
```solidity
    // updates collateral token configs - and check if limit is not surpassed (check is only done on increasing debt shares)
    function _updateAndCheckCollateral(//@note updateAndCheckCollateral bypass with zero share change. for withdraw NFT.
        uint256 tokenId,//@user
        uint256 debtExchangeRateX96,//refreshed
        uint256 lendExchangeRateX96,//
        uint256 oldShares,//Borrow: loan.debtShares                              Repay: oldLoanDebtShares before repay
        uint256 newShares//         loan.debtShares + shares(USDC borrow share)         new loanDebtshare after repay
    ) internal {
        if (oldShares != newShares) {
            (,, address token0, address token1,,,,,,,,) = nonfungiblePositionManager.positions(tokenId);

            // remove previous collateral - add new collateral
            if (oldShares > newShares) {
                tokenConfigs[token0].totalDebtShares -= SafeCast.toUint192(oldShares - newShares);
                tokenConfigs[token1].totalDebtShares -= SafeCast.toUint192(oldShares - newShares);
            } else {
                tokenConfigs[token0].totalDebtShares += SafeCast.toUint192(newShares - oldShares);//@ +shares just minted from USDC
                tokenConfigs[token1].totalDebtShares += SafeCast.toUint192(newShares - oldShares);

                // check if current value of used collateral is more than allowed limit
                // if collateral is decreased - never revert
                uint256 lentAssets = _convertToAssets(totalSupply(), lendExchangeRateX96, Math.Rounding.Up);
                uint256 collateralValueLimitFactorX32 = tokenConfigs[token0].collateralValueLimitFactorX32;
                if (
                    collateralValueLimitFactorX32 < type(uint32).max//@in test this always max for all token
                        && _convertToAssets(tokenConfigs[token0].totalDebtShares, debtExchangeRateX96, Math.Rounding.Up)
                            > lentAssets * collateralValueLimitFactorX32 / Q32
                ) {//@ collateralAsset = totalDebtShares * current debtExchangeRate / Q96 = currentValue of oldShare + new USDC
                    revert CollateralValueLimit();//@debt share converted from request borrow USDC. share = oldShare + new asset(USDC)/debtExchangeRate * Q96
                }
                collateralValueLimitFactorX32 = tokenConfigs[token1].collateralValueLimitFactorX32;
                if (
                    collateralValueLimitFactorX32 < type(uint32).max
                        && _convertToAssets(tokenConfigs[token1].totalDebtShares, debtExchangeRateX96, Math.Rounding.Up)
                            > lentAssets * collateralValueLimitFactorX32 / Q32
                ) {
                    revert CollateralValueLimit();
                }//@audit check collateral does not limit lend value when limitFactor is 100% Q32
            }
        }
    }
```
What does `_updateAndCheckCollateral()` do is when debt is updated, check if current debt of certain token is more than allowed limit. If it is, revert.


## Tools Used

## Recommended Mitigation Steps
