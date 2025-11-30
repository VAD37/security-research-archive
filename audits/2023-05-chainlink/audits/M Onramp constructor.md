# OnRamp Constructor Fails to update `s_allowList`

## Impact

The `allowList` input in `EVM2EVMOnRamp.sol` constructor is incorrectly handled.
While it activates whitelist `s_allowlistEnabled`, restricting message sending from whitelisted addresses, it doesn't update the `s_allowList` array in the mapping.
Consequently, cross-chain messaging is disabled until the owner manually updates the allowList.


## Proof of Concept


If the constructor encounters a non-empty allowlist, it [updates the allowList directly](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/onRamp/EVM2EVMOnRamp.sol#L234-L237).

```js
    if (allowlist.length > 0) {
      s_allowlistEnabled = true;
      _applyAllowListUpdates(allowlist, new address[](0));//@audit order here is reveresed
    }
```

However, in the internal function `_applyAllowListUpdates()`, the `removes` array is ordered first processed before the `adds` array.

Thus, during construction, no addresses are added to `s_allowList`, but `s_allowlistEnabled` is activated, effectively blocking any messages through the router.

```js
  function _applyAllowListUpdates(address[] memory removes, address[] memory adds) internal {
    for (uint256 i = 0; i < removes.length; ++i) {
      address toRemove = removes[i];
      if (s_allowList.remove(toRemove)) {
        emit AllowListRemove(toRemove);
      }
    }
    for (uint256 i = 0; i < adds.length; ++i) {
      address toAdd = adds[i];
      if (toAdd == address(0)) {
        continue;
      }
      if (s_allowList.add(toAdd)) {
        emit AllowListAdd(toAdd);
      }
    }
  }
```


## Tools Used

manual

## Recommended Mitigation Steps
To resolve this, the inputs to `_applyAllowListUpdates()` in the constructor should be reversed, changing from `_applyAllowListUpdates(allowlist, new address[](0));` to `_applyAllowListUpdates(new address[](0),allowlist);`.
