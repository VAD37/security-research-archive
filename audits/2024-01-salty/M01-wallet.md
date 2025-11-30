# `ManagedWallet.sol` is not a wallet if it does not transferout ETH transfered to it

`ManagedWallet` accept ETH as confirmation for changing wallet owner but does not refund ETH after the owner is changed.
Send ETH with false check and limit and 30K gas is simple implementation and protection against DOS and gas attack.
There simply no reason for not implementing it.

## Impact

`ManagedWallet` is main team protocol wallet. It might be change later when there is a team exist.
There is no reason for 0.05ETH stuck in that contract each time changing new team wallet.

## Proof of Concept

1. new wallet send in 0.05 ETH for transition process to kick in. After 30 days, the main wallet address can be changed. <https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/ManagedWallet.sol#L59-L70>
2. `changeWallets()` function does not refund token balance to new confirmation wallet for sending 0.05ETH.<https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/ManagedWallet.sol#L73-L89>
3. 0.05ETH is stuck in the contract forever.

## Tools Used

<https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/ManagedWallet.sol#L59-L70>

## Recommended Mitigation Steps

Add fail-safe transfer ETH to changeWallets.

```solidity
File: ManagedWallet.sol
72:  // Confirm the wallet proposals - assuming that the active timelock has already expired.
73:  function changeWallets() external
74:   {
75:   // proposedMainWallet calls the function - to make sure it is a valid address.
76:   require( msg.sender == proposedMainWallet, "Invalid sender" );
77:   require( block.timestamp >= activeTimelock, "Timelock not yet completed" );
      +++   confirmationWallet.call{value: address(this).balance, gas: 30000}(""); // refund original eth for confirmationWallet. 30k gas is safe amount to prevent gas exploit and safe transfer. Also ignore return value.
79:   // Set the wallets
80:   mainWallet = proposedMainWallet;
81:   confirmationWallet = proposedConfirmationWallet;
82: 
83:   emit WalletChange(mainWallet, confirmationWallet);
84: 
85:   // Reset
86:   activeTimelock = type(uint256).max;
87:   proposedMainWallet = address(0);
88:   proposedConfirmationWallet = address(0);
89:   }

```
