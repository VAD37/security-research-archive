// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IVirtualStakingRewards.sol";

contract VirtualStakingRewards is IVirtualStakingRewards, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error Forbidden(address sender);
    error RewardPeriodNotFinished();
    error InsufficientRewards();

    /* ========== STATE VARIABLES ========== */

    address public rewardsDistribution;
    address public operator;//@note VirtualStakignRewards operator is votingEscrowTruf

    address public immutable rewardsToken;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== MODIFIERS ========== */

    modifier onlyRewardsDistribution() {
        if (msg.sender != rewardsDistribution) {
            revert Forbidden(msg.sender);
        }
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) {
            revert Forbidden(msg.sender);
        }
        _;
    }
    //@rewardRate = (reward * 1e18) / 604800   *1e18/ (totalSypply * 1e18)
    modifier updateReward(address account) {//@audit-ok M RewardRate *1e18 make it high enough.H DOS, missing rewards, stuck token. rewardPerTokenStored does not update when time span block.timestamp is too small. On L2 user can spam call update rewards to prevent update rewards globally
        rewardPerTokenStored = rewardPerToken();//@rewardPerTokenStored does not update when time hit periodFinish
        lastUpdateTime = lastTimeRewardApplicable();//@time linear for 7 days from block.timestamp to periodFinish
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    constructor(address _rewardsDistribution, address _rewardsToken) {//@reward token is also TrufToken
        if (_rewardsToken == address(0) || _rewardsDistribution == address(0)) {
            revert ZeroAddress();
        }
        rewardsToken = _rewardsToken;
        rewardsDistribution = _rewardsDistribution;//@rewardsDistribution is also owner
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored + (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }//@audit-ok cache refresh earned rewards every user operation.user can inflate rewards by flashloan earned token then immediately stake and withdraw them

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(address user, uint256 amount) external updateReward(user) onlyOperator {
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (user == address(0)) {
            revert ZeroAddress();//@note why the heck staking involve 3 different contracts with rewards as final destination? TrufVesting->VotingEscrow->VirtualStakingRewards
        }
        _totalSupply += amount;
        _balances[user] += amount;
        emit Staked(user, amount);//@audit you can force someone refresh updateReward  by donate staking to them. Through VotingEscrowTruf
    }

    function withdraw(address user, uint256 amount) public updateReward(user) onlyOperator {
        if (amount == 0) {
            revert ZeroAmount();
        }
        _totalSupply -= amount;
        _balances[user] -= amount;
        emit Withdrawn(user, amount);
    }

    function getReward(address user) public updateReward(user) returns (uint256 reward) {
        reward = rewards[user];
        if (reward != 0) {
            rewards[user] = 0;
            IERC20(rewardsToken).safeTransfer(user, reward);
            emit RewardPaid(user, reward);
        }
    }

    function exit(address user) external {
        if (_balances[user] != 0) {
            withdraw(user, _balances[user]);
        }
        getReward(user);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward) external onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;//@audit-ok Synthetix StakingRewards clone. does remaining rewards the same as updateReward?
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardsToken).balanceOf(address(this));
        if (rewardRate > balance / rewardsDuration) {
            revert InsufficientRewards();
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        if (block.timestamp <= periodFinish) {
            revert RewardPeriodNotFinished();
        }
        if (_rewardsDuration == 0) {
            revert ZeroAmount();
        }

        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsDuration);
    }

    function setRewardsDistribution(address _rewardsDistribution) external onlyOwner {
        if (_rewardsDistribution == address(0)) {
            revert ZeroAddress();
        }
        rewardsDistribution = _rewardsDistribution;

        emit RewardsDistributionUpdated(_rewardsDistribution);
    }

    function setOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) {
            revert ZeroAddress();
        }
        operator = _operator;

        emit OperatorUpdated(_operator);
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event RewardsDistributionUpdated(address indexed rewardsDistribution);
    event OperatorUpdated(address indexed operator);
}
