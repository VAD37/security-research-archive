# Exploit: Avoiding Escrow Late Fee via Loan Closing Swap Without Price Protection

## Summary

Under mainnet conditions, borrowers can potentially avoid paying full late fees through a self-sandwich exploit during loan closure. This exploit manipulates the loan repayment swap to reduce late fees to near zero.
**However, this exploit is impractical** as it provides no meaningful gain or incentive for anyone to execute it.

## Finding Description

When closing loan, borrower repay loan in full to receive back their gain from Taker position and any potential left over after repaying escrow fee.
Here is step by steps what going through `LoansNFT.closeLoan()`:

- borrower send full loan repayment amount in cash(USDC). [Ref](https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/LoansNFT.sol#L251)
- `LoansNFT` settle Taker position and receive all cash gain from Taker position.[(Ref)](https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/LoansNFT.sol#L243)
- `LoansNFT` take all cash(USDC) from Taker position and loan repayment swap them all to underlying asset(WETH). [Ref](https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/LoansNFT.sol#L256)
- `LoansNFT` send all swap output to Escrow contract to settle repayment. [Ref](https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/LoansNFT.sol#L770-L774)
- `EscrowSupplierNFT` take their cut of any lateFee and repay left over to `LoansNFT`. [Ref](https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/EscrowSupplierNFT.sol#L522-L531)
- `LoansNFT` send all left over underlying asset to borrower. [Ref](https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/EscrowSupplierNFT.sol#L530-L531)

This logic function.
<https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/LoansNFT.sol#L258-L261>

```solidity
        // release escrow if it was used, paying any late fees if needed
        // @dev no slippage param / check on escrow release result since it depends only on time
        // so cannot be manipulated and so can be checked off-chain / known in advance reliably
        underlyingOut = _conditionalReleaseEscrow(loan, underlyingFromSwap);
```

can be simplifed to `underlyingOut = underlyingFromSwap - lateFee`. Escrow still receive their full original Escrow and interest regardless of swap result.

POC below explain how to exploit Uniswap swap to reduce `underlyingFromSwap` as much as possible to avoid paying lateFee to Escrow contract.
While still keeping their Taker position gain through Uniswap sandwich exploit.
The final result of exploit would be:

- Escrower receive: original escrow amount + interest held + late fee if any (this was stolen)
- Borrower receive: taker position gain - lateFee (none payed)

## Impact Explanation

Because Escrow is optional, also there is no benefit for borrower to put any money to Escrow. As explained in docs comments, Escrow is used for tax purpose.
There is no incentive nor economic benefit for borrower to put any money into Escrow.

While there is lost of funds, but this is impractical in deployment so I guess Medium severity is fit. It is an optional exploit that no one might meet.

## Likelihood Explanation

Basically none in real deployment condition. No one gonna put money deposit into Escrow that is large enough to result in huge amount of late fee.
No huge amount of late fee. no incentive for this exploit.

## Proof of Concept (if required)

Pre condition:

- Assuming we have 1_000_000 USDC loan and 1_000_000 escrow with 1200% late fee already accrued over 29 days.
- Resulting in ~900_000 USDC late fee.
- 500_000 USDC in Taker position. provider position lock in 50% put and 200% call strike percentage.
- Because of ETH price increase 100%, taker position now gain 200% value on their long position. Worth over 1_500_000 USDC.
- Borrower need to pay 1_000_000 USDC repayment to receive 1_500_000 USDC of taker position while repaying 900_000 of late fee. (a loss of 600_000 USDC)
- WETH/USDC 0.05% fee is accepted as pool swap. With 2_000_000 USDC and 200 ETH as liquidity.
- Assuming getting 100_000_000 USDC to flash loan with no fee.
Exploit Path:
- Follow sandwich attack, Using 100_000_000 USDC WETH to reduce UniswapV3 pool spot price close to zero.
- UniswapV3 virtual pool now hold lots of USDC and no WETH. spot price now reach close to nil.
- Calling `closeLoan()`. send in 1_000_000 repayment. `LoansNFT` Swap all USDC to WETH now return really small of WETH due to sandwich attack.
- WETH/USDC 0.05% pool now hold 104_500_000 USDC in liquidity.
- The amount of WETH output is not enough to repay all lateFee.
- `EscrowSupplierNFT.sol` try to use all available WETH output to pay to Escrow position anyway.
- Loan is closed. No WETH is transfer to borrower.
- End of sandwich attack. swapping back all WETH to pool equilibrium to receive original USDC and borrower profit from taker position.
- Pool now hold 2_100_000 USDC and 200 ETH as liquidity. 100_000 is pool 0.05% fee gain from sandwich attack.
- Borrower exploit gain back 2_400_000 USDC from uniswap. Gain full Taker position while avoiding paying late fee.

## Recommendation

Include price swap protection at the discreet of developer on the purpose of Escrow. Currently Escrow hold no purpose other than tax report. Borrower gain no benefit when open loan with escrow.
So any potential exploit on Escrow latefee is unlikely.
