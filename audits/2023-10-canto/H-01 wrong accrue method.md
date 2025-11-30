https://github.com/code-423n4/2023-10-canto/blob/37a1d64cf3a10bf37cbc287a22e8991f04298fa0/canto_ambient/contracts/mixins/TradeMatcher.sol#L342

# `TradeMatcher.harvestRange()` use wrong accrue method


## Impact

`TradeMatcher.harvestRange()` use wrong function to accrued reward. Allowing further exploit on claiming more rewards than user suppose to get.
## Proof of Concept

`TradeMatcher` operation `harvestRange()` call `liquidityPayable (CurveMath.CurveState memory curve, uint128 seeds)` 
```solidity
File: canto_ambient\contracts\mixins\TradeMatcher.sol
333:     function harvestRange (CurveMath.CurveState memory curve, int24 priceTick,
334:                            int24 lowTick, int24 highTick, bytes32 poolHash,
335:                            address lpOwner)
336:         internal returns (int128, int128) {
337:         uint72 feeMileage = clockFeeOdometer72(poolHash, priceTick, lowTick, highTick,
338:                                                curve.concGrowth_);
339:         uint128 rewards = harvestPosLiq(lpOwner, poolHash,
340:                                         lowTick, highTick, feeMileage);
341:         withdrawConduit(poolHash, lowTick, highTick, 0, feeMileage, lpOwner);
342:         accrueConcentratedGlobalTimeWeightedLiquidity(poolHash, curve);//@audit this thing bump ambient not cencentrated
343:         (uint128 base, uint128 quote) = liquidityPayable(curve, rewards);
344:         return signBurnFlow(base, quote);
345:     }
```
which call into `bumpAmbent()`

```solidity
File: canto_ambient\contracts\mixins\LiquidityCurve.sol
193:     function liquidityPayable (CurveMath.CurveState memory curve, uint128 seeds)
194:         internal pure returns (uint128 base, uint128 quote) {
195:         (base, quote) = liquidityFlows(curve, seeds);
196:         bumpAmbient(curve, -(seeds.toInt128Sign()));
197:     }
```

not `liquidityPayable (CurveMath.CurveState memory curve, uint128 liquidity, uint64 rewardRate, int24 lowerTick, int24 upperTick)`
which call into `bumpConcentrated()` like [in `burnKnockOut() here`](https://github.com/code-423n4/2023-10-canto/blob/37a1d64cf3a10bf37cbc287a22e8991f04298fa0/canto_ambient/contracts/mixins/TradeMatcher.sol#L263-L274)
```solidity
File: canto_ambient\contracts\mixins\LiquidityCurve.sol
140:     function liquidityPayable (CurveMath.CurveState memory curve, uint128 liquidity,
141:                                uint64 rewardRate, int24 lowerTick, int24 upperTick)
142:         internal pure returns (uint128 base, uint128 quote) {
143:         (base, quote) = liquidityPayable(curve, liquidity, lowerTick, upperTick);
144:         (base, quote) = stackRewards(base, quote, curve, liquidity, rewardRate);
145:    }
...
169:     function liquidityPayable (CurveMath.CurveState memory curve, uint128 liquidity,
170:                                int24 lowerTick, int24 upperTick)
171:         internal pure returns (uint128 base, uint128 quote) {
172:         bool inRange;
173:         (base, quote, inRange) = liquidityFlows(curve.priceRoot_, liquidity,
174:                                                 lowerTick, upperTick);
175:         bumpConcentrated(curve, -(liquidity.toInt128Sign()), inRange);
176:     }
```

So calling `accrueConcentrated` here is wrong and should be `accrueAmbient` as it update `curve.ambientSeeds_` value internally.

## Tools Used

Manual

## Recommended Mitigation Steps

```git
File: canto_ambient\contracts\mixins\TradeMatcher.sol
        function harvestRange (CurveMath.CurveState memory curve, int24 priceTick,
                           int24 lowTick, int24 highTick, bytes32 poolHash,
                           address lpOwner)
        internal returns (int128, int128) {
        uint72 feeMileage = clockFeeOdometer72(poolHash, priceTick, lowTick, highTick,
                                               curve.concGrowth_);
        uint128 rewards = harvestPosLiq(lpOwner, poolHash,
                                        lowTick, highTick, feeMileage);
        withdrawConduit(poolHash, lowTick, highTick, 0, feeMileage, lpOwner);
-        accrueConcentratedGlobalTimeWeightedLiquidity(poolHash, curve);//@audit this thing bump ambient not concentrated
+        accrueAmbientGlobalTimeWeightedLiquidity(poolHash, curve);
        (uint128 base, uint128 quote) = liquidityPayable(curve, rewards);
        return signBurnFlow(base, quote);
    }

```
