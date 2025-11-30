# BurnMintERC677 forget access control

## Impact

`BurnMintERC677.grantMintAndBurnRoles()` function currently lacks access control.
This absence of restrictions allows anyone to mint and burn tokens arbitrarily.
Although `BurnMintERC677.sol` doesn't wrap any tokens presently, it serves as a temporary holder for ERC20 tokens on another chain.
With the current setup, it leaves two routes open for potential manipulation:

1. Users could mint tokens for free on the sidechain and request tokens from the mainnet's TokenPool through OnRamp, assuming Decentralized Oracle Networks permit this.
2. Users could execute a DOS attack on the `tokenPool` and `OnRamp` contracts by burning other users' tokens, preventing tokens from being transferred back to their original chain.

## Proof of Concept

The `BurnMintERC677.sol` appears to be a [test setup file](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/test/pools/BurnMintERC677.t.sol#L61) within the scope of the contest. 
It serves as a wrapper token for ERC20, specifically designed to work with TokenPool while disregarding unconventional ERC20 tokens.

The minter and burn roles are [publicly accessible for anyone to use.](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/pools/tokens/BurnMintERC677.sol#L58-L61)

On the other hand, `BurnMintTokenPool.sol` functions as the token pool controller for the wrapper `BurnMintERC677.sol`, but it does[ not currently support actual token transfers.](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/pools/BurnMintTokenPool.sol#L19-L43)

The potential attack path is limited to denial-of-service (DOS), unless the oracle network allows messages to be sent back to the offRamp. In such a case, someone could mint free tokens and drain actual tokens from another chain's pool.

Users have the ability to route tokens from the offRamp in the mainnet chain to the sidechain. The sidechain possesses a wrapper token, with the wrapper token's burner role belonging to the OnRamp contract.

When users attempt to return these tokens to the mainnet, the current chain's OnRamp [calling `lockOrBurn` for tokens](https://github.com/code-423n4/2023-05-chainlink/blob/f5795088a8390094ffb362e30391c88923ad5033/contracts/onRamp/EVM2EVMOnRamp.sol#L313-L322) will always result in failure.

This is due to the fact that any user can burn other people's tokens simply by burning them. Consequently, the OnRamp is unable to execute the `lockOrBurn` function to return tokens to the original chain.

## Tools Used

manual

## Recommended Mitigation Steps

`onlyOwner` modifier