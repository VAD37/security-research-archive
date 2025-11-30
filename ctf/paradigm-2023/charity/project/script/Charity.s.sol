// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "src/Router.sol";
import "src/Challenge.sol";

contract CharityScript is Script {
    Challenge challenge =
        Challenge(address(0x4D2a60E8ccEa87926344409b55F3752bDF3eCfB4));
    uint deployerPrivateKey =
        0x95df4dce53bd7fc6c2cb86b87480bd50f51b49003cb165f0abe54b1da867c76e;

    Router router;

    function setUp() public {
        router = Router(challenge.ROUTER());
    }

    function run() public {
        VmSafe.Wallet memory wallet = vm.createWallet(
            deployerPrivateKey,
            "attacker"
        );
        address owner = wallet.addr;
        console.log("attacker wallet: ", owner);
        console.log("balance: %e", owner.balance);

        vm.startBroadcast(deployerPrivateKey);
        ////////////////

        console.log("list token count: ", router.listingTokensCount());
        console.log("lp token count: ", router.lpTokensCount());

        router.createToken("name", "symbol");
        

        ////////////////
        vm.stopBroadcast();
    }
}
