# `refreshRoutes` Issue improper `AgentPolice` address sync and potential FileCoin miner frontrun

## Overview

The public method `refreshRoutes()` enforces subcontract update of the core logic contract address (Registry or `AgentPolice`) to the newest version. However, the function lacks sufficient checks to verify the availability of newer versions and to halt calls until the update is executed. If the admin fails to force a refresh when a new contract is available, `Agent` may rely on an outdated `AgentPolice` logic.

## Vulnerability Details

- [`refreshRoutes()`](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L329-L334) is a public method.
- Major operations only verify [`Agent.sol` version](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L534-L536) from `AgentDeployer.sol`.
- `Agent.sol` relies on `AgentPolice.sol` to [validate transactions](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L496-L501).
- `AgentPolice` address lacks a version and depends on admin for refresh.
- Updated `AgentPolice` might share the [same issue address](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/VCVerifier/VCVerifier.sol#L67) (same offchain bot that sign transactions)

A failure by the admin could lead to `Agent.sol` using an obsolete `AgentPolice` address. While transaction is validated by newer offchain bot logic.

This opens a potential attack vector due to the Filecoin Miner's frontrun transaction capability and `AgentFactory.sol` allowing anyone to create a new `Agent.sol` contract.

A miner could detect Router updating new AgentPolice and immediately frontrun transaction with deploying a new `Agent.sol` with the old AgentPolice address before the update.

This can happen with offchain upgrades (hardhat deployer code queue transactions but does not consider if new agent just get deployed in same block) and give rise to a valid attack path.

## Impact

An `Agent` might employ the old `AgentPolice.sol` logic if they both share an `issuer` address.

## Code References

- [`refreshRoutes()` method](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L329-L334)
- [`Agent.sol` version check](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L534-L536)
- [Transaction validation](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/Agent.sol#L496-L501)

## Tooling

Manual Review

## Suggested Measures

Migration should be a solidity contract executed on-chain to mitigate the miner frontrun transaction risk, however *small*.
Router owner should reassign ownership to the migration contract before execution and revert it afterward.
