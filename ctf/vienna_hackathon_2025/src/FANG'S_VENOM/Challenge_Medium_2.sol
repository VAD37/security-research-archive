// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPot} from "src/IPot.sol";

contract ChallengeMedium2 {
    bytes32 private constant MAGIC_NUMBER = 0x8badf00d8badf00d8badf00d8badf00d8badf00d8badf00d8badf00d8badf00d;
    bytes32 private constant XOR_MASK = 0xf00df00df00df00df00df00df00df00df00df00df00df00df00df00df00df00d;

    uint256 private _state1;//0 hash of block.timestamp and block.prevrandao
    uint256 private _state2;//1 hash of block.number and blockhash(block.number - 1)
    uint256 private _state3;//2 hash of msg.sender and address(this)
    address private _state4;//3 pot

    bytes32 private _secretData;// 4 targetHash

    address private _controlAddr;

    bytes32 private _scrambledSalt;
    uint8 private _accessCounter;

    event StateTransition(uint256 indexed phase, bytes32 data);
    event VerificationAttempt(address indexed user, bool success);

    constructor(address _pot, bytes32 _targetHash) {
        assembly {
            sstore(3, _pot)
            sstore(4, _targetHash)
        }

        _state1 = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
        _state2 = uint256(keccak256(abi.encodePacked(block.number, blockhash(block.number - 1))));
        _state3 = uint256(keccak256(abi.encodePacked(msg.sender, address(this))));

        _controlAddr = msg.sender;
        _scrambledSalt = bytes32(_state1 ^ _state2);
        _accessCounter = 0;
    }

    function _updateSystemState() private {
        _state1 = uint256(keccak256(abi.encodePacked(_state1, _state2)));
        _state2 = uint256(keccak256(abi.encodePacked(_state2, _state3)));
        _state3 = uint256(keccak256(abi.encodePacked(_state3, _state4)));

        _accessCounter++;

        emit StateTransition(_accessCounter, bytes32(_state1));
    }

    function _decodeTarget() private view returns (bytes32) {
        bytes32 obfuscated;
        assembly {
            obfuscated := sload(4)
        }
        return obfuscated;
    }

    function _getController() private view returns (address) {
        address masked;
        assembly {
            masked := sload(3)
        }
        return masked;
    }
    //@ignore
    function _complexOperation(bytes32 input1, bytes32 input2) private pure returns (bytes32) {
        bytes32 intermediate = input1 ^ input2;
        bytes32 rotated = bytes32((uint256(intermediate) << 1) | (uint256(intermediate) >> 255));
        return rotated ^ MAGIC_NUMBER;
    }

    function _verifyInput(bytes32 input1, uint256 input2) private view returns (bool) {
        bytes32 hashedInputs = keccak256(abi.encodePacked(input1, input2));
        bytes32 target = _decodeTarget();

        return hashedInputs == target;
    }

    function _securityCheck() private view returns (bool) {
        if (_accessCounter >= 255) {
            return false;
        }

        if (block.timestamp % 2 == 1 && msg.sender == _controlAddr) {
            return false;
        }

        return true;
    }

    function _obscureData(bytes32 data) private view returns (bytes32) {
        return bytes32(uint256(data) ^ _state1 ^ uint256(_scrambledSalt));
    }

    function _retrievePot() private view returns (IPot) {
        address potAddr = _getController();
        return IPot(potAddr);
    }
    //@flag function. Entry point for the challenge.
    function imadeadbeef(bytes32 x, uint256 y) external {
        _0xdeadbeef(x, y);
    }

    function _executeReward(address recipient) private {
        _updateSystemState();

        IPot potInstance = _retrievePot();
        potInstance.addPoints(recipient);

        emit VerificationAttempt(recipient, true);
    }

    function getSystemMetadata() external view returns (bytes32) {
        return bytes32(uint256(block.number) ^ uint256(block.timestamp) ^ _state1);
    }
    //@entry 1
    function _0xdeadbeef(bytes32 _param1, uint256 _param2) public {
        bool _flag1 = _securityCheck();//@odd block transaction only
        require(_flag1, "System access denied");

        bool _flag2 = _verifyInput(_param1, _param2);//@input must hash into secret
        require(_flag2, "Challenge verification failed");

        _executeReward(msg.sender);
    }

    function _0xfeedface(bytes32 _x, bytes32 _y) external view returns (bytes32) {
        return _complexOperation(_x, _y);//@noise unused
    }

    function retrieve_0x37c8bb82() external view returns (bytes32) {
        return _decodeTarget();//@show secret hash function
    }

    function getAccessState() external view returns (uint8) {
        return _accessCounter;
    }

    function pot() external view returns (address) {
        return _getController();
    }

    function getComplexityScore() external view returns (uint256) {//@get current hash of the system state
        return uint256(keccak256(abi.encodePacked(_state1, _state2, _state3)));
    }

    receive() external payable {
        revert("Contract does not accept payments");
    }

    fallback() external payable {
        revert("Function signature not recognized");
    }
}
