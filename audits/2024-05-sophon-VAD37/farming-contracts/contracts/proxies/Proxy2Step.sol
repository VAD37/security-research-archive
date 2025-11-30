// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./Upgradeable2Step.sol";

contract Proxy2Step is Upgradeable2Step {

    constructor(address impl_) {
        implementation = impl_;
    }

    fallback() external virtual payable {
        assembly {
            calldatacopy(0, 0, calldatasize())//@ok dirty bit if use whole slot. Next storage is mapping. it use whole slot
            let result := delegatecall(gas(), sload(implementation.slot), 0, calldatasize(), 0, 0)//@ pass calldata to impl
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external virtual payable {}
}
