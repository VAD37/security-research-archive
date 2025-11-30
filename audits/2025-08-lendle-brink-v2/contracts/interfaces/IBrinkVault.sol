// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IBrinkVault {
    //////////////////////////////////////////////////////////////
    //                  STRUCTS                                   //
    //////////////////////////////////////////////////////////////

    /// @notice Struct to hold rebalance arguments
    /// @notice strategiesRebalanceFrom must be an ordered array of strategy addresses with no duplicates
    /// @param strategiesRebalanceFrom Array of strategy addresses to rebalance from
    /// @param weightsRebalanceFrom Array of weights to rebalance from each strategy
    /// @param strategiesRebalanceTo Array of strategy addresses to rebalance to
    /// @param weightsOfRedestribution Array of weights for redistribution
    /// @param slippage Slippage tolerance for the rebalance
    struct RebalanceArgs {
        address[] strategiesRebalanceFrom;
        uint256[] weightsRebalanceFrom;
        address[] strategiesRebalanceTo;
        uint256[] weightsOfRedestribution;
    }

    /// @notice Structure of strategies which are active right now and their weights
    struct StrategyConfig {
        address strategy;
        uint256 weight;
    }

    struct DepositArgs {
        address recipient;
        uint256 assets;
        uint256 shares;
        uint256 numberOfStrategies;
        StrategyConfig[] strategyConfigs;
    }

    struct WithdrawArgs {
        address recipient;
        address owner;
        uint256 assets;
        uint256 shares;
        uint256 numberOfStrategies;
        StrategyConfig[] strategyConfigs;
    }



    //////////////////////////////////////////////////////////////
    //                  ErrorsLib                                   //
    //////////////////////////////////////////////////////////////

    error STRATEGY_DOES_NOT_EXIST();
    error STRATEGY_ALREADY_EXISTS();
    error STRATEGY_DOES_NOT_SUPPORT_ASSET();
    error STRATEGY_DOES_NOT_SUPPORT_VAULT();
    error CANNOT_REMOVE_NOT_EMPTY_STRATEGY();
    error CANNOT_REMOVE_LAST_STRATEGY();
    error ALREADY_INITIALIZED();
    error NOT_VAULT_STRATEGIST();
    error NOT_VAULT_MANAGER();
    error EMPTY_WEIGHTS_REBALANCE_FROM();
    error EMPTY_STRATEGY_ARRAYS();
    error INVALID_STRATEGY_REBALANCE_FROM();
    error DUPLICATE_STRATEGY_REBALANCE_FROM();
    error DUPLICATE_STRATEGIES_REBALANCE_TO();
    error STRATEGY_NOT_WHITELISTED();
    error INVALID_WEIGHTS();
    error DEPOSIT_LIMIT_EXCEEDED();
    error SLIPPAGE_TOO_HIGH();

    //////////////////////////////////////////////////////////////
    //                  EVENTS                                   //
    //////////////////////////////////////////////////////////////

    /// @notice Emitted when the BrinkVault is rebalanced
    /// @param strategies Array of final strategy addresses of the BrinkVault
    /// @param finalWeights Array of final weights of the BrinkVault
    event RebalanceComplete(address[] strategies, uint256[] finalWeights);

    /// @notice Emitted when the deposit limit is set
    /// @param depositLimit The new deposit limit
    event DepositLimitSet(uint256 depositLimit);

    /// @notice Emitted when dust is forwarded to the paymaster
    /// @param dust The amount of dust forwarded
    event DustForwardedToPaymaster(uint256 dust);

    /// @notice Emitted when the strategist is set
    /// @param strategist The new strategist
    event StrategistSet(address strategist);

    event Initialized(address[] strategies, uint256[] weights);

    /// @notice Emitted when a strategy is whitelisted
    /// @param strategy The strategy address that was whitelisted
    /// @param isWhitelisted Whether the strategy was whitelisted
    event StrategyWhitelisted(address strategy, bool isWhitelisted);

    /// @notice Emitted when the vault manager is set
    /// @param vaultManager The new vault manager
    event VaultManagerSet(address vaultManager);

    event Deposited(address caller, address receiver, uint256 assetAmount, uint256 shares);

    event Withdrawal(address caller, address receiver, uint256 assetAmount, uint256 shares);

    /// @notice Emitted when funds are deposited into strategies by strategist
    /// @param assets The amount of funds deposited
    event DepositFunds(uint256 assets);

    /// @notice Emitted when funds are withdrawn from strategies by strategist
    /// @param assets The amount of funds withdrawn
    event WithdrawFunds(uint256 assets);
}
