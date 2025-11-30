# QA

## 1. `GameItem.mint()` missing zero input validation

[Allow mint zero NFT and transfer no token.](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/GameItems.sol#L147)

## 2. `RankedBattle._addResultPoints()` missing input validation for eloFactor

No verification for offchain game server to send reasonable number.
Elo normally range from 1000-3000.
Offchain gameserver can send such higher number (>1e10) that cause user gain infinite points.
<https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L445>

## 3. Missing `updateBattleRecord()` `battleResult` enum validation

GameServer can send invalid battle result. Which is `battleResult > 2`.
The transaction will return success but no record is updated. While energy is still spent.

<https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L325>

## 4. `GameItem.createGameItem()` missing admin input validation to prevent revert later when using item

These input invariant case must be true and currently not checked:

- `itemsRemaining > dailyAllowance`: allow buy even when infinite supply.
- `itemsRemaining > 0`: allow buy even when infinite supply.

## 5. `AiArenaHelper.addAttributeProbabilities()` lack validate for `probabilities.length < 50`

probabilities length must smaller than 50 so its `dnaToIndex()` never return index 50.
Index 50 is hardcoded as beta/premium cosmetic.
<https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/AiArenaHelper.sol#L105>

## 6. Missing admin `bpsLostPerLoss` validation to prevent user lose all their stake.
`setBpsLostPerLoss()` allow admin to set lost stake `bpsLostPerLoss` >= 100%.
It should be capped at 10% or 20% to prevent user lose all their stake after lose single battle.
https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L226-L229

# Information

1. [`VoltageManager.sol` allowing user burn their own energy without purpose.](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/VoltageManager.sol#L110)
2. [Energy check](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L334-L338) in `RankedBattle.updateBattleRecord()` is duplicate/redundancy. Spending energy already check if user already have enough energy. You can merge both [spending](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L345-L347) and [require check](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/RankedBattle.sol#L334-L338) into just spending voltage.
3. `AiArenaHelper.constructor` have duplicate opeartion. It write `attributeProbabilities[]` twice times with same array and same value. [First](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/AiArenaHelper.sol#L45) then [second](https://github.com/code-423n4/2024-02-ai-arena/blob/f2952187a8afc44ee6adc28769657717b498b7d4/src/AiArenaHelper.sol#L49) time again.