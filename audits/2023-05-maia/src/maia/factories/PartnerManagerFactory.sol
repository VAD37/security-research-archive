// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {console} from "forge-std/console.sol";
import {IPartnerManagerFactory} from "../interfaces/IPartnerManagerFactory.sol";
import {ERC4626PartnerManager as PartnerManager, IBaseVault} from "../tokens/ERC4626PartnerManager.sol";

/// @title Factory for managing PartnerManagers
contract PartnerManagerFactory is Ownable, IPartnerManagerFactory {
    /*//////////////////////////////////////////////////////////////
                         PARTNER MANAGER STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPartnerManagerFactory
    ERC20 public immutable override bHermes;

    /// @inheritdoc IPartnerManagerFactory
    PartnerManager[] public override partners;

    /// @inheritdoc IPartnerManagerFactory
    IBaseVault[] public override vaults;

    /// @inheritdoc IPartnerManagerFactory
    mapping(PartnerManager => uint256) public override partnerIds;

    /// @inheritdoc IPartnerManagerFactory
    mapping(IBaseVault => uint256) public override vaultIds;

    /**
     * @notice Initializes the contract with the owner and bHermes token.
     * @param _bHermes The address of the bHermes token.
     * @param _owner The owner of the contract.
     */
    constructor(ERC20 _bHermes, address _owner) {
        _initializeOwner(_owner);
        bHermes = _bHermes;
        partners.push(PartnerManager(address(0)));
    }

    /// @inheritdoc IPartnerManagerFactory
    function getPartners() external view returns (PartnerManager[] memory) {
        return partners;
    }

    /// @inheritdoc IPartnerManagerFactory
    function getVaults() external view returns (IBaseVault[] memory) {
        return vaults;
    }

    function getPartnerId(PartnerManager partnerManager) external view returns (uint256) {
        return partnerIds[partnerManager];
    }

    function getVaultId(address vaultAddress) external view returns (uint256) {
        return vaultIds[IBaseVault(vaultAddress)];
    }

    /*//////////////////////////////////////////////////////////////
                        NEW PARTNER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPartnerManagerFactory
    function addPartner(PartnerManager newPartnerManager) external onlyOwner {
        uint256 id = partners.length;
        partners.push(newPartnerManager);
        partnerIds[newPartnerManager] = id;

        emit AddedPartner(newPartnerManager, id);
    }

    /// @inheritdoc IPartnerManagerFactory
    function addVault(IBaseVault newVault) external onlyOwner {
        uint256 id = vaults.length;
        vaults.push(newVault);
        vaultIds[newVault] = id;
        emit AddedVault(newVault, id);
    }

    /*//////////////////////////////////////////////////////////////
                        MIGRATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPartnerManagerFactory
    function removePartner(PartnerManager partnerManager) external onlyOwner {//@audit-ok L lack safety check for remove init zero address for zero ID
        if (partners[partnerIds[partnerManager]] != partnerManager) revert InvalidPartnerManager();
        delete partners[partnerIds[partnerManager]];
        delete partnerIds[partnerManager];//@audit-ok. delete array does not pop array index. add and remove dictionary here does not swap index to removed item cause duplicate length ID as Index ID

        emit RemovedPartner(partnerManager);
    }

    /// @inheritdoc IPartnerManagerFactory
    function removeVault(IBaseVault vault) external onlyOwner {
        if (vaults[vaultIds[vault]] != vault) revert InvalidVault();
        delete vaults[vaultIds[vault]];
        delete vaultIds[vault];

        emit RemovedVault(vault);
    }
}
