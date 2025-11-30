# Delete Order will set wrong index. Causing undefined behaviour

## Summary

In `BuyOrderFactory.sol` and `AuctionFactory.sol`,
Delete latest Order not only remove order, but also update Order with `address(0)` to different index.

The impact is undefined logic behaviour. Order with zero address is never used but its index value keep changing due to logic error.

## Root Cause

In delete buy order both `BuyOrderFactory.sol` and `AuctionFactory.sol`.
<https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/buyOrders/buyOrderFactory.sol#L126-L137>
<https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/auctions/AuctionFactory.sol#L145-L159>

```solidity
    function _deleteAuctionOrder(address _AuctionOrder) external onlyAuctions {
        // get index of the Auction order
        uint index = AuctionOrderIndex[_AuctionOrder];
        AuctionOrderIndex[_AuctionOrder] = 0;

        // get last Auction order
        allActiveAuctionOrders[index] = allActiveAuctionOrders[
            activeOrdersCount - 1
        ];
        // take out last Auction order
        allActiveAuctionOrders[activeOrdersCount - 1] = address(0);

        // switch index of the last Auction order to the deleted Auction order
        AuctionOrderIndex[allActiveAuctionOrders[index]] = index;
        activeOrdersCount--;
    }
```

This variable `allActiveAuctionOrders[index]` suppose to be "swapped" order before switching index
If delete last array Order, there is no need to swap.
Then take out last Auction order already reset last array value
`allActiveAuctionOrders[activeOrdersCount - 1] = address(0);`
But switch index still happen, `AuctionOrderIndex[allActiveAuctionOrders[index]] = index;`
And it set address(0) to different index. Which is no different than
`AuctionOrderIndex[allActiveAuctionOrders[activeOrdersCount - 1]] = AuctionOrderIndex[address(0)] = index`

## internal pre-conditions

Example: We have array `allActiveAuctionOrders` of 5 elements

`[ address(1), address(5), address(3), address(2), address(4) ]`

And `AuctionOrderIndex[address(4)] = 4`

## External pre-conditions

Removing last element which is address(4). And we get:
`[ address(1), address(5), address(3), address(2)]`

- `AuctionOrderIndex[address(4)] = 0`
- `AuctionOrderIndex[address(0)] = 4`

`address(0)` is never used

## Attack Path

This happen everytime any user create new order and then cancel order right after.

## Impact

Undefined logic behaviour. Function say delete order and swap index does not work with order just happen tobe the order in the last array of active order.

## PoC



## Mitigation

Use if check to safe remove last array as special case.