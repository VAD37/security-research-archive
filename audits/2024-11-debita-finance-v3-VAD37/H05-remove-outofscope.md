# REMOVED


# `BuyOrder.sol` never send NFT to buyer

## Summary

`BuyOrder.sol` mistakenly transfer NFT to the contract itself instead of buyer.
Resulting in buyer never receive the NFT after paying cash.

## Root Cause

<https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/buyOrders/buyOrder.sol#L99-L103>

```solidity
    function sellNFT(uint receiptID) public {
        ...
        IERC721(buyInformation.wantedToken).transferFrom(//veNFTAerodrome
            msg.sender,
            address(this), //@this should be buyInformation.owner
            receiptID
        );
        ...
    }
```

## internal pre-conditions

## External pre-conditions

## Attack Path

## Impact

The buyer never receives the NFT after paying cash.

## PoC

## Mitigation

```solidity
        IERC721(buyInformation.wantedToken).transferFrom(//veNFTAerodrome
            msg.sender,
            buyInformation.owner, //@this should be buyInformation.owner
            receiptID
        );
```
