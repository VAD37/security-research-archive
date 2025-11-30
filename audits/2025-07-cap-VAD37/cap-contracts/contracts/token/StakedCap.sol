// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Access } from "../access/Access.sol";

import { IStakedCap } from "../interfaces/IStakedCap.sol";
import { StakedCapStorageUtils } from "../storage/StakedCapStorageUtils.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20Upgradeable,
    ERC4626Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Staked Cap Token
/// @author kexley, Cap Labs
/// @notice Slow releasing yield-bearing token that distributes the yield accrued from agents
/// borrowing from the underlying assets.
/// @dev Calling notify permissionlessly will start the linear unlock
contract StakedCap is
    IStakedCap,
    UUPSUpgradeable,
    ERC4626Upgradeable,
    ERC20PermitUpgradeable,
    Access,
    StakedCapStorageUtils
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IStakedCap
    function initialize(address _accessControl, address _asset, uint256 _lockDuration) external initializer {
        string memory _name = string.concat("Staked ", IERC20Metadata(_asset).name());
        string memory _symbol = string.concat("st", IERC20Metadata(_asset).symbol());

        __ERC4626_init(IERC20(_asset));//capToken or cUSD cETH
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __Access_init(_accessControl);
        __UUPSUpgradeable_init();
        getStakedCapStorage().lockDuration = _lockDuration;//24 hours
    }

    /// @inheritdoc IStakedCap
    function notify() external {//@only locking prodit or cash mistakenly send in.
        StakedCapStorage storage $ = getStakedCapStorage();
        if ($.lastNotify + $.lockDuration > block.timestamp) revert StillVesting();

        uint256 total = IERC20(asset()).balanceOf(address(this));//@audit L anyone can frontrun send tiny wei notify to lock profit for 24 hours. before actual profit is sent by FeeReceiver.sol
        if (total > $.storedTotal) {
            uint256 diff = total - $.storedTotal;

            $.totalLocked = diff;
            $.storedTotal = total;//@this reset total value equal to capToken deposit+donated
            $.lastNotify = block.timestamp;

            emit Notify(msg.sender, diff);
        }
    }

    /// @inheritdoc ERC4626Upgradeable
    function decimals() public view override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8 _decimals) {
        _decimals = ERC4626Upgradeable.decimals();
    }

    /// @inheritdoc IStakedCap
    function lastNotify() external view returns (uint256 _lastNotify) {
        _lastNotify = getStakedCapStorage().lastNotify;
    }

    /// @inheritdoc IStakedCap
    function lockDuration() external view returns (uint256 _lockDuration) {
        _lockDuration = getStakedCapStorage().lockDuration;
    }

    /// @inheritdoc IStakedCap
    function lockedProfit() public view returns (uint256 locked) {
        StakedCapStorage storage $ = getStakedCapStorage();
        if ($.lockDuration == 0) return 0;
        uint256 elapsed = block.timestamp - $.lastNotify;
        uint256 remaining = elapsed < $.lockDuration ? $.lockDuration - elapsed : 0;
        locked = $.totalLocked * remaining / $.lockDuration;//@ linear reduced from 100% to 0% over the lock duration
    }//@linear rewards profit vesting? it is possible to boost the yield temporary right?

    /// @inheritdoc ERC4626Upgradeable
    function totalAssets() public view override returns (uint256 total) {//@audit L yieldProfit can be higher than total deposit. through donated attack after 20 hours. when rewards linearly distributed to force yield high enough. This can cause reverse and prevent anyone from depositing. Can be abused to force permanent loop of no one can deposit or withdraw
        total = getStakedCapStorage().storedTotal - lockedProfit();//@audit info. forced yield cUSD rewards does not count towards total assets in ERC4626 vault.
    }//@total value split between stock and yield. //@audit M people deposit later do not benefit from share of unyielded profit. aka deposit early do not receive correct amount of shares. this is noted on Docs and tradeback

    /// @dev Overridden to update the total assets including unvested tokens
    /// @param _caller Caller of the deposit
    /// @param _receiver Receiver of the staked cap tokens
    /// @param _assets Amount of cap tokens to pull from the caller
    /// @param _shares Amount of staked cap tokens to send to receiver
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal override {
        super._deposit(_caller, _receiver, _assets, _shares);
        getStakedCapStorage().storedTotal += _assets;
    }//@audit L early deposit attack inflation value still available for ERC4626 vault.

    /// @dev Overridden to reduce the total assets including unvested tokens
    /// @param _caller Caller of the withdrawal
    /// @param _receiver Receiver of the cap tokens
    /// @param _owner Owner of the staked cap tokens being burnt
    /// @param _assets Amount of cap tokens to send to the receiver
    /// @param _shares Amount of staked cap tokens to burn from the owner
    function _withdraw(address _caller, address _receiver, address _owner, uint256 _assets, uint256 _shares)
        internal
        override
    {
        super._withdraw(_caller, _receiver, _owner, _assets, _shares);//@audit L if ERC20 stable token have callback. this will be distrastous. should update erc price before token transfer?
        getStakedCapStorage().storedTotal -= _assets;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override checkAccess(bytes4(0)) { }
}
