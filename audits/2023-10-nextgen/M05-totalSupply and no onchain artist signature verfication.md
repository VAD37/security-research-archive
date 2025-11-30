
# artist *Signature* does not check if max TotalSupply is correct allow artist payment address be *changed* after artist signing

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L149>

## Impact

There are 2 issues related to each other:

- `NextGenCore.artistSignature()` only check 1 out of 2 immutable variables of a collection:  `collectionArtistAddress` and `maxTotalSupply`.
- `collectionArtistAddress` or artist payment address can be changed after artist signing.

Missing artist signature check for maxTotalSupply can accidentally lead to situtaion where more NFT minted than artist intended.
Longterm devalued due to oversupply or simply NFT uri not support that many token.

Changing `collectionArtistAddress` *again* can only be done by *Collection Admin*.
Assuming Collection Admin is not NextGen project owner but by malicious actor.
Right after artist sign and propose payment addresses, malicious actor can propose their own payment address, override original artist payment address.

## Proof of Concept

For `collectionAdditonalDataStructure` (NFT info collection), there is only 2 things cannot be changed after it was created.
Which are `collectionArtistAddress` and `collectionTotalSupply`, both admin and artist cannot change these variable as trust mechanism. (Admin can change sale time and price but not supply)
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L147-L166>

`collectionArtistAddress` is used as EOA to propose payment share for NFT developer.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L380-L390>

Because payment address can be updated before finalization by admin, so anyone can change artist address for a specific collection would be quite alarming
Malicous actor can change payment address right after artist propose their own payment address. Effectively stealing artist payment before they are aware of it.

Project do verify if collection artist payment address is correct. By artist calling `NextGenCore.artistSignature()` function.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L257-L262>

`collectionArtistAddress` suppose to only set once, be immutable. But this can be easily bypass if `CollectionAdmin` who have access to `setCollectionData()` function set original collection supply to 0.
Allowing collection admin to update `collectionArtistAddress` again.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L149-L153>

This also reveal the problem where `artistSignature()` never check for `collectionTotalSupply` is correct amount as artist intended.
The problem can be easily fixed by allowing artistSignature to check for `collectionTotalSupply` as well.

## Tools Used

Manual

## Recommended Mitigation Steps

`NextGenCore.artistSignature()` should allow artist to verify for `collectionAdditionalData[_collectionID].collectionTotalSupply` value as well.
