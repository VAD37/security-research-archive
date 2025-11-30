// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract Random {

    bool public solved = false;

    function _getRandomNumber() internal pure returns (uint256) {   // chosen by fair dice roll.
        return 4;                                                   // guaranteed to be random.
    }
    
    function solve(uint256 guess) public {
        require(guess == _getRandomNumber());
        solved = true;
    }
}
contract Setup {

    Random public random;

    constructor() {
        random = new Random();
    }

    function isSolved() public view returns (bool) {
        return random.solved();
    }
}

contract RandomTest is Test {
    Setup setup = new Setup();

    function setUp() public {
        console.log("random: %s", address(setup.random()));
    }
    function testRandom() public {
        console.log("is solved before: %s", setup.random().solved());
        setup.random().solve(4);
        assertTrue(setup.isSolved());
    }
}
