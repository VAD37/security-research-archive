// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {IPot} from "src/IPot.sol";

contract ChallengeEasy1 is ERC2771Context {
    error INVALID_SENDER();

    IPot public immutable pot;

    constructor(address _pot, address _forwarder) ERC2771Context(_forwarder) {
        pot = IPot(_pot);
    }

    modifier onlyContract() {
        assembly ("memory-safe") {
            if iszero(extcodesize(caller())) {
                mstore(0x00, 0xb78bd21b)
                revert(0x1c, 0x04)
            }
        }
        _;
    }

    function solve() external onlyContract {
        pot.addPoints(_msgSender());
    }

}
