# Data Corruption Issue with deleting OpenZeppelin `EnumerableMap` and `s_nops` Mapping

## Impact Summary

Deleting the OpenZeppelin `EnumerableSet` doesn't actually remove the old data. This issue can cause irreversible corruption to the `EnumerableMap.length()` result when a new Node Operator (NOP) configuration is set. As a result:

- Old Node Operator addresses get obscured and aren't recoverable.
- Only new Node Operator addresses are registered.
- The length of new Node Operators only contains new addresses, while the total node weight remains the same.

This means when payments are made to Node Operators, only newly added operators receive their dues. Old operators, even those listed in the new configuration, get omitted.

## Proof of Concept

When updating the `EnumerableMap.AddressToUintMap internal s_nops` with new NOP addresses and weights, the `getNops()` function, which reads `s_nops` address mapping, returns an altered list.

| old `s_nops` | new NopAndWeight[] | after `_setNops()` |
| ------------ | ------------------ | ------------------ |
| address(1)   | address(2)         | address(4)         |
| address(2)   | address(1)         | empty              |
| address(3)   | address(4)         | empty              |

Old Node Operator addresses get hidden. The length of `s_nops` returned by `s_nops.length()` is incorrect after calling `delete EnumerableSet`. Only new Node Operator addresses get added.

Add a length check to the `testSetNopsSuccess` test in the `EVM2EVMOnRamp.t.sol` file [here](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/test/onRamp/EVM2EVMOnRamp.t.sol#L905-L919).
```ts
    s_onRamp.setNops(nopsAndWeights);
    
    (EVM2EVMOnRamp.NopAndWeight[] memory actual, ) = s_onRamp.getNops();
    assertEq(actual.length, nopsAndWeights.length); //@audit this test here will fail as new length only contain 1 address
    for (uint256 i = 0; i < actual.length; ++i) {// @ this should have been local variable not returned result
      assertEq(actual[i].weight, s_nopsToWeights[actual[i].nop]);
    }
```
The test will fail as the new length only contains one address.

### Explanation

OpenZeppelin has a [warning](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/vendor/openzeppelin-solidity/v4.8.0/utils/structs/EnumerableMap.sol#L40-L43) against deleting `EnumerableMap`.

When the admin calls `setNops()` and [deletes `s_nops`](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/onRamp/EVM2EVMOnRamp.sol#L632), it only removes the keys array. The index mapping of key to value still exists. As a result, when a [new configuration is added](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/onRamp/EVM2EVMOnRamp.sol#L639-L642), because the old mapping is not deleted, the key already exists and isn't updated. Thus, the mapping isn't refreshed, and neither is the length.

## Tools Used

manual

## Mitigation Steps

To solve this, manually remove old addresses from `s_nops` before adding a new configuration:

```ts
    // Remove previous
    uint256 length = s_nops.length();
    if(length > 0)
    {
      for (uint256 i = length - 1 ; i >= 0; --i) {//@ inverse loop for gas efficient
        (address key,) = s_nops.at(i);
        s_nops.remove(key);
      }
    }
```
