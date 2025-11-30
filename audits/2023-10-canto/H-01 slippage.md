# Slippage attack on claiming rewards

## code

<https://github.com/code-423n4/2023-10-canto/blob/37a1d64cf3a10bf37cbc287a22e8991f04298fa0/canto_ambient/contracts/mixins/LiquidityMining.sol#L276-L282>

## Impact

Exploiter can abuse slippage to claim more weekly reward.

The amount of slippage damage is unclear due to lack of deployment context and testing.
Worst case scenario is the exploiter own 100% deposit of single pool allowing extreme slippage to steal entire contract token.
Owning 100% of single pool rarely happen on live network. But it is possible to flashloan to own majority of the pool token.

## Tools Used

Manual

## summary

New *sidecar* `LiquidityMiningPath.sol` provide function to claim new CANTO reward token based on time spend deposit on UniswapV2 (AmbientPosition) or V3(Concentrated) pool position.
The new rewards fomular can be simplified as:
`reward = userTimeWeight * weeklyRewardRate / totalTimeWeighted`

- `weeklyRewardRate`: fixed value set by governance
- `userTimeWeight`: user time spend in the pool weighted. Update everytime user mint/burn/claim through `TradeMatcher.sol` operation
- `totalTimeWeighted`: total time weight. Update along userTimeWeight.

Here is how acrrued reward calculated in code:

- `userTimeWeight = userDeltaTimeWeekly * pos.seeds_`
  - `pos.seeds_` is user provided liquidity/token in pool
  - `pos.seeds_` change everytime user mint/burn/claim through `TradeMatcher.sol` operation
- `totalTimeWeighted = globalDeltaTime * curve.ambientSeeds_`
  - `curve.ambientSeeds_` is a very convoluted/complex value change through `LiquidityCurve.liquidityPayable()` which is outside of user influence
  - `curve.ambientSeeds_` > `pos.seeds_` most of the time.
  - `curve.ambientSeeds_` does not update to new value if accrued on same block.
  - By abusing globalAccrue not updating on same block but user accrued do on different account. Exploiter can abuse this by making this condition `pos.seeds_` > `curve.ambientSeeds_` become true

Under assumption that:

- user can flashloan token to deposit and inflate `pos.seeds_` to very high value
- deltaTime is at 1 second by accrue right after the beginning of new week.
- `curve.ambientSeeds_` can be really small value if exploiter can own majority of the pool token.
- `curve.ambientSeeds_` value is *frozen* with small value and not updating to bigger value along with `pos.seeds_`

`reward` can be inflated to really high value by making this condition become true `pos.seeds_ >= curve.ambientSeeds_` or `userTimeWeight > totalTimeWeighted`

## Proof of concept

As an exploiter, all I need to do is the following:

1. Have multiple accounts deposit/mint small amount token to pool for previous week. Just so when calling `claimAmbientRewards()` it can update accrued reward for previous week and next week.
2. Before end of the week, like in last block/second. `curve.ambientSeeds_` need to be really small value as much as possible for higher slippage payout
3. Withdraw/burn token from pool will reduce both global `curve.ambientSeeds_` and user `pos.seeds_`.
4. Wait for new week to start. Wait 1 second just so deltatime is 1 second.
5. Calling accrue update through mint/burn or claim reward.
6. `accrueAmbientGlobalTimeWeightedLiquidity()` will be called once. This update global weight to new value: `deltaTime * curve.ambientSeeds_`
7. global weight is shared among all user. So next time user accrue, updating global weight will be skipped and using old value. Which is smaller.
8. Inflate `pos.seeds_` value by mint/deposit token to the pool. This will update user weight to new value: `deltaTime * pos.seeds_`. `curve.ambientSeeds_` also updated but not global weight when calling on same block.
9. Calling `claimAmbientRewards()` for previous week, the current week deltaTime is 1 second, hopefully new `userTimeWeight` > non-updated `totalTimeWeighted`
10. Repeat 7-9 steps for all accounts that was ready in step 1. Hopefully enough profit to cover gas cost on CANTO network.
11. Waiting till next week to withdraw inflated rewards from the pool.

## Vulneribility Details

Look at how rewards is calcualted in `LiquidityMining.sol`:

```js
File: canto_ambient\contracts\mixins\LiquidityMining.sol
256:     function claimAmbientRewards(//@user operation
257:         address owner,//msg.sender through delegatecall to Dex
258:         bytes32 poolIdx,//user
259:         uint32[] memory weeksToClaim//user
260:     ) internal {
...
273:             uint256 overallTimeWeightedLiquidity = timeWeightedWeeklyGlobalAmbLiquidity_[
274:                     poolIdx
275:                 ][week];//@overallTimeWeightedLiquidity == totalTimeWeighted
276:             if (overallTimeWeightedLiquidity > 0) {//@ timeWeightedWeeklyPositionAmbLiquidity_ == userTimeWeight per week
277:                 uint256 rewardsForWeek = (timeWeightedWeeklyPositionAmbLiquidity_[
278:                     poolIdx
279:                 ][posKey][week] * ambRewardPerWeek_[poolIdx][week]) /
280:                     overallTimeWeightedLiquidity;//@audit M user can exploit timeweighted weekly to very small value to get more reward
281:                 rewardsToSend += rewardsForWeek;
282:             }
```

As above, this can simplified as:
`reward = userTimeWeight * weeklyRewardRate / totalTimeWeighted`

The value `timeWeightedWeeklyGlobalAmbLiquidity_` is updated in [function `LiquidityMining.accrueAmbientGlobalTimeWeightedLiquidity()`](https://github.com/code-423n4/2023-10-canto/blob/37a1d64cf3a10bf37cbc287a22e8991f04298fa0/canto_ambient/contracts/mixins/LiquidityMining.sol#L198-L222). Which is called everytime user mint/burn/claim position.

```js
File: canto_ambient\contracts\mixins\TradeMatcher.sol
63:     function mintAmbient (CurveMath.CurveState memory curve, uint128 liqAdded, 
64:                           bytes32 poolHash, address lpOwner)
65:         internal returns (int128 baseFlow, int128 quoteFlow) {
66:         // Can be used to increase position, need to accrue first
67:         accrueAmbientGlobalTimeWeightedLiquidity(poolHash, curve);
68:         accrueAmbientPositionTimeWeightedLiquidity(payable(lpOwner), poolHash);
69:         uint128 liqSeeds = mintPosLiq(lpOwner, poolHash, liqAdded,
70:                                       curve.seedDeflator_);
71:         depositConduit(poolHash, liqSeeds, curve.seedDeflator_, lpOwner);
72: 
73:         (uint128 base, uint128 quote) = liquidityReceivable(curve, liqSeeds);
74:         (baseFlow, quoteFlow) = signMintFlow(base, quote);
75:     }
```

Look at how global weight and user weight is calculated

```js
File: canto_ambient\contracts\mixins\LiquidityMining.sol
198:     function accrueAmbientGlobalTimeWeightedLiquidity(
199:         bytes32 poolIdx,//@audit can accrue non exist pool
200:         CurveMath.CurveState memory curve
201:     ) internal {
202:         uint32 lastAccrued = timeWeightedWeeklyGlobalAmbLiquidityLastSet_[poolIdx];
203:         // Only set time on first call
204:         if (lastAccrued != 0) {
205:             uint256 liquidity = curve.ambientSeeds_;//@audit where is this value come from
206:             uint32 time = lastAccrued;
207:             while (time < block.timestamp) {
208:                 uint32 currWeek = uint32((time / WEEK) * WEEK);
209:                 uint32 nextWeek = uint32(((time + WEEK) / WEEK) * WEEK);
210:                 uint32 dt = uint32(
211:                     nextWeek < block.timestamp
212:                         ? nextWeek - time
213:                         : block.timestamp - time
214:                 );
215:                 timeWeightedWeeklyGlobalAmbLiquidity_[poolIdx][currWeek] += dt * liquidity;
216:                 time += dt;
217:             }
218:         }
219:         timeWeightedWeeklyGlobalAmbLiquidityLastSet_[poolIdx] = uint32(
220:             block.timestamp
221:         );
222:     }

224:     function accrueAmbientPositionTimeWeightedLiquidity(
225:         address payable owner,
226:         bytes32 poolIdx
227:     ) internal {
228:         bytes32 posKey = encodePosKey(owner, poolIdx);
229:         uint32 lastAccrued = timeWeightedWeeklyPositionAmbLiquidityLastSet_[
230:             poolIdx
231:         ][posKey];
232:         // Only init time on first call
233:         if (lastAccrued != 0) {
234:             AmbientPosition storage pos = lookupPosition(owner, poolIdx);
235:             uint256 liquidity = pos.seeds_;//@audit-ok M can pos.seeds_ change midway. if it can then manipulate reward accrue
236:             uint32 time = lastAccrued;
237:             while (time < block.timestamp) {
238:                 uint32 currWeek = uint32((time / WEEK) * WEEK);
239:                 uint32 nextWeek = uint32(((time + WEEK) / WEEK) * WEEK);//@gas
240:                 uint32 dt = uint32(
241:                     nextWeek < block.timestamp
242:                         ? nextWeek - time
243:                         : block.timestamp - time
244:                 );
245:                 timeWeightedWeeklyPositionAmbLiquidity_[poolIdx][posKey][
246:                     currWeek
247:                 ] += dt * liquidity;
248:                 time += dt;//@if (nextweek >= block.timestamp) break;
249:             }//@1st loop give reward from lasttime to the end of the week.
250:         }//@2nd time skip to next week. give reward of current week then loop to next week. 
251:         timeWeightedWeeklyPositionAmbLiquidityLastSet_[poolIdx][
252:             posKey
253:         ] = uint32(block.timestamp);//@3 give final reward of current timestamp to beginning of the week
254:     }

```

There are several things to look at here:

1. Global weekly rewards is depend on liquidity or `curve.ambientSeeds_`
2. User weekly rewards also depend on liquidity or `pos.seeds_`
3. global weight skip update to new value if `(time == block.timestamp)`
4. Update user weight is unique for each user

Now we only need to figure out how to manipulate `curve.ambientSeeds_` and `pos.seeds_`.
Back-tracking this project is a nightmarish process.
To replicate this bug, it is much simpler to add a bunch of console.log on
`LiquidityCurve.liquidityPayable()` and `LiquidityCurve.liquidityReceivable()` to see how `curve.ambientSeeds_` change.
Also, `PositionRegistar.mintPosLiq` and `PositionRegistar.burnPosLiq` to see how `pos.seeds_` change.

Running test file, it is easy to found out another several things:

- `curve.ambientSeeds_` always >= `pos.seeds_`
- `curve.ambientSeeds_`,`pos.seeds_` change with user mint/burn pool LP token.
- The value can be range from 0 -> 1e9
- So if user own 100% of the pool. it is possible to manipunate `curve.ambientSeeds_` as 1e1 and `pos.seeds_` as 1e9.

So to exploit this bug, we only need to making sure accrue global method called when `curve.ambientSeeds_` is small value.
Then deposit a bunch of token to inflate `pos.seeds_` value on the same block.
Then call claim/mint to update accrue reward. Because global weight or `accrueAmbientGlobalTimeWeightedLiquidity()` never update global weight on same block, global weight still using old value which is smaller than new `pos.seeds_` value.

## Recommended Mitigation Steps

None
