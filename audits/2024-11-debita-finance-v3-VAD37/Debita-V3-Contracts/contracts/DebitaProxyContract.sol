pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Proxy.sol";
contract DebitaProxyContract is Proxy {
    constructor(address _logic) {
        bytes32 implementationPosition = bytes32(
            uint256(keccak256("eip1967.implementationSlot")) - 1
        );
        assembly {
            sstore(implementationPosition, _logic)//@audit-ok non accept EIP, M nonstandard ERP1967 slot. this will prevent etherscan from finding correct proxy implementation
        }
    }
    function _implementation() internal view override returns (address) {
        bytes32 implementationPosition = bytes32(
            uint256(keccak256("eip1967.implementationSlot")) - 1
        );
        address implementationAddress;
        // sload and return implementationPosition
        assembly {
            implementationAddress := sload(implementationPosition)
        }
        return implementationAddress;
    }
}
