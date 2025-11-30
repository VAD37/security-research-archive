
# `RandomizerVRF.sol` and `RandomizerRNG.sol` forget hashing `abi.encodePacked` result before calling `setTokenHash()`

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/RandomizerVRF.sol#L65-L68>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/RandomizerRNG.sol#L48-L50>

## Impact

`RandomizerVRF.sol` and `RandomizerRNG.sol` use first 32 bytes of *hash input value* instead of calling `keccak256` to get hash result of entire *input*.

This result in NFT unique hash result does not depend on tokenID. This is not suppose to happen.
The randomness hashing result depend entirely on 3rd party offchain provider.

This impact directly to NFT uniqueness and value.
If chainlink or ARRng.io service return same randomness for different tokenID, then NFT will have same hash result and same image.

## Proof of Concept

Consider `RandomizerNXT.sol` contract hashing way is correct. keccak256 on `abi.encodePacked` result

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/RandomizerNXT.sol#L55-L60>

```solidity
    function calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o) public {
        require(msg.sender == gencore);
        bytes32 hash = keccak256(abi.encodePacked(_mintIndex, blockhash(block.number - 1), randoms.randomNumber(), randoms.randomWord()));
        gencoreContract.setTokenHash(_collectionID, _mintIndex, hash);
    }
```

While `RandomizerVRF.sol` and `RandomizerRNG.sol` contract hashing way is incorrect. only using first 32 bytes of `abi.encodePacked` `bytes memory` result
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/RandomizerRNG.sol#L48-L50>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/RandomizerVRF.sol#L65-L68>

```solidity
    function fulfillRandomWords(uint256 id, uint256[] memory numbers) internal override {
        gencoreContract.setTokenHash(tokenIdToCollection[requestToToken[id]], requestToToken[id], bytes32(abi.encodePacked(numbers,requestToToken[id])));
    }
```

`bytes32(abi.encodePacked(numbers,requestToToken[id]))` only return first array of `numbers` array.
Because both VRF and RNG only return array with length of 1.

So token hashing result is just the randomness result of 3rd party randomness provider Chainlink and ARRng.io service. It does not depend on tokenID which is unique for each token

## Tools Used

Manual

## Recommended Mitigation Steps

Use hashing result like `RandomizerNXT.sol` contract does. keccak256 on `abi.encodePacked` result
