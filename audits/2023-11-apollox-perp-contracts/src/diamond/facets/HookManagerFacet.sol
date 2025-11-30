// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ZeroAddress, ITradingPortalError} from "../../utils/Errors.sol";
import "../../dependencies/IAPXCallback.sol";
import "../interfaces/IHookManager.sol";
import "../libraries/LibHookManager.sol";
import "../libraries/LibAccessControlEnumerable.sol";
import "../../utils/Constants.sol";
contract HookManagerFacet is IHookManager, IHookManagerError {

    function addPartner(
        string calldata name, string calldata url, address protocolAddress, address callbackReceiver
    ) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        if (protocolAddress == address(0)) revert ZeroAddress();
        LibHookManager.addPartner(name, url, protocolAddress, callbackReceiver);
    }

    function updatePartnerName(address protocolAddress, string calldata name) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibHookManager.Partner storage p = LibHookManager.hookManagerStorage().partners[protocolAddress];
        if (p.callbackReceiver == address(0)) {
            revert NonexistentPartner(protocolAddress);
        }
        p.name = name;
        emit UpdatePartnerName(protocolAddress, name);
    }

    function updatePartnerUrl(address protocolAddress, string calldata url) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibHookManager.Partner storage p = LibHookManager.hookManagerStorage().partners[protocolAddress];
        if (p.callbackReceiver == address(0)) {
            revert NonexistentPartner(protocolAddress);
        }
        p.url = url;
        emit UpdatePartnerUrl(protocolAddress, url);
    }

    function updatePartnerCallbackReceiver(address protocolAddress, address callbackReceiver) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibHookManager.Partner storage p = LibHookManager.hookManagerStorage().partners[protocolAddress];
        if (p.callbackReceiver == address(0)) {
            revert NonexistentPartner(protocolAddress);
        }
        p.callbackReceiver = callbackReceiver;
        emit UpdatePartnerCallbackReceiver(protocolAddress, callbackReceiver);
    }

    function getPartnerByAddress(address protocolAddress) external view override returns (uint256 blockNumber, PartnerInfo memory) {
        LibHookManager.Partner storage p = LibHookManager.hookManagerStorage().partners[protocolAddress];
        return (block.number, PartnerInfo(p.name, p.url, protocolAddress, p.callbackReceiver, p.gasCost));
    }

    function partners(uint start, uint8 length) external view override returns (uint256 blockNumber, PartnerInfo[] memory) {
        LibHookManager.HookManagerStorage storage hms = LibHookManager.hookManagerStorage();
        address[] storage protocols = hms.protocolAddresses;
        if (start >= protocols.length || length == 0) {
            return (block.number, new PartnerInfo[](0));
        }
        uint count = length <= protocols.length - start ? length : protocols.length - start;
        PartnerInfo[] memory partnerInfos = new PartnerInfo[](count);
        for (uint i; i < count; i++) {
            address protocolAddress = protocols[start + i];
            LibHookManager.Partner storage p = hms.partners[protocolAddress];
            partnerInfos[i] = PartnerInfo(p.name, p.url, protocolAddress, p.callbackReceiver, p.gasCost);
        }
        return (block.number, partnerInfos);
    }

    function afterMarketExecuted(bytes32 tradeHash, ITrading.OpenTrade memory ot) external override {
        LibHookManager.Partner storage p = LibHookManager.hookManagerStorage().partners[ot.user];
        if (p.callbackReceiver != address(0)) {
            uint256 gasBefore = gasleft();
            try IAPXCallback(p.callbackReceiver).afterMarketExecuted(tradeHash, ot) {} catch Error(string memory) {}
            unchecked {
                uint256 gasCost = (gasBefore - gasleft() + 1e5) * tx.gasprice;
                p.gasCost += gasCost;
            }
        }
    }

    function afterMarketRefund(bytes32 tradeHash, address user, ITradingChecker.Refund refund) external override {
        LibHookManager.Partner storage p = LibHookManager.hookManagerStorage().partners[user];
        if (p.callbackReceiver != address(0)) {
            uint256 gasBefore = gasleft();
            try IAPXCallback(p.callbackReceiver).afterMarketRefund(tradeHash, refund) {} catch Error(string memory) {}
            unchecked {
                uint256 gasCost = (gasBefore - gasleft() + 1e5) * tx.gasprice;
                p.gasCost += gasCost;
            }
        }
    }

    function afterClose(bytes32 tradeHash, address user, CloseInfo memory info) external override {
        LibHookManager.Partner storage p = LibHookManager.hookManagerStorage().partners[user];
        if (p.callbackReceiver != address(0)) {
            uint256 gasBefore = gasleft();
            try IAPXCallback(p.callbackReceiver).afterClose(tradeHash, info) {} catch Error(string memory) {}
            unchecked {
                uint256 gasCost = (gasBefore - gasleft() + 1e5) * tx.gasprice;
                p.gasCost += gasCost;
            }
        }
    }
}