
# Stealing ETH from `AuctionDemo.sol`. Duplicate withdraw bid when `block.timestamp == getAuctionEndTime()`

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L105>
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L125>

## Impact

Post auction withdraw method does not reset withdrawal status to false.
Allow reentrancy callback exploit to withdraw same bid twice.

This can only happen when `block.timestamp == getAuctionEndTime()`.
On mainnet can happen 1 out of 12 time as current fork block time is 12 seconds.

So 8% chance to withdraw twice amount of ETH from Auction contract.

## Proof of Concept

The only method to withdraw bid after auction end is `claimAuction()`. Winner refund all loser bids.
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L104-L120>

`cancelBid()` and `cancelAllBids()` only work before auction end.
<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L124-L125>

This is how `claimAuction()` time validation work:

- time validation: `require(block.timestamp >= minter.getAuctionEndTime(_tokenid) && auctionClaim[_tokenid] == false && minter.getAuctionStatus(_tokenid) == true);`
- send fund: `(bool success, ) = payable(auctionInfoData[_tokenid][i].bidder).call{value: auctionInfoData[_tokenid][i].bid}("");`

This is how `cancelBid()` validation work:

- time validation: `require(block.timestamp <= minter.getAuctionEndTime(_tokenid), "Auction ended");`
- reset status: `auctionInfoData[_tokenid][index].status = false;`

`claimAuction` can work when `block.timestamp == minter.getAuctionEndTime(_tokenid)`.
`cancelBid` also work when `block.timestamp == minter.getAuctionEndTime(_tokenid)`.

`claimAuction()` do refund loser bids but does not reset status to false like `cancelBid()` does.
`claimAuction()` refund process use external call so it can have callback exploit to reenter `cancelBid()` again.

So by waiting winner to call `claimAuction()`
It will make contract call to exploiter address.
Exploiter contract fallback function check if `block.timestamp == minter.getAuctionEndTime(_tokenid)`
Exploiter contract call `cancelBid()`
This condition still work `auctionInfoData[_tokenid][index].status == true;`
`cancelBid()` does not revert, transfer funds to exploiter.
`claimAuction()` transfer another fund to exploiter.

## Tools Used

manual

## Recommended Mitigation Steps

Fix time validation in `claimAuction` only work after auction end.

```js
- require(block.timestamp >= minter.getAuctionEndTime(_tokenid) && auctionClaim[_tokenid] == false && minter.getAuctionStatus(_tokenid) == true);
+ require(block.timestamp > minter.getAuctionEndTime(_tokenid) && auctionClaim[_tokenid] == false && minter.getAuctionStatus(_tokenid) == true);
```
