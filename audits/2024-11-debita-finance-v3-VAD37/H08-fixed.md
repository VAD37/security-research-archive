# Anyone can delete Borrow Order before index was created will delete other user orders

## Summary

`DebitaBorrowOffer-Factory.sol` have reentrancy right after active order and before setup index.
Attacker can exploit this to delete other user order and mess up active orders list.

## Root Cause

Standard reentrancy attack pattern. Change after unsafe external call.

- In `DBOFactory.createBorrowOrder()`, unsafe external call before include new order to active order list. [Here](https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/DebitaBorrowOffer-Factory.sol#L125-L138)
- There is no token whitelist. Token can be custom attack contract.
- Attacker can call delete order using reentrancy. [Here](https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/DebitaBorrowOffer-Implementation.sol#L188-L218)
- `DBOFactory.sol` accept delete order with address alone and no safety check. [Here](https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/DebitaBorrowOffer-Factory.sol#L162-L177)

## internal pre-conditions

- `DBOFactory` have several active orders.
- `activeOrdersCount > 1`

## External pre-conditions

Attacker prepare custom ERC20/ERC721 contract for reentrancy attack.

## Attack Path

- Attacker create a borrow order. A borrow offer contract is created
- The borrow contract is activated immediately. [Here](https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/DebitaBorrowOffer-Factory.sol#L124) `isBorrowOrderLegit[address(borrowOffer)] = true;`
- The modifier `DBOFactory.onlyBorrowOrder` will pass as order was created.
- During token transfer. use reentrancy contract. [Here](https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/DebitaBorrowOffer-Factory.sol#L125-L138)
- Use reentrancy to call delete order on Borrow Order contract. [Here](https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/DebitaBorrowOffer-Implementation.sol#L188)

During delete phase:
<https://github.com/sherlock-audit/2024-11-debita-finance-v3-VAD37/blob/877aca0c5bf364eff2a8b3b0a72df9927b784720/Debita-V3-Contracts/contracts/DebitaBorrowOffer-Factory.sol#L159-L177>

- Factory will try to delete latest order, but it still have zero address.
- Factory delete order at index 0, which is other user order. Then swap latest index to 0 index.
- Then Factory create new index and add attacker order to active list.
- Attacker order is no longer activated, but still in active list.

## Impact

The active order list is required to allow web user access their active order.
Without this list, user will have to manually find their order contract address through events.

Which is unlikely, leads to reputation lost and website operation down until fixed.

## PoC

## Mitigation

Move external calls (Token transfer) to the end of function.
