// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {INudgeCampaign} from "./interfaces/INudgeCampaign.sol";
import "./interfaces/INudgeCampaignFactory.sol";

/// @title NudgeCampaign
/// @notice A contract for managing Nudge campaigns with token rewards
contract NudgeCampaign is INudgeCampaign, AccessControl {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // Role granted to the entity which is running the campaign and managing the rewards
    bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");
    uint256 private constant BPS_DENOMINATOR = 10_000;
    // Denominator in parts per quadrillion
    uint256 private constant PPQ_DENOMINATOR = 1e15;
    // Special address representing the native token (ETH)
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Factory reference
    INudgeCampaignFactory public immutable factory;

    // Campaign Configuration
    uint32 public immutable holdingPeriodInSeconds;
    address public immutable targetToken;
    address public immutable rewardToken;
    uint256 public immutable rewardPPQ;
    uint256 public immutable startTimestamp;
    address public immutable alternativeWithdrawalAddress;
    // Fee parameter in basis points (1000 = 10%)
    uint16 public feeBps;//10%
    bool public isCampaignActive;
    // Unique identifier for this campaign
    uint256 public immutable campaignId;

    // Scaling factors for 18 decimal normalization
    uint256 public immutable targetScalingFactor;
    uint256 public immutable rewardScalingFactor;

    // Campaign State
    uint256 public pID;
    uint256 public pendingRewards;
    uint256 public totalReallocatedAmount;
    uint256 public accumulatedFees;
    uint256 public distributedRewards;
    // Track whether campaign was manually deactivated
    bool private _manuallyDeactivated;

    // Participations
    mapping(uint256 pID => Participation) public participations;

    /// @notice Creates a new campaign with specified parameters
    /// @param holdingPeriodInSeconds_ Duration users must hold tokens
    /// @param targetToken_ Address of token users need to hold
    /// @param rewardToken_ Address of token used for rewards
    /// @param rewardPPQ_ Amount of reward tokens earned for participating in the campaign, in parts per quadrillion
    /// @param campaignAdmin Address granted CAMPAIGN_ADMIN_ROLE
    /// @param startTimestamp_ When the campaign becomes active (0 for immediate)
    /// @param feeBps_ Nudge's fee percentage in basis points
    /// @param alternativeWithdrawalAddress_ Optional alternative address for withdrawing unallocated rewards (zero
    /// address to re-use `campaignAdmin`)
    /// @param campaignId_ Unique identifier for this campaign
    constructor(
        uint32 holdingPeriodInSeconds_,//7 days any //@audit M no validation for maximum time. holding period can be infinity
        address targetToken_,//any
        address rewardToken_,//any
        uint256 rewardPPQ_,// 5e13 = 5%
        address campaignAdmin,// any
        uint256 startTimestamp_,//any or 0
        uint16 feeBps_,//1000 = 10% default. max 100%
        address alternativeWithdrawalAddress_,//@any
        uint256 campaignId_//@any
    ) {
        if (rewardToken_ == address(0) || campaignAdmin == address(0)) {
            revert InvalidCampaignSettings();
        }

        if (startTimestamp_ != 0 && startTimestamp_ <= block.timestamp) {
            revert InvalidCampaignSettings();
        }

        factory = INudgeCampaignFactory(msg.sender);

        targetToken = targetToken_;
        rewardToken = rewardToken_;
        campaignId = campaignId_;

        // Compute scaling factors based on token decimals
        uint256 targetDecimals = targetToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(targetToken_).decimals();
        uint256 rewardDecimals = rewardToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(rewardToken_).decimals();

        // Calculate scaling factors to normalize to 18 decimals
        targetScalingFactor = 10 ** (18 - targetDecimals);//@audit L not support token more than 18 decimals
        rewardScalingFactor = 10 ** (18 - rewardDecimals);//18 decimals, 10^ 0 = scale = 1

        _grantRole(CAMPAIGN_ADMIN_ROLE, campaignAdmin);

        startTimestamp = startTimestamp_ == 0 ? block.timestamp : startTimestamp_;
        // Campaign is active if start time is now or in the past
        isCampaignActive = startTimestamp <= block.timestamp;

        // Initialize as not manually deactivated
        _manuallyDeactivated = false;
        rewardPPQ = rewardPPQ_; //@audit-ok still be able to withdraw M no validation for rewardPPQ more than 100%. reward really high to uint might leads to overflow contracts and prevent withdrawal
        holdingPeriodInSeconds = holdingPeriodInSeconds_;
        feeBps = feeBps_;
        alternativeWithdrawalAddress = alternativeWithdrawalAddress_;
    }

    /// @notice Ensures the campaign is not paused
    modifier whenNotPaused() {
        if (factory.isCampaignPaused(address(this))) revert CampaignPaused();
        _;
    }

    /// @notice Restricts access to factory contract or Nudge admins
    modifier onlyFactoryOrNudgeAdmin() {
        if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender) && msg.sender != address(factory)) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Restricts access to Nudge operators
    modifier onlyNudgeOperator() {
        if (!factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Calculates the total reward amount (including platform fees) based on target token amount
    /// @param toAmount Amount of target tokens to calculate rewards for
    /// @return Total reward amount including platform fees, scaled to reward token decimals
    function getRewardAmountIncludingFees(uint256 toAmount) public view returns (uint256) {
        // If both tokens have 18 decimals, no scaling needed
        if (targetScalingFactor == 1 && rewardScalingFactor == 1) {
            return toAmount.mulDiv(rewardPPQ, PPQ_DENOMINATOR);//toAmount * 5e13 / 1e15
        }

        // Scale amount to 18 decimals for reward calculation // USDC_e6 -> random doge token_e18
        uint256 scaledAmount = toAmount * targetScalingFactor;// scaledAmount = toAmount * (1e18 -> 1e0)

        // Calculate reward in 18 decimals //@compensate precision is good enough. except when target token is 1e18, and send in small wei
        uint256 rewardAmountIn18Decimals = scaledAmount.mulDiv(rewardPPQ, PPQ_DENOMINATOR);// to * 1e12 * 5e12 / 1e15 (USDC)
                                                                                            // to * 1 * 5e12 / 1e15  (USDT)
        // Scale back to reward token decimals
        return rewardAmountIn18Decimals / rewardScalingFactor; // to_e6 * 1e12 * 5e12 / 1e15 / 1 (USDC_e6 - USDT_e18 reward)
    }// to_e6 * 1e12 * 5e12 / 1e15 / 1e12 (USDC_e6 - USDC_e6 reward)
    // to_e18 * 1 * 5e12 / 1e15 / 1e12 (Token1_e18 - Token2_e6 reward) //@audit L rewards token loss signficant amount of precision if its decimals smaller than 18.While target token is 18 decimals. assume e18 really is always small token value
    /// @notice Handles token reallocation for campaign participation
    /// @param campaignId_ ID of the campaign
    /// @param userAddress Address of the participating user
    /// @param toToken Address of the token being acquired
    /// @param toAmount Expected amount of tokens to be acquired
    /// @param data Additional data for the reallocation
    /// @dev Only callable by SWAP_CALLER_ROLE, handles both ERC20 and native tokens
    function handleReallocation(
        uint256 campaignId_,
        address userAddress,
        address toToken,
        uint256 toAmount,
        bytes memory data
    ) external payable whenNotPaused {
        // Check if campaign is active or can be activated
        _validateAndActivateCampaignIfReady();

        if (!factory.hasRole(factory.SWAP_CALLER_ROLE(), msg.sender)) { //@called by Li.fi’s contracts Executor
            revert UnauthorizedSwapCaller();//@Executor is simply glorified multicall()
        }

        if (toToken != targetToken) {
            revert InvalidToTokenReceived(toToken);
        }

        if (campaignId_ != campaignId) {
            revert InvalidCampaignId();
        }

        uint256 amountReceived;
        if (toToken == NATIVE_TOKEN) {
            amountReceived = msg.value;
        } else {
            if (msg.value > 0) {
                revert InvalidToTokenReceived(NATIVE_TOKEN);
            }
            IERC20 tokenReceived = IERC20(toToken);
            uint256 balanceOfSender = tokenReceived.balanceOf(msg.sender);
            uint256 balanceBefore = getBalanceOfSelf(toToken);//@audit-ok L reentracy token allow duplicate reallocation with ERC777 token.

            SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);//@audit-ok Executor does not work. Someone can really block this contracts by making sure Executor balance increase by a little bit.

            amountReceived = getBalanceOfSelf(toToken) - balanceBefore;
        }

        if (amountReceived < toAmount) {
            revert InsufficientAmountReceived();
        }//@audit-ok H02 no minimum deposit. This will overwhelm backend code with small deposit on L2 network.

        _transfer(toToken, userAddress, amountReceived);//@audit-ok refund backend Escrow M why transfer token back to user? where is the escrow
        //@reentrancy callback. no significant change
        totalReallocatedAmount += amountReceived;//@audit-ok H toToken can be malicious contract used by anyone to inflate price swapping. User might pay more than they gain to get rewards. Turn Nudge platform into honey pot scam
//@audit-ok M totalReallocatedAmount can grow to infinity if let it be. Any user can reuse reallocation and self lost to participation in campaign. as long as rewards exist
        uint256 rewardAmountIncludingFees = getRewardAmountIncludingFees(amountReceived);//fixed

        uint256 rewardsAvailable = claimableRewardAmount();//this.balanceOf(rewardToken) - pendingRewards - accumulatedFees
        if (rewardAmountIncludingFees > rewardsAvailable) {
            revert NotEnoughRewardsAvailable();
        }

        (uint256 userRewards, uint256 fees) = calculateUserRewardsAndFees(rewardAmountIncludingFees);
        pendingRewards += userRewards;//@audit-ok reentrancy attack does not work well. does not bypass rewards check right after M campaign Admin can withdraw pendingRewards by self reentrancy deposit reallocation themself and frontrun withdraw against other users.
        accumulatedFees += fees;//@audit-ok H01 anyone can abuse campaign system to drain all rewards to Fee. No users will ever receive rewards.

        pID++;
        // Store the participation details
        participations[pID] = Participation({
            status: ParticipationStatus.PARTICIPATING,
            userAddress: userAddress,
            toAmount: amountReceived,
            rewardAmount: userRewards,
            startTimestamp: block.timestamp,
            startBlockNumber: block.number
        });

        emit NewParticipation(campaignId_, userAddress, pID, amountReceived, userRewards, fees, data);
    }

    /// @notice Checks if campaign is active or can be activated based on current timestamp
    function _validateAndActivateCampaignIfReady() internal {
        if (!isCampaignActive) {//@false
            // Only auto-activate if campaign has not been manually deactivated
            // and if the start time has been reached
            if (!_manuallyDeactivated && block.timestamp >= startTimestamp) {//@audit-ok manually deactivate also set campaignActive to false. M manually Deactivate does not stop campaign.
                // Automatically activate the campaign if start time reached
                isCampaignActive = true;
            } else if (block.timestamp < startTimestamp) {
                // If start time not reached, explicitly revert
                revert StartDateNotReached();
            } else {
                // If campaign was manually deactivated, revert with InactiveCampaign
                revert InactiveCampaign();
            }
        }//@true, no check for manually deactivated nor campaigned ended. Manually also turn off activeCampaign.
    }

    /// @notice Claims rewards for multiple participations
    /// @param pIDs Array of participation IDs to claim rewards for
    /// @dev Verifies holding period, caller and participation status, and handles reward distribution
    function claimRewards(uint256[] calldata pIDs) external whenNotPaused {
        if (pIDs.length == 0) {
            revert EmptyParticipationsArray();
        }

        uint256 availableBalance = getBalanceOfSelf(rewardToken);

        for (uint256 i = 0; i < pIDs.length; i++) {
            Participation storage participation = participations[pIDs[i]];

            // Check if participation exists and is valid
            if (participation.status != ParticipationStatus.PARTICIPATING) {
                revert InvalidParticipationStatus(pIDs[i]);
            }

            // Verify that caller is the participation address
            if (participation.userAddress != msg.sender) { //@audit-ok H03 steal all rewards token by input UNISWAP pool as user address. This acocunt might have lots of balance and never failed.
                revert UnauthorizedCaller(pIDs[i]);
            }//@audit L this prevent user from using other people address M This will prevent user claim rewards if contract is a vault with limited use case. There is no purpose for claiming rewards to verify caller. If target received token is set anyway

            // Verify holding period has elapsed
            if (block.timestamp < participation.startTimestamp + holdingPeriodInSeconds) {
                revert HoldingPeriodNotElapsed(pIDs[i]);
            }

            uint256 userRewards = participation.rewardAmount;
            // Break if insufficient balance for this claim
            if (userRewards > availableBalance) {
                break;
            }//@audit-ok M debase token gonna have a hard time with this contract.

            // Update contract state
            pendingRewards -= userRewards;
            distributedRewards += userRewards;//@audit-ok M it seem like campaign manager can rugpull by manipulate swap.

            // Update participation status and transfer rewards
            participation.status = ParticipationStatus.CLAIMED;
            availableBalance -= userRewards;//@note participation never got their original token back. only rewards

            _transfer(rewardToken, participation.userAddress, userRewards);//@callback

            emit NudgeRewardClaimed(pIDs[i], participation.userAddress, userRewards);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                              ADMIN FUNCTIONS
  //////////////////////////////////////////////////////////////////////////*/

    /// @notice Invalidates specified participations
    /// @param pIDs Array of participation IDs to invalidate
    /// @dev Only callable by operator role
    function invalidateParticipations(uint256[] calldata pIDs) external onlyNudgeOperator {
        for (uint256 i = 0; i < pIDs.length; i++) {
            Participation storage participation = participations[pIDs[i]];

            if (participation.status != ParticipationStatus.PARTICIPATING) {
                continue;
            }

            participation.status = ParticipationStatus.INVALIDATED;
            pendingRewards -= participation.rewardAmount;//@this must also move fee back to pool too
        }//@audit-ok M totalReallocatedAmount must also removed here too

        emit ParticipationInvalidated(pIDs);
    }

    /// @notice Withdraws unallocated rewards from the campaign
    /// @param amount Amount of rewards to withdraw
    /// @dev Only callable by campaign admin
    function withdrawRewards(uint256 amount) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
        if (amount > claimableRewardAmount()) { //@audit-ok no user deposit exist here L Campaign manager can withdraw user deposit token if reward and deposit is the same token.
            revert NotEnoughRewardsAvailable();
        }

        address to = alternativeWithdrawalAddress == address(0) ? msg.sender : alternativeWithdrawalAddress;

        _transfer(rewardToken, to, amount);//@audit-ok as designed M can withdraw rewards while campaign is ongoing. This does not affect pending rewards

        emit RewardsWithdrawn(to, amount);
    }

    /// @notice Collects accumulated fees
    /// @return feesToCollect Amount of fees collected
    /// @dev Only callable by NudgeCampaignFactory or Nudge admins
    function collectFees() external onlyFactoryOrNudgeAdmin returns (uint256 feesToCollect) {
        feesToCollect = accumulatedFees;
        accumulatedFees = 0;

        _transfer(rewardToken, factory.nudgeTreasuryAddress(), feesToCollect);

        emit FeesCollected(feesToCollect);
    }

    /// @notice Marks a campaign as active, i.e accepting new participations
    /// @param isActive New active status
    /// @dev Only callable by Nudge admins
    function setIsCampaignActive(bool isActive) external {
        if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {
            revert Unauthorized();
        }

        if (isActive && block.timestamp < startTimestamp) {
            revert StartDateNotReached();
        }

        isCampaignActive = isActive;
        // If deactivating, mark as manually deactivated
        if (!isActive) {
            _manuallyDeactivated = true;
        } else {
            // If activating, clear the manual deactivation flag
            _manuallyDeactivated = false;
        }

        emit CampaignStatusChanged(isActive);
    }

    /// @notice Rescues tokens that were mistakenly sent to the contract
    /// @param token Address of token to rescue
    /// @dev Only callable by NUDGE_ADMIN_ROLE, can't rescue the reward token
    /// @return amount Amount of tokens rescued
    function rescueTokens(address token) external returns (uint256 amount) {
        if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {
            revert Unauthorized();
        }

        if (token == rewardToken) {
            revert CannotRescueRewardToken();
        }

        amount = getBalanceOfSelf(token);
        if (amount > 0) {
            _transfer(token, msg.sender, amount); //@audit-ok not able to inflate maximum rewards M admin failed to rescue rewards token is a mistake. Rewards can be ridiculous amount and failed to withdraw
            emit TokensRescued(token, amount);
        }

        return amount;
    }

    /*//////////////////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets the balance of the specified token for this contract
    /// @param token Address of token to check
    /// @return Balance of the token
    function getBalanceOfSelf(address token) public view returns (uint256) {
        if (token == NATIVE_TOKEN) {
            return address(this).balance;
        } else {
            return IERC20(token).balanceOf(address(this));
        }
    }

    /// @notice Calculates the amount of rewards available for distribution
    /// @return Amount of claimable rewards
    function claimableRewardAmount() public view returns (uint256) {
        return getBalanceOfSelf(rewardToken) - pendingRewards - accumulatedFees;
    }

    /// @notice Calculates user rewards and fees from total reward amount
    /// @param rewardAmountIncludingFees Total reward amount including fees
    /// @return userRewards Amount of rewards for the user
    /// @return fees Amount of fees to be collected
    function calculateUserRewardsAndFees(
        uint256 rewardAmountIncludingFees
    ) public view returns (uint256 userRewards, uint256 fees) {
        fees = (rewardAmountIncludingFees * feeBps) / BPS_DENOMINATOR;
        userRewards = rewardAmountIncludingFees - fees;
    }

    /// @notice Returns comprehensive information about the campaign
    /// @return _holdingPeriodInSeconds Duration users must hold tokens
    /// @return _targetToken Address of token users need to hold
    /// @return _rewardToken Address of token used for rewards
    /// @return _rewardPPQ Reward parameter in parts per quadrillion
    /// @return _startTimestamp When the campaign becomes active
    /// @return _isCampaignActive Whether the campaign is currently active
    /// @return _pendingRewards Total rewards pending claim
    /// @return _totalReallocatedAmount Total amount of tokens reallocated
    /// @return _distributedRewards Total rewards distributed
    /// @return _claimableRewards Amount of rewards available for distribution
    function getCampaignInfo()
        external
        view
        returns (
            uint32 _holdingPeriodInSeconds,
            address _targetToken,
            address _rewardToken,
            uint256 _rewardPPQ,
            uint256 _startTimestamp,
            bool _isCampaignActive,
            uint256 _pendingRewards,
            uint256 _totalReallocatedAmount,
            uint256 _distributedRewards,
            uint256 _claimableRewards
        )
    {
        return (
            holdingPeriodInSeconds,
            targetToken,
            rewardToken,
            rewardPPQ,
            startTimestamp,
            isCampaignActive,
            pendingRewards,
            totalReallocatedAmount,
            distributedRewards,
            claimableRewardAmount()
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////////////////*/
    /// @notice Internal function to transfer tokens
    /// @param token Address of token to transfer
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @dev Handles both ERC20 and native token transfers
    function _transfer(address token, address to, uint256 amount) internal {
        if (token == NATIVE_TOKEN) {
            (bool sent, ) = to.call{value: amount}("");
            if (!sent) revert NativeTokenTransferFailed();
        } else {
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        }
    }

    /// @notice Allows contract to receive native token transfers
    receive() external payable {}

    /// @notice Fallback function to receive native token transfers
    fallback() external payable {}
}
