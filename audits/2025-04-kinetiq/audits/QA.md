# Low

## 1. L - Oracle report rewards token in 8 decimals while it suppose to be 18 decimals

<https://github.com/code-423n4/2025-04-kinetiq/blob/7f29c917c09341672e73be2f7917edf920ea2adb/src/ValidatorManager.sol#L53-L57>
<https://github.com/code-423n4/2025-04-kinetiq/blob/7f29c917c09341672e73be2f7917edf920ea2adb/src/StakingAccountant.sol#L213-L216>

```solidity
    /// @notice Total amount slashed across all validators
    uint256 public totalSlashing; // In 8 decimals

    /// @notice Total rewards across all validators
    uint256 public totalRewards; // In 8 decimals
```

```solidity
        // Calculate total HYPE (in 8 decimals)
        uint256 rewardsAmount = validatorManager.totalRewards();
        uint256 slashingAmount = validatorManager.totalSlashing();//@audit R reward/slashing in e8 decimal, while totalStaked token in e18 decimal
        uint256 totalHYPE = totalStaked + rewardsAmount - totalClaimed - slashingAmount;
```

Code comments seem like a bit out of date and still say rewards in 8 decimals. L1 HYPE token is 8 decimals but on L2 it is 18 decimals.

Reward/slashing amount is decided by Oracle Operator, so it offchain components and no way to verify if it will report 8 decimals or 18 decimals value.
Look at testnet transaction tell little about this.
<https://testnet.purrsec.com/tx/0xff3e7b942a198eb00114f90848297ddc36714c2a2200078dfd4dcf6e53ddf67a>

Not medium issue because it seem like old comments error instead of actual current production code.
Impact is Medium, oracle report wrong rewards -> wrong exchange rate -> user receive less rewards when claiming.

## 2. L - StakingManager should enable whitelist by default during initialization

- Early Staker deposit have can mess up queue execution order. Which is another medium issue.
- Whitelist features seem like benefit for better exchange rate for people join early, and that privilage should be enable by default instead of waiting admin turn it on.

Admin can disable whitelist later on to allow everyone join validator pool staking. So there is no reason not to toggle whitelist during init by choice.
