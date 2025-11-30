# note

- testing only work with testnet sepolia
- forking mainnet does not work for unknown reason. Suspect is managedteam wallet is empty contract. It is DAO contract only deployed on testnet. DAO.sol on mainnet must be deployed again.

## Path

1. Before Voting and init exchange
2. Post Voting and normal exchange
3. When project launch there is a window for exploit

## 2024-01-20

10 more days till audit end.
1 oracle down, 1 cannot be exploited. 1 can be exploited if I understand how underlaying of project work.
1 more to go for extreme H issue.

## memo

### Root

ManagedWallet: SAlty.IO Team wallet. controlled by project owner. or simply 1 guy.
Salt: main  voting token 1M token
SigningTools: nonstandard ECSDA Library. allow weird signature library.
AccessManager: GEO IP whitelist. User need to go through web3 portal get signature signed by 1 bot account after confirming KYC
ExchangeConfig: DAO config.Also work as Singleton with `walletHasAccess()` function

### DAO

DAO: contract is immutable with no way to change things, prefixed operation. Only config can be changed.
