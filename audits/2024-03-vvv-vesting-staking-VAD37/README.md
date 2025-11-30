
# vVv Vesting & Staking contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Mainnet, possibly Avalanche C-Chain for the staking contract.
___

### Q: Which ERC20 tokens do you expect will interact with the smart contracts? 
$VVV 
___

### Q: Which ERC721 tokens do you expect will interact with the smart contracts? 
none
___

### Q: Do you plan to support ERC1155?
no
___

### Q: Which ERC777 tokens do you expect will interact with the smart contracts? 
none
___

### Q: Are there any FEE-ON-TRANSFER tokens interacting with the smart contracts?

no
___

### Q: Are there any REBASING tokens interacting with the smart contracts?

no
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED?
TRUSTED -- if `AuthorizationRegistry` is considered a protocol in this case
___

### Q: Is the admin/owner of the protocol/contracts TRUSTED or RESTRICTED?
TRUSTED
___

### Q: Are there any additional protocol roles? If yes, please explain in detail:
1. `DefaultAdmin`, any arbitrary role
2. actions:
   a. Create role
   b. Remove role
   c. Set permission
   d. Call function
3. expected outcomes:
   * `DefaultAdmin` must be allowed to take all these actions (d. only if `setPermission` was used to give it permission`).
   * Any arbitrary role should only be allowed to take action d. if (and only if) given permission through `setPermission`
4. prohibited:
   * Any arbitrary role must not be allowed to take action a - c
   * No role may be able to take action d without having the role assigned through `setPermission`
___

### Q: Is the code/contract expected to comply with any EIPs? Are there specific assumptions around adhering to those EIPs that Watsons should be aware of?
no
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
We accept a loss of precision of 0.000000000001% on the vested amount calculation.
___

### Q: Please provide links to previous audits (if any).
none
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, input validation expectations, etc)?
no
___

### Q: In case of external protocol integrations, are the risks of external contracts pausing or executing an emergency withdrawal acceptable? If not, Watsons will submit issues related to these situations that can harm your protocol's functionality.
no
___

### Q: Do you expect to use any of the following tokens with non-standard behaviour with the smart contracts?
no
___

### Q: Add links to relevant protocol resources
https://hackmd.io/@vvv-knowledge/Syme5HlRT
___



# Audit scope


[vvv-platform-smart-contracts @ 7008f399a58c05832ef361dc5c54bd091d723f84](https://github.com/vvvdevs/vvv-platform-smart-contracts/tree/7008f399a58c05832ef361dc5c54bd091d723f84)
- [vvv-platform-smart-contracts/contracts/auth/VVVAuthorizationRegistry.sol](vvv-platform-smart-contracts/contracts/auth/VVVAuthorizationRegistry.sol)
- [vvv-platform-smart-contracts/contracts/auth/VVVAuthorizationRegistryChecker.sol](vvv-platform-smart-contracts/contracts/auth/VVVAuthorizationRegistryChecker.sol)
- [vvv-platform-smart-contracts/contracts/staking/VVVETHStaking.sol](vvv-platform-smart-contracts/contracts/staking/VVVETHStaking.sol)
- [vvv-platform-smart-contracts/contracts/tokens/VvvToken.sol](vvv-platform-smart-contracts/contracts/tokens/VvvToken.sol)
- [vvv-platform-smart-contracts/contracts/vesting/VVVVesting.sol](vvv-platform-smart-contracts/contracts/vesting/VVVVesting.sol)


