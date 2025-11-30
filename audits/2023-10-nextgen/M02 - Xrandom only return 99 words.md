
# `XRandoms.sol` only return random *99 words* out of 100 provided words

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/XRandoms.sol#L31>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/XRandoms.sol#L41>

## Impact

`XRandoms.sol` have a list of 100 words. call `randomWord()` suppose to return 1 random word from the list.

The last word `Watermelon` never returned due to index truncated in if-else case.

For all NFT use `RandomizerNXT` as randomizer, possible affect of how NFT is generated from this randomness as that the last word `Watermelon` never appear in NFT randomness image.

## Proof of Concept

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/XRandoms.sol#L28-L32>

```solidity
        if (id==0) {
            return wordsList[id]; //@ return first index 0
        } else {
            return wordsList[id - 1];//@ return index from 0 to 98
        }//@ the 100th word with index 99 never returned
```

function `getWord(uint index)` have words array with length of 100.
`getWord(0)` and `getWord(1)` return same value which is first word in the array.
Only by calling `getWord(100)` that the last word `Watermelon` is returned.

but randomness function `randomWord()` can only reach maximum of `getWord(99)`. due to division `% 100`.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/XRandoms.sol#L40-L43>

So the last word `Watermelon` never returned for randomness.

## Tools Used

manual

## Recommended Mitigation Steps

Change to this is enough

```solidity
-        if (id==0) {
-            return wordsList[id]; //@ return first index 0
-        } else {
-            return wordsList[id - 1];//@ return index from 0 to 98
-        }//@ the 100th word with index 99 never returned
+       return wordsList[id];
```
