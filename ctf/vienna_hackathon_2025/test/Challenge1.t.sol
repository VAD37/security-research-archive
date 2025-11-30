// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ERC2771Forwarder, ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ChallengeEasy1} from "src/MIGHTY'S_IDENTITY_CRISIS/Challenge_Easy_1.sol";

contract ChallengeEasy1Test is Test {
    /// address of the deployed challenge on mainnet (forked)
    address constant CHALLENGE = 0x1237B533A88612E27aE447f7D84aa7Eb6722e39D;

    Vm.Wallet user = vm.createWallet("user"); // EOA with private key
    Challenge1Solver solver;
    
    function setUp() public {
        // fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 24_908_500);

        // deploy our little helper that batches meta-txs
        solver = new Challenge1Solver(CHALLENGE);
    }

    function _testSolve1() public {
        // grab the forwarder to log it
        address fwd = ERC2771Context(CHALLENGE).trustedForwarder();
        console.log("Forwarder:", fwd);

        // pretend all calls come from our user EOA
        vm.startPrank(user.addr);

        // build the next meta-tx + its digest
        (bytes32 digest, ERC2771Forwarder.ForwardRequestData memory req) = solver.buildNextDigest();
        if (digest == bytes32(0)) {
            console.log("already solved");
            return;
        }

        // sign with our EOA key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user, digest);
        req.signature = abi.encodePacked(r, s, v);

        // execute through the forwarder
        solver.execute(req);
    }
}

/// @notice Helper contract that wraps the ERC2771 logic
contract Challenge1Solver {
    ChallengeEasy1 public immutable challenge;
    ERC2771Forwarder public immutable forwarder;

    constructor(address _challenge) {
        challenge = ChallengeEasy1(_challenge);
        forwarder = ERC2771Forwarder(ERC2771Context(_challenge).trustedForwarder());
    }

    function execute(ERC2771Forwarder.ForwardRequestData memory req) public {
        forwarder.execute(req);
    }

    function getNonces() public view returns (uint256) {
        return ERC2771Forwarder(challenge.trustedForwarder()).nonces(msg.sender);
    }
    /// Build the meta-tx and EIP-712 digest

    function buildNextDigest() public view returns (bytes32, ERC2771Forwarder.ForwardRequestData memory req) {
        uint256 nonce = getNonces();
        bytes memory data = abi.encodeWithSignature("solve()");

        req = ERC2771Forwarder.ForwardRequestData({
            from: msg.sender,
            to: address(challenge),
            value: 0,
            gas: 1_000_000,
            deadline: type(uint48).max,
            data: data,
            signature: ""
        });

        // compute struct hash
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
                ),
                req.from,
                req.to,
                req.value,
                req.gas,
                nonce,
                req.deadline,
                keccak256(req.data)
            )
        );

        // compute domain separator
        (, string memory name, string memory version, uint256 chainId,,,) = forwarder.eip712Domain();

        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                address(forwarder)
            )
        );

        // final EIP-712 digest
        return (MessageHashUtils.toTypedDataHash(domain, structHash), req);
    }
}
