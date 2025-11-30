// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MockToken} from "../MockToken.t.sol";

contract MockVe is MockToken {
    MockToken public AERO = new MockToken("AERO", "AERO");
    constructor(string memory name, string memory symbol) MockToken(name, symbol) {}

    function token() public view returns (address) {
        // return address(1024);//@note this cause Test issue with 0x400
        return address(this);
    }
}
