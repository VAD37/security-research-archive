
# NFT broken tokenURI only for public sale token. JS parsing string error

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L226>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L456>

## Impact

For public sale token, all tokenData is string like this `"public"`. Include quote in string.
But the tokenURI already include quote in its script tag.
So when tokenURI return JS script, it will return broken JS script like this

```js
let tokenData=[""public""];
```

So for all NFT token which are public sale and enable on-chain metadata will have broken tokenURI due to error in JavaScript inside HTML file.
Disallow public user to view their token on OpenSea.

This can be fixed by admin calling `changeTokenData()` manually for each token. Which is very expensive on mainnet and not practical post deploy.
So the impact is high due to the cost involved to remedy the issue.

## Proof of Concept

NFT TokenURI get its JavaScript script here:
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L450-L457>

parsing string already have its own *quote*
`";let tokenData=[",tokenData[tokenId],"];"`

So set tokenData string its own quote in string is just redundant and lead to error.
This happen only for public sale token, when project hardcode tokenData string to `"public"`
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/MinterContract.sol#L226>

This will be the result return by `retrieveGenerativeScript()`

```js
let hash='TOKEN STRING';
let tokenId="TOKEN ID";
let tokenData=[""public""];
```

## Tools Used

manual

## Recommended Mitigation Steps

Maybe change `tokData = '"public"';` to `tokData = "public";`
