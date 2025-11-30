// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// import {MathHarness} from "./harnesses/MathHarness.sol";
// import {Errors} from "@libraries/Errors.sol";
// import {LiquidityChunk, LiquidityChunkLibrary} from "@types/LiquidityChunk.sol";
// import {LiquidityAmounts} from "v3-periphery/libraries/LiquidityAmounts.sol";
// import {TickMath} from "v3-core/libraries/TickMath.sol";
// import {FullMath} from "v3-core/libraries/FullMath.sol";
import "forge-std/Test.sol";
import {PanopticMath} from "@libraries/PanopticMath.sol";
import {SafeTransferLib} from "@libraries/SafeTransferLib.sol";

contract Debugtest is Test {
    using SafeTransferLib for address;

    address FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address CRV = 0x58Dc5a51fE44589BEb22E8CE67720B5BC5378009;
    address UNI = 0xDafd66636E2561b0284EDdE37e42d192F2844D40;
    address COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    function setUp() public {}


    function testFRAXTransferRevertFuzz() public {
        uint256 to = (0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 amount = 1087893706350927760098536183485;
        deal(FRAX, address(this), amount);
        address _to;
        assembly ("memory-safe") {
            let pos := mload(0x40)
            mstore(pos, to)
            _to := mload(pos)
        }
        FRAX.safeTransfer(_to, amount);
    }
    function testUSDCTransferRevertFuzz() public {
        uint256 to = (0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 amount = 1087893706350927760098536183485;
        deal(USDC, address(this), amount);
        address _to;
        assembly ("memory-safe") {
            let pos := mload(0x40)
            mstore(pos, to)
            _to := mload(pos)
        }
        USDC.safeTransfer(_to, amount);
    }
    function testUSDTTransferRevertFuzz() public {
        uint256 to = (0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 amount = 1087893706350927760098536183485;
        deal(USDT, address(this), amount);
        address _to;
        assembly ("memory-safe") {
            let pos := mload(0x40)
            mstore(pos, to)
            _to := mload(pos)
        }
        USDT.safeTransfer(_to, amount);
    }
    function testCRVTransferRevertFuzz() public {
        uint256 to = (0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 amount = 1087893706350927760098536183485;
        deal(CRV, address(this), amount);
        address _to;
        assembly ("memory-safe") {
            let pos := mload(0x40)
            mstore(pos, to)
            _to := mload(pos)
        }
        CRV.safeTransfer(_to, amount);
    }
    function testUNITransferRevertFuzz() public {
        uint256 to = (0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 amount = 1087893706350927760098536183485;
        deal(UNI, address(this), amount);
        address _to;
        assembly ("memory-safe") {
            let pos := mload(0x40)
            mstore(pos, to)
            _to := mload(pos)
        }
        UNI.safeTransfer(_to, amount);
    }
    function testCOMPTransferRevertFuzz() public {
        uint256 to = (0x0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint256 amount = 1087893706350927760098536183485;
        deal(COMP, address(this), amount);
        address _to;
        assembly ("memory-safe") {
            let pos := mload(0x40)
            mstore(pos, to)
            _to := mload(pos)
        }
        COMP.safeTransfer(_to, amount);
    }





    // function testHashXOR() public {
    //     uint248 encode = (0x11002233ffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    //     console.log("%x", encode);
    //     console.log("%x", type(uint256).max); //0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    //     console.log("%x", type(uint248).max); //0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    //     console.log("%x", uint248(0x11002233ffffffffffffffffffffffffffffffffffffffffffffffff12ff00) ^ encode);
    // }
}
