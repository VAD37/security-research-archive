# `registerCredentialUseBlock()`: potential FileCoin Miner frontrun risk & DOS key `Agent.sol` operations

## Overview

As an extension to the FileCoin network, FVM converts EVM transactions into FileCoin transactions, thereby enabling EVM usage. However, its mechanism poses risks due to its EVM compatibility, which comes with *caveats*.

The `AgentPolice.sol` function primarily depends on the `issuer` address signed transactions, and uses the public function `registerCredentialUseBlock()` to prevent duplicate transactions. This mechanic can be exploited, allowing attackers to disrupt `Agent.sol` operations.

## Vulnerability Details

- [`registerCredentialUseBlock()`](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/AgentPolice.sol#L270-L279) security checks can be circumvented with the `msg.sender` being a contract that simulates the same id number as `SignedCredential`.

### Miner Frontrun Exploit Capability

Quick references from the FileCoin documentation reveal:

- Miners don't execute the [latest transactions from the most recent block](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/AgentPolice.sol#L270-L279), creating potential time gaps for frontrun transactions.
- Transaction execution order is not based on gasFee, but sorted within [tipsets](https://spec.filecoin.io/systems/filecoin_vm/interpreter/#section-systems.filecoin_vm.interpreter).
- Tipsets are miner blocks where [duplicate EVM transactions can be submitted by multiple miners, but only one gets executed](https://spec.filecoin.io/systems/filecoin_vm/interpreter/#section-systems.filecoin_vm.interpreter.duplicate-messages).
- There is no information on how transaction inside tipset(block) is sorted. But from the look of explorer, EVM transaction order mixed with normal FileCoin transaction, miner can sort it however they want as long as it is valid. Same as Ethereum.

## Impact

Miner have power to DOS `Agent.sol` operations.

## Code Reference

https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/AgentPolice.sol#L270-L279

## Tooling

Manual Review

## Suggestions

Reliance on `agentFactory` to fetch the ID, rather than `msg.sender`, can prevent ID spoofing.
```js
  function registerCredentialUseBlock(
    SignedCredential memory sc
  ) external {
    if (GetRoute.agentFactory(router).agents(msg.sender) != sc.vc.subject) revert Unauthorized();
    _credentialUseBlock[createSigKey(sc.v, sc.r, sc.s)] = block.number;
  }
```
