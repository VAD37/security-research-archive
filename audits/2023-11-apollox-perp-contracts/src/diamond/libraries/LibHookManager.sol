// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IHookManagerError} from "../../utils/Errors.sol";

library LibHookManager {

    bytes32 constant HOOK_MANAGER_POSITION = keccak256("apx.hook.manager.storage");

    struct Partner {
        string name;
        string url;
        uint256 gasCost;
        address callbackReceiver;
        uint24 partnerIndex;
    }

    struct HookManagerStorage {
        mapping(address protocolAddress => Partner) partners;
        address[] protocolAddresses;
    }

    function hookManagerStorage() internal pure returns (HookManagerStorage storage hms) {
        bytes32 position = HOOK_MANAGER_POSITION;
        assembly {
            hms.slot := position
        }
    }

    event AddPartner(address indexed protocolAddress, Partner partner);

    function addPartner(
        string calldata name, string calldata url, address protocolAddress, address callbackReceiver
    ) internal {
        HookManagerStorage storage hms = hookManagerStorage();
        Partner storage partner = hms.partners[protocolAddress];
        if (partner.callbackReceiver != address(0)) {
            revert IHookManagerError.ExistentPartner(protocolAddress, partner.name, partner.url);
        }
        hms.partners[protocolAddress] = Partner(name, url, 0, callbackReceiver, uint24(hms.protocolAddresses.length));
        hms.protocolAddresses.push(protocolAddress);
        emit AddPartner(protocolAddress, partner);
    }
}
