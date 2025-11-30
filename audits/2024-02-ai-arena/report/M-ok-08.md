# H Rare case `div 0`. `RankedBattle.claimNRN()` can be bricked, if a round have no points earned, like all staked users have negative win ratio

It is possible for `totalAccumulatedPoints[currentRound]` return 0. Causing division 0 and revert `RankedBattle.claimNRN()` transaction.

Only if no user stake any token. No points earned.
Or all stake user lose every battle. All points earned are reduce to zero. This mean there is no stake and no points earned anymore.

## Impact

Permanently bricked contract. No user can claim rewards ever again.

## Proof of Concept

Here is division 0 bug.
<https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L301-L303>

```solidity
    function claimNRN(uint256 tokenId) external {
        // .......
        claimableNRN += (
            accumulatedPointsPerAddress[msg.sender][currentRound] * nrnDistribution   
        ) / totalAccumulatedPoints[currentRound];//@possible div 0
    // .......
    }
```

Points only increase for [staked user](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L342-L344)

`totalAccumulatedPoints[currentRound]` [increase](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L468) and [decrease](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L487) when user win/lose battle.

When user keep losing, `totalAccumulatedPoints[currentRound]` will be 0.
<https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L479-L487>

## Tools Used
<https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L301-L303>

## Recommended Mitigation Steps
