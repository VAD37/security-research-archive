// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import "./BytesLib.sol";
contract Lockbox2 {

    bool public locked = true;
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function solve() external {
        console.logBytes(msg.data);
        bool[] memory successes = new bool[](5);
        (successes[0],) = address(this).delegatecall(abi.encodePacked(this.stage1.selector, msg.data[4:]));
        (successes[1],) = address(this).delegatecall(abi.encodePacked(this.stage2.selector, msg.data[4:]));
        (successes[2],) = address(this).delegatecall(abi.encodePacked(this.stage3.selector, msg.data[4:]));
        (successes[3],) = address(this).delegatecall(abi.encodePacked(this.stage4.selector, msg.data[4:]));
        (successes[4],) = address(this).delegatecall(abi.encodePacked(this.stage5.selector, msg.data[4:]));
        for (uint256 i = 0; i < 5; ++i) require(successes[i]);
        locked = false;
    }

    function stage1() external {
        require(msg.data.length < 500);
        console.log("stage1 length:",msg.data.length);
    }

    function stage2(uint256[4] calldata arr) external {
        for (uint256 i = 0; i < arr.length; ++i) {
            require(arr[i] >= 1);
            for (uint256 j = 2; j < arr[i]; ++j) {
                require(arr[i] % j != 0);
            }
        }
        console.log("solve stage2");
    }

    function stage3(uint256 a, uint256 b, uint256 c) external {
        vm.breakpoint("d");
        assembly { mstore(a, b) }// store into memory 0xb into 0xa. Static call did call load from memory 0x40
        (bool success, bytes memory data) = address(uint160(a + b)).staticcall("");
        console.log("weirdAddress:",address(uint160(a + b)) );
        console.logBytes(data);
        console.log(data.length);
        require(success && data.length == c);
        console.log("solve stage3");
    }

    function stage4(bytes memory a, bytes memory b) external {
        address addr;
        assembly { addr := create(0, add(a, 0x20), mload(a)) }
        (bool success, ) = addr.staticcall(b);
        require(tx.origin == address(uint160(uint256(addr.codehash))) && success);
        console.log("solve stage4");
    }

    function stage5() external {
        if (msg.sender != address(this)) {
            (bool success,) = address(this).call(abi.encodePacked(this.solve.selector, msg.data[4:]));
            require(!success);
        }
        console.log("solve stage5");
    }
}

contract LockboxTest is Test {
    Lockbox2 lockbox;

    function setUp() public {
        lockbox = new Lockbox2();
    }

    function testBreak() public {
        
        bytes memory solveData;
        //stage 2: 4 prime number
        //2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97
        uint[4] memory array = [uint(97),uint(431),uint(1),uint(1)];
        solveData = abi.encodePacked(array);
        // stage 3 need a+b into address precompiled contract
        // stage 4 have another check

        //stage 1
        assertLt(solveData.length,500);
        (bool success,) = address(lockbox).call(abi.encodePacked(lockbox.solve.selector, solveData));
    }
}
