
# `AuctionDemo` bid time validation issues. Fail to withdraw bid after auction end. Anyone can remove other people bid

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L135>
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L124>

## Impact

Time require validation check on `cancelBid()` and `cancelAllBids()` pass if auction is not ended. It suppose to happen after auction end.

This cause these issues:

- User cannot manually withdraw bid after auction end.
- Losing bid user can only receive refund when winner claim NFT.
- Exploiter can cancel other people bid and quote smallest value 1 wei to win NFT auction.

## Proof of Concept

Here is current cancel time validation implementation in project:
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L124>
`require(block.timestamp <= minter.getAuctionEndTime(_tokenid), "Auction ended");`

It mean if `block.timestamp` or current time larger than `minter.getAuctionEndTime(_tokenid)` or auction end time, then it will fail.
In other word, you cannot cancel/revert bid after auction end.
The only way for user get their refund back is through `claimAuction()` after auction end.
It can be called by admin or winner. If winner decided not to claim, then all other users fund will be stuck till admin intervene.

Another problem is `cancelAllBids()` can be called by anyone, it refund all user and reset highest bid to 0.
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L134-L143>

This can also used by any exploiter to reset bid to 0 right before auction end and bid their own smallest bid 1 wei to win auction.

## Tools Used

manual

## Recommended Mitigation Steps

`cancelAllBids()` should only be called after auction.
Also user should be allowed to withdraw their own bid after auction end. To use that fund for emergency purpose and not waiting for admin to claim NFT.
