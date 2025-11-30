
# Ajna #2 contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Ethereum mainnet, Arbitrum, Optimism, Binance Smart Chain, Polygon, Fantom, Tron, Avalanche
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
any - ERC20's are used in fungible, collection and subset pool types. No rebasing or fee-on-transfer tokens.
___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
any - ERC721's are used in collection and subset pool types. 
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
none
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

none
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

none
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
N/A no admins
___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
N/A no admins
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
No assigned roles.
___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
N/A
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
N/A
___

### Q: Please provide links to previous audits (if any).
https://github.com/ajna-finance/audits
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
N/A
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
N/A
___

### Q: Do you expect to use any of the following tokens with non-standard behaviour with the smart contracts?
N/A
___

### Q: Add links to relevant protocol resources
- [Twitter](https://mobile.twitter.com/ajnafi)
- [Website](https://www.ajna.finance/)
- [Whitepaper](https://www.ajna.finance/whitepaper)
- [Ajna Technical Master Spec](https://docsend.com/view/ai74yqgzjp3yydyt)
- [ELI5](https://www.ajna.finance/eli5)
- [Technical Diagrams](https://github.com/ajna-finance/ajna-core/tree/main/docs)
___



# Audit scope


[ajna-core @ 14e8655948efdb84af1a7eb96083cf9bec09d98b](https://github.com/ajna-finance/ajna-core/tree/14e8655948efdb84af1a7eb96083cf9bec09d98b)
- [ajna-core/src/ERC20Pool.sol](ajna-core/src/ERC20Pool.sol)
- [ajna-core/src/ERC20PoolFactory.sol](ajna-core/src/ERC20PoolFactory.sol)
- [ajna-core/src/ERC721Pool.sol](ajna-core/src/ERC721Pool.sol)
- [ajna-core/src/ERC721PoolFactory.sol](ajna-core/src/ERC721PoolFactory.sol)
- [ajna-core/src/PoolInfoUtils.sol](ajna-core/src/PoolInfoUtils.sol)
- [ajna-core/src/PoolInfoUtilsMulticall.sol](ajna-core/src/PoolInfoUtilsMulticall.sol)
- [ajna-core/src/base/FlashloanablePool.sol](ajna-core/src/base/FlashloanablePool.sol)
- [ajna-core/src/base/PermitERC721.sol](ajna-core/src/base/PermitERC721.sol)
- [ajna-core/src/base/Pool.sol](ajna-core/src/base/Pool.sol)
- [ajna-core/src/base/PoolDeployer.sol](ajna-core/src/base/PoolDeployer.sol)
- [ajna-core/src/interfaces/pool/IERC3156FlashBorrower.sol](ajna-core/src/interfaces/pool/IERC3156FlashBorrower.sol)
- [ajna-core/src/interfaces/pool/IERC3156FlashLender.sol](ajna-core/src/interfaces/pool/IERC3156FlashLender.sol)
- [ajna-core/src/interfaces/pool/IPool.sol](ajna-core/src/interfaces/pool/IPool.sol)
- [ajna-core/src/interfaces/pool/IPoolFactory.sol](ajna-core/src/interfaces/pool/IPoolFactory.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolBorrowerActions.sol](ajna-core/src/interfaces/pool/commons/IPoolBorrowerActions.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolDerivedState.sol](ajna-core/src/interfaces/pool/commons/IPoolDerivedState.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolErrors.sol](ajna-core/src/interfaces/pool/commons/IPoolErrors.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolEvents.sol](ajna-core/src/interfaces/pool/commons/IPoolEvents.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolImmutables.sol](ajna-core/src/interfaces/pool/commons/IPoolImmutables.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolInternals.sol](ajna-core/src/interfaces/pool/commons/IPoolInternals.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolKickerActions.sol](ajna-core/src/interfaces/pool/commons/IPoolKickerActions.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolLPActions.sol](ajna-core/src/interfaces/pool/commons/IPoolLPActions.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolLenderActions.sol](ajna-core/src/interfaces/pool/commons/IPoolLenderActions.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolSettlerActions.sol](ajna-core/src/interfaces/pool/commons/IPoolSettlerActions.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolState.sol](ajna-core/src/interfaces/pool/commons/IPoolState.sol)
- [ajna-core/src/interfaces/pool/commons/IPoolTakerActions.sol](ajna-core/src/interfaces/pool/commons/IPoolTakerActions.sol)
- [ajna-core/src/interfaces/pool/erc20/IERC20Pool.sol](ajna-core/src/interfaces/pool/erc20/IERC20Pool.sol)
- [ajna-core/src/interfaces/pool/erc20/IERC20PoolBorrowerActions.sol](ajna-core/src/interfaces/pool/erc20/IERC20PoolBorrowerActions.sol)
- [ajna-core/src/interfaces/pool/erc20/IERC20PoolEvents.sol](ajna-core/src/interfaces/pool/erc20/IERC20PoolEvents.sol)
- [ajna-core/src/interfaces/pool/erc20/IERC20PoolFactory.sol](ajna-core/src/interfaces/pool/erc20/IERC20PoolFactory.sol)
- [ajna-core/src/interfaces/pool/erc20/IERC20PoolImmutables.sol](ajna-core/src/interfaces/pool/erc20/IERC20PoolImmutables.sol)
- [ajna-core/src/interfaces/pool/erc20/IERC20PoolLenderActions.sol](ajna-core/src/interfaces/pool/erc20/IERC20PoolLenderActions.sol)
- [ajna-core/src/interfaces/pool/erc20/IERC20Taker.sol](ajna-core/src/interfaces/pool/erc20/IERC20Taker.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721Pool.sol](ajna-core/src/interfaces/pool/erc721/IERC721Pool.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721PoolBorrowerActions.sol](ajna-core/src/interfaces/pool/erc721/IERC721PoolBorrowerActions.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721PoolErrors.sol](ajna-core/src/interfaces/pool/erc721/IERC721PoolErrors.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721PoolEvents.sol](ajna-core/src/interfaces/pool/erc721/IERC721PoolEvents.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721PoolFactory.sol](ajna-core/src/interfaces/pool/erc721/IERC721PoolFactory.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721PoolImmutables.sol](ajna-core/src/interfaces/pool/erc721/IERC721PoolImmutables.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721PoolLenderActions.sol](ajna-core/src/interfaces/pool/erc721/IERC721PoolLenderActions.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721PoolState.sol](ajna-core/src/interfaces/pool/erc721/IERC721PoolState.sol)
- [ajna-core/src/interfaces/pool/erc721/IERC721Taker.sol](ajna-core/src/interfaces/pool/erc721/IERC721Taker.sol)
- [ajna-core/src/libraries/external/BorrowerActions.sol](ajna-core/src/libraries/external/BorrowerActions.sol)
- [ajna-core/src/libraries/external/KickerActions.sol](ajna-core/src/libraries/external/KickerActions.sol)
- [ajna-core/src/libraries/external/LPActions.sol](ajna-core/src/libraries/external/LPActions.sol)
- [ajna-core/src/libraries/external/LenderActions.sol](ajna-core/src/libraries/external/LenderActions.sol)
- [ajna-core/src/libraries/external/PoolCommons.sol](ajna-core/src/libraries/external/PoolCommons.sol)
- [ajna-core/src/libraries/external/PositionNFTSVG.sol](ajna-core/src/libraries/external/PositionNFTSVG.sol)
- [ajna-core/src/libraries/external/SettlerActions.sol](ajna-core/src/libraries/external/SettlerActions.sol)
- [ajna-core/src/libraries/external/TakerActions.sol](ajna-core/src/libraries/external/TakerActions.sol)
- [ajna-core/src/libraries/helpers/PoolHelper.sol](ajna-core/src/libraries/helpers/PoolHelper.sol)
- [ajna-core/src/libraries/helpers/RevertsHelper.sol](ajna-core/src/libraries/helpers/RevertsHelper.sol)
- [ajna-core/src/libraries/helpers/SafeTokenNamer.sol](ajna-core/src/libraries/helpers/SafeTokenNamer.sol)
- [ajna-core/src/libraries/internal/Buckets.sol](ajna-core/src/libraries/internal/Buckets.sol)
- [ajna-core/src/libraries/internal/Deposits.sol](ajna-core/src/libraries/internal/Deposits.sol)
- [ajna-core/src/libraries/internal/Loans.sol](ajna-core/src/libraries/internal/Loans.sol)
- [ajna-core/src/libraries/internal/Maths.sol](ajna-core/src/libraries/internal/Maths.sol)


