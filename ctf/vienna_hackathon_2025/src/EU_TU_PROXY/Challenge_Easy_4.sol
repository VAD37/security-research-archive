// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;
//0xb73E7da3fA04A37bbE6be13CA4f1eC68b82a8A26
contract ChallengeEasy4 {
    bytes32 private constant _MASK = 0x8b1a3d44d0f5ba0c17d3f5f631e2df0348578f5f18b6f83b51dd8713f55e250a;
    uint256 private _seed;//@pot address
    bytes32 private _vault;//sload(2) == owner
    bytes32 private _proxy;

    constructor(address _a, address _b) {
        assembly {
            sstore(0, _a)
            sstore(1, xor(_b, 0x0000000000000000000000000000000000000000000000000000000000000000))
            sstore(2, caller())
        }
    }

    function _pot() internal view returns (address) {
        address _addr;
        assembly {
            _addr := sload(0)
        }
        return _addr;
    }

    function _0x58f31a09() internal view returns (address) {
        address _addr;
        assembly {
            _addr := sload(1)
        }
        return _addr;
    }

    function _vaultAddr() internal view returns (address) {
        address _addr;
        assembly {
            _addr := sload(2)
        }
        return _addr;
    }

    receive() external payable {
        assembly {
            mstore(0x00, 0x4e487b7100000000000000000000000000000000000000000000000000000000)
            mstore(0x04, 0x0000001100000000000000000000000000000000000000000000000000000000)
            revert(0x00, 0x24)
        }
    }

    fallback() external payable {
        address _t;
        assembly {
            _t := sload(1)
        }

        assembly {
            calldatacopy(0, 0, calldatasize())
            let r := delegatecall(gas(), _t, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch r
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _verifyAccess() internal view returns (bool) {
        return msg.sender == _vaultAddr();
    }
    //0x09aec97a == breakTheWall()
    function _0x57c1669d() public {
        require(_verifyAccess(), "0x41636365737320766f6c6174696f6e");

        address _pot = _pot();
        address _usr = msg.sender;

        (bool _s,) = _pot.call(abi.encodeWithSelector(bytes4(keccak256("addPoints(address)")), _usr));

        if (!_s) {
            assembly {
                revert(0, 0)
            }
        }
    }

    function pot() external view returns (address) {
        return _pot();
    }

    function owner() external view returns (address) {
        return _vaultAddr();
    }

    function breakTheWall() external {
        _0x57c1669d();//@call solve
    }
}
