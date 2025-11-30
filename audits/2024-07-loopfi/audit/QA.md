
## Low

1. PoolV3 did not return 1:1 share:assets ratio
`PoolV3.sol` never override these ERC4626 function from OpenZepplin:

- `convertToShares(uint256 assets)`
- `convertToAssets(uint256 shares)`

Poolv3 suppose to return asset:share price ratio as 1:1
As seen here: <https://github.com/code-423n4/2024-07-loopfi/blob/57871f64bdea450c1f04c9a53dc1a78223719164/src/PoolV3.sol#L426-L439>

Calling `convertToShares()` still use default ERC4626 logic which it never return 1:1 share price.

2. `PoolV3.updateQuotaRevenue()` can underflow and record breaking profit if revenue ever negative.

Solidity still allow underflow like `uint(int256(-100)) = type(uint256).max - 99`
This function `updateQuotaRevenue`. It is possible for `-quotaRevenueDelta > quotaRevenue` causing underflow here.
<https://github.com/code-423n4/2024-07-loopfi/blob/57871f64bdea450c1f04c9a53dc1a78223719164/src/PoolV3.sol#L691-L701>

While, it is impossible with current logic to have `quotaRevenue < 0` . Because `quotaRevenue -= negativeRevenue(badDebt)` rarely happen.
It is still minor security issue that should be patched to prevent infinity revenue.
