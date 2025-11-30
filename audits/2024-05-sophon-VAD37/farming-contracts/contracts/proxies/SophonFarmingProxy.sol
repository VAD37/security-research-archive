// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "./Proxy2Step.sol";

contract SophonFarmingProxy is Proxy2Step {

    constructor(address impl_) Proxy2Step(impl_) {}//@ impl = SophonFarming

    receive() external override payable {
        (bool success,) = implementation.delegatecall("");//@audit-ok proxy delegatecall for receive look like it will fail. calldata was not copy over?
        require(success, "subcall failed");
    }
}
