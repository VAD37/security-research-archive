
# GLIF contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Filecoin FEVM Mainnet
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
- Wrapped FIL https://github.com/wadealexc/fevmate/blob/5eabf6ad94508fe18312646089d9180bb58f4db9/contracts/token/WFIL.sol
- iFIL is the liquid staking token for the Infinity pool https://github.com/glifio/glifmate/blob/main/src/PoolToken.sol
___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
None
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

No
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

No
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
N/A
___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
TRUSTED
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
The protocol itself is generally owned and operated by the GLIF team. The GLIF team controls the `owner` key to these smart contracts (which are multisigs and not EOAs)

The Agent smart contract is owned by the Storage Provider itself not the protocol.

Liquidations of storage providers must occur off chain - and the GLIF team (in this version) is responsible for handling liquidations
___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
It's inspired by ERC4626 tokenized vaults but not 100% spec compatible 
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
We understand that withdrawing and redeeming iFIL directly through the Infinity Pool will not work - you must go through the SimpleRamp contract directly 
___

### Q: Please provide links to previous audits (if any).
(PDF not linked here)
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
GLIF runs and solely controls its own unique oracling system that issues verifiable credentials to Storage Providers who wish to borrow. Read more here https://docs.google.com/document/d/1nHpdoUqtPuOGBWZu2BsqiaHle8qY4aTTxRr46bMLXR8/edit#heading=h.vlhbgo23a58p
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
N/A
___



# Audit scope


[pools @ e7c43ea72687930aa6fa9822c57f1730b087388f](https://github.com/glifio/pools/tree/e7c43ea72687930aa6fa9822c57f1730b087388f)
- [pools/shim/FEVM/MinerHelper.sol](pools/shim/FEVM/MinerHelper.sol)
- [pools/src/Agent/Agent.sol](pools/src/Agent/Agent.sol)
- [pools/src/Agent/AgentDeployer.sol](pools/src/Agent/AgentDeployer.sol)
- [pools/src/Agent/AgentFactory.sol](pools/src/Agent/AgentFactory.sol)
- [pools/src/Agent/AgentPolice.sol](pools/src/Agent/AgentPolice.sol)
- [pools/src/Agent/MinerRegistry.sol](pools/src/Agent/MinerRegistry.sol)
- [pools/src/Auth/AuthController.sol](pools/src/Auth/AuthController.sol)
- [pools/src/Auth/Operatable.sol](pools/src/Auth/Operatable.sol)
- [pools/src/Auth/Ownable.sol](pools/src/Auth/Ownable.sol)
- [pools/src/Constants/Epochs.sol](pools/src/Constants/Epochs.sol)
- [pools/src/Constants/Routes.sol](pools/src/Constants/Routes.sol)
- [pools/src/Credentials/CredParser.sol](pools/src/Credentials/CredParser.sol)
- [pools/src/OffRamp/SimpleRamp.sol](pools/src/OffRamp/SimpleRamp.sol)
- [pools/src/Pool/Account.sol](pools/src/Pool/Account.sol)
- [pools/src/Pool/InfinityPool.sol](pools/src/Pool/InfinityPool.sol)
- [pools/src/Pool/PoolRegistry.sol](pools/src/Pool/PoolRegistry.sol)
- [pools/src/Pool/RateModule.sol](pools/src/Pool/RateModule.sol)
- [pools/src/Router/GetRoute.sol](pools/src/Router/GetRoute.sol)
- [pools/src/Router/Router.sol](pools/src/Router/Router.sol)
- [pools/src/Types/Structs/Account.sol](pools/src/Types/Structs/Account.sol)
- [pools/src/Types/Structs/Credentials.sol](pools/src/Types/Structs/Credentials.sol)
- [pools/src/VCVerifier/VCVerifier.sol](pools/src/VCVerifier/VCVerifier.sol)



