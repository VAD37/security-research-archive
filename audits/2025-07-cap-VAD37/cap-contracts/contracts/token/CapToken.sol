// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { Vault } from "../vault/Vault.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Cap Token https://etherscan.io/address/0xcccc62962d17b8914c62d74ffb843d73b2a3cccc#readProxyContract
/// @author kexley, Cap Labs
/// @notice Token representing the basket of underlying assets
contract CapToken is UUPSUpgradeable, Vault {//@note all capToken are Vault ERC4626. It accept all kinds of underlying assets and mint cToken
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the Cap token
    /// @param _name Name of the cap token
    /// @param _symbol Symbol of the cap token
    /// @param _accessControl Access controller
    /// @param _feeAuction Fee auction address
    /// @param _oracle Oracle address
    /// @param _assets Asset addresses to mint Cap token with
    /// @param _insuranceFund Insurance fund
    function initialize(
        string memory _name,//unqiue per asset, e.g. cUSD, cETH
        string memory _symbol,
        address _accessControl,//@shared AccessControl.sol contract
        address _feeAuction,//@unique FeeAuction.sol contract
        address _oracle,//shared Oracle.sol contract not chainlink, it read price directly from chainlink or other token adapter //@oracle also minter?
        address[] calldata _assets,// USDT,USDC,USDx or [WETH]
        address _insuranceFund//EOA
    ) external initializer {
        __Vault_init(_name, _symbol, _accessControl, _feeAuction, _oracle, _assets, _insuranceFund);
        __UUPSUpgradeable_init();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override checkAccess(bytes4(0)) { }
}
