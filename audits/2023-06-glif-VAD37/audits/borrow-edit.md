# `InfinityPool.sol`: incorrect interest rate fee calculation when multiple borrowing occurs

## Overview

The `InfinityPool.Borrow()` function fails to adjust the interest rate during subsequent borrowings, causing the users to pay more interest than required. The rate is only recalculated during the first loan or repayment, causing the interest to be calculated based on the total loan duration rather than the actual amount and loan duration.

## Vulnerability Details

Example scenario:

- A user borrows 100 tokens on Day 1 and 900 tokens on Day 30, with a daily interest rate of 1%.
- The correct interest due on Day 30 should be 100 * 30% = 30 tokens.
- However, it is incorrectly calculated as 1000 * 30% = 300 tokens due to the second borrowing.
- If the user repays a minor amount, say 1 token, before the second borrowing, the interest due would still be correct, i.e., 1000 * 30% = 30 tokens.

Code analysis:

- The `Borrow()` [function](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L338-L348) only sets the interest date for new loans and allows subsequent borrowings after a tolerance period of one day.
- The `Pay()` [function](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L398-L409) calculates the interest due as `totalDebt * blockDelta * interestRate`.
- If the repayment is less than the interest due, the [blockDelta is updated](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L417), and if it covers the interest due, [blockDelta is reset](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L445).
- `InfinityPool.Borrow()` lacks a mechanism to adjust the debt calculation based on the amount and loan duration for the second and subsequent borrowings.

## Impact

Users might end up paying inflated interest if they borrow again without making some repayment.

## Code Reference

[`InfinityPool.sol`](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L338-L348)

## Tooling

Manual Review

## Recommendations

Revise the debt calculation logic from `account.epochsPaid` to something else or consider the following **temporary** fix with *caveats*:
```js
    // fresh account, set start epoch and epochsPaid to beginning of current window
    if (account.epochsPaid == 0) {
        uint256 currentEpoch = block.number;
        account.startEpoch = currentEpoch;
        account.epochsPaid = currentEpoch;
        poolRegistry.addPoolToList(vc.subject, id);
    } else if (account.startEpoch + maxEpochsOwedTolerance < block.number) {//@audit change epochsPaid to startEpoch
        // ensure the account's epochsPaid is at most maxEpochsOwedTolerance behind the current epoch height
        // this is to prevent the agent overpaying on previously borrowed amounts
        revert PayUp();
    } else {//@ the case where borrow second time. recalculate interest rate here
        account.startEpoch = block.number; //reset
        uint256 interestPerEpoch = account.principal.mulWadUp(getRate(vc));
        uint256 interestFee = interestPerEpoch.mulWadUp(block.number - account.epochsPaid);
        account.epochsPaid = account.principal.divWadUp(interestPerEpoch.mulWadUp(block.number - account.epochsPaid));
    }
```
