
# DOS auction demo. spend all gas on `claimAuction()` or `cancelAllBids()`. Lock ETH in contract

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L116>

## Impact

`claimAuction()` require winner refund all other bids by making external call to external address.
It does not have any gas limit check, so it can be used to spend all winner gas.
Prevent winner from claiming NFT and refunding other bids.

Because the only way for user to get their fund back is through `claimAuction()` after auction ended.
So anyone can bid smallest amount and DOS all NFT token auction. Prevent all users withdraw their fund after auction ended.

## Proof of Concept

winner refund other loser bids by making external call.
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L116>
This ignore failure call but does not limit gas usage.

The only way to withdraw fund is through `cancelBid()`. But it only work before auction end.
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L124-L130>

`cancelAllBids()` have same mechanics and same issue as `claimAuction()`.

## Tools Used

manual

## Recommended Mitigation Steps

Limit gas to standard amount 30000. Or use transfer() instead of call() to refund other bids.
Include function to allow user manually withdraw bids after auction end too.
