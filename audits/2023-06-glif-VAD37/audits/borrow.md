# `InfinityPool.sol` Borrow second time might inflate interest debt more than necessary

## Summary

`InfinityPool.Borrow()` does not recalculate interest rate when user borrow second time.
The interest rate only recalculate when user borrow first time or repay. 
This cause user to pay interest fee for the whole duration of the loan using total debt instead of the actual debt based on the amount and time of the loan.



## Vulnerability Detail

User Example: 

- User borrow 100 token on Day1. Borrow again 900 token on Day30. Interest rate for 1 day is 1%.
- When user borrow again on D30. The interest rate fee should be 100 * 30% = 30 Token.
- But the actual interest rate fee is 1000 * 30% = 300 Token on D30. Right at the moment user borrow again.
- If user pay a very small amount of 1 Token on D30 before borrow again.
- The interest rate fee will still be 1000 * 30% = 30 Token on D30. Which is correct.

Code Explaination:
- Borrow [function only set interest date for new loan](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L338-L348). Borrow allow agent borrow again when borrow outside tolerance time which is one day.
- Calculation on how much agent should paid interest is in `Pay()` [function](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L398-L409). Follow this fomular: `totalDebt * blockDelta * interestRate`.
- If user pay debt less than interest fee. [Change blockDelta](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L417)
- if User pay enough to cover interest fee. Reset [blockDelta to zero.](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L445)
- `InfinityPool.Borrow()` missing logic to recalculate debt based on the amount and time of the loan for the second time and so on.


## Impact

User pay more interest fee than necessary if borrowing again without repay first.

## Code Snippet

https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Pool/InfinityPool.sol#L338-L348

## Tool used

Manual Review

## Recommendation

Change logic of how debt is calculated using `account.epochsPaid` to something else.
Or temporary hack it like this.
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
            account.startEpoch = block.number;//reset
            uint256 interestPerEpoch = account.principal.mulWadUp(getRate(vc));
            uint256 interestFee = interestPerEpoch.mulWadUp(block.number - account.epochsPaid);
            account.epochsPaid = account.principal.divWadUp(interestPerEpoch.mulWadUp(block.number - account.epochsPaid));
        }
```
