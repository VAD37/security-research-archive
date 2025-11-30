// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ERC2771Forwarder, ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "src/FANG'S_VENOM/Challenge_Medium_2.sol";

contract ChallengeEasy5Test is Test {
    /// address of the deployed challenge on mainnet (forked)
    ChallengeMedium2 public challenge = ChallengeMedium2(payable(0x8919B92F52bb8C1aF7C9AFeE2Bdd179d3272919e));

    Vm.Wallet user = vm.createWallet("user"); // EOA with private key

    function setUp() public {
        // fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 24_908_500);
    }

    function testSolve6() public {
        console.logBytes32(challenge.retrieve_0x37c8bb82()); //0x98de0bff1fd1afdd3978d3dc3a57fc8af4b4d05ca4d23f4ec3593c0276ce0eb9
        console.log("complex:", challenge.getComplexityScore()); //81839643953218953315535426257876167177938413872904048004191263811280539072814
        console.logBytes32(bytes32(challenge.getComplexityScore())); //81839643953218953315535426257876167177938413872904048004191263811280539072814
        console.logBytes32(challenge.getSystemMetadata());
    }

    function testDummy() public {
    bytes32  MAGIC_NUMBER = 0x8badf00d8badf00d8badf00d8badf00d8badf00d8badf00d8badf00d8badf00d;
    bytes32  XOR_MASK = 0xf00df00df00df00df00df00df00df00df00df00df00df00df00df00df00df00d;
        
        bytes32 mask = XOR_MASK ^ MAGIC_NUMBER;//0x7ba000007ba000007ba000007ba000007ba000007ba000007ba000007ba00000
        console.logBytes32(mask);
        bytes32 intermediate = 0x7ba000007ba000007ba000007ba000007ba000007ba000007ba000007ba00000;
        bytes32 rotated = bytes32((uint256(intermediate) << 1) | (uint256(intermediate) >> 255));
        console.logBytes32(rotated); //0x7ba000007ba000007ba000007ba000007ba000007ba000007ba000007ba00000
        
        bytes32 codeHash;
        bytes32 reqHash1 = bytes32(0);
        bytes32 reqHash2 = keccak256("");
        address r = address(0xafab1f131b3a21b2a1b23a123f1f231b1212);
        assembly {
            codeHash := extcodehash(r)
        }
        console.logBytes32(codeHash); //0x
        console.logBytes32(reqHash1); //0x
        console.logBytes32(reqHash2); //0x
        
    }
}
