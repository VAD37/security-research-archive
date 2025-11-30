# public `registerCredentialUseBlock()` function allow FileCoin Miner to frontrun transaction and prevent `Agent.sol` key actions

## Summary

**FileCoin** first and foremost is a storage provider. **FVM** is an extension of FileCoin network allow user to use EVM before miner convert these EVM transactions into FileCoin transactions.
FVM while is fully EVM compatible come with lots of *asterisk*.

Because `AgentPolice.sol` heavily relied on signed transaction from `issuer` address, and the mechanic to prevent user from submit duplicate transaction is public function `registerCredentialUseBlock()`.
It make quite easy for attacker to DOS `Agent.sol` operations if they somehow know everyone signed transaction before hand and bypassing security check.

## Vulnerability Detail

- `registerCredentialUseBlock()` [security check can be bypassed](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/AgentPolice.sol#L270-L279). `msg.sender` can be a contract faking id number to be the same as `SignedCredential`.

### Miner frontrun exploit capibility

A quick skim through FileCoin docs. It easy to found these point.

- Miner [does not execute latest transaction from latest block.](https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/AgentPolice.sol#L270-L279) Allow ample time during 30s block time to detect frontrun transaction if possible.
- The order of execution of message is not by gasFee. But sorted inside [tipset](https://spec.filecoin.io/systems/filecoin_vm/interpreter/#section-systems.filecoin_vm.interpreter)
- Tipset is a miner block. [Multiple miner can submit same EVM transaction. But only one will be executed.](https://spec.filecoin.io/systems/filecoin_vm/interpreter/#section-systems.filecoin_vm.interpreter.duplicate-messages) Transaction from Miner with ID sorted by A-Z will be first.
- Ultimately, Miner have power to ordering transaction as much as they want. As long as miner is choosed by FileCoin concensus network.

## Impact

DOS `Agent.sol` operations. Prevent user from using `Agent.sol`.

## Code Snippet
https://github.com/sherlock-audit/2023-06-glif-VAD37/blob/7933a1c310fa98a040d28fc6ab7086f7cc52fd53/pools/src/Agent/AgentPolice.sol#L270-L279
## Tool used

Manual Review

## Recommendation

Use `agentFactory` to find ID rather than relied on msg.sender to send ID. This will prevent attacker from faking ID.
```js
  function registerCredentialUseBlock(
    SignedCredential memory sc
  ) external {
    if (GetRoute.agentFactory(router).agents(msg.sender) != sc.vc.subject) revert Unauthorized();
    _credentialUseBlock[createSigKey(sc.v, sc.r, sc.s)] = block.number;
  }
```
