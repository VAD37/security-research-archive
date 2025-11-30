// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "forge-ctf/CTFDeployer.sol";

import "src/Challenge.sol";

contract Deploy is CTFDeployer {
    uint32 constant MERKLE_TREE_HEIGHT=20;
    
    uint constant ETH_AMOUNT=100000000000000000; // in wei

    function deployContract(bytes memory bytecode ) public returns (address deployed) {
      assembly{
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(extcodesize(deployed)) {
                revert(0, 0)
            }
      }
   }
    function deploy(address system, address player) internal override returns (address challenge) {
        vm.startBroadcast(system);

        challenge = address(new Challenge{value:10 ether}(player));
        
        vm.stopBroadcast();
    }
}