// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RewardsSource} from "../interfaces/RewardsSource.sol";
import {IVirtualStakingRewards} from "../interfaces/IVirtualStakingRewards.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";

/**
 * @title VotingEscrowTRUF smart contract (modified from Origin Staking for Truflation)
 * @author Ryuhei Matsuda
 * @notice Provides staking, vote power history, vote delegation, and rewards
 * distribution.
 *
 * The balance received for staking (and thus the voting power and rewards
 * distribution) goes up exponentially by the end of the staked period.
 */

contract VotingEscrowTruf is ERC20Votes, IVotingEscrow {//@note voting escrow cannot transfer but can delegate. approve still work but does nothing for now
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error Forbidden(address sender);
    error InvalidAmount();
    error InvalidAccount();
    error TransferDisabled();
    error MaxPointsExceeded();
    error NoAccess();
    error LockupAlreadyUnstaked();
    error LockupNotEnded();
    error NotIncrease();
    error NotMigrate();
    error TooShort();
    error TooLong();

    // 1. Core Storage
    /// @dev minimum staking duration in seconds
    uint256 public immutable minStakeDuration;

    // 2. Staking and Lockup Storage
    uint256 public constant YEAR_BASE = 18e17;//@ whats up with these year base

    /// @dev Maximum duration
    uint256 public constant MAX_DURATION = 365 days * 3; // 3 years

    /// @dev lockup list per users
    mapping(address => Lockup[]) public lockups;

    /// @dev TRUF token address
    IERC20 public immutable trufToken; // Must not allow reentrancy

    /// @dev Virtual staking rewards contract address
    IVirtualStakingRewards public immutable stakingRewards;

    /// @dev TRUF Vesting contract address
    address public immutable trufVesting;

    modifier onlyVesting() {
        if (msg.sender != trufVesting) {
            revert Forbidden(msg.sender);
        }
        _;
    }

    // 1. Core Functions

    constructor(address _trufToken, address _trufVesting, uint256 _minStakeDuration, address _stakingRewards)
        ERC20("Voting Escrowed TRUF", "veTRUF")
        ERC20Permit("veTRUF")
    {
        trufToken = IERC20(_trufToken);
        trufVesting = _trufVesting;//@trufVesting set votingTruf later after this contract is created.
        minStakeDuration = _minStakeDuration;//@note 1 hour minimum stake duration
        stakingRewards = IVirtualStakingRewards(_stakingRewards);
    }

    function _transfer(address, address, uint256) internal override {
        revert TransferDisabled();
    }

    // 2. Staking and Lockup Functions

    /**
     * @notice Stake TRUF to an address that may not be the same as the
     * sender of the funds. This can be used to give staked funds to someone
     * else.
     *
     * @param amount TRUF to lockup in the stake
     * @param duration in seconds for the stake
     * @param to address to receive ownership of the stake
     */
    function stake(uint256 amount, uint256 duration, address to) external {
        _stake(amount, duration, to, false);//@audit M stake to someone else does not return lockId
    }

    /**
     * @notice Stake TRUF from vesting
     * @param amount TRUF to lockup in the stake
     * @param duration in seconds for the stake
     * @param to address to receive ownership of the stake
     * @return lockupId Lockup id
     */
    function stakeVesting(uint256 amount, uint256 duration, address to)
        external
        onlyVesting
        returns (uint256 lockupId)
    {
        if (to == trufVesting) {
            revert InvalidAccount();
        }
        lockupId = _stake(amount, duration, to, true);
    }

    /**
     * @notice Stake TRUF
     *
     * @param amount TRUF to lockup in the stake
     * @param duration in seconds for the stake
     * @return lockupId Lockup id
     */
    function stake(uint256 amount, uint256 duration) external returns (uint256 lockupId) {
        lockupId = _stake(amount, duration, msg.sender, false);//@note stake for vote token 3 branch of stake.
    }

    /**
     * @dev Internal method used for public staking
     * @param amount TRUF to lockup in the stake
     * @param duration in seconds for the stake
     * @param to address to receive ownership of the stake
     * @param isVesting flag to stake with vested tokens or not
     * @return lockupId Lockup id
     */
    function _stake(uint256 amount, uint256 duration, address to, bool isVesting) internal returns (uint256 lockupId) {
        if (to == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();//@note minimum amount stake can be 1 wei TRUF
        }
        if (amount > type(uint128).max) {
            revert InvalidAmount();
        }

        // duration checked inside previewPoints. @points = amount * duration(3600:) / 94608000;
        (uint256 points, uint256 end) = previewPoints(amount, duration);//@points can be zero due truncate due to amount too small.
        if (points + totalSupply() > type(uint192).max) {
            revert MaxPointsExceeded();//@ points always smaller amount of token transfered in.
        }//@audit L no revert on zero points.

        lockups[to].push(//@audit-ok 4 max lockups .using array to store lockup. This might cause out of gas if there are too many lockup.
            Lockup({
                amount: uint128(amount), // max checked in require above
                duration: uint128(duration),
                end: uint128(end),//block.timestamp + duration
                points: points,//amount * duration(3600:) / 94608000
                isVesting: isVesting//vesting called from TrufVesting contract
            })
        );
        //@trufVesting already approve new amount to this contract
        trufToken.safeTransferFrom(msg.sender, address(this), amount); // Important that it's sender
        //@audit-ok admin set votingToken allowed for each private address. whose money is vesting here? User can vest their own token for rewards. and there is also vesting contract onbehalf of user.
        stakingRewards.stake(to, points);//@audit-ok It spread ok .does rewards to virtual staking spread evenly? points is linear based on duration
        _mint(to, points);

        if (delegates(to) == address(0)) {
            // Delegate voting power to the receiver, if unregistered
            _delegate(to, to);
        }

        lockupId = lockups[to].length - 1;
        emit Stake(to, isVesting, lockupId, amount, end, points);
    }

    /**
     * @notice Collect staked TRUF for a lockup.
     * @param lockupId the id of the lockup to unstake
     * @return amount TRUF amount returned
     */
    function unstake(uint256 lockupId) external returns (uint256 amount) {
        amount = _unstake(msg.sender, lockupId, false, false);
    }

    /**
     * @notice Collect staked TRUF for a vesting lockup.
     * @param user User address
     * @param lockupId the id of the lockup to unstake
     * @param force True to unstake before maturity (Used to cancel vesting)
     * @return amount TRUF amount returned
     */
    function unstakeVesting(address user, uint256 lockupId, bool force) external onlyVesting returns (uint256 amount) {
        amount = _unstake(user, lockupId, true, force);
    }

    /**
     * @notice Extend lock duration
     *
     * @param lockupId the id of the old lockup to extend
     * @param duration number of seconds from now to stake for
     */
    function extendLock(uint256 lockupId, uint256 duration) external {
        _extendLock(msg.sender, lockupId, duration, false);
    }

    /**
     * @notice Extend lock duration for vesting
     *
     * @param duration number of seconds from now to stake for
     */
    function extendVestingLock(address user, uint256 lockupId, uint256 duration) external onlyVesting {
        _extendLock(user, lockupId, duration, true);
    }

    /**
     * @notice Migrate lock to another user
     * @param oldUser Old user address
     * @param newUser New user address
     * @param lockupId the id of the old user's lockup to migrate
     * @return newLockupId the id of new user's migrated lockup
     */
    function migrateVestingLock(address oldUser, address newUser, uint256 lockupId)
        external
        onlyVesting
        returns (uint256 newLockupId)
    {
        if (oldUser == newUser) {
            revert NotMigrate();
        }
        if (newUser == address(0)) {
            revert ZeroAddress();
        }
        Lockup memory oldLockup = lockups[oldUser][lockupId];
        if (!oldLockup.isVesting) {//@revert if not vesting lock. This mean not called through TrufVesting to lock escrow.
            revert NoAccess();
        }

        uint256 points = oldLockup.points;
        stakingRewards.withdraw(oldUser, points);//@audit-ok unstaked should be reverted due to user not exist .M escrow migration does not check if lockup already ended or unstaked.
        _burn(oldUser, points);

        newLockupId = lockups[newUser].length;
        lockups[newUser].push(oldLockup);
        _mint(newUser, points);//@audit-ok M migration also forget claim or move rewards to new user as well. If user lost their private key, they lost their rewards.
        stakingRewards.stake(newUser, points);

        delete lockups[oldUser][lockupId];

        emit Migrated(oldUser, newUser, lockupId, newLockupId);
    }

    /**
     * @notice Claim TRUF staking rewards
     */
    function claimReward() external {
        stakingRewards.getReward(msg.sender);
    }

    /**
     * @notice Preview the number of points that would be returned for the
     * given amount and duration.
     *
     * @param amount TRUF to be staked
     * @param duration number of seconds to stake for
     * @return points staking points that would be returned
     * @return end staking period end date
     */
    function previewPoints(uint256 amount, uint256 duration) public view returns (uint256 points, uint256 end) {
        if (duration < minStakeDuration) {
            revert TooShort();
        }
        if (duration > MAX_DURATION) {
            revert TooLong();
        }
        //@points = amount * duration(3600:) / 94608000;
        points = amount * duration / MAX_DURATION;
        end = block.timestamp + duration;
    }

    /**
     * @notice Interal function to unstake
     * @param user User address
     * @param lockupId the id of the lockup to unstake
     * @param isVesting flag to stake with vested tokens or not
     * @param force unstake before end period (used to force unstake for vesting lock)
     */
    function _unstake(address user, uint256 lockupId, bool isVesting, bool force) internal returns (uint256 amount) {
        Lockup memory lockup = lockups[user][lockupId];//@unstake 3 branch of logic.
        if (lockup.isVesting != isVesting) {//@unstake by vesting contract have 2 branch of logic include force
            revert NoAccess();
        }
        amount = lockup.amount;
        uint256 end = lockup.end;
        uint256 points = lockup.points;
        if (end == 0) {
            revert LockupAlreadyUnstaked();
        }
        if (!force && block.timestamp < end) {
            revert LockupNotEnded();
        }
        delete lockups[user][lockupId]; // Keeps empty in array, so indexes are stable

        stakingRewards.withdraw(user, points);
        _burn(user, points);
        trufToken.safeTransfer(msg.sender, amount); // Sender is msg.sender

        emit Unstake(user, isVesting, lockupId, amount, end, points);

        if (block.timestamp < end) {
            emit Cancelled(user, lockupId, amount, points);
        }
    }

    /**
     * @notice Extend lock duration
     *
     * The stake end time is computed from the current time + duration, just
     * like it is for new stakes. So a new stake for seven days duration and
     * an old stake extended with a seven days duration would have the same
     * end.
     *
     * If an extend is made before the start of staking, the start time for
     * the new stake is shifted forwards to the start of staking, which also
     * shifts forward the end date.
     *
     * @param user user address
     * @param lockupId the id of the old lockup to extend
     * @param duration number of seconds from now to stake for
     * @param isVesting true if called from vesting
     */
    function _extendLock(address user, uint256 lockupId, uint256 duration, bool isVesting) internal {
        // duration checked inside previewPoints
        Lockup memory lockup = lockups[user][lockupId];//@@extendlock 2 branch of logic. 
        if (lockup.isVesting != isVesting) {//@1. isVesting == false. lockup.isvesting can be true or false depend manually stake or through vesting
            revert NoAccess();//@1.user vest anyLockId with isVesting is false. So user can only manually extend lock with isVesting true. or vest from TrufVesting
        }//@2.extend through TrufVesting. isVesting == lockup.isvesting == true 
        //@ you can only extend lockup with vesting through TrufVesting contract and manually extend lockup with normal stake through veTruf contract.
        uint256 amount = lockup.amount;
        uint256 oldEnd = lockup.end;//@audit-ok M extendLock does not check if lock already ended. allow reuse old lock for points then withdraw
        uint256 oldPoints = lockup.points;
        uint256 newDuration = lockup.duration + duration;

        (uint256 newPoints,) = previewPoints(amount, newDuration);
        //@end = block.timestamp + duration;
        if (newPoints <= oldPoints) {
            revert NotIncrease();
        }
        //@audit-ok M missing require check (points + totalSupply() < type(uint192).max) 
        uint256 newEnd = oldEnd + duration;//@audit-ok extendlock newEnd is higher than duration input. or end duration can be higher than max 4 years

        uint256 mintAmount = newPoints - oldPoints;

        lockup.end = uint128(newEnd);
        lockup.duration = uint128(newDuration);
        lockup.points = newPoints;

        lockups[user][lockupId] = lockup;

        stakingRewards.stake(user, mintAmount);
        _mint(user, mintAmount);

        emit Unstake(user, isVesting, lockupId, amount, oldEnd, oldPoints);
        emit Stake(user, isVesting, lockupId, amount, newEnd, newPoints);
    }
}
