// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract BasicTest is Test {
    function setUp() public {}

    function testDebugDecode() public {
        bytes memory _data =
            hex"803ba26d0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000c96d4f72f69d6eb6000000000000000000000000000000000000000000000000001183062edd8e710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b99d8a9c45b2eca8864373a26d1459e3dff1e17f3002710c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000869584cd00000000000000000000000008a3c2a819e3de7aca384c798269b3ce1cd0e437000000000000000000000000000000002038022d7f26996da7c5918108798368";
        // 0x803ba26d0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000c96d4f72f69d6eb6000000000000000000000000000000000000000000000000001183062edd8e710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b99d8a9c45b2eca8864373a26d1459e3dff1e17f3002710c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000869584cd00000000000000000000000008a3c2a819e3de7aca384c798269b3ce1cd0e437000000000000000000000000000000002038022d7f26996da7c5918108798368;
        vm.breakpoint("u");
        (address inputToken, address outputToken, uint256 inputTokenAmount, address recipient, bytes4 selector) = _decodeUniswapV3Data(_data);
        // console.log("inputToken: ", inputToken);
        // console.log("outputToken: ", outputToken);
        // console.log("inputTokenAmount: ", inputTokenAmount);
        // console.log("recipient: ", recipient);
        // console.logBytes32(bytes32(selector));
    }

    /**
     * @notice Decodes the data sent from 0x API when UniswapV3 is used
     * @param _data      swap data from 0x API
     */
    function _decodeUniswapV3Data(bytes memory _data)
        internal
        
        returns (address inputToken, address outputToken, uint256 inputTokenAmount, address recipient, bytes4 selector)
    {
        uint256 encodedPathLength;
        vm.breakpoint("i");
        assembly {
            let p := 0
            selector := calldataload(p) //@selector is dirty. this only take 4 bytes of data
            p := add(p, 36) // Data: selector 4 + lenght data 32
            inputTokenAmount := calldataload(p)
            recipient := calldataload(add(p, 64))
            encodedPathLength := calldataload(add(p, 96)) // Get length of encodedPath (obtained through abi.encodePacked)
            inputToken := shr(96, calldataload(add(p, 128))) // Shift to the Right with 24 zeroes (12 bytes = 96 bits) to get address
            outputToken := shr(96, calldataload(add(p, add(encodedPathLength, 108)))) // Get last address of the hop
        }
    }

    /**
     * @notice Decodes the data sent from 0x API when other exchanges are used via 0x TransformERC20 function
     * @param _data      swap data from 0x API
     */
    function _decodeTransformERC20Data(bytes memory _data)
        internal
        
        returns (address inputToken, address outputToken, uint256 inputTokenAmount, bytes4 selector)
    {
        vm.breakpoint("o");
        assembly {
            let p := 0
            selector := calldataload(p)
            inputToken := calldataload(add(p, 4)) // Read slot, selector 4 bytes
            outputToken := calldataload(add(p, 36)) // Read slot
            inputTokenAmount := calldataload(add(p, 68)) // Read slot
        }
    }
}
