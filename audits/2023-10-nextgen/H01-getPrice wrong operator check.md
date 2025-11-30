
# `getPrice()` return wrong price (original mint cost) when `block.timestamp == publicEndTime`. Wrong timestamp comparision operation

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L540>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L351>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L260>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L221>

## Impact

For NFT sale using options 2 which is price drop overtime.
When token is minted in this condition `block.timestamp == publicEndTime`, `getPrice()` function will return `collectionMintCost` instead of `collectionEndMintCost`.

On mainnet deploy, user transaction will very likely revert because not send enough ETH to cover unexpected higher mint cost.
So the only harm is user cannot mint token right at the end of public sale. Lost of revenue for the project.

## Proof of Concept

Token was still allowed to mint when `block.timestamp <= collectionPhases[index].publicEndTime`. As show in these `mint()` function here.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L351>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L260>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L221>

So all mint timestamp use this operation `<=`.

All mint function use `getPrice()` to [calculate mint cost](https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L530-L567).

For `saleOption == 2`, `getPrice()` timestamp is check using this `<`.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L540>

This ignore the case where `block.timestamp == publicEndTime` and return wrong price which is final else case fixed-price.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L564-L567>

So price just return `collectionMintCost` instead of `collectionEndMintCost` when `block.timestamp == publicEndTime`.

## Tools Used

manual

## Recommended Mitigation Steps

[Change `block.timestamp < collectionPhases[_collectionId].publicEndTime` to `block.timestamp <= collectionPhases[_collectionId].publicEndTime` here.](https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L540)
