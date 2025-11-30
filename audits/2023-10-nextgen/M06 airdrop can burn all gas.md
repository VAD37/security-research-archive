
# Admin airdrop DOS. Lack abilities to force send NFT. NFT recipient can burn all gas

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L181-L192>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L178-L185>

## Impact

Admin can airdrop NFTs to a list of address through `MinterContract.airDropTokens()`.
Because NFT use OpenZeppelin `_safeMint()`. It have callback for any contract implement IERC721 receiver.

This make it possible for malicious airdrop recipient to burn all gas by implementing `onERC721Received()`.

On mainnet, this is a huge finance cost and waste of time for admin to make new transaction.

## Proof of Concept

OpenZeppelin `_safeMint()` callback:
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/ERC721.sol#L237-L251>

Project use `_mintProcessing` for all minting:
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L227-L232>

Minting through airdrop will have callback:
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L178-L185>

Only admin can call airdrop and it does not have any gas protection:
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L181-L192>

## Tools Used

manual

## Recommended Mitigation Steps

A quick fix would just be use normal `_mint()` for airdrop function only.
Without callback, it is not possible to burn all gas.
