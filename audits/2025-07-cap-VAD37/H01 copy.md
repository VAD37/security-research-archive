
# Manipulating `DebtToken` via AAVE to inflate interest rate and impose excessive debt on Symbiotic Network Operators

## Summary

The `DebtToken.sol` contract can be manipulated to cache an inflated interest rate (up to 19% APR) sourced from AAVE. This leads to significantly higher debt being accrued by agents or operators upon repayment.

The manipulation is invisible in public views or the oracle UI and is only exposed during repayment. Since the exploit requires only gas fees and no capital loss to the attacker, this is classified as a **High severity issue**.

---

## Root Cause

* `DebtToken.sol` computes the interest rate using the AAVE rate via `AaveAdapter.sol`, which depends on external oracle data.

  * [Code reference](https://github.com/sherlock-audit/2025-07-cap-VAD37/blob/6473ce3fef4c5c3adca7d2683e6adb2a3c24739f/cap-contracts/contracts/lendingPool/tokens/DebtToken.sol#L95-L104)
* The formula used is:
  `interestRate = max(aaveRate, defaultBenchmarkRate) + vaultAdapterRate`
* AAVE's stablecoin markets allow the borrow rate to spike up to \~19%–20% APY under full utilization.
* AAVE does not charge fees for borrowing or repaying, so attackers can freely use flashloans (no-fee) to manipulate market rates.
* The function `Lender.realizeRestakerInterest()` is publicly callable and allows any user to refresh `DebtToken`'s cached rate based on current oracle data.

  * [Code reference](https://github.com/sherlock-audit/2025-07-cap-VAD37/blob/6473ce3fef4c5c3adca7d2683e6adb2a3c24739f/cap-contracts/contracts/lendingPool/tokens/DebtToken.sol#L72-L104)

---

## Preconditions

### Internal

* The attack works under default test settings (`Scenario.basic.t.sol`).
* The Cap protocol is live, with whitelisted agents borrowing stablecoins for off-mainnet-chain investment.
* Supported stablecoin collateral types: USDC, USDT, pyUSD.

### External

* AAVE oracle rates typically float around 5% APY.
* Cap's oracle rate adds a utility premium (\~2%), yielding \~7% effective APR.
* Flashloan platforms (e.g., Balancer V2) offer zero-fee, high-volume flash loans.
* For USDC/USDT, \~1B collateral is needed to spike utilization.
* pyUSD pool is small enough to be manipulated with BalancerV2 collateral alone.

---

## Attack Path

1. Attacker takes a flashloan to obtain enough collateral.
2. Deposits collateral and borrows all stablecoins (USDC, USDT, pyUSD) from AAVE.
3. AAVE pool reaches 100% utilization, interest rate spikes to max (19% APY).
4. Attacker sends 1 unit of each borrowed stablecoin to `SymbioticNetworkMiddleware` (to bypass restaker issue).
5. Calls `Lender.realizeRestakerInterest()`, updating the interest rate cached by `DebtToken`.
6. Repays the borrowed amount + flashloan, at no net loss.
7. All subsequent repayments from legitimate agents now accrue debt at 19% APR instead of the expected \~5%.

---

## Impact

* Operators (whitelisted agents) unknowingly accrue 3x–4x more debt.
* Attack is low-cost and repeatable (gas only).
* Hidden: no visibility via view functions or standard oracles.
* Restakers benefit from inflated repayments.
* Detection is delayed, possibly over a long period.

**Severity Justification:**

* Asset losses scale with time and operator activity.
* Attack is non-obvious and requires deep investigation to detect.

---

## Proof of Concept

* A coded PoC forks AAVE + Symbiotic mainnet and runs under `forge test`.
* Run with:
  `forge test -vv --mc Debug`
* File path:
  `cap-contracts/test/scenario/Scenario.fork1.t.sol`
* PoC shows \$10,000 borrowed at 5% APR, spiked to 19%, resulting in >\$10 extra debt in 3 days.

---

## Mitigation

Only the following functions can refresh `DebtToken`'s cached interest rate:

* `Lender.borrow()` – restricted to whitelisted operator
* `Lender.repay()` – requires min repayment amount (\$100)
* `Lender.realizeRestakerInterest()` – **public**, unrestricted

**Recommendations:**

1. Restrict `realizeRestakerInterest()` to whitelisted operators.
2. Implement rate TWAP (Time Weighted Average Price) for AAVE market rate to resist flashloan spikes.
3. Consider caching with delay or sanity-checking changes in rate deltas.

