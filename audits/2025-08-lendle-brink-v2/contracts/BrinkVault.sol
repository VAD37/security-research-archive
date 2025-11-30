// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {Test, console} from "forge-std/Test.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    IERC20,
    ERC4626,
    ERC20,
    Math,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IBrinkVault } from "./interfaces/IBrinkVault.sol";
import { IBaseStrategy } from "./interfaces/IBaseStrategy.sol";
import { ErrorsLib } from "./libraries/ErrorsLib.sol";

/// @title BrinkVault
/// @notice A vault contract that manages multiple Strategy positions
/// @dev Inherits and implements IBrinkVault
/// @author b11a
contract BrinkVault is IBrinkVault, ERC4626, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Math for uint256;

    //////////////////////////////////////////////////////////////
    //                     STATE VARIABLES                      //
    //////////////////////////////////////////////////////////////

    /// @notice The total weight used for calculating proportions (10000 = 100%)
    uint256 private constant TOTAL_WEIGHT = 10_000;

    /// @notice The maximum allowed slippage (1% = 100)
    uint256 private constant MAX_SLIPPAGE = 100;

    /// @notice The number of Strategies in the vault
    uint256 public numberOfStrategies;

    /// @notice The deposit limit for the vault
    uint256 public depositLimit;

    address public strategist;
    address public vaultManager;

    /// @notice Set of whitelisted Strategies in the whole vault
    EnumerableSet.AddressSet private whitelistedStrategiesSet;

    StrategyConfig[] public strategyConfigs;

    bool public initialized;

    //////////////////////////////////////////////////////////////
    //                       MODIFIERS                          //
    //////////////////////////////////////////////////////////////

    /// @notice Ensures that only the Brink Vaults Strategist can call the function
    modifier onlyVaultStrategist() {
        if (strategist != msg.sender) {
            revert NOT_VAULT_STRATEGIST();
        }
        _;
    }

    /// @notice Ensures that only the Vault Manager can call the function
    modifier onlyVaultManager() {
        if (vaultManager != msg.sender) {
            revert NOT_VAULT_MANAGER();
        }
        _;
    }

    //////////////////////////////////////////////////////////////
    //                       CONSTRUCTOR                        //
    //////////////////////////////////////////////////////////////

    /**
     * @notice Constructor for the BrinkVault contract
     * @param _asset Address of the asset token
     * @param _strategist Address of the strategist
     * @param _vaultManager Address of the vault manager
     * @param _name Name of the BrinkVault shares
     * @param _symbol Symbol of the BrinkVault shares
     * @param _depositLimit Maximum deposit limit
     */
    constructor(
        address _asset,
        address _strategist,
        address _vaultManager,
        string memory _name,
        string memory _symbol,
        uint256 _depositLimit
    ) 
        ERC4626(IERC20(_asset)) ERC20(_name, _symbol)
    {
        if (_strategist == address(0) || _vaultManager == address(0)) {
            revert ErrorsLib.ZERO_ADDRESS();
        }

        strategist = _strategist;
        vaultManager = _vaultManager;
        depositLimit = _depositLimit;
    }

    //////////////////////////////////////////////////////////////
    //                  EXTERNAL FUNCTIONS                      //
    //////////////////////////////////////////////////////////////

    function initialize(address[] calldata _strategies, uint256[] calldata _weights) external onlyVaultManager {
        if (initialized) revert ALREADY_INITIALIZED();

        uint256 _numberOfStrategies = _strategies.length;

        if (_numberOfStrategies == 0) revert ErrorsLib.ZERO_STRATEGIES();

        if (_numberOfStrategies != _weights.length) revert ErrorsLib.ARRAY_LENGTH_MISMATCH();

        uint256 totalWeight;
        address strategy;
        StrategyConfig memory _strategyConfig;

        for (uint256 i; i < _numberOfStrategies; ++i) {
            /// @dev this BrinkVault only supports strategy that have the same asset as the vault
            strategy = _strategies[i];

            if (IBaseStrategy(strategy).asset() != asset()) revert STRATEGY_DOES_NOT_SUPPORT_ASSET();

            if (IBaseStrategy(strategy).brinkVault() != address(this)) revert STRATEGY_DOES_NOT_SUPPORT_VAULT();

            bool isAdded = _addToWhitelist(_strategies[i]);
            if (!isAdded) revert ErrorsLib.DUPLICATE_STRATEGY(_strategies[i]);
            _strategyConfig = StrategyConfig(_strategies[i], _weights[i]);
            strategyConfigs.push(_strategyConfig);

            totalWeight += _weights[i];
        }

        if (totalWeight != TOTAL_WEIGHT) revert INVALID_WEIGHTS();

        numberOfStrategies = strategyConfigs.length;

        initialized = true;

        emit Initialized(_strategies, _weights);
    }

    /// @notice Sets the strategist for the vault
    /// @param strategist_ The new strategist
    function setStrategist(address strategist_) external onlyVaultManager {
        strategist = strategist_;

        emit StrategistSet(strategist_);
    }

    /// @notice Sets the vault manager
    /// @param _vaultManager The new vault manager
    function setVaultManager(address _vaultManager) external onlyVaultManager {
        if (_vaultManager == address(0)) revert ErrorsLib.ZERO_ADDRESS();
        vaultManager = _vaultManager;

        emit VaultManagerSet(_vaultManager);
    }

    function setStrategy(address _strategy, bool _isWhitelisted) external onlyVaultManager {
        bool currentlyWhitelisted = whitelistedStrategiesSet.contains(_strategy);

        // Only process if there's an actual change
        if (currentlyWhitelisted != _isWhitelisted) {
            if (_isWhitelisted) {
                _addToWhitelist(_strategy);
            } else {
                uint256 bal_ = IBaseStrategy(_strategy).balance();
                if (bal_ != 0) revert CANNOT_REMOVE_NOT_EMPTY_STRATEGY();
                if (whitelistedStrategiesSet.length() == 1) revert CANNOT_REMOVE_LAST_STRATEGY();
                _removeFromWhitelist(_strategy);
            }

            emit StrategyWhitelisted(_strategy, _isWhitelisted);
        }
    }

    function setDepositLimit(uint256 _depositLimit) external onlyVaultManager {
        depositLimit = _depositLimit;

        emit DepositLimitSet(_depositLimit);
    }

    function depositFunds() external onlyVaultStrategist {
        uint256 _assets = _getAssetBalance(asset());
        _executeSupplyOrWithdraw(
            numberOfStrategies, _assets, strategyConfigs, true
        );

        emit DepositFunds(_getAssetBalance(address(0)));//@audit M this event report total assets based on current supply. which is not interface tells it what to do
    }

    function withdrawFunds() external onlyVaultStrategist {
        StrategyConfig[] memory _strategyConfigs = strategyConfigs;
        uint256 numberOfStrategies_ = numberOfStrategies;
        address _strategy;
        for (uint256 i; i < numberOfStrategies_;) {
            harvest();

            _strategy = _strategyConfigs[i].strategy;

            uint256 bal = IBaseStrategy(_strategy).balance();
            IBaseStrategy(_strategy).withdraw(bal);//@audit morpho only withdraw minimum but does not report back how much it receive in cash.

            unchecked {
                ++i;
            }
        }

        emit WithdrawFunds(_getAssetBalance(asset()));//@report total USDC withdraw from all strategies
    }

    /// @notice Rebalances the BrinkVault
    /// @notice _rebalanceArgs.strategiesRebalanceFrom must be an ordered array of strategy addresses with no duplicates
    /// @notice the logic is as follows:
    /// select the addresses to rebalance from
    /// send an amount to take from those addresses
    /// the total underlying asset amount is redestributed according to the desired weights
    function rebalance(RebalanceArgs calldata _rebalanceArgs) external onlyVaultStrategist {
        uint256 lenRebalanceFrom = _rebalanceArgs.strategiesRebalanceFrom.length;
        uint256 lenWeightsRebalanceFrom = _rebalanceArgs.weightsRebalanceFrom.length;
        uint256 letRebalanceTo = _rebalanceArgs.strategiesRebalanceTo.length;//@audit L typo

        if (lenWeightsRebalanceFrom == 0) revert EMPTY_WEIGHTS_REBALANCE_FROM();
        if (letRebalanceTo == 0 || lenRebalanceFrom == 0) revert EMPTY_STRATEGY_ARRAYS();
        if (lenRebalanceFrom != lenWeightsRebalanceFrom || letRebalanceTo != _rebalanceArgs.weightsOfRedestribution.length) {
            revert ErrorsLib.ARRAY_LENGTH_MISMATCH();
        }

        {
            /// @dev caching to avoid multiple loads
            uint256 foundCount;
            uint256 nStrategies = numberOfStrategies;//@note rebalance toStrategies also whitelist new strategies new config too.
            for (uint256 i; i < lenRebalanceFrom; ++i) {
                for (uint256 j; j < nStrategies; ++j) {
                    if (_rebalanceArgs.strategiesRebalanceFrom[i] == strategyConfigs[j].strategy) {//@make sure all these strategy is whitelisted.
                        foundCount++;//@if empty all these strategy from. it also removed from Strategies list configs
                        break;
                    }
                }
            }

            if (foundCount != lenRebalanceFrom) {
                revert INVALID_STRATEGY_REBALANCE_FROM();
            }
        }
        for (uint256 i = 1; i < lenRebalanceFrom; ++i) {//@audit-ok this for-if just skip if single strat. there must be always two strategies in a list. This ignore case where config simply just want a single strategy
            if (_rebalanceArgs.strategiesRebalanceFrom[i] <= _rebalanceArgs.strategiesRebalanceFrom[i - 1]) {//@audit-ok I was wrong L check duplicate wrong. it should be "<" not "<="
                revert DUPLICATE_STRATEGY_REBALANCE_FROM();//@check for sorting rebalance
            }
        }

        for (uint256 i; i < letRebalanceTo; ++i) {
            if (i >= 1 && _rebalanceArgs.strategiesRebalanceTo[i] <= _rebalanceArgs.strategiesRebalanceTo[i - 1]) {
                revert DUPLICATE_STRATEGIES_REBALANCE_TO();
            }
            if (!whitelistedStrategiesSet.contains(_rebalanceArgs.strategiesRebalanceTo[i])) {//@all strategies must whitelisted. checking it.
                revert STRATEGY_NOT_WHITELISTED();
            }
        }

        StrategyConfig[] memory _localStrategyConfigs = new StrategyConfig[](lenRebalanceFrom);//@old weights cached.
        for(uint256 i = 0; i < lenRebalanceFrom;) {
            _localStrategyConfigs[i] = StrategyConfig(_rebalanceArgs.strategiesRebalanceFrom[i], _rebalanceArgs.weightsRebalanceFrom[i]);

            unchecked {
                ++i;
            }
        }


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
        );//@audit if any strategies refuse withdraw 0 amount. it will revert. If receive any cash at all, slippage is ignored

        StrategyConfig[] memory filteredConfigs_ =
            _filterNonZeroWeights(_rebalanceArgs.strategiesRebalanceTo, _rebalanceArgs.weightsOfRedestribution);//@audit rebalance to list can contains zero amount, aka just remove these strategies from configs

        /// @dev step 3: prepare deposit arguments
        uint256 shares_ = previewDeposit(receivedAmount_);//@suppose this withdraw everything. we already receive everything we need
        DepositArgs memory depositArgs_ = DepositArgs({
            recipient: address(this),
            assets: receivedAmount_,
            shares: shares_,
            numberOfStrategies: _rebalanceArgs.strategiesRebalanceTo.length,
            strategyConfigs: filteredConfigs_
        });

        /// @dev step 4: do deposit
        _executeSupplyOrWithdraw(
            depositArgs_.numberOfStrategies, 
            depositArgs_.assets, 
            depositArgs_.strategyConfigs,
            true
        );//@ok

        /// @dev step 5: update BV data
        /// @notice no issue about reentrancy as the external contracts are trusted
        /// @notice updateBV emits rebalance event
        _updateBVData(filteredConfigs_);
    }

    /// @notice Forwards dust to the vaultManager
    function forwardDustToVaultManager() external onlyVaultManager {
        address token = asset();
        uint256 dust = _getAssetBalance(token);

        if (dust != 0) {
            IERC20(token).safeTransfer(vaultManager, dust);
            emit DustForwardedToPaymaster(dust);
        }
    }//@audit dust transfer all USDC that is not used in investment to vaultManager. Shady as heck. This ignore rewards token in another form though

    //////////////////////////////////////////////////////////////
    //                 EXTERNAL VIEW/PURE FUNCTIONS             //
    //////////////////////////////////////////////////////////////

    /// @notice Returns whether a strategy is whitelisted
    /// @param _strategies Array of strategy addresses
    /// @return _isWhitelisted Array of booleans indicating whether each strategy is whitelisted
    function getIsWhitelisted(address[] memory _strategies) external view returns (bool[] memory _isWhitelisted) {
        uint256 length = _strategies.length;
        _isWhitelisted = new bool[](length);

        for (uint256 i; i < length; ++i) {
            _isWhitelisted[i] = whitelistedStrategiesSet.contains(_strategies[i]);
        }

        return _isWhitelisted;
    }

    /// @notice Returns the array of whitelisted strategy addresses
    /// @return Array of whitelisted strategy addresses
    function getWhitelist() external view returns (address[] memory) {
        return whitelistedStrategiesSet.values();
    }

    /// @notice Returns the strategy addresses and weights of the BrinkVault
    /// @return _strategyConfigs Struct containing the strategy addresses and weights
    function getBrinkVaultData() external view returns (StrategyConfig[] memory) {
        return strategyConfigs;
    }

    /// @notice Returns whether the deposit limit has been reached
    /// @param _assets The amount of asset to check
    /// @return _result Whether the deposit limit has been reached
    function checkDepositLimit(uint256 _assets) public view returns (bool _result) { 
        uint256 balance = _getAssetBalance(address(0));
        _result = (_assets + balance < depositLimit);
    }

    //////////////////////////////////////////////////////////////
    //            VAULTS PUBLIC OVERRIDES                       //
    //////////////////////////////////////////////////////////////

    function totalAssets() public view override returns (uint256 _totalAssets) {
        uint256 numberOfStrategies_ = numberOfStrategies;
        for (uint256 i; i < numberOfStrategies_;) {
            _totalAssets += IBaseStrategy(strategyConfigs[i].strategy).balance();//@audit strategy never include zero-balance strategy.

            unchecked {
                ++i;
            }
        }
        _totalAssets += _getAssetBalance(asset());//@if vaultManager withdraw all. there still cash inside
    }

    /// @notice Deposit assets to the strategies
    /// @param _assets The amount of assets to supply
    /// @param _recipient The recipient of the shares
    function deposit(uint256 _assets, address _recipient) public override nonReentrant returns (uint256 _shares) {
        if (_assets == 0) revert ErrorsLib.ZERO_AMOUNT();
        if (!checkDepositLimit(_assets)) revert DEPOSIT_LIMIT_EXCEEDED();

        harvest();

        _shares = previewDeposit(_assets);//@share = asset * totalSupply / (totalAsset + 1)
        DepositArgs memory depositArgs_ = DepositArgs(
            _recipient,
            _assets,//take from user
            _shares,//share mint
            numberOfStrategies,//cash in to strategy and split money too
            strategyConfigs
        );
        _deposit(depositArgs_);
    }

    function mint(uint256 _shares, address _recipient) public override nonReentrant returns (uint256 _assets) {
        harvest();

        _assets = previewMint(_shares);//@asset = share * (totalAsset + 1) / totalSupply
        if (_assets == 0) revert ErrorsLib.ZERO_AMOUNT();
        if (!checkDepositLimit(_assets)) revert DEPOSIT_LIMIT_EXCEEDED();

        DepositArgs memory depositArgs_ = DepositArgs(
            _recipient,
            _assets,
            _shares,
            numberOfStrategies,
            strategyConfigs
        );
        _deposit(depositArgs_);
    }

    /// @notice Withdraw funds from the strategies
    /// @param _assets The amount of funds to withdraw
    function withdraw(uint256 _assets, address _recipient, address _owner) public override nonReentrant returns (uint256 _shares) {
        if (_assets == 0) revert ErrorsLib.ZERO_AMOUNT();

        harvest();

        _shares = previewWithdraw(_assets);// share = asset * totalSupply / (totalAsset + 1)
        WithdrawArgs memory withdrawArgs_ = WithdrawArgs(
            _recipient,
            _owner,
            _assets,
            _shares,
            numberOfStrategies,
            strategyConfigs
        );
        _withdraw(withdrawArgs_);
    }

    function redeem(uint256 _shares, address _recipient, address _owner) public override nonReentrant returns (uint256 _assets) {
        _assets = previewRedeem(_shares);//@asset = share * (totalAsset + 1) / totalSupply
        if (_assets == 0) revert ErrorsLib.ZERO_AMOUNT();

        harvest();

        WithdrawArgs memory withdrawArgs_ = WithdrawArgs(
            _recipient,
            _owner,
            _assets,
            _shares,
            numberOfStrategies,
            strategyConfigs
        );
        _withdraw(withdrawArgs_);
    }

    function harvest() public {
        uint256 numberOfStrategies_ = numberOfStrategies;
        for (uint256 i; i < numberOfStrategies_;) {
            IBaseStrategy(strategyConfigs[i].strategy).harvest();

            unchecked {
                ++i;
            }
        }
    } 

    //////////////////////////////////////////////////////////////
    //                     INTERNAL FUNCTIONS                   //
    //////////////////////////////////////////////////////////////

    function _deposit(DepositArgs memory _args) internal {
        address caller_ = _msgSender();
        IERC20 asset = IERC20(asset());

        asset.safeTransferFrom(caller_, address(this), _args.assets);

        _executeSupplyOrWithdraw(
            _args.numberOfStrategies, _args.assets, _args.strategyConfigs, true);

        _mint(_args.recipient, _args.shares);

        emit Deposited(caller_, _args.recipient, _args.assets, _args.shares);
    }

    function _withdraw(WithdrawArgs memory _args) internal {
        address caller_ = _msgSender();
        IERC20 asset = IERC20(asset());

        uint256 receivedAmount_ = _executeSupplyOrWithdraw(
            _args.numberOfStrategies, _args.assets, _args.strategyConfigs, false);

        if (caller_ != _args.owner) {
            _spendAllowance(_args.owner, caller_, _args.shares);
        }
        _burn(_args.owner, _args.shares);//@allow zero

        asset.safeTransfer(_args.recipient, receivedAmount_);

        emit Withdrawal(caller_, _args.recipient, receivedAmount_, _args.shares);
    }

    function _executeSupplyOrWithdraw(
        uint256 _numberOfStrategies,
        uint256 _assets,
        StrategyConfig[] memory _strategyConfigs,
        bool _isSupply
    ) internal returns (uint256 receivedAmount_) {
        address token = asset();
        IERC20 asset = IERC20(token);
        uint256[] memory amounts_ = new uint256[](_numberOfStrategies);
        address _strategy;

        if (_isSupply) {
            for (uint256 i; i < _numberOfStrategies;) {//@rebalance, use new config
                _strategy = _strategyConfigs[i].strategy;
                amounts_[i] = _assets.mulDiv(_strategyConfigs[i].weight, TOTAL_WEIGHT, Math.Rounding.Floor);

                asset.safeIncreaseAllowance(_strategy, amounts_[i]);
                console.log("_deposit %s amount: %e", i, amounts_[i]);
                IBaseStrategy(_strategy).supply(amounts_[i]);

                if (asset.allowance(address(this), _strategy) > 0) asset.forceApprove(_strategy, 0);

                unchecked {
                    ++i;
                }
            }
        } else {
            uint256 balBefore_ = _getAssetBalance(token);
            uint256 _assets_;

            for (uint256 i; i < _numberOfStrategies;) {
                _strategy = _strategyConfigs[i].strategy;
                _assets_ = _assets;
                if (_assets == 0) {//@withdraw all. @audit BaseStrategies balance() must allow withdraw_all()
                    _assets_ = IBaseStrategy(_strategy).balance();
                }
                amounts_[i] = _assets_.mulDiv(_strategyConfigs[i].weight, TOTAL_WEIGHT, Math.Rounding.Floor);//@audit withdraw all here. It should not scale with weight by config
                console.log("_withdraw %s amount: %e", i, amounts_[i]);
                IBaseStrategy(_strategy).withdraw(amounts_[i]);//@audit all strategy must allow withdraw empty amount

                unchecked {
                    ++i;
                }
            }

            uint256 balAfter_ = _getAssetBalance(token);
            receivedAmount_ = balAfter_ - balBefore_;
            _checkSlippage(_assets, receivedAmount_);//@slippage accept 1% less from morpho due to not enough liquidity. morpho still have leftover USDC slippage from user. those cash is split among share owner.
        }//@audit slippage is ignored if we get more token than we get
    }

    /// @notice Gets the current balance of the asset token held by this contract
    /// @return balance The current balance of the asset token
    function _getAssetBalance(address _token) internal view returns (uint256 balance) {
        balance = (_token == address(0))
            ? _convertToAssets(totalSupply(), Math.Rounding.Floor)
            : IERC20(_token).balanceOf(address(this));
    }

    function _checkStrategyZeroBalance(address _strategy) internal view returns (bool) {
        return IBaseStrategy(_strategy).balance() == 0;
    }

    function _checkSlippage(uint256 _expectedAmount, uint256 _actualAmount) internal pure {
        uint256 slippage = _expectedAmount > _actualAmount
            ? ((_expectedAmount - _actualAmount) * TOTAL_WEIGHT) / _expectedAmount
            : 0;

        if (slippage > MAX_SLIPPAGE) {
            console.log("expected: %e", _expectedAmount);
            console.log("actual: %e", _actualAmount);
            revert SLIPPAGE_TOO_HIGH();
        }
    }

    /// @notice Filters out zero weights and returns corresponding strategy addresses and weights
    /// @param _strategies Array of strategy addresses
    /// @param _weights Array of weights
    /// @return _filteredStruct Array of strategy addresses and weights
    function _filterNonZeroWeights(
        address[] calldata _strategies,
        uint256[] calldata _weights
    )
        internal
        pure
        returns (StrategyConfig[] memory _filteredStruct)
    {
        uint256 count;
        uint256 length = _weights.length;
        for (uint256 i; i < length; ++i) {
            if (_weights[i] != 0) {
                count++;
            }
        }

        // Initialize the array with the correct size
        _filteredStruct = new StrategyConfig[](count);
        
        uint256 j;
        uint256 totalWeight;
        for (uint256 i; i < length; ++i) {
            if (_weights[i] != 0) {
                _filteredStruct[j] = StrategyConfig(_strategies[i], _weights[i]);
                totalWeight += _weights[i];
                j++;
            }
        }
        if (totalWeight != TOTAL_WEIGHT) revert INVALID_WEIGHTS();
    }

    /// @notice Updates the BrinkVault data after rebalancing
    /// @param _finalStrategies Array of final strategies to rebalance to (with target weights)
    function _updateBVData(StrategyConfig[] memory _finalStrategies) internal {
        // Cache current strategies and asset address
        StrategyConfig[] memory _currentStrategyConfigs = strategyConfigs;
        address assetCache = address(asset());
        uint256 numFinalStrategies = _finalStrategies.length;
        uint256 numCurrentStrategies = _currentStrategyConfigs.length;
        
        if (numFinalStrategies == 0) revert ErrorsLib.ZERO_STRATEGIES();
        
        // Count strategies that need to be added (current strategies not in final list with non-zero balance)
        uint256 additionalStrategies = 0;
        for (uint256 i; i < numCurrentStrategies;) {
            bool found = false;
            for (uint256 j; j < numFinalStrategies;) {
                if (_currentStrategyConfigs[i].strategy == _finalStrategies[j].strategy) {
                    found = true;
                    break;
                }
                unchecked {
                    ++j;
                }
            }//@found old strategy that not in newer list. check if have non zero balance? new balance is received from deposit above
            if (!found && !_checkStrategyZeroBalance(_currentStrategyConfigs[i].strategy)) {
                additionalStrategies++;
            }
            unchecked {
                ++i;
            }
        }
        
        // Create final array with exact size needed
        uint256 totalStrategies = numFinalStrategies + additionalStrategies;
        StrategyConfig[] memory finalStrategies = new StrategyConfig[](totalStrategies);
        
        // Copy strategies from _finalStrategies first
        for (uint256 i; i < numFinalStrategies;) {
            finalStrategies[i] = _finalStrategies[i];
            unchecked {
                ++i;
            }
        }
        
        // Add current strategies that weren't in final list but have non-zero balance
        uint256 currentIndex = numFinalStrategies;
        for (uint256 i; i < numCurrentStrategies;) {
            bool found = false;
            for (uint256 j; j < numFinalStrategies;) {
                if (_currentStrategyConfigs[i].strategy == _finalStrategies[j].strategy) {
                    found = true;
                    break;
                }
                unchecked {
                    ++j;
                }
            }
            if (!found && !_checkStrategyZeroBalance(_currentStrategyConfigs[i].strategy)) {
                finalStrategies[currentIndex] = StrategyConfig(_currentStrategyConfigs[i].strategy, 0);
                unchecked {
                    ++currentIndex;
                }
            }
            unchecked {
                ++i;
            }
        }
        
        // Validate strategies and get their actual balances
        uint256 totalValue = 0;
        for (uint256 i; i < totalStrategies;) {
            address strategy = finalStrategies[i].strategy;
            
            // Validate strategy supports the vault's asset
            if (IBaseStrategy(strategy).asset() != assetCache) {
                revert STRATEGY_DOES_NOT_SUPPORT_ASSET();
            }
            
            // Validate strategy supports this vault
            if (IBaseStrategy(strategy).brinkVault() != address(this)) {
                revert STRATEGY_DOES_NOT_SUPPORT_VAULT();
            }
            
            // Get the actual balance and update the strategy config
            uint256 actualBalance = IBaseStrategy(strategy).balance();
            finalStrategies[i].weight = actualBalance;
            totalValue += actualBalance;
            
            unchecked {
                ++i;
            }
        }
        
        // Calculate new weights as percentages, ensuring they sum to TOTAL_WEIGHT
        if (totalValue > 0) {
            uint256 totalAssignedWeight = 0;
            for (uint256 i; i < totalStrategies - 1;) {
                finalStrategies[i].weight = finalStrategies[i].weight.mulDiv(
                    TOTAL_WEIGHT, 
                    totalValue, 
                    Math.Rounding.Floor
                );
                totalAssignedWeight += finalStrategies[i].weight;
                unchecked {
                    ++i;
                }
            }
            // Assign remaining weight to the last strategy to ensure total equals TOTAL_WEIGHT
            finalStrategies[totalStrategies - 1].weight = TOTAL_WEIGHT - totalAssignedWeight;
        } else {
            // If total value is 0, distribute weights equally
            uint256 equalWeight = TOTAL_WEIGHT / totalStrategies;
            uint256 remainder = TOTAL_WEIGHT % totalStrategies;
            
            for (uint256 i; i < totalStrategies;) {
                finalStrategies[i].weight = equalWeight + (i < remainder ? 1 : 0);
                unchecked {
                    ++i;
                }
            }
        }
        
        // Update strategyConfigs
        delete strategyConfigs;
        for (uint256 i = 0; i < totalStrategies;) {
            strategyConfigs.push(finalStrategies[i]);
            unchecked {
                ++i;
            }
        }
        
        numberOfStrategies = totalStrategies;
        
        emit RebalanceComplete(_extractStrategies(finalStrategies), _extractWeights(finalStrategies));
    }

    /// @notice Extracts strategy addresses from StrategyConfig array
    /// @param _strategyConfigs Array of StrategyConfig
    /// @return strategies Array of strategy addresses
    function _extractStrategies(StrategyConfig[] memory _strategyConfigs) internal pure returns (address[] memory strategies) {
        uint256 length = _strategyConfigs.length;
        strategies = new address[](length);
        for (uint256 i; i < length;) {
            strategies[i] = _strategyConfigs[i].strategy;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Extracts weights from StrategyConfig array
    /// @param _strategyConfigs Array of StrategyConfig
    /// @return weights Array of weights
    function _extractWeights(StrategyConfig[] memory _strategyConfigs) internal pure returns (uint256[] memory weights) {
        uint256 length = _strategyConfigs.length;
        weights = new uint256[](length);
        for (uint256 i; i < length;) {
            weights[i] = _strategyConfigs[i].weight;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Adds a strategy address to the whitelist array
    /// @param _strategy The strategy address to add
    function _addToWhitelist(address _strategy) internal returns (bool) {
        return whitelistedStrategiesSet.add(_strategy);
    }

    /// @notice Removes a strategy address from the whitelist array
    /// @param _strategy The strategy address to remove
    function _removeFromWhitelist(address _strategy) internal {
        whitelistedStrategiesSet.remove(_strategy);
    }
}