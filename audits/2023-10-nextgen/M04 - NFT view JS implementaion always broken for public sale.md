
# It is very easy for `CollectionAdmin` or artist themself to update NFT onchain-metadata into something malicious purpose without admin approval after sale

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L238-L253>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L450-L457>
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L343-L357>

## Impact

Collection Owner have lowest power and only allowed to update collection sale supply,sale time and collection metadata.
Assuming CollectionAdmin is NFT creator or artist themself, since it give them easy access to change sale supply as needed.

Because metadata rarely change, it make more sense to prevent CollectionAdmin from changing metadata after collection is created without higher admin approval.

By changing artist information like `collectionWebsite` or `collectionScript`, It is very easy process to scam user post sale.
Either artist lost wallet or simply NFT creator have malicious intention themself.

## Proof of Concept

Permission check `CollectionAdminRequired()` only check if `msg.sender` is collection admin. So any collection admin can call all function with `CollectionAdminRequired` modifier.

Collection Admin or possible NFT creator can update their collection information at anytime here.
<https://github.com/code-423n4/2023-10-nextgen/blob/main/smart-contracts/NextGenCore.sol#L247>

By simply changing Collection information into something phishing. Like changing `collectionWebsite` into phishing site that look like OpenSea or Rarible. Or changing `collectionScript` into something that can invoke call to metamask or other wallet to request user to sign transaction.

Artist simply have very easy tool to scam user post sale. And rewards incentive is really high for them to do so.

## Tools Used

manual

## Recommended Mitigation Steps

Collection should be freeze directly when sale end after calling `setFinalSupply()`
Any further update to collection information should be done by admin approval.
