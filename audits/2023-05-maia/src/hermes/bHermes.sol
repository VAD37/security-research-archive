// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ERC4626DepositOnly} from "@ERC4626/ERC4626DepositOnly.sol";

import {bHermesBoost} from "./tokens/bHermesBoost.sol";
import {bHermesGauges} from "./tokens/bHermesGauges.sol";
import {bHermesVotes} from "./tokens/bHermesVotes.sol";
import {UtilityManager} from "./UtilityManager.sol";

/**
 * @title bHermes: Yield bearing, boosting, voting, and gauge enabled Hermes
 *  @notice bHermes is a deposit only ERC-4626 for HERMES tokens which:
 *          mints bHermes utility tokens (Weight, Boost, Governance)
 *          in exchange for burning HERMES.
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⡀⠀⣀⣀⠀⢀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⢀⣠⣴⣾⣿⣿⣇⠸⣿⣿⠇⣸⣿⣿⣷⣦⣄⡀⠀⠀⠀⠀⠀⠀
 *  ⢀⣠⣴⣶⠿⠋⣩⡿⣿⡿⠻⣿⡇⢠⡄⢸⣿⠟⢿⣿⢿⣍⠙⠿⣶⣦⣄⡀⠀
 *  ⠀⠉⠉⠁⠶⠟⠋⠀⠉⠀⢀⣈⣁⡈⢁⣈⣁⡀⠀⠉⠀⠙⠻⠶⠈⠉⠉⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣿⡿⠛⢁⡈⠛⢿⣿⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠿⣿⣦⣤⣈⠁⢠⣴⣿⠿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠻⢿⣿⣦⡉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢷⣦⣈⠛⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣴⠦⠈⠙⠿⣦⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣤⡈⠁⢤⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠷⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⠑⢶⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠁⢰⡆⠈⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⠈⣡⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *  ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 *
 *      ⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀
 *      ⠀⠀⠀⠀⠀⠀⠀⣼⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀
 *      ⠀⠀⠀⠀⠀⠀⠀⣿⡿⠛⠛⢿⣿⠀⠀⠀⠀⠀⠀⠀
 *      ⠀⠀⠀⠀⠀⠀⠀⢿⠁⠀⠀⠈⡿⠀⠀⠀⠀⠀⠀⠀
 *      ⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠀⠀
 *      ⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣦⠀⠀⠀⠀⠀⠀
 *      ⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀
 *      ⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢀⣤⣄
 *      ⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣀⣀⣀⣸⣿⣿
 *      ⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
 *      ⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢸⣿⣿
 *      ⠀⠀⠀⠀⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⡀⠀⠀⠀⠉⠁
 *      ⠀⠀⠀⣠⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀
 *      ⢀⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣤⡀
 *      ⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿
 */
contract bHermes is UtilityManager, ERC4626DepositOnly {
    using SafeTransferLib for address;

    constructor(ERC20 _hermes, address _owner, uint32 _gaugeCycleLength, uint32 _incrementFreezeWindow)//_gaugeCycleLength = 1 weeks, _incrementFreezeWindow = 12 hours
        UtilityManager(
            address(new bHermesGauges(_owner, _gaugeCycleLength, _incrementFreezeWindow)),
            address(new bHermesBoost(_owner)),//@audit why bHermes owner is GaugeManager? And why GaugeManager "admin" not owner can transferOwnerShip away?
            address(new bHermesVotes(_owner))
        )
        ERC4626DepositOnly(_hermes, "Burned Hermes: Gov + Yield + Boost", "bHermes")
    {}

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks available weight allows for the call.
    modifier checkWeight(uint256 amount) override {
        if (balanceOf[msg.sender] < amount + userClaimedWeight[msg.sender]) {//@note bHermers modifier check token can be easily bypass by receive token from other account
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available boost allows for the call.
    modifier checkBoost(uint256 amount) override {
        if (balanceOf[msg.sender] < amount + userClaimedBoost[msg.sender]) {//@note why bHermes token must be the same as other sub-token
            revert InsufficientShares();
        }
        _;
    }

    /// @dev Checks available governance allows for the call.
    modifier checkGovernance(uint256 amount) override {
        if (balanceOf[msg.sender] < amount + userClaimedGovernance[msg.sender]) {
            revert InsufficientShares();
        }
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            UTILITY MANAGER LOGIC
    //////////////////////////////////////////////////////////////*/

    function claimOutstanding() public virtual {//@audit-ok H claimOutstanding use user balance. user can inflate their BoostGaugeVote token by transfer bHermes from other account.
        uint256 balance = balanceOf[msg.sender];
        /// @dev Never overflows since balandeOf >= userClaimed.
        claimWeight(balance - userClaimedWeight[msg.sender]);
        claimBoost(balance - userClaimedBoost[msg.sender]);
        claimGovernance(balance - userClaimedGovernance[msg.sender]);
    }

    /*///////////////////////////////////////////////////////////////
                            ERC4626 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Computes the amounts of tokens available in the contract.
     * @dev Front-running first deposit vulnerability is not an
     *      issue since in the initial state:
     *      total assets (~90,000,000 ether) are larger than the
     *      underlying's remaining circulating supply (~30,000,000 ether).
     */
    function totalAssets() public view virtual override returns (uint256) {//@audit front-running first deposit still an issue without share being created
        return address(asset).balanceOf(address(this));
    }// when this contract was created. it have 90M hermes token. So what is the first share price?

    /*///////////////////////////////////////////////////////////////
                             ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint new bHermes and its underlying tokens: governance, boost and gauge tokens
     * @param to address to mint new tokens for
     * @param amount amounts of new tokens to mint
     */
    function _mint(address to, uint256 amount) internal virtual override {//mint from ERC4626
        gaugeWeight.mint(address(this), amount);//@note erc20 solmint does not call _transfer()
        gaugeBoost.mint(address(this), amount);//these sub token have lots of restriction along with transfer
        governance.mint(address(this), amount);
        super._mint(to, amount);//@note bHermes token totalBalance is the same as Weight Boost Vote token.
    }

    /**
     * @notice Transfer bHermes and its underlying tokens.
     * @param to address to transfer the tokens to
     * @param amount amounts of tokens to transfer
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        uint256 userBalance = balanceOf[msg.sender];

        if (
            userBalance - userClaimedWeight[msg.sender] < amount || userBalance - userClaimedBoost[msg.sender] < amount
                || userBalance - userClaimedGovernance[msg.sender] < amount
        ) revert InsufficientUnderlying();//@audit-ok is there anyway to bypass transfer balance check?

        return super.transfer(to, amount);
    }

    /**
     * @notice Transfer bHermes and its underlying tokens from a specific account
     * @param from address to transfer the tokens from
     * @param to address to transfer the tokens to
     * @param amount amounts of tokens to transfer
     */

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 userBalance = balanceOf[from];

        if (
            userBalance - userClaimedWeight[from] < amount || userBalance - userClaimedBoost[from] < amount
                || userBalance - userClaimedGovernance[from] < amount
        ) revert InsufficientUnderlying();

        return super.transferFrom(from, to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Insufficient Underlying assets in the vault for transfer.
    error InsufficientUnderlying();
}
