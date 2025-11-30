# Cash Token Approval to Loans KeeperBot will be used to steal funds against another user

## Summary

`LoansNFT.closeLoan()` allow KeeperBot to close loan if Loan NFT owner have enough cash and enough allowance.
This can be abused by transfered in NFT made by someone else, this NFT can hold negative balance sheet.
Then, Keeper bot can automacially close loan. Taking cash from user's account and repaying huge penalty late fee to attacker account.

## Finding Description

Through out Collar codebase, there are only 2 instances of `ERC20.safeTransferFrom()` with `from != msg.sender`. Assuming max approval is the norm, this can be abused to steal funds if it is not checked properly.

It happened here in `LoansNFT.closeLoan()`:
<https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/LoansNFT.sol#L251>

Simplied the way of `LoansNFT.closeLoan()` works are:

1. Check if `msg.sender` is NFT owner or whitelisted KeeperBot who have owner permission.
2. get all CASH from Taker/Provider position
3. take loan repayment amount of CASH from NFT owner
4. swap all CASH to underlying asset
5. pay any Escrow potential late fee or getting refund for early closing in underlying asset
6. transfer remaining underlying asset to NFT owner

Assuming KeeperBot automatically refresh Loans NFT every minutes checking owner address:

- have called `LoansNFT.setKeeperApproved()` to approve KeeperBot to close loan
- have cash token allowance approval
- Have enough CASH to repay loan

This open up attack where attacker transfer in another LoansNFT ERC721 made by someone else with unfavourable condition.
As attacker can prepare Loan NFT where profit from Taker position to zero and huge amount of late fee as penalty.
Then when KeeperBot automatically close this loan.
Follow above simplifed steps: taking CASH from NFT owner, taking Taker position profit and swap it underlying token, paying any potential escrow fee then refund to user.

User will now receive less than what they have before.Funds is stolen to Escrow account.

POC below explain more on details condition.

## Impact Explanation

High severity because exploit provide monetary gain with no downside for attacker.

## Likelihood Explanation

Depend on how offchain KeeperBot work. Likely if keeperbot work like simple bot as describe above.

100% will happen if keeper bot account is compromised, this attack is possible to steal all users who have approve KeeperBot address before and still USDC allowance to `LoansNFT.sol`.

## Proof of Concept (if required)

Assuming 1 WETH = 1,000 USDC.

Attacker can follow this attack path:

- Create Provider offer with 99.99% put and 100.01% call strike percentage. With minimum duration of 5 minutes
- Create Escrow offer of 1200% late fee penalty and max 30 days grace. With minimum duration of 5 minutes, escrow fee interest is almost zero
- Create LoansNFT with above Provider and Escrow offer.
- Create loan of 10,000 USDC, with 10 WETH as Escrow.
- After 5 minutes passed, Price drop 0.1%, Provider gain 100% locked value in Taker position.
- Settle Taker/Provider position but not close loan yet.
- Attacker now have regain back most of 10,000 USDC that was locked in Provider position and 10 WETH of escrow hold inside Escrow contract.
- Wait a few days for late fee to accumulate. maximum 30 days reach 98% of 10 WETH. Or ~9.8 WETH late fee.
- Transfer this LoansNFT to another user that satisfy attack condition as explained in description.
- Bot call `LoansNFT.closeLoan()` to close loan.
- 10,000 USDC is transfered from user account
- User gain Taker position but it have no value.
- 10,000 USDC swap to 10 WETH token.
- 9.8 WETH late fee is transfered to Escrow contract to attacker.
- 0.2 WETH is transfered to user account.

User now lost 10,000 USDC and gain back 0.2 WETH.

## Recommendation

There currently no good fix without compromise on some features.

Patching offchain KeeperBot is not a solution due to potential compromise of KeeperBot account.

Some potential options:

- Prevent any loans ERC721 transfer unless it was made through some Collar contract
- `closeLoan()` should check if repayment result in negative balance sheet for borrower owner. (still exploitable)
- 