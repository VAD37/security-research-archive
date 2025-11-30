
# `AuctionDemo.sol` cannot receive NFT ERC721 tokens

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L112>

## Impact

Auctioning NFT currently hold on EOA is unsafe.
EOA can refuse approve Auction contract to transfer NFT or remove approval before auction end.

This can be easily avoided by transfer NFT to Auction contract directly.
But it didnt work, because Auction contract have no `IERC721.onERC721Received()` implementation.

## Proof of Concept

`MinterContract.mintAndAuction()` called by admin to airdrop NFT to an address and starting auction.

This address can be EOA owned by admin or a contract.
And this address must choose to call approve() on NFT contract to allow Auction contract to transfer NFT to winner bid.

This look extreme unsecure compare to wellknown safe-trust mechanism like transfer NFT directly to `AuctionDemo` contract.

Because `AuctionDemo.sol` have no `IERC721.onERC721Received()` implementation, so it will fail.

## Tools Used

manual

## Recommended Mitigation Steps

Allow `mintAndAuction()` NFT to AuctionDemo contract directly.
Only auctioning NFT owned by auction contract.
