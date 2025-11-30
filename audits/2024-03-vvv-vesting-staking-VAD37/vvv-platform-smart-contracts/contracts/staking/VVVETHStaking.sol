///SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { VVVAuthorizationRegistryChecker } from "contracts/auth/VVVAuthorizationRegistryChecker.sol";

contract VVVETHStaking is VVVAuthorizationRegistryChecker {
    using SafeERC20 for IERC20;

    uint256 public constant DENOMINATOR = 10_000;

    ///@notice the interface to the $VVV token
    IERC20 public vvvToken;

    ///@notice flag for whether new stakes are allowed
    bool public newStakesPermitted;

    ///@notice The id of the last stake
    uint256 public stakeId;

    ///@notice The options for staking duration
    enum StakingDuration {
        ThreeMonths,
        SixMonths,
        OneYear
    }

    /**
        @notice The data stored for each stake
        @param stakedEthAmount The amount of ETH staked
        @param stakeStartTimestamp The timestamp when the stake was made
        @param stakeIsWithdrawn Whether the stake has been withdrawn
        @param stakeDuration The duration of the stake
     */
    struct StakeData {
        uint224 stakedEthAmount;
        uint32 stakeStartTimestamp;
        bool stakeIsWithdrawn;
        StakingDuration stakeDuration;
    }

    ///@notice maps the duration enum entry to the number of seconds in that duration
    mapping(StakingDuration => uint256) public durationToSeconds;//keccak(uint) . 2

    ///@notice maps the duration enum entry to the $VVV accrual multiplier for that duration
    mapping(StakingDuration => uint256) public durationToMultiplier;//keccak(uint) . 3

    ///@notice maps user to their stakes by stakeId
    mapping(address => mapping(uint256 => StakeData)) public userStakes;//first mapping = keccak(address . 4) and StakeData = keccak(uint256 . keccak(address . 4))

    ///@notice maps user to their stakeIds
    mapping(address => uint256[]) private _userStakeIds;// keccak(address . 5) and uint256[] = keccak(address . 5) + i

    ///@notice maps user to the amount of $VVV claimed
    mapping(address => uint256) public userVvvClaimed;// keccak(address . 6)

    ///@notice emitted when ETH is received
    event EtherReceived();

    ///@notice emitted when a user stakes
    event Stake(
        address indexed staker,
        uint256 indexed stakeId,
        uint224 stakedEthAmount,
        uint32 stakeStartTimestamp,
        StakingDuration stakeDuration
    );

    ///@notice emitted when a user withdraws
    event Withdraw(
        address indexed staker,
        uint256 indexed stakeId,
        uint224 stakedEthAmount,
        uint32 stakeStartTimestamp,
        StakingDuration stakeDuration
    );

    ///@notice emitted when a user claims $VVV
    event VvvClaim(address indexed staker, uint256 vvvAmount);

    ///@notice thrown when a user tries to claim 0 $VVV
    error CantClaimZeroVvv();

    ///@notice thrown when a user tries to stake 0 eth
    error CantStakeZeroEth();

    ///@notice thrown when a user tries to withdraw before the stake duration has elapsed
    error CantWithdrawBeforeStakeDuration();

    ///@notice thrown when a user tries to claim more $VVV than they have accrued
    error InsufficientClaimableVvv();

    ///@notice thrown when a user tries to withdraw a stake that hasn't been initialized
    error InvalidStakeId();

    ///@notice thrown when a user attempts to staken when new stakes are not permitted
    error NewStakesNotPermitted();

    ///@notice thrown when a user tries to withdraw a stake that has already been withdrawn
    error StakeIsWithdrawn();

    ///@notice thrown when a user tries to withdraw and the transfer fails
    error WithdrawFailed();

    ///@notice initializes the second values corresponding to each duration enum entry
    constructor(
        address _authorizationRegistryAddress
    ) VVVAuthorizationRegistryChecker(_authorizationRegistryAddress) {
        durationToSeconds[StakingDuration.ThreeMonths] = 90 days;
        durationToSeconds[StakingDuration.SixMonths] = 180 days;
        durationToSeconds[StakingDuration.OneYear] = 360 days;

        durationToMultiplier[StakingDuration.ThreeMonths] = 10_000;
        durationToMultiplier[StakingDuration.SixMonths] = 15_000;//@audit H duration multiplier is wrong. stake 180 days get less token than double 90 days stake
        durationToMultiplier[StakingDuration.OneYear] = 30_000;
    }

    ///@notice Fallback function to receive ETH
    receive() external payable {
        emit EtherReceived();
    }

    ///@notice enforces that newStakesPermitted is true before allowing a stake
    modifier whenStakingIsPermitted() {
        if (!newStakesPermitted) revert NewStakesNotPermitted();
        _;
    }

    /**
        @notice Stakes ETH for a given duration
        @param _stakeDuration The duration of the stake
        @return The id of the stake
     */
    function stakeEth(
        StakingDuration _stakeDuration
    ) external payable whenStakingIsPermitted returns (uint256) {
        _stakeEth(_stakeDuration, msg.value);
        return stakeId;
    }

    /**
        @notice Restakes ETH for a given duration, marks previous stake as withdrawn but does not transfer the ETH
        @param _stakeId The id of the stake to restake
        @param _stakeDuration The duration of the new stake
     */
    function restakeEth(
        uint256 _stakeId,
        StakingDuration _stakeDuration
    ) external whenStakingIsPermitted returns (uint256) {//@audit-ok 2 mapping keccak this memory slot query index allow storage jumping.
        StakeData storage stake = userStakes[msg.sender][_stakeId];//@audit-ok restake non exist stakeID
        _withdrawChecks(stake);//@revert when no staked amount exist
        stake.stakeIsWithdrawn = true;
        _stakeEth(_stakeDuration, stake.stakedEthAmount);
        return stakeId;
    }

    /**
        @notice Withdraws a stake
        @param _stakeId The id of the stake
     */
    function withdrawStake(uint256 _stakeId) external {
        StakeData storage stake = userStakes[msg.sender][_stakeId];
        _withdrawChecks(stake);

        stake.stakeIsWithdrawn = true;
        (bool withdrawSuccess, ) = payable(msg.sender).call{ value: stake.stakedEthAmount }("");
        if (!withdrawSuccess) revert WithdrawFailed();

        emit Withdraw(
            msg.sender,
            _stakeId,
            stake.stakedEthAmount,
            stake.stakeStartTimestamp,
            stake.stakeDuration
        );
    }

    /**
        @notice Claims $VVV for a user
        @param _vvvAmount The amount of $VVV to claim
     */
    function claimVvv(uint256 _vvvAmount) external {
        if (_vvvAmount == 0) revert CantClaimZeroVvv();

        uint256 claimableVvv = calculateClaimableVvvAmount();//@ total accrued - claimed
        if (_vvvAmount > claimableVvv) revert InsufficientClaimableVvv();

        userVvvClaimed[msg.sender] += _vvvAmount;

        vvvToken.safeTransfer(msg.sender, _vvvAmount);

        emit VvvClaim(msg.sender, _vvvAmount);
    }

    /**
        @notice Returns accrued $VVV for a user based on their staking activity
        @dev Does not account for any claimed tokens
        @return $VVV accrued
     */
    function calculateAccruedVvvAmount() public view returns (uint256) {
        uint256[] memory stakeIds = _userStakeIds[msg.sender];
        if (stakeIds.length == 0) return 0;

        uint256 totalVvvAccrued;
        for (uint256 i = 0; i < stakeIds.length; ++i) {
            StakeData memory stake = userStakes[msg.sender][stakeIds[i]];//@audit accrued include already claimed unstaking
            unchecked {
                totalVvvAccrued += calculateAccruedVvvAmount(stake);
            }
        }

        return totalVvvAccrued;
    }

    /**
        @notice Returns the total amount of $VVV accrued by a single stake
        @dev considers the "nominalAccruedEth" and multiplies by the exchange rate and duration multiplier to obtain the total $VVV accrued
        @param _stake A StakeData struct representing the stake for which the accrued $VVV is to be calculated
        @return $VVV accrued
     */
    function calculateAccruedVvvAmount(StakeData memory _stake) public view returns (uint256) {
        uint256 stakeDuration = durationToSeconds[_stake.stakeDuration];//@ 3 months = 7776000s, 6 months, 1 year
        uint256 secondsSinceStakingStarted = block.timestamp - _stake.stakeStartTimestamp;//@uint32 block.timestamp
        uint256 secondsStaked;
        uint256 nominalAccruedEth;//@ value range from 0 to stakedEthAmount
        uint256 accruedVvv;

        unchecked {
            secondsStaked = secondsSinceStakingStarted >= stakeDuration
                ? stakeDuration
                : secondsSinceStakingStarted;//clamp to max stake duration

            nominalAccruedEth = (secondsStaked * _stake.stakedEthAmount) / stakeDuration;
            
            accruedVvv =
                (nominalAccruedEth * ethToVvvExchangeRate() * durationToMultiplier[_stake.stakeDuration]) /
                DENOMINATOR;//@  eth * 1 * (10000,15000,30000) / 10000
        }//@accrued = stakedETH * timePassed/stakedTime * 100%->300%

        return accruedVvv;
    }

    /**
        @notice Returns the remaining claimable amount of $VVV
        @dev where claimable = accrued - claimed
        @return $VVV claimable
     */
    function calculateClaimableVvvAmount() public view returns (uint256) {
        return calculateAccruedVvvAmount() - userVvvClaimed[msg.sender];
    }

    ///@notice Returns the exchange rate of ETH to $VVV for staking reward accrual
    function ethToVvvExchangeRate() public pure returns (uint256) {
        return 1;
    }

    ///@notice Returns the array of stake IDs for a user externally
    function userStakeIds(address _user) external view returns (uint256[] memory) {
        return _userStakeIds[_user];
    }

    ///@notice sets the duration multipliers for a duration enum entry
    function setDurationMultipliers(
        StakingDuration[] memory _duration,
        uint256[] memory _multipliers
    ) external onlyAuthorized {
        for (uint256 i = 0; i < _duration.length; ++i) {//@audit L missing length check
            durationToMultiplier[_duration[i]] = _multipliers[i];
        }//@audit what happen when set new multiplier affect user already claim token?
    }

    ///@notice sets newStakesPermitted
    function setNewStakesPermitted(bool _newStakesPermitted) external onlyAuthorized {
        newStakesPermitted = _newStakesPermitted;
    }

    ///@notice Sets the address of the $VVV token
    function setVvvToken(address _vvvTokenAddress) external onlyAuthorized {
        vvvToken = IERC20(_vvvTokenAddress);
    }

    ///@notice allows admin to withdraw ETH
    function withdrawEth(uint256 _amount) external onlyAuthorized {
        (bool success, ) = payable(msg.sender).call{ value: _amount }("");
        if (!success) revert WithdrawFailed();
    }

    ///@notice Private function to stake ETH, used by both stakeEth and restakeEth
    function _stakeEth(StakingDuration _stakeDuration, uint256 _stakedEthAmount) private {
        if (_stakedEthAmount == 0) revert CantStakeZeroEth();//@stake msg.value
        ++stakeId;

        userStakes[msg.sender][stakeId] = StakeData({
            stakedEthAmount: uint224(_stakedEthAmount),
            stakeStartTimestamp: uint32(block.timestamp),
            stakeIsWithdrawn: false,
            stakeDuration: _stakeDuration//@stake duration can be anything.
        });//@audit-ok duration limited missing stake duration limit

        _userStakeIds[msg.sender].push(stakeId);//@note tracking user stakes id using array

        emit Stake(
            msg.sender,
            stakeId,
            uint224(_stakedEthAmount),
            uint32(block.timestamp),
            _stakeDuration
        );
    }

    ///@notice checks permissions for withdrawing a stake based on eth amount, stake start time, and whether the stake has been withdrawn
    function _withdrawChecks(StakeData memory _stake) private view {
        if (_stake.stakedEthAmount == 0) revert InvalidStakeId();
        if (_stake.stakeIsWithdrawn) revert StakeIsWithdrawn();
        if (block.timestamp < _stake.stakeStartTimestamp + durationToSeconds[_stake.stakeDuration]) {
            revert CantWithdrawBeforeStakeDuration();//@audit L uint32 + uint256 . stake duration is limited low so this never overflow
        }
    }
}
