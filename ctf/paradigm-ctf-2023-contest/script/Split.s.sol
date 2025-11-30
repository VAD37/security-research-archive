// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "test/Split.t.sol";
import "forge-std/Vm.sol";


contract SplitScript is Script {
    Challenge challenge = Challenge(address(0xE9c7Ab98685b303422E40E14451d42c2Ea6fE234));
    uint deployerPrivateKey = 0x3d1a6946ba05145f601a94a39ae17fd27a0a1c0732fbdb56acbf3ff870140c55;

    function setUp() public {
        
    }


    function run() public {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey, "attacker");        
        console.log("attacker wallet: ", wallet.addr);
        console.log("balance: %e", address(wallet.addr).balance);

        vm.startBroadcast(deployerPrivateKey);
        ////////////////
        SplitSolver solver = new SplitSolver(challenge);
        console.log("solver: ", address(solver));
        payable(solver).transfer(0.5e21);
        console.log("try solve");
        solver.solve();

        console.log("is solved: ", challenge.isSolved());
        ////////////////
        vm.stopBroadcast();
    }
}
