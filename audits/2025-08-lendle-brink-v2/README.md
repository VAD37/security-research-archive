## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

For 1000 USDC 
Vault Strategy | Old config weights | New config Weights | Final Result
Vault 1 | 100USDC(10%) | 300USDC(30%)  | 130 USDC
Vault 2 | 900USDC(90%) | 700USDC(70%) | 870 USDC




When rebalance() try to withdraw everything. It try to call _executeSupplyOrWithdraw() with zero asset amount
```solidity
        /// @dev step 1: prepare withdraw arguments
        WithdrawArgs memory withdrawArgs_ = WithdrawArgs({
            recipient: address(this),
            owner: address(this),
            assets: 0,
            shares: 0,
            numberOfStrategies: _rebalanceArgs.strategiesRebalanceFrom.length,
            strategyConfigs: _localStrategyConfigs
        });

        /// @dev step 2: do withdraw
        uint256 receivedAmount_ = _executeSupplyOrWithdraw(
            withdrawArgs_.numberOfStrategies, 
            withdrawArgs_.assets,
            withdrawArgs_.strategyConfigs, //@withdraw scale with old config weights.
            false
        );
```

In `_executeSupplyOrWithdraw()`, withdraw 0 amount is equivenient with withdraw all balance from strategy.
But then withdraw all balance is replaced with scaled version by weigts of strategy.
```solididty
            for (uint256 i; i < _numberOfStrategies;) {
                _strategy = _strategyConfigs[i].strategy;
                _assets_ = _assets;
                if (_assets == 0) {//@withdraw all
                    _assets_ = IBaseStrategy(_strategy).balance();
                }
                amounts_[i] = _assets_.mulDiv(_strategyConfigs[i].weight, TOTAL_WEIGHT, Math.Rounding.Floor);//@audit withdraw all here. It should not scale with weight by config

                IBaseStrategy(_strategy).withdraw(amounts_[i]);//@audit all strategy must allow withdraw empty amount

                unchecked {
                    ++i;
                }
            }
```

I think the correct versions of the code is like this:
```solididty
            for (uint256 i; i < _numberOfStrategies;) {
                _strategy = _strategyConfigs[i].strategy;
                _assets_ = _assets;
                
								//@ move scaling for normal user withdraw before
								amounts_[i] = _assets_.mulDiv(_strategyConfigs[i].weight, TOTAL_WEIGHT, Math.Rounding.Floor);
								
								//@ then withdraw all if it is called by rebalance
								if (_assets == 0) {
                    _assets_ = IBaseStrategy(_strategy).balance();
                }
								
                IBaseStrategy(_strategy).withdraw(amounts_[i]);//@audit all strategy must allow withdraw empty amount

                unchecked {
                    ++i;
                }
            }
```

