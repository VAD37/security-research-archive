/// SPDX-License-Identifier: BUSL-1.1

/// Copyright (C) 2023 Brahma.fi

pragma solidity 0.8.19;
//import foundry test
import "forge-std/Test.sol";
import {AddressProviderService} from "../AddressProviderService.sol";

/**
 * @title WalletRegistry
 * @author Brahma.fi
 * @notice Registry for wallet and sub account addresses
 */
contract WalletRegistry is AddressProviderService {
    error AlreadyRegistered();
    error InvalidSender();
    error IsSubAccount();

    event RegisterWallet(address indexed wallet);
    event RegisterSubAccount(address indexed wallet, address indexed subAccount);

    /// @notice subAccount addresses mapped to owner wallet
    mapping(address subAccount => address wallet) public subAccountToWallet;
    /// @notice wallet addresses mapped to list of subAccounts
    mapping(address wallet => address[] subAccountList) public walletToSubAccountList;
    /// @notice address of wallet mapped to boolean indicating if it's a wallet
    mapping(address => bool) public isWallet;

    constructor(address _addressProvider) AddressProviderService(_addressProvider) {}

    /**
     * @notice Registers a wallet
     * @dev Can only be called by safe deployer or the wallet itself
     */
    function registerWallet() external {
        if (isWallet[msg.sender]) revert AlreadyRegistered();
        if (subAccountToWallet[msg.sender] != address(0)) revert IsSubAccount();//@audit H this can be bypassed. subaccount created through manual direct mode through gnosis safe factory. 
        isWallet[msg.sender] = true;
        emit RegisterWallet(msg.sender);
    }

    /**
     * @notice Registers a sub account for a Safe
     * @param _wallet Console account address, owner of sub account
     * @param _subAccount Sub account address to register
     * @dev Can only be called by safe deployer
     */

    function registerSubAccount(address _wallet, address _subAccount) external {
        console.log("registerSubAccountSender:",msg.sender,AddressProviderService._getAuthorizedAddress(_SAFE_DEPLOYER_HASH));
        if (msg.sender != AddressProviderService._getAuthorizedAddress(_SAFE_DEPLOYER_HASH)) revert InvalidSender();//@audit M how msg.sender can be safeDeployer if caller is gnosisFactory?
        if (subAccountToWallet[_subAccount] != address(0)) revert AlreadyRegistered();
        subAccountToWallet[_subAccount] = _wallet;//@audit-ok M can frontrun register someone else wallet
        walletToSubAccountList[_wallet].push(_subAccount);//@audit cannot change subaccount original owner/creator. but can add new owners[] or executor
        emit RegisterSubAccount(_wallet, _subAccount);
    }

    /**
     * @notice sub account list getter
     * @dev returns sub account list associated with _wallet
     * @param _wallet safe address
     * @return list of subAccounts for wallet
     */
    function getSubAccountsForWallet(address _wallet) external view returns (address[] memory) {
        return walletToSubAccountList[_wallet];
    }

    /**
     * @notice checks if _wallet owns _subAccount
     * @param _wallet address of wallet
     * @param _subAccount address of subAccount
     * @return isWalletOwnerOfSubAccount
     */
    function isOwner(address _wallet, address _subAccount) external view returns (bool) {
        return subAccountToWallet[_subAccount] == _wallet;
    }
}
