# `refreshRoutes` upgrade address synchonization issue with bypassing newer `AgentPolice` code due to FileCoin miner frontrun

## Summary

While project have public method `refreshRoutes()` to force subcontract to update their core logic contract (Registry or agentPolice) address to latest version.
It is optional and there are not enough check to confirm if there are newer version is available and prevent call until upgrade to newer address.
Consider the case of admin failed to force call all contracts refresh their address when there are new upgraded contract.
There is a possible case where `Agent` can use older `AgentPolice` logic instead of newer one.

## Vulnerability Detail

- `refreshRouters()` is [public method that can be called by anyone.](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L329-L334)
- Most key operation function only [checking `Agent.sol` version](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L534-L536) from `AgentDeployer.sol`
- `Agent.sol` code depend on `AgentPolice.sol` [confirming if transactions are valid or not.](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L496-L501)
- `agentPolice` address does not have a version. It is depend on admin to refresh all contract to latest version.

In case of admin failed to do so, and `Agent.sol` using old `agentPolice` address instead of upgraded one.

If upgraded `AgentPolice.sol` is still centralized version share the same `issuer` address to sign transaction, older AgentPolice code will still be valid as they share the same struct.

## Impact

Agent can use older `AgentPolice.sol` logic instead of updated `AgentPolice.sol` if they both share the same `issuer` address.

This can also become a viable attack path because Filecoin Miner allow frontrun transaction in their EVM. And `AgentFactory.sol` allow anyone to create new `Agent.sol` contract.
Just so any offchain upgrade code will ignore newly created agent contract and allow this issue become valid attack path.

## Code Snippet

https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L329-L334
https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L534-L536
https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L496-L501

## Tool used

Manual Review

## Recommendation

Aware that any migration **must** be solidity contract run on-chain. Instead of normal offchain upgrade code. Due to *very small risk* of miner frontrun transaction.
Router owner must change owner to migration contract before migration run and switch it back.
