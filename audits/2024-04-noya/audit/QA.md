
## L1 `BalancerFlashLoan` missing emergencyManager permission check

Balancer flashloan callback check caller permission is KeeperContract, but it fail to check emergencyManager after getting the address.
<https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/contracts/connectors/BalancerFlashLoan.sol#L69-L72>

```solidity
        (,,, address keeperContract,, address emergencyManager) = registry.getGovernanceAddresses(vaultId);
        if (!(caller == keeperContract)) {//@audit L failed to check emergency manager in flashloan callback.
            revert Unauthorized(caller);
        }
```

Emergency Permission have same level of authority as KeeperContract, so it should be checked in the same way.
<https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/contracts/governance/NoyaGovernanceBase.sol#L31-L37>

## 2. Vault Manager can still interact with disable vault connector until its balance reach 0

when new vault is added with its connectors and trusted tokens.
<https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/contracts/accountingManager/Registry.sol#L136-L140>

BaseConnector will call `Registry.updateHoldingPosition()` every time token balance change.
It only update new position if token is allowed and token balance is greater than 0.
And remove position if token balance is 0.

After intial token balance > 0, `Registry.updateHoldingPosition()` will be called once and never called for same position,same token again until balance reaches 0.
Because there is no vault connectors check inside `BaseConnector`, vault maintainer can still swap, transfer token from disabled vault connector to somewhere else before its balance reaches 0.

## 3. It will revert when withdraw all tokens from disabled vault connector

BaseConnector will call `Registry.updateHoldingPosition()` every time token balance change.
It only update new position if token is allowed and token balance is greater than 0.
And remove position if token balance is 0.

`Registry.updateHoldingPosition()` will revert is vault connector is disabled.
So any attempt for manager to transfers token stuck inside disabled vault connector will fail.
Unless they spare a few tokens to keep the vault connector from calling remove position.

## 4. `Registry.addTrustedPosition()` logic error. Fail to revert when connector not supporting wrong positionTypeId and `getUnderlyingTokens()` return empty array

<https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/contracts/accountingManager/Registry.sol#L252-L257>
`Registry.addTrustedPosition()` have check to prevent vault maintainer interact with connector that have tokens not supported by vault.
Most Connector default returning empty array when asked for non-zero positionTypeId.
This bypass loop check for supported tokens.

```solidity
    for (uint256 i = 0; i < usingTokens.length; i++) {
        if (!isTokenTrusted(vaultId, usingTokens[i], calculatorConnector)) {
            revert TokenNotTrusted(usingTokens[i]);
        }
    }
```
