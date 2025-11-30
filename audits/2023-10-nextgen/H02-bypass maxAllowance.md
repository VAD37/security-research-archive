
# Reentrancy issue. User can easily mint more than allowed presale, bypassing merkle root limit

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L220>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L192-L199>

## Impact

Lack of reentrancy protection and code not follow *Checks, Effects, Interactions* pattern guideline.

Here are the *Effects* stuff happen after *Interactions* affected by reentrancy:

- `tokensMintedAllowlistAddress`: tracking presale minted NFT per address.
- `tokensMintedPerAddress`: tracking public minted NFT per address.
- `lastMintDate`: tracking last mint auction price, only for off-chain price calculation.
- `collectionTotalAmount`: tracking income, only for off-chain view.
- `burnAmount`: tracking burn NFT, only for off-chain view.

Only presale tracking part have anything to do with possible finance damage, because user can bypass presale limit tracked by merkleroot.

The only one hurt by this exploit is NFT project use sale option 3 where price increase for each token mint.
If user can bypass presale limit, they can mint at much lower price than other user.
It would be unfair to other user who mint at the end of presale, whom might have to pay higher price than other user.

Other case include when presale price is much lower than public sale. This require admin updated price when presale end.

## Proof of Concept

All NFT minting go through `_mintProcessing()` function
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L227-L232>

It call `_safeMint()` which by default have callback `onERC721Received()`.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/ERC721.sol#L245-L251>

So anything change after `_mintProcessing()` can be exploited by reentrancy.

We only care about this variable `tokensMintedAllowlistAddress`,track token count change for presale user, after `_mintProcessing()`
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L192-L199>

As show here this variable is used for get amount of token minted for presale user.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L404-L406>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L212-L219>

Because presale `mint()` function is called before `tokensMintedAllowlistAddress` is changed, exploiter can simply use the same merkleroot to mint again during `onERC721Received()` callback.

## Tools Used

manual

## Recommended Mitigation Steps

Add reentrancy protection
