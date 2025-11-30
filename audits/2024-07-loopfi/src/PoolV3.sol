// SPDX-License-Identifier: BUSL-1.1
// Gearbox Protocol. Generalized leverage for DeFi protocols
// (c) Gearbox Foundation, 2023.
pragma solidity ^0.8.19;
pragma abicoder v1;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// INTERFACES
import {IAddressProviderV3, AP_TREASURY, NO_VERSION_CONTROL} from "@gearbox-protocol/core-v3/contracts/interfaces/IAddressProviderV3.sol";
import {ICreditManagerV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ICreditManagerV3.sol";
import {ILinearInterestRateModelV3} from "@gearbox-protocol/core-v3/contracts/interfaces/ILinearInterestRateModelV3.sol";
import {IPoolQuotaKeeperV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolQuotaKeeperV3.sol";
import {IPoolV3} from "@gearbox-protocol/core-v3/contracts/interfaces/IPoolV3.sol";

// LIBS & TRAITS
import {CreditLogic} from "@gearbox-protocol/core-v3/contracts/libraries/CreditLogic.sol";
import {ACLNonReentrantTrait} from "@gearbox-protocol/core-v3/contracts/traits/ACLNonReentrantTrait.sol";
import {ContractsRegisterTrait} from "@gearbox-protocol/core-v3/contracts/traits/ContractsRegisterTrait.sol";

// CONSTANTS
import {RAY, MAX_WITHDRAW_FEE, SECONDS_PER_YEAR, PERCENTAGE_FACTOR} from "@gearbox-protocol/core-v2/contracts/libraries/Constants.sol";

import {ICDM} from "./interfaces/ICDM.sol";

// EXCEPTIONS
import "@gearbox-protocol/core-v3/contracts/interfaces/IExceptions.sol";

/// @dev Struct that holds borrowed amount and debt limit
struct DebtParams {
    uint128 borrowed;
    uint128 limit;
}

/// @title Pool V3
/// @notice Pool contract that implements lending and borrowing logic, compatible with ERC-4626 standard
/// @notice Pool shares implement EIP-2612 permits
contract PoolV3 is ERC4626, ERC20Permit, ACLNonReentrantTrait, ContractsRegisterTrait, IPoolV3 {
    using Math for uint256;//@audit-ok I inherit ContractsRegisterTrait.sol but does not use it. contractsRegister = ContractsRegister(v3AddressProvider). AddressProvider selfloop point contract register to itself
    using SafeCast for int256;
    using SafeCast for uint256;
    using CreditLogic for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    error CallerNotManagerException();
    error PoolV3LockedException();
    error IncompatibleDecimalsException();

    /// @notice Contract version
    uint256 public constant override version = 3_00;

    /// @notice Address provider contract address
    address public immutable override addressProvider;

    /// @notice Underlying token address
    address public immutable override underlyingToken;

    /// @notice Protocol treasury address
    address public immutable override treasury;

    /// @notice Interest rate model contract address
    address public override interestRateModel;
    /// @notice Timestamp of the last base interest rate and index update
    uint40 public override lastBaseInterestUpdate;
    /// @notice Timestamp of the last quota revenue update
    uint40 public override lastQuotaRevenueUpdate;
    /// @notice Withdrawal fee in bps
    uint16 public override withdrawFee;//0->1%.default 0
    /// @notice Redeeming or withdrawing locked status
    bool public locked;

    /// @notice Pool quota keeper contract address
    address public override poolQuotaKeeper;
    /// @dev Current quota revenue
    uint96 internal _quotaRevenue;

    /// @dev Current base interest rate in ray
    uint128 internal _baseInterestRate;
    /// @dev Cumulative base interest index stored as of last update in ray
    uint128 internal _baseInterestIndexLU;

    /// @dev Expected liquidity stored as of last update
    uint128 internal _expectedLiquidityLU;

    /// @dev Aggregate debt params
    DebtParams internal _totalDebt;

    /// @dev Mapping credit manager => debt params
    mapping(address => DebtParams) internal _creditManagerDebt;

    /// @dev List of all connected credit managers
    EnumerableSet.AddressSet internal _creditManagerSet;

    /// @dev Map of whitelisted accounts that are allowed to redeem or withdraw when pool is locked
    mapping(address => bool) internal _allowed;

    /// @dev Ensures that function can only be called by the pool quota keeper
    modifier poolQuotaKeeperOnly() {
        _revertIfCallerIsNotPoolQuotaKeeper();
        _;
    }

    /// @dev Ensures that function caller is an allowed credit manager
    modifier creditManagerOnly() {
        _revertIfCallerNotCreditManager();
        _;
    }

    modifier whenNotLocked() {
        if (_allowed[msg.sender]) {
            _;
        } else {
            _revertIfLocked();
            _;
        }
    }

    function _revertIfCallerIsNotPoolQuotaKeeper() internal view {
        if (msg.sender != poolQuotaKeeper) revert CallerNotPoolQuotaKeeperException(); // U:[LP-2C]
    }

    /// @dev Reverts if `msg.sender` is not an allowed credit manager
    function _revertIfCallerNotCreditManager() internal view {
        if (!_creditManagerSet.contains(msg.sender)) {
            revert CallerNotCreditManagerException(); // U:[PQK-4]
        }
    }

    function _revertIfLocked() internal view {
        if (locked) revert PoolV3LockedException(); // U:[LP-2C]
    }

    /// @notice Constructor
    /// @param addressProvider_ Address provider contract address
    /// @param underlyingToken_ Pool underlying token address
    /// @param interestRateModel_ Interest rate model contract address
    /// @param totalDebtLimit_ Initial total debt limit, `type(uint256).max` for no limit
    /// @param name_ Name of the pool
    /// @param symbol_ Symbol of the pool's LP token
    constructor(
        address addressProvider_,//Gearbox-protocol core AddressProviderV3. AP_WETH_TOKEN= mockETH, AP_TREASURY=EOA,AP_CONTRACTS_REGISTER=ContractsRegister(v3AddressProvider)
        address underlyingToken_,//mockWETH
        address interestRateModel_,//immutable Gearbox LinearInterestRateModelV3 . slope 85,95% . rate 10%, 30%,50%,90%
        uint256 totalDebtLimit_,//100B ether
        string memory name_,//Loop Liquidity Pool
        string memory symbol_//lpETH
    )
        ACLNonReentrantTrait(addressProvider_) // U:[LP-1A] //@admin of ACL can call as configurator. Include pause and controller role.
        ContractsRegisterTrait(addressProvider_)//this is useless. not use for anything except have immutable           //@note call ContractsRegister.sol to get pool address is registered to ContractsRegister. This is different from VaultRegistry.sol
        ERC4626(IERC20(underlyingToken_)) // U:[LP-1B]
        ERC20(name_, symbol_) // U:[LP-1B]
        ERC20Permit(name_) // U:[LP-1B]
        nonZeroAddress(underlyingToken_) // U:[LP-1A]
        nonZeroAddress(interestRateModel_) // U:[LP-1A]
    {
        addressProvider = addressProvider_; // U:[LP-1B]
        underlyingToken = underlyingToken_; // U:[LP-1B]

        treasury = IAddressProviderV3(addressProvider_).getAddressOrRevert({
            key: AP_TREASURY,//EOA
            _version: NO_VERSION_CONTROL
        }); // U:[LP-1B]

        lastBaseInterestUpdate = uint40(block.timestamp); // U:[LP-1B]
        _baseInterestIndexLU = uint128(RAY); // U:[LP-1B]

        interestRateModel = interestRateModel_; // U:[LP-1B]
        emit SetInterestRateModel(interestRateModel_); // U:[LP-1B]

        if (ERC20(underlyingToken_).decimals() != 18) {//@note all ETH LP must be 18 decimals
            revert IncompatibleDecimalsException();
        }

        locked = true;//@admin must manually unlock Pool after initialization

        _setTotalDebtLimit(totalDebtLimit_); // U:[LP-1B]
    }

    /// @notice Pool shares decimals, matches underlying token decimals
    function decimals() public view override(ERC20, ERC4626, IERC20Metadata) returns (uint8) {
        return ERC4626.decimals();//18 = _underlyingDecimals + _decimalsOffset();
    }

    /// @notice Addresses of all connected credit managers
    function creditManagers() external view override returns (address[] memory) {
        return _creditManagerSet.values();
    }

    /// @notice Available liquidity in the pool
    function availableLiquidity() public view override returns (uint256) {//@standard exploit for donation attack
        return IERC20(underlyingToken).balanceOf(address(this)); // U:[LP-3]
    }

    /// @notice Amount of underlying that would be in the pool if debt principal, base interest
    ///         and quota revenue were fully repaid
    function expectedLiquidity() public view override returns (uint256) {
        return _expectedLiquidityLU + _calcBaseInterestAccrued() + _calcQuotaRevenueAccrued(); // U:[LP-4]
    }

    /// @notice Expected liquidity stored as of last update
    function expectedLiquidityLU() public view override returns (uint256) {
        return _expectedLiquidityLU;
    }

    // ---------------- //
    // ERC-4626 LENDING //
    // ---------------- //

    /// @notice Total amount of underlying tokens managed by the pool, same as `expectedLiquidity`
    /// @dev Since `totalAssets` doesn't depend on underlying balance, pool is not vulnerable to the inflation attack
    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256 assets) {
        return expectedLiquidity();
    }

    /// @notice Deposits given amount of underlying tokens to the pool in exchange for pool shares
    /// @param assets Amount of underlying to deposit
    /// @param receiver Account to mint pool shares to
    /// @return shares Number of shares minted
    function deposit(
        uint256 assets,//amount WETH
        address receiver
    )
        public
        override(ERC4626, IERC4626)
        whenNotPaused // U:[LP-2A]
        nonReentrant // U:[LP-2B]
        nonZeroAddress(receiver) // U:[LP-5]
        returns (uint256 shares)
    {
        uint256 assetsReceived = _amountMinusFee(assets); // U:[LP-6] //@not fee-transfer token
        shares = _convertToShares(assetsReceived); // U:[LP-6] //@note PoolV3. share convert 1:1 ratio with underlying token. deposit 1ETH always get 1e18 share
        _deposit(receiver, assets, assetsReceived, shares); // U:[LP-6]
    }

    /// @dev Same as `deposit`, but allows to specify the referral code
    function depositWithReferral(
        uint256 assets,
        address receiver,
        uint256 referralCode
    ) external override returns (uint256 shares) {
        shares = deposit(assets, receiver); // U:[LP-2A,2B,5,6]
        emit Refer(receiver, referralCode, assets); // U:[LP-6]
    }

    /// @notice Deposits underlying tokens to the pool in exhcange for given number of pool shares
    /// @param shares Number of shares to mint
    /// @param receiver Account to mint pool shares to
    /// @return assets Amount of underlying transferred from caller
    function mint(
        uint256 shares,
        address receiver
    )
        public
        override(ERC4626, IERC4626)
        whenNotPaused // U:[LP-2A]
        nonReentrant // U:[LP-2B]
        nonZeroAddress(receiver) // U:[LP-5]
        returns (uint256 assets)
    {
        uint256 assetsReceived = _convertToAssets(shares); // U:[LP-7]
        assets = _amountWithFee(assetsReceived); // U:[LP-7]
        _deposit(receiver, assets, assetsReceived, shares); // U:[LP-7]
    }

    /// @dev Same as `mint`, but allows to specify the referral code
    function mintWithReferral(
        uint256 shares,
        address receiver,
        uint256 referralCode
    ) external override returns (uint256 assets) {
        assets = mint(shares, receiver); // U:[LP-2A,2B,5,7]
        emit Refer(receiver, referralCode, assets); // U:[LP-7]
    }

    /// @notice Withdraws pool shares for given amount of underlying tokens
    /// @param assets Amount of underlying to withdraw
    /// @param receiver Account to send underlying to
    /// @param owner Account to burn pool shares from
    /// @return shares Number of pool shares burned
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(ERC4626, IERC4626)
        whenNotPaused // U:[LP-2A]
        whenNotLocked
        nonReentrant // U:[LP-2B]
        nonZeroAddress(receiver) // U:[LP-5]
        returns (uint256 shares)
    {
        uint256 assetsToUser = _amountWithFee(assets);
        uint256 assetsSent = _amountWithWithdrawalFee(assetsToUser); // U:[LP-8] //max 1% withdrawal fee
        shares = _convertToShares(assetsSent); // U:[LP-8]//@shares = assets
        _withdraw(receiver, owner, assetsSent, assets, assetsToUser, shares); // U:[LP-8]
    }//@audit-ok maxwithdrawal already include this . M withdraw 100% asset is not possible. cannot burn all shares due to inflate withdrawal fee increase assets value.

    /// @notice Redeems given number of pool shares for underlying tokens
    /// @param shares Number of pool shares to redeem
    /// @param receiver Account to send underlying to
    /// @param owner Account to burn pool shares from
    /// @return assets Amount of underlying withdrawn
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override(ERC4626, IERC4626)
        whenNotPaused // U:[LP-2A]
        whenNotLocked
        nonReentrant // U:[LP-2B]
        nonZeroAddress(receiver) // U:[LP-5]
        returns (uint256 assets)
    {
        uint256 assetsSent = _convertToAssets(shares); // U:[LP-9]//assetsSend = shares
        uint256 assetsToUser = _amountMinusWithdrawalFee(assetsSent); //99% assets
        assets = _amountMinusFee(assetsToUser); // U:[LP-9] //99% assets - fee-on-transfer //@audit-ok L context fee-on-transfer override differ between withdraw/redeem.
        _withdraw(receiver, owner, assetsSent, assets, assetsToUser, shares); // U:[LP-9]
    }

    /// @notice Number of pool shares that would be minted on depositing `assets`
    function previewDeposit(uint256 assets) public view override(ERC4626, IERC4626) returns (uint256 shares) {
        shares = _convertToShares(_amountMinusFee(assets)); // U:[LP-10]//@ok , share = asset - fee-on-transfer
    }

    /// @notice Amount of underlying that would be spent to mint `shares`
    function previewMint(uint256 shares) public view override(ERC4626, IERC4626) returns (uint256) {
        return _amountWithFee(_convertToAssets(shares)); // U:[LP-10]
    }

    /// @notice Number of pool shares that would be burned on withdrawing `assets`
    function previewWithdraw(uint256 assets) public view override(ERC4626, IERC4626) returns (uint256) {
        return _convertToShares(_amountWithWithdrawalFee(_amountWithFee(assets))); // U:[LP-10]//@ 
    }

    /// @notice Amount of underlying that would be received after redeeming `shares`
    function previewRedeem(uint256 shares) public view override(ERC4626, IERC4626) returns (uint256) {
        return _amountMinusFee(_amountMinusWithdrawalFee(_convertToAssets(shares))); // U:[LP-10]
    }

    /// @notice Maximum amount of underlying that can be deposited to the pool, 0 if pool is on pause
    function maxDeposit(address) public view override(ERC4626, IERC4626) returns (uint256) {
        return paused() ? 0 : type(uint256).max; // U:[LP-11]
    }

    /// @notice Maximum number of pool shares that can be minted, 0 if pool is on pause
    function maxMint(address) public view override(ERC4626, IERC4626) returns (uint256) {
        return paused() ? 0 : type(uint256).max; // U:[LP-11]
    }

    /// @notice Maximum amount of underlying that can be withdrawn from the pool by `owner`, 0 if pool is on pause
    function maxWithdraw(address owner) public view override(ERC4626, IERC4626) returns (uint256) {
        return
            paused()
                ? 0
                : _amountMinusFee(//@assets = share * 9900/10000 - (fee-on-transfer)
                    _amountMinusWithdrawalFee(Math.min(availableLiquidity(), _convertToAssets(balanceOf(owner))))//@share * 9900/10000
                ); // U:[LP-11]
    }

    /// @notice Maximum number of shares that can be redeemed for underlying by `owner`, 0 if pool is on pause
    function maxRedeem(address owner) public view override(ERC4626, IERC4626) returns (uint256) {
        return paused() ? 0 : Math.min(balanceOf(owner), _convertToShares(availableLiquidity())); // U:[LP-11]
    }

    /// @dev `deposit` / `mint` implementation
    ///      - transfers underlying from the caller
    ///      - updates base interest rate and index
    ///      - mints pool shares to `receiver`
    function _deposit(address receiver, uint256 assetsSent, uint256 assetsReceived, uint256 shares) internal {
        IERC20(underlyingToken).safeTransferFrom({from: msg.sender, to: address(this), value: assetsSent}); // U:[LP-6,7]
        //@shares = assetsSend = assetsReceived
        _updateBaseInterest({//@global accrued update
            expectedLiquidityDelta: assetsReceived.toInt256(),
            availableLiquidityDelta: 0,
            checkOptimalBorrowing: false
        }); // U:[LP-6,7]

        _mint(receiver, shares); // U:[LP-6,7]
        emit Deposit(msg.sender, receiver, assetsSent, shares); // U:[LP-6,7]
    }

    /// @dev `withdraw` / `redeem` implementation
    ///      - burns pool shares from `owner`
    ///      - updates base interest rate and index
    ///      - transfers underlying to `receiver` and, if withdrawal fee is activated, to the treasury
    function _withdraw(
        address receiver,//input nonzero
        address owner,//input
        uint256 assetsSent,// 101.01% assets , redeem: 100% assets
        uint256 assetsReceived,//100% assets, redeem: 99% assets - fee-on-transfer
        uint256 amountToUser,//100% assets - fee-on-transfer , redeem: 99% assets
        uint256 shares//@101.01% assets, redeem: 100% assets
    ) internal {
        if (msg.sender != owner) _spendAllowance({owner: owner, spender: msg.sender, amount: shares}); // U:[LP-8,9]
        _burn(owner, shares); // U:[LP-8,9] //@audit-ok R share is dilutated if not burn 100% share of user deposit? So user have to input include 100% asset + fee

        _updateBaseInterest({
            expectedLiquidityDelta: -assetsSent.toInt256(),
            availableLiquidityDelta: -assetsSent.toInt256(),
            checkOptimalBorrowing: false
        }); // U:[LP-8,9]

        IERC20(underlyingToken).safeTransfer({to: receiver, value: amountToUser}); // U:[LP-8,9]
        if (assetsSent > amountToUser) {//@only happen with fee on transfer token which is not used.
            unchecked {//@assetsSent always > amountToUser due to bug in withdraw fee calculation
                IERC20(underlyingToken).safeTransfer({to: treasury, value: assetsSent - amountToUser}); // U:[LP-8,9]
            }
        }
        emit Withdraw(msg.sender, receiver, owner, assetsReceived, shares); // U:[LP-8,9]
    }

    /// @dev Internal conversion function (from assets to shares) with support for rounding direction
    /// @dev Pool is not vulnerable to the inflation attack, so the simplified implementation w/o virtual shares is used
    function _convertToShares(uint256 assets) internal pure returns (uint256 shares) {//@audit-ok maxwithdrawal make this already compliant.M not convert/override internal OZ ERC4626. prevent pool from being ERC4626 compliant
        // uint256 supply = totalSupply();
        return assets; //(assets == 0 || supply == 0) ? assets : assets.mulDiv(supply, totalAssets(), rounding);
    }

    /// @dev Internal conversion function (from shares to assets) with support for rounding direction
    /// @dev Pool is not vulnerable to the inflation attack, so the simplified implementation w/o virtual shares is used
    function _convertToAssets(uint256 shares) internal pure returns (uint256 assets) {
        //uint256 supply = totalSupply();
        return shares; //(supply == 0) ? shares : shares.mulDiv(totalAssets(), supply, rounding);
    }

    // --------- //
    // BORROWING //
    // --------- //

    /// @notice Total borrowed amount (principal only)
    function totalBorrowed() external view override returns (uint256) {
        return _totalDebt.borrowed;
    }

    /// @notice Total debt limit, `type(uint256).max` means no limit
    function totalDebtLimit() external view override returns (uint256) {
        return _convertToU256(_totalDebt.limit);
    }

    /// @notice Amount borrowed by a given credit manager
    function creditManagerBorrowed(address creditManager) external view override returns (uint256) {
        return _creditManagerDebt[creditManager].borrowed;
    }

    /// @notice Debt limit for a given credit manager, `type(uint256).max` means no limit
    function creditManagerDebtLimit(address creditManager) external view override returns (uint256) {
        return _convertToU256(_creditManagerDebt[creditManager].limit);
    }

    /// @notice Amount available to borrow for a given credit manager
    function creditManagerBorrowable(address creditManager) external view override returns (uint256 borrowable) {
        borrowable = _borrowable(_totalDebt); // U:[LP-12]
        if (borrowable == 0) return 0; // U:[LP-12]

        borrowable = Math.min(borrowable, _borrowable(_creditManagerDebt[creditManager])); // U:[LP-12]
        if (borrowable == 0) return 0; // U:[LP-12]

        uint256 available = ILinearInterestRateModelV3(interestRateModel).availableToBorrow({
            expectedLiquidity: expectedLiquidity(),
            availableLiquidity: availableLiquidity()
        }); // U:[LP-12]

        borrowable = Math.min(borrowable, available); // U:[LP-12]
    }

    /// @notice Lends funds to a credit account, can only be called by credit managers
    /// @param borrowedAmount Amount to borrow
    /// @param creditAccount Credit account to send the funds to
    function lendCreditAccount(
        uint256 borrowedAmount,//input amount. Not include fee
        address creditAccount//flashloan user
    )
        external
        override
        creditManagerOnly // U:[LP-2C]
        whenNotPaused // U:[LP-2A]
        nonReentrant // U:[LP-2B]
    {
        uint128 borrowedAmountU128 = borrowedAmount.toUint128();

        DebtParams storage cmDebt = _creditManagerDebt[msg.sender];
        uint128 totalBorrowed_ = _totalDebt.borrowed + borrowedAmountU128;
        uint128 cmBorrowed_ = cmDebt.borrowed + borrowedAmountU128;
        if (borrowedAmount == 0 || cmBorrowed_ > cmDebt.limit || totalBorrowed_ > _totalDebt.limit) {
            revert CreditManagerCantBorrowException(); // U:[LP-2C,13A]
        }
//@audit-ok M flashlending updateBaseInterest depend on blockTime  as well. so flashloan update available Liquidity is not going to work. This can be bypassed by refresh it before hand
        _updateBaseInterest({//@audit-ok it refresh use old value before update .FlashLending credit manager. can be used to cheat inflated accrued debt index. This manipulate baseInterest refresh because it refresh using deltaTime * updated_interest_rate. instead of deltaTime * _previous_inte
            expectedLiquidityDelta: 0,
            availableLiquidityDelta: -borrowedAmount.toInt256(),//@increase baseInterestRate briefly, because lend money away, token is transfered away. ratio is dropped
            checkOptimalBorrowing: true
        }); // U:[LP-13B]

        cmDebt.borrowed = cmBorrowed_; // U:[LP-13B]
        _totalDebt.borrowed = totalBorrowed_; // U:[LP-13B]

        IERC20(underlyingToken).safeTransfer({to: creditAccount, value: borrowedAmount}); // U:[LP-13B]
        emit Borrow(msg.sender, creditAccount, borrowedAmount); // U:[LP-13B]
    }

    /// @notice Updates pool state to indicate debt repayment, can only be called by credit managers
    ///         after transferring underlying from a credit account to the pool.
    ///         - If transferred amount exceeds debt principal + base interest + quota interest,
    ///           the difference is deemed protocol's profit and the respective number of shares
    ///           is minted to the treasury.
    ///         - If, however, transferred amount is insufficient to repay debt and interest,
    ///           which may only happen during liquidation, treasury's shares are burned to
    ///           cover as much of the loss as possible.
    /// @param repaidAmount Amount of debt principal repaid
    /// @param profit Pool's profit in underlying after repaying
    /// @param loss Pool's loss in underlying after repaying
    /// @custom:expects Credit manager transfers underlying from a credit account to the pool before calling this function
    /// @custom:expects Profit/loss computed in the credit manager are cosistent with pool's implicit calculations
    function repayCreditAccount(//@note repayCreditAccount never check how many token it receive back. This should be IR to be checked by other contracts.
        uint256 repaidAmount,
        uint256 profit,
        uint256 loss//@note IR cannot report profit and loss at the same times.
    )
        external
        override
        creditManagerOnly // U:[LP-2C]
        whenNotPaused // U:[LP-2A]
        nonReentrant // U:[LP-2B]
    {
        uint128 repaidAmountU128 = repaidAmount.toUint128();

        DebtParams storage cmDebt = _creditManagerDebt[msg.sender];
        uint128 cmBorrowed = cmDebt.borrowed;
        if (cmBorrowed == 0) {//@ totalSupply = total deposit WETH.
            revert CallerNotCreditManagerException(); // U:[LP-2C,14A]
        }//@audit-ok RH repayCreditAccount use base.ERC4626.convertToShares() instead of _convertToShares().
//profit WETH assets convert to share. share = assets * totalSupply / (_expectedLiquidityLU + _calcBaseInterestAccrued() + _calcQuotaRevenueAccrued())
        if (profit > 0) {//@note IV: CreditManager must transfer token before hand before call repayCredit. 
            _mint(treasury, convertToShares(profit)); // U:[LP-14B] //@same as deposit //@audit L this ignore the fee-on-transfer though
        } else if (loss > 0) {
            address treasury_ = treasury;
            uint256 sharesInTreasury = balanceOf(treasury_);
            uint256 sharesToBurn = convertToShares(loss);
            if (sharesToBurn > sharesInTreasury) {
                unchecked {
                    emit IncurUncoveredLoss({
                        creditManager: msg.sender,
                        loss: convertToAssets(sharesToBurn - sharesInTreasury)//@audit-ok R convertToAssets never overrided. it use updated totalAsset/totalSupply
                    }); // U:[LP-14D]
                }//@audit-ok R _expectedLiquidityLU was never subtracted when there is a loss. but increase when user deposit?
                sharesToBurn = sharesInTreasury;
            }
            _burn(treasury_, sharesToBurn); // U:[LP-14C,14D]
        }
//@audit-ok only accrued use block timestamp ratio interest still update normally. HR flashlending updateBaseInterest depend on blockTime  as well. so flashloan update available Liquidity is not going to work.
        _updateBaseInterest({
            expectedLiquidityDelta: -loss.toInt256(),//@ why not use profit value?
            availableLiquidityDelta: 0,//flashlending token already transfered back. so availableLiquidity increase backup. refresh baseInterestRate will result in the same interest rate
            checkOptimalBorrowing: false
        }); // U:[LP-14B,14C,14D]

        _totalDebt.borrowed -= repaidAmountU128; // U:[LP-14B,14C,14D]
        cmDebt.borrowed = cmBorrowed - repaidAmountU128; // U:[LP-14B,14C,14D]

        emit Repay(msg.sender, repaidAmount, profit, loss); // U:[LP-14B,14C,14D]
    }

    /// @dev Returns borrowable amount based on debt limit and current borrowed amount
    function _borrowable(DebtParams storage debt) internal view returns (uint256) {
        uint256 limit = debt.limit;
        if (limit == type(uint128).max) {
            return type(uint256).max;
        }
        uint256 borrowed = debt.borrowed;
        if (borrowed >= limit) return 0;
        unchecked {
            return limit - borrowed;
        }
    }

    // ------------- //
    // INTEREST RATE //
    // ------------- //

    /// @notice Annual interest rate in ray that credit account owners pay per unit of borrowed capital
    function baseInterestRate() public view override returns (uint256) {
        return _baseInterestRate;
    }

    /// @notice Annual interest rate in ray that liquidity providers receive per unit of deposited capital,
    ///         consists of base interest and quota revenue,
    /// @dev This function expects all liquidity providers to be staked.
    function supplyRate() external view override returns (uint256) {
        uint256 assets = expectedLiquidity();
        uint256 baseInterestRate_ = baseInterestRate();
        if (assets == 0) return baseInterestRate_;
        return
            ((baseInterestRate_ * _totalDebt.borrowed) * (PERCENTAGE_FACTOR - withdrawFee)) /
            PERCENTAGE_FACTOR /
            assets; // U:[LP-15]
    }

    /// @notice Current cumulative base interest index in ray
    function baseInterestIndex() public view override returns (uint256) {
        uint256 timestampLU = lastBaseInterestUpdate;
        if (block.timestamp == timestampLU) return _baseInterestIndexLU; // U:[LP-16]
        return _calcBaseInterestIndex(timestampLU); // U:[LP-16]
    }

    /// @notice Cumulative base interest index stored as of last update in ray
    function baseInterestIndexLU() external view override returns (uint256) {
        return _baseInterestIndexLU;
    }

    /// @dev Computes base interest accrued since the last update
    function _calcBaseInterestAccrued() internal view returns (uint256) {
        uint256 timestampLU = lastBaseInterestUpdate;
        if (block.timestamp == timestampLU) return 0; // U:[LP-17]
        return _calcBaseInterestAccrued(timestampLU); // U:[LP-17]
    }

    function calcAccruedQuotaInterest() external view returns (uint256) {
        return _calcQuotaRevenueAccrued();
    }

    /// @dev Updates base interest rate based on expected and available liquidity deltas
    ///      - Adds expected liquidity delta to stored expected liquidity
    ///      - If time has passed since the last base interest update, adds accrued interest
    ///        to stored expected liquidity, updates interest index and last update timestamp
    ///      - If time has passed since the last quota revenue update, adds accrued revenue
    ///        to stored expected liquidity and updates last update timestamp
    function _updateBaseInterest(//@ assetsSent = share = input = assetRecived,
        int256 expectedLiquidityDelta,//deposit: assetsReceived, withdraw: -assetSent
        int256 availableLiquidityDelta,//deposit: 0 , withdraw: -assetSent
        bool checkOptimalBorrowing//deposit: false , withdraw: false
    ) internal {
        uint256 expectedLiquidity_ = (expectedLiquidity().toInt256() + expectedLiquidityDelta).toUint256();// lastLiquidity_include_accrue + newLiquidity
        uint256 availableLiquidity_ = (availableLiquidity().toInt256() + availableLiquidityDelta).toUint256();// WETH balance - pending_withdrawal

        uint256 lastBaseInterestUpdate_ = lastBaseInterestUpdate;
        if (block.timestamp != lastBaseInterestUpdate_) {
            _baseInterestIndexLU = _calcBaseInterestIndex(lastBaseInterestUpdate_).toUint128(); // U:[LP-18]
            lastBaseInterestUpdate = uint40(block.timestamp);
        }//@this update last interest rate index before refresh baseInterestRate to new value

        if (block.timestamp != lastQuotaRevenueUpdate) {
            lastQuotaRevenueUpdate = uint40(block.timestamp); // U:[LP-18]
        }

        _expectedLiquidityLU = expectedLiquidity_.toUint128(); // U:[LP-18]
        _baseInterestRate = ILinearInterestRateModelV3(interestRateModel)//@ refresh baseInterestRate so next time it can change it back.
            .calcBorrowRate({
                expectedLiquidity: expectedLiquidity_,
                availableLiquidity: availableLiquidity_,
                checkOptimalBorrowing: checkOptimalBorrowing
            })
            .toUint128(); // U:[LP-18]
    }

    /// @dev Computes base interest accrued since given timestamp
    function _calcBaseInterestAccrued(uint256 timestamp) private view returns (uint256) {
        return (_totalDebt.borrowed * baseInterestRate().calcLinearGrowth(timestamp)) / RAY;
    }

    /// @dev Computes current value of base interest index
    function _calcBaseInterestIndex(uint256 timestamp) private view returns (uint256) {//@ _baseInterestIndexLU >= 1e27
        return (_baseInterestIndexLU * (RAY + baseInterestRate().calcLinearGrowth(timestamp))) / RAY;
    }//@  baseInterestRate() = 0 . for first update.

    // ------ //
    // QUOTAS //
    // ------ //

    /// @notice Current annual quota revenue in underlying tokens
    function quotaRevenue() public view override returns (uint256) {
        return _quotaRevenue;
    }

    /// @notice Updates quota revenue value by given delta
    /// @param quotaRevenueDelta Quota revenue delta
    function updateQuotaRevenue(
        int256 quotaRevenueDelta
    )
        external
        override
        nonReentrant // U:[LP-2B]
        //poolQuotaKeeperOnly // U:[LP-2C]
        creditManagerOnly
    {//@audit-ok L no safety check for quotaRevenueDelta. it can overflow when casting.
        _setQuotaRevenue(uint256(quotaRevenue().toInt256() + quotaRevenueDelta)); // U:[LP-19]
    }

    /// @notice Sets new quota revenue value
    /// @param newQuotaRevenue New quota revenue value
    function setQuotaRevenue(
        uint256 newQuotaRevenue
    )
        external
        override
        nonReentrant // U:[LP-2B]
        poolQuotaKeeperOnly // U:[LP-2C]
    {
        _setQuotaRevenue(newQuotaRevenue); // U:[LP-20]
    }

    /// @dev Computes quota revenue accrued since the last update
    function _calcQuotaRevenueAccrued() internal view returns (uint256) {
        uint256 timestampLU = lastQuotaRevenueUpdate;
        if (block.timestamp == timestampLU) return 0; // U:[LP-21]
        return _calcQuotaRevenueAccrued(timestampLU); // U:[LP-21]
    }

    /// @dev Sets new quota revenue value
    ///      - If time has passed since the last quota revenue update, adds accrued revenue
    ///        to stored expected liquidity and updates last update timestamp
    function _setQuotaRevenue(uint256 newQuotaRevenue) internal {
        uint256 timestampLU = lastQuotaRevenueUpdate;
        if (block.timestamp != timestampLU) {
            _expectedLiquidityLU += _calcQuotaRevenueAccrued(timestampLU).toUint128(); // U:[LP-20]
            lastQuotaRevenueUpdate = uint40(block.timestamp); // U:[LP-20]
        }
        _quotaRevenue = newQuotaRevenue.toUint96(); // U:[LP-20]
    }

    /// @dev Computes quota revenue accrued since given timestamp
    function _calcQuotaRevenueAccrued(uint256 timestamp) private view returns (uint256) {
        return quotaRevenue().calcLinearGrowth(timestamp);//@audit-ok idk R quotaRevenue here is not growthRate value. why is it used as one?
    }

    // ------------- //
    // CONFIGURATION //
    // ------------- //

    /// @notice Sets new interest rate model, can only be called by configurator
    /// @param newInterestRateModel Address of the new interest rate model contract
    function setInterestRateModel(
        address newInterestRateModel
    )
        external
        override
        configuratorOnly // U:[LP-2C]
        nonZeroAddress(newInterestRateModel) // U:[LP-22A]
    {
        interestRateModel = newInterestRateModel; // U:[LP-22B]//@audit-ok L update before change interest model.
        _updateBaseInterest(0, 0, false); // U:[LP-22B]
        emit SetInterestRateModel(newInterestRateModel); // U:[LP-22B]
    }

    /// @notice Sets new pool quota keeper, can only be called by configurator
    /// @param newPoolQuotaKeeper Address of the new pool quota keeper contract
    function setPoolQuotaKeeper(
        address newPoolQuotaKeeper
    )
        external
        override
        configuratorOnly // U:[LP-2C]
        nonZeroAddress(newPoolQuotaKeeper) // U:[LP-23A]
    {
        if (IPoolQuotaKeeperV3(newPoolQuotaKeeper).pool() != address(this)) {
            revert IncompatiblePoolQuotaKeeperException(); // U:[LP-23C]
        }

        poolQuotaKeeper = newPoolQuotaKeeper; // U:[LP-23D]

        uint256 newQuotaRevenue = IPoolQuotaKeeperV3(poolQuotaKeeper).poolQuotaRevenue();
        _setQuotaRevenue(newQuotaRevenue); // U:[LP-23D]

        emit SetPoolQuotaKeeper(newPoolQuotaKeeper); // U:[LP-23D]
    }

    /// @notice Sets new total debt limit, can only be called by controller
    /// @param newLimit New debt limit, `type(uint256).max` for no limit
    function setTotalDebtLimit(
        uint256 newLimit
    )
        external
        override
        controllerOnly // U:[LP-2C]
    {
        _setTotalDebtLimit(newLimit); // U:[LP-24]
    }

    /// @notice Sets new debt limit for a given credit manager, can only be called by controller
    ///         Adds credit manager to the list of connected managers when called for the first time
    /// @param creditManager Credit manager to set the limit for
    /// @param newLimit New debt limit, `type(uint256).max` for no limit (has smaller priority than total debt limit)
    function setCreditManagerDebtLimit(
        address creditManager,//Flashlender.sol
        uint256 newLimit
    )
        external
        override
        controllerOnly // U:[LP-2C]
        nonZeroAddress(creditManager) // U:[LP-25A]
    {
        if (!_creditManagerSet.contains(creditManager)) {
            if (address(this) != ICreditManagerV3(creditManager).pool()) {
                revert IncompatibleCreditManagerException(); // U:[LP-25C]
            }
            _creditManagerSet.add(creditManager); // U:[LP-25D]
            emit AddCreditManager(creditManager); // U:[LP-25D]
        }
        _creditManagerDebt[creditManager].limit = _convertToU128(newLimit); // U:[LP-25D]
        emit SetCreditManagerDebtLimit(creditManager, newLimit); // U:[LP-25D]
    }

    /// @notice Sets new withdrawal fee, can only be called by controller
    /// @param newWithdrawFee New withdrawal fee in bps
    function setWithdrawFee(
        uint256 newWithdrawFee
    )
        external
        override
        controllerOnly // U:[LP-2C]
    {
        if (newWithdrawFee > MAX_WITHDRAW_FEE) {
            revert IncorrectParameterException(); // U:[LP-26A]
        }
        if (newWithdrawFee == withdrawFee) return;

        withdrawFee = newWithdrawFee.toUint16(); // U:[LP-26B]
        emit SetWithdrawFee(newWithdrawFee); // U:[LP-26B]
    }

    /// @notice Allows or denies account to redeem or withdraw even if pool is locked
    /// @param account Account to allow or disallow
    /// @param status `true` to allow, `false` to disallow
    function setAllowed(address account, bool status) external controllerOnly {
        _allowed[account] = status;
    }

    /// @notice Locks or unlocks the pool, can only be called by controller
    /// @param status `true` to lock, `false` to unlock, default pool status is locked
    function setLock(bool status) external controllerOnly {
        locked = status;
    }

    /// @notice Returns `true` if account is allowed to redeem or withdraw even if pool is locked
    /// @param account Account to check
    function isAllowed(address account) external view returns (bool) {
        return _allowed[account];
    }

    /// @dev Sets new total debt limit
    function _setTotalDebtLimit(uint256 limit) internal {
        uint128 newLimit = _convertToU128(limit);
        if (newLimit == _totalDebt.limit) return;

        _totalDebt.limit = newLimit; // U:[LP-1B,24]
        emit SetTotalDebtLimit(limit); // U:[LP-1B,24]
    }

    // --------- //
    // INTERNALS //
    // --------- //

    /// @dev Returns amount of token that should be transferred to receive `amount`
    ///      Pools with fee-on-transfer underlying should override this method
    function _amountWithFee(uint256 amount) internal view virtual returns (uint256) {
        return amount;
    }

    /// @dev Returns amount of token that will be received if `amount` is transferred
    ///      Pools with fee-on-transfer underlying should override this method
    function _amountMinusFee(uint256 amount) internal view virtual returns (uint256) {
        return amount;
    }

    /// @dev Returns amount of token that should be withdrawn so that `amount` is actually sent to the receiver
    function _amountWithWithdrawalFee(uint256 amount) internal view returns (uint256) {
        return (amount * PERCENTAGE_FACTOR) / (PERCENTAGE_FACTOR - withdrawFee);//amount *= 10000/9900
    }//@audit-ok MaxWithdrawal() calculate correctly. H withdrawFee is inversed? it increase 101.01% instead reduce to 99% . is maxWithdrawal calculate correctly.
//@audit-ok. This is correct. 9990 * 10000/9900 = 10000 H withdrawFee 1% but take 1.01% of asset. math wrong calculation
    /// @dev Returns amount of token that would actually be sent to the receiver when withdrawing `amount`
    function _amountMinusWithdrawalFee(uint256 amount) internal view returns (uint256) {
        return (amount * (PERCENTAGE_FACTOR - withdrawFee)) / PERCENTAGE_FACTOR;//amount *= 9900/10000
    }

    /// @dev Converts `uint128` to `uint256`, preserves maximum value
    function _convertToU256(uint128 limit) internal pure returns (uint256) {
        return (limit == type(uint128).max) ? type(uint256).max : limit;
    }

    /// @dev Converts `uint256` to `uint128`, preserves maximum value
    function _convertToU128(uint256 limit) internal pure returns (uint128) {
        return (limit == type(uint256).max) ? type(uint128).max : limit.toUint128();
    }

    function mintProfit(uint256 amount) external creditManagerOnly {
        _mint(treasury, amount);

        _updateBaseInterest({
            expectedLiquidityDelta: amount.toInt256(),
            availableLiquidityDelta: 0,
            checkOptimalBorrowing: false
        }); // U:[LP-14B,14C,14D]
    }
}
