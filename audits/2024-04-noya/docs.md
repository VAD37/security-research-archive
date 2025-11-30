Noya smart contract docs

Project overview
Noya at its core is a vault that allows people who deposit into this vault, to benefit from the actions of the strategy manager. It also prevents the strategy manager from executing actions that are not according to the security settings of the vault.

1. Functional requirements
1.1. Roles
	1.1.1. Governor
		This is a timelock smart contract that is responsible for changing the addresses of others. 
	1.1.2. Maintainer
		This smart contract is in charge of adding a new vault, adding trusted tokens for that vault, and adding trusted positions to the registry.
	1.1.3. Keepers
		This is the smart contract that manages execution of the strategies. It’s a multisig contract. Strategy managers can submit their transactions into IPFS in an encrypted way and the keepers will decrypt and execute it.
	1.1.4 watchers
		This smart contract is responsible to make sure the execution of noya is going on correctly. If there is any misbehaving (like price manipulation or any suspicious actions from the keepers) the watchers and undo the action.
	1.1.5 emergency 
		This address is also a cold wallet that is going to be used in situations that a position is stuck or another role of noya is compromised.
	1.1.6 users
		Users can provide funds to the accountingManager contract


1.2 entities
	1.2.1 registry 
		This contract is responsible for holding information about each vault. 
Most important information are:
	- connectors: this field is holding the information about each connector, the address and trusted tokens. To save space, we are holding the vault's trusted tokens (tokens that are trusted for all of the connectors) in the “accountingManager” connector data(look at line 93 in Registry.sol).
	- TrustedPostionBP: This is holding information about which position types are trusted. This is a blueprint of the position so the connector can build a position by having this information. It generally helps us to make transactions safer (since we are not giving any new addresses on the run and we have to set this first)
	- HoldingPositions: This is an array of current positions in the system.
	- IsPositionUsed: This indicated the index of the position in the array(if 0 it means that position is not in the array so we have to add one dummy position to not have an actual position at index 0)

	1.2.2 accountingManager
		This contract is in charge of:
1. Accounting of Noya vaults (calculating the value of each share)
2. BookKeeping for noya shareholders (ERC4626 standard)
3. Implementing the delayed withdrawals and deposits
	1.2.3 connectors
		This set of smart contracts are responsible for connecting to a protocol. They all support the IConnector interface, but each of them could have different functions to deposit into protocols. At this time, they all inherit the “BaseConnector.sol” too.
The IConnector functionalities are:
- function addLiquidity(address[] memory tokens, uint256[] memory amounts, bytes memory data)
This function is for adding Liquidity to the connector
- function getUnderlyingTokens(uint256 positionTypeId, bytes memory data)view returns (address[] memory);
This function is giving what are the underlying tokens of a position blueprint
- function getPositionTVL(HoldingPI memory, address) external view returns (uint256);
This function is for getting the holding position value based on the base address
	
	1.2.4 valueOracle
This contract is allowing us to calculate the value of a token based on another. We can define routes in this contract (we have a price source for tokens A-B, B-C, C-D and we want to get the price of A-D. we can define the route of [B,C] in the smart contract and it loops through the route to get the price of A-D.
	1.2.4.1 Chainink Oracle
This contract is responsible for getting prices from chainlink oracle
	1.2.4.2 Uniswap Oracle
This contract is responsible for getting TWAP (time weighted average price) from uniswap v3
	1.2.5 swapHandler
This contract allows us to swap and bridge to other chains in a secure way.
We are currently using lifi to execute the swap and bridge.
The only contract that can use the bridging feature is the OmniChainLogic (and the two contracts that are inheriting from it)
For swapping, it’s using the valueOracle to get the prices of two tokens, and checks for the slippage and reverts if the slippage is not acceptable.
	1.2.6 keeperContract
This is the multiSig contract that is responsible for executing the strategies.

1. Technical overview
	1.1 Architecture 

* red arrow indicates the flow of funds and blue arrow indicates the flow of information

This is a simplified version of relation between the connectors, AccountingManager, registry, Omnichain managers.
Adding a trusted position
	To add a trusted position, the “maintainer” of the vault first needs to add the trusted tokens to the vault information in the registry.  Then the “maintainerWithoutTimelock” can add the trusted position to the registry if its calculator connector is a valid connector and the tokens are trusted.
The positions flow
When a connector creates a position, it notifies the registry (by using the “updateHoldingPosition” of the registry),  and the registry after checking if this is a duplicate or it’s a trusted position, adds it to the “HoldingPositions” array of the vault.

Later on, the accountingManager contract (using the TVLHelper library), gets the holding positions from the registry and loops through it and calls the calculator connector to get the value of that position.

2.2 deposit and withdrawal flow
	2.2.1 deposit flow
Users can deposit the “base” token of a vault into it using the “deposit“ function. This function transfers the tokens of the users into the “accountingManager” contracts and adds this deposit record into the deposit queue. Then we should wait for any timed position (explained in 2.7) that we hold at the moment to update. After all positions are updated, we can “calculate” the value of the deposited amount. After calculation we should wait for a fixed period of time (depositWaitingTime). This period allows the watchers to prevent any miscalculation due to issues in the calculating TVL or price manipulation.
2.2.2. Withdraw flow
Users with a positive balance of share tokens can burn their tokens and receive the underlying base token. Same process of waiting for all timed positions update (2.7).
Once we have updated all positions we calculate the base token amount of the burning shares. Once we have calculated the prices for a couple of withdrawal requests, we can initiate the withdrawal group. WithdrawGroup consists of a couple of withdrawal requests that we are going to retrieve the funds for them from the connectors.
fulfillCurrentWithdrawGroup function is being called when we have enough funds to execute these withdrawal requests.
At last, by calling the “executeWithdrawal” we transfer the users funds to the receiver address and pop the request from the queue.
	2.3 keepers
In noya we have a set of strategy managers for each vault. The process of consensus between these managers happens off-chain. And at the end they submit the final transaction to the keepers via IPFS and encrypted. Then the keepers decrypt the strategy and submit the transaction to the chain. We are using a multi sig that requires multiple signatures of the owners at once to execute the transaction (for example 5 out of 7 or 3 out of 5). Using the method allows us to execute noya transactions faster and more securely.
	2.4 valueOracle
	Noya uses multiple value oracles to calculate the price of each asset that we are holding. NoyaValueOracle is capable of\ defining and executing different routes to get the price of each asset based on another by using the “updatePriceRoute” function. For example we need the price of token A based on token C but we don’t have a stable pool or price source between A and C. in that case we can define to the smart contract to use pool A/B of uniswap and B/C of chainlink to get the price of A/C.
At the moment we support chainlink price feeds and Uniswap v3 TWAP as price sources.
	2.5 position creation and TVL calculation
In noya, when we need to create a position (for example a UNIv3 position) we use the “updateHoldingPosition “ function of the registry to add this position to the vault. By doing so, whenever we need to calculate the TVL of the vault, we can simply add up the value of holding positions of each vault with the “getPositionTVL “ of the calculator connector.
	2.6 fees
	Noya takes 3 types of fees
1. Withdrawal fee (which happens when someone is withdrawing their tokens)
	This fee is being taken at the time of the execution of the withdrawal.
2. Management fees (x% of the liquidity per year)
We can simply mint x% of the total shares * (time_elapsed_from_last_fee / seconds_in_year) to the feeReceiver periodically (at most every 10 days).
Also to prevent the compounding effect on the fees (taking fees from the previous fees), the fee receiver is a contract that can only burn or withdraw shares(can't transfer) and we reduce the balance of this account from all shares to not count it in the fee calculation
3. Performance fee ( x% of the profit that we make in noya)
Taking this fee happens in a 2 step process. First the strategy manager calls the “recordProfitForFee “ function to calculate the shares of the fees and store the fee amount in “preformanceFeeSharesWaitingForDistribution “ variable. Then after 12 hours, if the profit has not been dropped during this period, the manager can claim the amount. We use the mechanism to prevent the strategy manager from manipulating the prices and trick the contract to get more fees than it’s supposed to get.
All users can check the profit and abort the fee if the profit drops below the amount that is stored in the contract using “checkIfTVLHasDroped “ function.
	2.7 omnichain handler
	There are vaults in noya that can move the assets between multiple chains. We use the omnichain handler to make these vaults possible. OmniChainManagerBaseChain is going to be deployed and added to the registry in the base chain and OmnichainManagerNormalChain in other chains that we want to use. They are using LayerZero infrastructure to pass information about TVL and time to the base chain. Then the OmniChainManagerBaseChain stores the information about these holdings on other chains.
On the other hand, OmnichainManagerNormalChain will be added to registry just like an accounting manager to handle the deposits and withdrawals to that chain
Documentation Request to Noya:
System architecture: 
what are the different elements of the system, and how do they translate into the smart contracts (top to bottom, e.g. the system consists in a set of vaults managed by each accounting manager, and linked to the registry?):
In each chain we have a registry that is responsible for storing and serving these information about each vault:


Address of accountingManager
Address of base token of the vault (token that we use for book keeping)
Information of connectors
Information of trusted position blueprint
Information of positions that we hold at the moment
Governance addresses (explained in 1.1.1 to 1.1.5)
	So in each vault that is defined in the registry, there is one accounting manager contract and a set of active connectors. To add positions, we need to add its corresponding position blueprint to the “trustedPositionsBP” mapping. Then we’ll be able to add positions to the holdingPositions array when we have an actual position that has some value.

What features has every vault
	It can receive money through the accountingManager, deposit that money to the connectors, swap the tokens and deposit into various possible positions that the connectors support. And calculating the value of those positions.
Value Oracle → how is the system choosing the usage of Chainlink or TWAP oracles?
	It’s an offchain decision (governance). We’ll use chainlink for any pair that we have a valid chainlink (or other compatible oracles like RedStone) and we’ll use uniswap for the ones that we don’t have one.
What are the users flows/functions the user will use and to do what
	Desposit, withdraw, transfer shares (all in accountingManager)
What is the benefit for users (e.g. yield)
	“Gaining yield when the positions of noya vault add more token to the connector and the accounting manager (using TVLHelper) increases the price of each vault token” and “exposure to expensive chains without paying expensive fees”
How is the system deployed onchain(e.g. the developer will deploy X contract, then create a Pool into registry, and add some connectors etc)
Deploy the registry
Deploy the value oracle and swap handler
Deploy accounting manager
Deploy keeper contract
Add the vault into the registry
Deploy connectors
Add connectors into the registry
On what chains is the project going to be deployed?
eth bnb base optimism arb avax polygon gnosis polygon zkevm zksync ERA
What roles are centralized and what are decentralized?
All of the roles are centralized other than strategy manager. Everyone can propose strategies but it happens off-chain. (they don’t have any on-chain access)
What roles are on-chain, and what roles are off-chain (e.g. a client, Front-End managed, etc).
Strategy manager: offchain 
Keepers : offchain and onchain
Governance onchain
Frontend (users endpoint)
Accounting Manager:
How is this contract used to comply with the flow
This contract is in charge of:
1. Accounting of Noya vaults (calculating the value of each share)
2. BookKeeping for noya shareholders (ERC4626 standard)
It inherits the ERC4626 standard to handle the shares of the user.
3. Implementing the delayed withdrawals and deposits
The client will cal `deposit` when they want to stake some tokens
What tokens are allowed
The “base token of the vault”
What happens when the user call this function
Their tokens will be sent to the accountingManagerContract and their deposit record will be added to the queue
The manager will then use the following functions of the deposit flow (under what criteria, and how does that work regarding groups, fulfill, etc)
Deposit flow: 
1. User deposits some tokens
2. After all of the positions that have time (look at positionTimestamp in HoldingPI struct) update their time, (or immediately if there is no position with timestamp) the keeper can call the calculateDepositShares function. This will calculate the shares of this deposit and record it in the queue, and update the middle of the queue that indicates which records have been calculated.
3. After a specified time, the keeper can call the executeDeposit function to mint the actual share tokens to the users and send the calculated amount to an active connector. This will also update the queue variables and total deposited amount.

How do shares work: how are they generated/burned and by who, what is their role in the system, how are they managed, etc.
Shares represent the value that each user owns from the vault. They can be minted using the deposit flow and can be burned (transferring the base tokens to the users) using the withdraw function.
The value of each share is calculated using this formula:
	baseTokenValue = (shareAmount) * totalAssets / totalShares
(totalAssets is a function in accountingManager that calculates the value of all positions based on the baseToken) 
What will happen with the tokens sent by the user (where do they go, or how are they used, etc)
Tokens sent by the users will be transferred to a connector to be used in a position.
What happens with the shares minted to the user.	
Users can hold the tokens or use them in various defi protocols (they are ERC20 tokens so they can be used as normal tokens)
How do interactions take place with registry
There is no interactions in the registry for handling the deposit.
How does the queue work, and how are the IDs managed.
Queue has four variables to function. 
First : holds the index of the first item of the queue
Last : holds the index of the last item of the queue
Middle : holds the index of the first queue item that needs to be calculated
Queue : a mapping from index => DepositRecords that hold information of all deposits
The client uses `withdraw` to recover their tokens
How did the user get some benefits/yield out of the interactions with this protocol (if any), and how are they 
When users deposit tokens into noya and get some shares, Noya will deposit those tokens into yield bearing positions and by generating more tokens, the value of each share will be increased compared to the moment that they’ve deposited
calculated/obtained/gathered by the user?
Explain the management flow to withdraw from the system: groups, fulfillment, conditions to do so, requirements, etc. 
Withtdraw Flow
1. User initiates the withdraw request
2. After all of the positions that have time (look at positionTimestamp in HoldingPI struct) update their time, (or immediately if there is no position with timestamp) the keeper can call the calculateWithdrawShares function. This will calculate the assets of this withdraw and record it in the queue, and update the middle of the queue.
3. After the keeper  calculates a couple of withdrawal records, it can start a withdrawGroup. Withdraw group is being used to retrieve the needed tokens to the AccountingManager so we can send them to the users.
4. The keeper should use the connectors’ functions to burn positions and swap tokens to the “baseToken” (so it can be withdrawn in the next step).
5. Once we have the needed amount (or a part of it) we can use the “retrieveTokensForWithdraw” function to move the assets from different connectors to the accounting manager for withdrawal and updates the “amountAskedForWithdraw” variable to prevent moving more or less base tokens that is needed.
6. Once we have requested all the tokens that we’ve calculated for withdrawal, the keeper will call the “fulfillCurrentWithdrawGroup” to finish the process of retrieving tokens for withdrawal.
7. Then we are ready for withdrawals. We can execute the withdrawal requests that the waiting time after the calculation has been passed by calling the “executeWithdraw” function. 
8. After a specified time (withdrawWaitingTime), the keeper can call the executeWithdraw  to burn the share tokens to the users and send the calculated amount to the user.
How are the funds managed in order to return to the user: what tokens, from what contract, how are they calculated, what happens with the shares, what happens with connectors, etc.
How does the queue work, and how are the IDs managed.
Same as the deposit queue
How do interactions take place with registry
No interaction in the registry for the withdrawal
How does resetMiddle work, what should we expect from it?
This function is for situations where we want to recalculate some of the deposits/withdrawal records. This will reset the “middle” of the queue so the items above the new middle and the last middle, will be calculated again with their related functions.
Fees:
	Noya takes 3 types of fees
1. Withdrawal fee (which happens when someone is withdrawing their tokens)
	This fee is being taken at the time of the execution of the withdrawal.
2. Management fees (x% of the liquidity per year)
We can simply mint x% of the total shares * (time_elapsed_from_last_fee / seconds_in_year) to the feeReceiver periodically (at most every 10 days).
Also to prevent the compounding effect on the fees (taking fees from the previous fees), the fee receiver is a contract that can only burn or withdraw shares(can't transfer) and we reduce the balance of this account from all shares to not count it in the fee calculation
3. Performance fee ( x% of the profit that we make in noya)
Taking this fee happens in a 2 step process. First the strategy manager calls the “recordProfitForFee “ function to calculate the shares of the fees and store the fee amount in “preformanceFeeSharesWaitingForDistribution “ variable. Then after 12 hours, if the profit has not been dropped during this period, the manager can claim the amount. We use the mechanism to prevent the strategy manager from manipulating the prices and trick the contract to get more fees than it’s supposed to get.
All users can check the profit and abort the fee if the profit drops below the amount that is stored in the contract using “checkIfTVLHasDroped “ function.
What is the usage of retrieveTokensForWithdraw
It’s being used in step 5 of the withdrawal procedure.
What is the usage of burnShares
No usage for the users (unless they want to lose their assets) . we use it in the noyaFeeReceiver to burn shares in case of excess fee.
Registry:
Purpose in the system?
In Registry we can add different vaults. For each of these vaults we can add connectors and trusted tokens. Then we’ll define the positions' blueprints and build actual positions and their data to registry as holding positions.
When are vaults created and by who?
When we want to deploy a new vault in the system.  By noya governance (us)
Can vaults be closed and by who?
They can’t be canceled.
When are connectors added, is there any requirement?
The maintainer will add a connector to a vault if its functionality is needed in the vault.
When connectors are added, they have to support the IConnector interface.
What are trusted positions, and under what conditions are they created? What is their role into the protocol
TrustedPostions work as the blueprint for the holding positions. For example we store the pool information of uniswapV3 in TrustedPostions and the actual information of LP tokens in the holding positions.
When is updateHoldingPosition called, and what is its purpose? Who calls this function? 
Holding positions are for storing information of the actual positions. The connectors will use this function to add their positions in TVLHelper.
It’s being created when the vault is added to the registry. At that time, one empty position is being added to the vault so we make sure that there is no active position in index 0 of this array.
Later we can add positions to this array using the updateHoldingPosition function. 
For each holding position of the vault, we calculate the holdingPositionId and use that as the key in the isPositionUsed mapping and use the index of that position in the array as the value. This is the reason that we added a dummy position in the array at the beginning (so we can check this mapping to see if a position exists with this Id (if the value is 0 means that it’s not been added to this mapping or it’s dummy position)). 
For example, in an aave position, in “supply” function, we call calculatePositionId first and then call updateHoldingPosition to add the position to the vault.
Later, when the accountingManager is trying to get the TVL of the vault, it loops through this array and calls the getPositionTVL of the BaseConnector which will call the _getPositionTVL of aave connector. This function will return the value of our deposits into aave and converts it to the base token.

Same as above questions, but for updateHoldingPositionWithTime
For some positions, we can’t calculate the TVL of the moment (for example the positions that are on other chains). So we update them regularly and save the TVL amount in the registry. For these positions we use this function to set the time.
What is a holding position? What is the difference between holding position and trusted position?
What are trusted tokens, what are base tokens? What is each token role within the system? Can they change, by who, under what circumstances?
Each vault has a base token that it handles the book keeping using that token. And also we define some trusted tokens that are added by the maintainer to the vault and later on we can add positions that their underlying tokens are already added as trusted tokens, to the vault.
What are active connectors?
The list of all connectors that we can use in a specific vault
What are trusted addresses?
All of active connectors + the accountingManager
What is vaults[vaultId].trustedPositionsBP[_positionId].isDebt
It’s for calculating the TVL of debtPositions correctly in the TVLHelper library. We reduce the sum of debt positions from credit positions to calculate the total value.
What is a calculator connector?
Calculator connector is the connector that contains the code for calculating the value of a specific position type. 
For each position, we might have different logic and data to calculate the value of that position based on the base token. The CalculatorConnector is the address of the connector, which will be called when the accountingManager wants to calculate the value of the position based on the base token of the vault.

Keepers
What is their role in the system?
Keepers are the ones who are executing strategy transactions. It’s a multisig contract.
Who will take this role? Multisig?
The governance/keepers.sol contract.
How is execution used? What is its purpose, who can call this, under what circumstances?
It’s for executing strategy transactions. It’ll gather all signatures from n of the owners (n = threshold) and executes the transaction,
What is the use of the state variable `nonce`?
It’s used to prevent the contract executor to run the same transaction twice without the consent of other owners.
Timelock
What is the purpose of this contract
It’s to prevent the maintainer of the contracts to simply add a malicious connector (or malicious token/position) and steal the tokens. For each action they have to propose and once the time has passed, they can execute it.
How is this used?
The maintainer (or governance, should use the “schedule” function and once the waiting time, by calling the “execute” function, the transaction will be executed. During this time, everyone can see what’s been scheduled.
Whatchers:
Same questions than Timelock
This smart contract is responsible to make sure the execution of noya is going on correctly. If there is any misbehaving (like price manipulation or any suspicious actions from the keepers) the watchers should undo the action.

It does this by requesting a recalculation of the share value in the accounting manager (using resetMiddle function)

TVLHelper:
Purpose in the system?
It’s a helper to calculate the tvl of all positions in the holdingPositions array of registry for each vault.
How is the TVL of the project calculated (e.g. sum or tokens into each vault - if so, which tokens (e.g. tokens deposited, tokens deposited executed, base tokens, shares…?)
The tvl is being calculated per vault. For each vault we try to calculate the value of each position or token that we hold based on “baseToken” (we use the noya value oracle to get the value of a token based on another). 
Does this fetch data from connectors, or registry, or token balances from users/contracts…?
It fetches the list of holding positions from the registry but it gets the value of each position from the calculatorConnector.
When is this feature used and how, called by what contracts or addresses?
When we are calling the “totalAssets” of accounting manager or in the omnichainManagerNormaChain when it’s trying to get the current TVL of this chain.
What is the usage of latestUpdateTime, when is it called and by who, to do what?
It’s the oldest timestamp of all of our positions that has timing.

Base Connector:
Purpose in the system?
Provide common functionalities of connectors to them.
What is the purpose health factor? When is this used? Why does it have a default value? Should this have any limits when set in the constructor?
It’s used in connectors that we have borrowing. We shouldn’t have a health factor bellow this number. We should have a limit for the range because we can change it in the baseConnector. So the malicious actor can change it and allow a dangerous trade to happen and cause liquidation for noya.
Why can the swap handler and value oracles be set? Is there a need to change them in the future?
Just in case that we need to update the value oracle and swap handler logic for an specific connector.
What is the purpose of sendTokens to trusted address? Who can call this (it is external)? What interactions are happening within this function? When is this called and to do what?
This function is used to send tokens to trusted addresses (vault, accounting manager, swap handler)
    * in case the caller is the accounting manager, the function will check with the watcher contract the number of tokens to withdraw
    * in case the caller is a connector, the function will check if the caller is an active connector
    * in case the caller is the swap handler, the function will check if the caller is a valid route

What is the purpose of updateTokenInRegistry, when is it called and by who?
It’s being called by the manager. It’s there to make sure we are taking into account all of the tokens that a connector is holding. In case that we are not including that token, we’ll call this function to add it to the registry holding positions
Same questions above but for addLiquidity
This function is called to add liquidity to this connector. It can be called by the accountingManager or other connectors.
Same questions for swapHoldings → are all connectors using this? If not, in what cases?
There are cases that we need to swap some tokens for another token. This function is being used in that scenario. Only the manager (keeper contract) can call this function. Yes all the connectors have swap functionality but they are limited to trusted tokens of the vault.
What is the usage of getUnderlyingTokens?
It’s there to get the underlying tokens of each position type.this is to prevent the maintainer to add a position that its underlying tokens are not trusted
What is the use of approve/revoke operations, when is this called and by who?
Approve operations is called when we need to give allowance to an external contract (when we want to deposit into aave contract and we do approveOperation before calling aave contract so it has a needed allowance).

Oracles:
Where are they fetched (i.e. who calls an oracle and under what circumstances)?
In the connectors and accounting Manager, when we want to get the value of a token based on the base token.
In swapHandler when we want to check the slippage of a swap.
Who adds the oracle addresses 
The governance
What is the difference between updateDefaultPriceSource, updateAssetPriceSource?
When we try to find the needed oracle address for a pair, first it’ll check if we have any specific price source for that pair. If not, it’ll try to get the price from the default one of that token. “updateDefaultPriceSource” updates the default price source.
“updateAssetPriceSource” updates the price source for each pair.
What is the purpose of updatePriceRoute?
We can define routes in this contract (we have a price source for tokens A-B, B-C, C-D and we want to get the price of A-D. we can define the route of [B,C] in the smart contract and it loops through the route to get the price of A-D.
When is TWAP or Chainlink used as a source of information
We’ll use chainlink for any pair that we have a valid chainlink (or other compatible oracles like RedStone) and we’ll use uniswap for the ones that we don’t have one.
How are decimals handled from oracles versus the decimals used by the system? 

What base tokens can be used to get the oracles value? Can they change?
For now WETH and usdc
Yes they can be more in the future
Are all asset tokens allowed to be used in the system and/or the oracle? Is there any whitelisting or are they input by the managers?
The whitelisting in oracle happens when we add the route
Also it happens when we use updateTrustedTokens in registry
On what chains are the oracles going to be fetched from? Is there a mix? Is there an oracle for each chain?
There is an oracle for each chain.

Uniswap Oracle:
Is there any limit to the period length? What happens if the value is not obtained for a period that is too long?
There is no limit to the period but it shouldn’t be too long to lose the accuracy of the price. It just needs to be more than 0.


What happens if a price is fetched for a pool that does not exist?
We shoudln’t add such a route in this Oracle
How are complementary prices obtained (i.e. asset A as a function of B versus asset B as a function of asset A)?
The OracleLibrary of uniswap is handling that for us, we’ll identify the tokenIn address and it’ll calculate the value according to this token based on the tokenOut.
Chainlink Oracle
How is chainlinkPriceAgeThreshold decided?
We will set it to a number that is safe for the vaults to operate on. (it’s 5 day now)
The limits are between 1days and 10 days.
How is assetsSources used?
We add the price feed of tokens here.
How are decimals handled?
In chainlink Oracle, there are two special tokens (usd and eth) with hardcoded decimals. for the rest, we’ll get the decimal from their ERC20 contract.
How are complementary prices obtained (i.e. asset A as a function of B versus asset B as a function of asset A)?
In the getValueFromChainlinkFeed function, there is a boolean argument that indicates if we need to calculate the reverse price of the tokens (the feed is A -> B and we need B -> A).
Based on this flag, it’ll calculate the price.
SwapAndBridgeHandler
What is the purpose of this contract? When and how is this used? By who?
It’s used to execute swaps and bridging transactions. The swap function is used by all connectors but the bridging function is only used in omnichain logic right now
What are the state variables `routes` and `isEligibleToUse`?
“Routes” enables us to have multiple implementations of swap and bridge functions. 
“isEligibleToUse” indicates which smart contracts can call the swap and bridge functions. So we need to add all of the connectors here too.
How is the slippage used? Are there any limits? Is this a fixed value or manually input?
We have two ways of checking slippage, first is manual input to the function. And second is automatic using the noyaValueOracle. We need to set the slippage for each pair and then it uses the value oracle to calculate what is the minimum output of the function. Then gives this to the implementation (so the implementation should enforce the minimum output).
When is executeSwap called? By who? To do what?
What interactions are happening under the hood here?
It’s used to execute swap transactions and is called by the connectors. First it calculates the minimum output and then calls the implementation which should bring the tokens into its address and do the swap and send back the tokens to the calling connector.
Same questions than above for executeBridge
It’s used to bridge tokens to another chain and it’s being used by “Omnichain logic”. It checks the bridge information (destination address and whitelisted bridges and …) then initiates the bridge transaction.
Lifi
What is its role in the system?
It’s the implementation of the bridge and swap functionalities.
How is this used as opposed to SwapAndBridgeHandler?
It’ll be set as a route within SwapAndBridgeHandler.
Are there going to be other contracts with similar purpose in the future?
Yes, They can be added as routes in SwapAndBridgeHandler.
What are the state variables `isHandler` and `isBridgeWhitelisted`, `lifi`?
`isHandler`: checks if the calling address is eligible to use the contract
`isBridgeWhitelisted`: We have to whitelist bridges before using them (to avoid using insecure bridges)
 `lifi`: this is the address of Lifi diamond (please look at lifi docs for more info about this)
What is the use of `rescuefunds`?
In case of “lifi” not using some of the tokens that has been approved for the swap, we use this function to take out the stuck tokens.
When, by who, and to do what, are the following functions called? What happens under the hood?
performSwapAction
It’s being called by the SwapAndBridgeHandler when another contract is trying to execute a swap. It receives the tokens and performs the swap transaction using lifi diamond
verifySwapData
We are giving a bytes “data” to lifi to execute the transaction. By using this function we make sure that the information of the data is correct.
performBridgeAction
It’s being called by the SwapAndBridgeHandler when another contract is trying to execute a bridge transaction. It receives the tokens and performs the bridge transaction using lifi diamond
verifyBridgeData

We are giving a bytes “data” to lifi to execute the transaction. By using this function we make sure that the information of the data is correct.
_forward
Calls lifi to execute the transaction
_setAllowance
Gives the needed allowance to lifi contract

Omnichain
What is its purpose in the system? When is this used, by who, to do what?
It’s used to create and handle positions in other chains than the base chain (different than the chain called base (base.org))
It’s added as a connector to a vault and can receive tokens and send those tokens to its counterparts in other chains. It’ll receive the TVL information through layer zero infrastructure and report back that information to the registry.
How are bridge transactions managed?
We have to add the bridge transactions in the contract and wait for 30 mins so the keeper network and watchers have time to check the sending transaction. They can reject the transaction during that time and once it’s been cleared, the keepers use the startBridgeTransaction to send the transaction.
What is the dust level?
It’s used to ignore small levels of liquidity on other chains to eliminate need for updating the TVL information if the amount is below the dust level
How are the different TVL functions, how are they used, by who, to do what?
In the omnichcianManagerNormalChain, we’ll report the TVL back to the base chain and in the omnichainManagerBaseChain, we are adding the TVL as a position in the registry.
What is happening under the hood?
It’s using lifi for executing bridge transactions and then uses layer zero to communicate back to the base chain the TVL information.
LZHelpers
What is their purpose in the system?
They are used for sending TVL information to the base chain.
When are they used, by who, to do what?
They are used by the OmnichainManagers to communicate with each other when we need to send an update about of the TVL
What is happening during the different functions?
We have a sender and a receiver, senders are deployed on other chains than the base chain and are responsible for communicating the TVL to the base chain. They are also responsible for the message fee (the noya keeper network should provide these contracts with enough eth to perform).
Connectors
What is their role in the system
They are responsible for creating and holding various positions for a vault.
Are there similarities between any of them? 
Yes. All of them inherit the baseConnector.sol and also other than that, most of them have “deposit” function and withdraw function. But the implementation is different.
Do they share anything?
How does the interaction with connectors take place? Who can interact with them?
Generally there are two types of interactions in the connectors, first are configurations that the maintainer is responsible for. The second are creating and withdrawing positions which the keeper contract is responsible for.
How do tokens interact with these contracts?
These contracts can hold tokens and for each token that they are holding there will be a record in the registry
How are rewards managed and what happens with holding positions (e.g. what happens with farmed $CAKE from PancakeSwap)
At the end our goal is to maximize the amount of “baseToken” so if we don’t want to use this token we can swap it to the base token and deposit it in another position.
Once the $CAKE is farmed, it means we have some $CAKE token in the contract. The strategy managers will decide about the next steps. They can swap these tokens into any other trusted tokens. Also they can transfer the tokens to another connector using transferPositionToAnotherConnector function.

AAVE Connector
How does poolBaseToken work?
Aave pools have a baseToken that they use it a source of value comparison (between the borrowed and deposited amount). When we call getUserAccountData on an aave pool, the information that it’s sending us is based on this token. We need the address of it to convert it to our baseToken that we use in _getPositionTVL.
Is there a connector for every AAVE pool?
One connector can handle (deposit and borrow) all of the tokens in a market.
Aerodrome Connector
Supply and withdraw directly perform transfers and call mint/burn/skim → how does the flow work in this connector? Seems weird that these functions should be called directly this way, since Aerodrome IPool interface refers to a router that should call them.
PancakeSwap Connector
What is the expected outcome of the function updatePosition
It’s being used in situations where the liquidity amount of our pancakeswap position has been changed and we want the masterchef contract to update the position our position nft.
