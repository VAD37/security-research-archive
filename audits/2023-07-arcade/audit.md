# duplicate address in merkleroot will prevent user from minting all `ReputationBadge` token

`ReputationBadge.mint()` using `merkleroot` to verify user claim.
The verify claim logic does not consider duplicate address in merkleroot which cause user can only mint token once before reaching maximum `totalClaimable` limit.

## Impact

If user have 2 leaf proof with same address, the user can only mint token once.
Any remedy fix would require admin to reupload merkleroot.

The project include [offchain code](https://github.com/code-423n4/2023-07-arcade/blob/88dcbdedebc506284fcfb3f14d20fc789ce811cf/scripts/airdrop/createMerkleTrieRepBadge.ts#L18-L25), which clearly show the merkleroot is generated whichout checking for duplicate address.

## Proof of Concept
- [Merkle verify](https://github.com/code-423n4/2023-07-arcade/blob/88dcbdedebc506284fcfb3f14d20fc789ce811cf/contracts/nft/ReputationBadge.sol#L211) using `(address,tokenId,amount)`
- If merkle root include leaf hash of same address, same token but different received amount. User can mint twice using same address.
- Each address cache `totalClaimable` [received when minting](https://github.com/code-423n4/2023-07-arcade/blob/88dcbdedebc506284fcfb3f14d20fc789ce811cf/contracts/nft/ReputationBadge.sol#L116).
- When user mint second time, `totalClaimable` is limited by amount in leaf hash. Which the limit already been reached when mint the first time.
- Hence user can only mint token to the maximum amount in one of `totalClaimable` leaf hash. Not the sum of `totalClaimable` in both leaf hash.

## Tools Used

manual

## Recommended Mitigation Steps

There is no reason for user to mint lesser amount of token. Because contract [take mint fee](https://github.com/code-423n4/2023-07-arcade/blob/88dcbdedebc506284fcfb3f14d20fc789ce811cf/contracts/nft/ReputationBadge.sol#L109), it make more sense to send user entire token amount in one leaf hash. Then use boolean check to ignore claimed leaf hash from merkleroot if user already minted token.