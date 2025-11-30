// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

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

contract RandomScript is Script {
     Setup setup = Setup(address(0x7884aF24899713e47A539cf943ab607A3fDaB183));

    function setUp() public {
        
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ////////////////
        console.log("is solved before: %s", setup.random().solved());
        setup.random().solve(4);
        console.log("is solved after: %s", setup.random().solved());

        ////////////////
        vm.stopBroadcast();
    }
}
