// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../vanity/public/contracts/Setup.sol";
contract RandomTest is Test {
    Setup setup;
    bytes32 private immutable MAGIC = keccak256(abi.encodePacked("CHALLENGE_MAGIC"));
    function setUp() public {
        setup = new Setup();
    }

    function testHash() public {
        //double encode because sending input bytes memory not just uint
        bytes memory _calldata = abi.encodeWithSelector(IERC1271.isValidSignature.selector,MAGIC, abi.encode(uint(3341776893)));
        console.logBytes32(MAGIC);
        console.logBytes(_calldata);
        bytes32 _result = sha256(_calldata);
        console.logBytes32(_result);
        console.logBytes32(bytes32( IERC1271.isValidSignature.selector));
        //final result 0x1626ba7e
        (bool success, bytes memory result) = address(0x02).staticcall(
            abi.encodeWithSelector(IERC1271.isValidSignature.selector, MAGIC , abi.encode(uint(3341776893)))
        );
        assertEq(success, true);
        console.logBytes(result);

    }

    function testFoundHash() public {
        bytes4 selector = IERC1271.isValidSignature.selector;
        uint counter;
        for (uint i = 2080000000; i < 1e11; i++) {// 3341776890
            bytes32 _result = sha256(abi.encodeWithSelector(IERC1271.isValidSignature.selector,MAGIC, abi.encode(uint(i))));
            if (bytes4(_result) == selector) {
                console.log("found hash: %s", i);
                counter= i;
                break;
            }
            if (i%10000000 == 0)
                console.log("index: %s", i);
        }
        setup.challenge().solve(address(0x02), abi.encode(counter));
        assertEq(setup.isSolved(), true);
    }
}
