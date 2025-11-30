
# `getPrice()` `decreaserate` is zero most of the time. Something odd with how sales option 2 is calculated

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L546-L558>

## Impact

TLDR: By remove a huge chunk of code, there is no difference in price calculation.

When sale Option is set to 2 and collection rate set to 0. Price will *exponetialy decrease* (quote from comment) to minimum price.

It just odd that sale price for a specific time is on [exponential decay curve](https://en.wikipedia.org/wiki/Exponential_decay).
And then final price is calculated as `finalPrice = price - decreaseRate`.

`decreaseRate` calculation formula is really long and hard to read.
By doing algreba and writing test on foundry. It is easy to detect that `decreaseRate` always zero for all input value.

It is unclear if this is intended or not. Because it is *uncommon* for price curve to be [exponential decay](https://en.wikipedia.org/wiki/Exponential_decay) and not [downward parabola](https://en.wikipedia.org/wiki/Parabola).
You would expect for NFT price drop to be slower at the beginning and faster at the end, like parabola curve.

## Proof of Concept

Below is affected code when NFT sell with saleoption 2:
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L546-L563>

It do the following:

- if rate is 0, return exponential decay, `price = mintCost/ time period`
- if rate is not 0, linear reduce price, `price = mintCost - (rate * time period)`

`decreaserate` formula is complicated
```decreaserate = ((price - (collectionPhases[_collectionId].collectionMintCost / (tDiff + 2))) / collectionPhases[_collectionId].timePeriod) * ((block.timestamp - (tDiff * collectionPhases[_collectionId].timePeriod) - collectionPhases[_collectionId].allowlistStartTime));```

`{P - (C / (t + 2)) } / T * (B - (t * T) - S)`

By doing algreba, everything just cancel each other out, leaving `decreaseRate` always zero.

Here is the test on foundry and logs proving `decreaserate=0` for all value

```solidity
```

## Tools Used

## Recommended Mitigation Steps
