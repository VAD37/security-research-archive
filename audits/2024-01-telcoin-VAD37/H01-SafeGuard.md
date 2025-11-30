---
name: Audit item
about: These are the audit items that end up in the report
title: ""
labels: ""
assignees: ""
---
# `SafeGuard` fail to protect against `delegatecall` execution or even verify `checkTransaction()` correctly

## Summary

Using context provided by Zodiac project and GnosisGuild project repo on github.

`SafeGuard.checkTransaction()` assume that `_msg.sender()` is `IReality` interface. I assume this is `RealityModule.sol`.

The problem is there is no guarantee or verfication check that `_msg.sender()` is `RealityModule.sol`.

A deep look inside on how Zodiac module and Avatar or gnosis safe work.
The one call `SafeGuard` for verification check is `Avatar` contract from Zodiac not `RealityModule.sol` as expected from documents.
And `Avatar` contract here is a gnosis safe wallet variant with similar function and same project layout.
Avatar using `RealityModule` as module the same way how module work on gnosis safe.


After learning that `msg.sender` here is not `RealityModule` but caller is Avatar contract (GnosisSafe wallet variant) through module execution.


So the result of `checkTransaction()` will likely revert for most `call` execution. Due to `msg.sender` (Avatar contract) does not have `getTransactionHash()` function.

And if come from module `delegatecall` execution, the `transactionHashes` verify will not belong to `SafeGuard` admin but rather data storage on Avatar contracts.


## Vulnerability Detail

## Impact

## Code Snippet

## Tool used

Manual Review

## Recommendation
