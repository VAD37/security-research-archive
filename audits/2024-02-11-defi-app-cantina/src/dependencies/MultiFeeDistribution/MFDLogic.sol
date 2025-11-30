// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {console} from "forge-std/console.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IBountyManager} from "../../interfaces/staker/IBountyManager.sol";
import {MFDBase} from "./MFDBase.sol";
import {StakedLock, Balances, MultiFeeDistributionStorage, Reward} from "./MFDDataTypes.sol";
import {IOracleRouter} from "../../interfaces/staker/IOracleRouter.sol";

/// @title MFDLogic
/// @author security@defi.app
library MFDLogic {
    using SafeERC20 for IERC20;

    uint256 public constant AGGREGATION_EPOCH = 6 days;//@note nonstandard epoch. 6 days per month
    uint256 public constant PRECISION = 1e18;
    uint256 public constant PERCENT_DIVISOR = 10000;

    // Custom Errors
    error MFDLogic_addressZero();
    error MGDLogic_insufficientPermission();
    error MFDLogic_invalidAmount();
    error MFDLogic_invalidPeriod();
    error MFDLogic_invalidType();
    error MGDLogic_invalidAction();
    error MGDLogic_noUnlockedTokens();

    /**
     * @dev Library logic to stake `stakeTokens` and receive rewards. Locked tokens cannot
     * be withdrawn for defaultLockDuration and are eligible to receive rewards.
     * @param $ MultiFeeDistributionStorage storage struct.
     * @param _amount to stake.
     * @param _onBehalf address for staking.
     * @param _typeIndex lock type index.
     * @param _isRelock true if this is with relock enabled.
     */
    function stakeLogic(//@ok
        MultiFeeDistributionStorage storage $,
        uint256 _amount,//@allow 0, skip hook register
        address _onBehalf,//any //@audit-ok R. onBehalf can be address(0) and this. user pay for stake and this receive rewards.
        uint256 _typeIndex,//[1,3,6,12] month lock
        bool _isRelock // false,
    ) public {
        if (_amount == 0) return;
        if ($.bountyManager != address(0)) {
            if (_amount < IBountyManager($.bountyManager).minDLPBalance()) revert MFDLogic_invalidAmount();
        }
        if (_typeIndex >= $.lockTypes.length) revert MFDLogic_invalidType();

        updateReward($, _onBehalf);//timepass * oldSpeed

        StakedLock[] memory userLocks = $.userLocks[_onBehalf];//@audit L copy whole storage array to memory gonna quite costly
        uint256 userLocksLength = userLocks.length;

        Balances storage bal = $.userBalances[_onBehalf];
        bal.total += _amount;
        bal.locked += _amount;
        $.lockedSupply += _amount;

        {
            uint256 rewardMultiplier = $.lockTypes[_typeIndex].multiplier;
            bal.lockedWithMultiplier += (_amount * rewardMultiplier);//@audit-ok Low issue M, multiplier use single digit precision in test. is there any precision deduction later?
            $.lockedSupplyWithMultiplier += (_amount * rewardMultiplier);
        }

        uint256 lockIndex;
        StakedLock memory newLock;
        {
            uint256 lockDurationWeeks = $.lockTypes[_typeIndex].duration / AGGREGATION_EPOCH;
            uint256 unlockTime = block.timestamp + (lockDurationWeeks * AGGREGATION_EPOCH);//rounded down duration to 6day/week
            lockIndex = _binarySearch(userLocks, userLocksLength, unlockTime);//@sorted list from low to high. earliest to longest lock
            newLock = StakedLock({
                amount: _amount,
                unlockTime: unlockTime,
                multiplier: $.lockTypes[_typeIndex].multiplier,
                duration: $.lockTypes[_typeIndex].duration
            });
        }

        if (userLocksLength > 0) {//@lockIndex range from 0-> length. so it must reduce by 1 to get actual index
            uint256 indexToAggregate = lockIndex == 0 ? 0 : lockIndex - 1;//@audit-ok not tested but it seem not possible M1 Out of sort list when lockIndex == 1 .this also result index 0 == index 1
            if (
                (indexToAggregate < userLocksLength)
                    && ( // && unlock at same epoch && same multiplier
                        userLocks[indexToAggregate].unlockTime / AGGREGATION_EPOCH == newLock.unlockTime / AGGREGATION_EPOCH
                    ) && (userLocks[indexToAggregate].multiplier == $.lockTypes[_typeIndex].multiplier)//@multiplier check prevent 1 months lock from now add to old 6 months lock with 5 months already passed
            ) {//@do not create new lock in this week. just add to current epoch already staked
                $.userLocks[_onBehalf][indexToAggregate].amount = userLocks[indexToAggregate].amount + _amount;//@audit M1 it is possible to increase old locked stake if admin change LockType multiplier to duplicate value.
            } else {
                _insertLock($, _onBehalf, newLock, lockIndex, userLocksLength);//@ every array from last to index will be moved to next index. and new lock will be inserted at index
                emit MFDBase.LockerAdded(_onBehalf);//@audit-ok Low issue, not affect user M2 multiplier==multiplier check also prevent increase old Locked stake on same week. If there is other multiplier in the middle between end time. Like . 1 month end,3 months end , now 1 month end will result in new lock with same epoch.
            }
        } else {//init first lock
            _insertLock($, _onBehalf, newLock, lockIndex, userLocksLength);//@audit-ok skip M3 no locks limit per address to prevent out of gas issue
            emit MFDBase.LockerAdded(_onBehalf);
        }

        if (!_isRelock) {
            IERC20($.stakeToken).safeTransferFrom(msg.sender, address(this), _amount);
        }

        emit MFDBase.Locked(_onBehalf, _amount, $.userBalances[_onBehalf].locked, $.lockTypes[_typeIndex].duration);
    }

    /**
     * @notice Claim `_user`s staking rewards
     * @param $ MultiFeeDistributionStorage storage struct.
     * @param _user address
     * @param _rewardTokens array of reward tokens
     */
    function claimRewardsLogic(MultiFeeDistributionStorage storage $, address _user, address[] memory _rewardTokens)
        external
    {
        uint256 len = _rewardTokens.length;
        for (uint256 i; i < len;) {
            address token = _rewardTokens[i];
            trackUnseenReward($, token);
            uint256 reward = $.rewards[_user][token] / PRECISION;
            if (reward > 0) {
                $.rewards[_user][token] = 0;
                $.rewardData[token].balance = $.rewardData[token].balance - reward;

                IERC20(token).safeTransfer(_user, reward);
                emit MFDBase.RewardPaid(_user, token, reward);
            }
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Withdraw all expired locks for `_address`.
     * @param $ MultiFeeDistributionStorage storage struct.
     * @param _user address
     * @param _isRelock true if withdraw with relock
     * @param _limit limit for looping operation
     * @return amount for withdraw
     * //
     */
    function handleWithdrawOrRelockLogic(//@ok
        MultiFeeDistributionStorage storage $,
        address _user,
        bool _isRelock,
        uint256 _limit
    ) external returns (uint256 amount) {
        if (_isRelock && msg.sender != _user && msg.sender != $.bountyManager) revert MGDLogic_insufficientPermission();
        updateReward($, _user);

        uint256 amountWithMultiplier;
        Balances storage bal = $.userBalances[_user];
        (amount, amountWithMultiplier) = _cleanWithdrawableLocks($, _user, _limit);//@remove lock from array
        if (amount == 0) revert MGDLogic_noUnlockedTokens();
        bal.locked -= amount;
        bal.lockedWithMultiplier -= amountWithMultiplier;
        bal.total -= amount;
        $.lockedSupply -= amount;
        $.lockedSupplyWithMultiplier -= amountWithMultiplier;

        if (_isRelock) {
            stakeLogic($, amount, _user, $.defaultLockIndex[_user], true);
        } else {
            IERC20($.stakeToken).safeTransfer(_user, amount);
            emit MFDBase.Withdrawn(_user, amount, $.userBalances[_user].locked);
        }
        return amount;
    }//@ok

    /**
     * @notice Update user reward info.
     * @param _account address
     */
    function updateReward(MultiFeeDistributionStorage storage $, address _account) public {
        uint256 balance = $.userBalances[_account].lockedWithMultiplier;
        uint256 len = $.rewardTokens.length;
        for (uint256 i = 0; i < len;) {
            address token = $.rewardTokens[i];
            uint256 rpt = rewardPerToken($, token);//@rpt = totalReward * e18 * timepass/totalTime
                                                //@rpt is an index variable.
            Reward storage r = $.rewardData[token];
            r.rewardPerTokenStored = rpt;//update new totalReward
            r.lastUpdateTime = _lastTimeRewardApplicable($, token);

            if (_account != address(this)) {//@earned must be calculate for each address. to cache last index of rpt.
                $.rewards[_account][token] = calculateRewardEarned($, _account, token, balance, rpt);//this is another index
                $.userRewardPerTokenPaid[_account][token] = rpt;//@cache lastIndex
            }
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Reward amount per token
     * @dev Reward is distributed only for locks.
     * @param _rewardToken for reward
     * @return rptStored current RPT with accumulated rewards
     */
    function rewardPerToken(MultiFeeDistributionStorage storage $, address _rewardToken)
        public
        view
        returns (uint256 rptStored)
    {
        rptStored = $.rewardData[_rewardToken].rewardPerTokenStored;
        if ($.lockedSupplyWithMultiplier > 0) {//@audit-ok .when user receive rewards. balance was too small to make up any different. index did inflated to huge value. but there is no follow-up possible attack .H inflated rewards speed or stored if early deposit is really small. lockedSupplyWithMultiplier must > 1e18 to prevent slippage attack
            uint256 newReward = (_lastTimeRewardApplicable($, _rewardToken) - $.rewardData[_rewardToken].lastUpdateTime)
                * $.rewardData[_rewardToken].rewardPerSecond;//@newReward = timepass * rewardSpeed_e18
            rptStored = rptStored + ((newReward * PRECISION) / $.lockedSupplyWithMultiplier);//@lockedSupply is deposit token * per month locked
        }//@rptStored = rptStored_e18 . carry precision from speed.
    }//@audit-ok it does support e18 .M precision not support token with non 18 decimals. This precision must sync with depositToken.

    /**
     * @notice Calculate rewardEarnings.
     * @param _user address of earning owner
     * @param _rewardToken address
     * @param _balance of the user
     * @param _currentRewardPerToken current RPT
     * @return rewardEarnings amount
     */
    function calculateRewardEarned(
        MultiFeeDistributionStorage storage $,
        address _user,//onbehalf
        address _rewardToken,//rewardToken[i]
        uint256 _balance,// total user locked*Multiplier
        uint256 _currentRewardPerToken//rptStored, latest index of rewardPerToken_e18
    ) public view returns (uint256 rewardEarnings) {
        rewardEarnings = $.rewards[_user][_rewardToken];//lastIndex
        uint256 realRPT = _currentRewardPerToken - $.userRewardPerTokenPaid[_user][_rewardToken];
        rewardEarnings = rewardEarnings + ((_balance * realRPT) / PRECISION);// rewardEarnings = previousIndex + user_totalLocked * rpt_delta_1e18 /e18
    }//@rewardEarning must reduce rewards by

    /**
     * @notice Track unseen rewards of `_token` received by the contract.
     * @param _token address
     */
    function trackUnseenReward(MultiFeeDistributionStorage storage $, address _token) public {// 180dd6aa
        if (_token == address(0)) revert MFDLogic_addressZero();
        Reward storage r = $.rewardData[_token];
        uint256 periodFinish = r.periodFinish;
        if (periodFinish == 0) revert MFDLogic_invalidPeriod(); //@this check rewards already init and added as token
        if (periodFinish < block.timestamp + $.rewardStreamTime - $.rewardsLookback) { //@ now + 7 - 1= now + 6 days. same as epoch
            uint256 unseen = IERC20(_token).balanceOf(address(this)) - r.balance;
            if (unseen > 0) {
                _handleUnseenReward($, _token, unseen);
            }//@note all tracking unseenRewards should be called last. to avoid reset rewards to newer value before given out rewards.
        }//@ reset period if current period < 6 days. same as fixed period time.
    }//@note you can only track new rewards every 6 days. or after new epoch.

    /// Private functions

    /**
     * @notice Add new lockings
     * @dev We keep the array to be sorted by unlock time.
     * @param user address to insert lock for.
     * @param newLock new lock info.
     * @param index of where to store the new lock.
     * @param lockLength length of the lock array.
     */
    function _insertLock(
        MultiFeeDistributionStorage storage $,
        address user,
        StakedLock memory newLock,
        uint256 index,
        uint256 lockLength
    ) private {
        StakedLock[] storage locks = $.userLocks[user];
        locks.push();//@audit HR anyone can increase locks to infinity length and prevent anyone from withdraw their locks 
        for (uint256 j = lockLength; j > index;) {
            locks[j] = locks[j - 1];
            unchecked {
                j--;
            }
        }
        locks[index] = newLock;
    }

    /**
     * @notice Adds new rewards to state, distributes to ops treasury and resets reward period.
     * @dev If prev reward period is not done, then it resets `rewardPerSecond` and restarts period
     * @param _rewardToken address
     * @param _rewardAmt amount
     */
    function _handleUnseenReward(MultiFeeDistributionStorage storage $, address _rewardToken, uint256 _rewardAmt)
        private
    {
        // Distribute to ops treasury if applicable
        address _opsTreasury = $.opsTreasury;
        uint256 _operationExpenseRatio = $.operationExpenseRatio;
        if (_opsTreasury != address(0) && _operationExpenseRatio != 0) {
            uint256 opExAmount = (_rewardAmt * _operationExpenseRatio) / PERCENT_DIVISOR;
            if (opExAmount != 0) {
                IERC20(_rewardToken).safeTransfer(_opsTreasury, opExAmount);
                _rewardAmt -= opExAmount;
            }
        }

        // Update reward per second according to the new reward amount
        Reward storage r = $.rewardData[_rewardToken];
        if (block.timestamp >= r.periodFinish) {//@this case never true
            r.rewardPerSecond = (_rewardAmt * PRECISION) / $.rewardStreamTime;//@this meant all rewards already givenOut. so reset rewardPerSecond
        } else {
            uint256 remaining = r.periodFinish - block.timestamp;
            uint256 leftover = (remaining * r.rewardPerSecond) / PRECISION;
            r.rewardPerSecond = ((_rewardAmt + leftover) * PRECISION) / $.rewardStreamTime;//7 days=6e5
        }//@precision is include inside reward persecond. must be reduced later. should rewardPerSecond_e18

        r.lastUpdateTime = block.timestamp;
        r.periodFinish = block.timestamp + $.rewardStreamTime;//@reset period to 7 days from now. 
        r.balance += _rewardAmt;//@note reward.balance must be removed if given out to user or gauge.

        emit MFDBase.RevenueEarned(_rewardToken, _rewardAmt, _calculateRewardUsdValue($, _rewardToken, _rewardAmt));
    }//@ok this is flywheel rewards

    /**
     * @notice Returns reward applicable timestamp.
     * @param _rewardToken for the reward
     * @return end time of reward period
     */
    function _lastTimeRewardApplicable(MultiFeeDistributionStorage storage $, address _rewardToken)
        internal
        view
        returns (uint256)//@block.timestamp or period end
    {
        uint256 periodFinish = $.rewardData[_rewardToken].periodFinish;
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function _binarySearch(StakedLock[] memory _locks, uint256 _length, uint256 _unlockTime)
        private
        pure
        returns (uint256)
    {
        uint256 low = 0;
        uint256 high = _length;//10
        while (low < high) {
            uint256 mid = (low + high) / 2;//5
            if (_locks[mid].unlockTime < _unlockTime) { //newLock time > middle lock
                low = mid + 1;// 6
            } else {
                high = mid;//5
            }
        }
        return low;
    }

    /**
     * @notice Withdraw all lockings tokens where the unlock time has passed
     * @param _user address
     * @param _limit limit for looping operation
     * @return withdrawable lock amount
     * @return withdrawableWithMultiplier withdraw amount with multiplier
     */
    function _cleanWithdrawableLocks(MultiFeeDistributionStorage storage $, address _user, uint256 _limit)
        private
        returns (uint256 withdrawable, uint256 withdrawableWithMultiplier)
    {
        StakedLock[] storage locks = $.userLocks[_user];
        if (locks.length != 0) {
            uint256 length = locks.length <= _limit ? locks.length : _limit;
            uint256 i;
            while (i < length && locks[i].unlockTime <= block.timestamp) {
                withdrawable += locks[i].amount;
                withdrawableWithMultiplier += (locks[i].amount * locks[i].multiplier);
                i = i + 1;
            }// i end at limit/length, or middle of array
            uint256 locksLength = locks.length;// i = 3, length = 5
            for (uint256 j = i; j < locksLength;) {//@ move leftover lock down to 0 index //@audit RH loop through infinity array. This exploited by another bug allow anyone to push any array to infinity
                locks[j - i] = locks[j];// this move index 3,4 to 0,1
                unchecked {
                    j++;
                }
            }
            for (uint256 j = 0; j < i;) {
                locks.pop();//remove last locks from array
                unchecked {
                    j++;
                }
            }
            if (locks.length == 0) {
                emit MFDBase.LockerRemoved(_user);
            }
        }
    }//@ok

    function _calculateRewardUsdValue(MultiFeeDistributionStorage storage $, address _rewardToken, uint256 _rewardAmt)
        private
        view
        returns (uint256)
    {
        return (_rewardAmt * IOracleRouter($.oracleRouter).getAssetPrice(_rewardToken))
            / IERC20Metadata(_rewardToken).decimals();
    }
}
