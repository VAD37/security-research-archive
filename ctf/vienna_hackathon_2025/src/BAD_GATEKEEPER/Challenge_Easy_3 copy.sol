// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

contract ChallengeEasy3 {
    bytes32 private constant _Z1 = 0x000000000000000000000000000000000000000000000000FFFFF0000000FFFF;
    bytes32 private constant _Z2 = 0xDEADBEEFCAFEBABEFEEDFACEDEADC0DEBEEFCAFEBABEFEED0000000000000000;

    uint256 public reenter = 1;

    modifier nonReentrant {
        reenter = 2;
        _;
        reenter = 1;
    }

    constructor(address x) {
        assembly {
            sstore(0x01, x)
            sstore(0x02, 0x00)
        }
    }

    function z9(bytes8 a, address b) public {
        require(reenter == 2, "reentrant");
        require(msg.sender != b, "invalid b");//b must have contract code

        bytes8 m = 0xFFFFF0000000FFFF;
        bytes8 t;
        bytes32 codeHash;
        bytes32 reqHash1 = bytes32(0);
        bytes32 reqHash2 = keccak256("");

        assembly {
            codeHash := extcodehash(b)
        }

        assembly {
            if eq(origin(), caller()) {//@must call through contract proxy
                invalid()
            }

            t := and(a, m)
            if iszero(eq(a, t)) {// mask check: a & m == a
                revert(0, 0)
            }

            if eq(eq(codeHash, reqHash1), 1) {// input address must be contract and have code
                revert(0, 0)
            }

            if eq(eq(codeHash, reqHash2), 1) {// input address must be contract and have code
                revert(0, 0)
            }

            sstore(0x02, b)// STORE address b as “approved caller”
        }
    }

    function z1(bytes8 x, address y) external nonReentrant {
        z9(x, y);
    }

    function z3() external pure returns (bytes32) {
        return _Z2;
    }

    function z4() external view returns (address) {
        assembly {
            mstore(0x00, sload(0x01))
            return(0x00, 0x20)
        }
    }

    fallback() external payable {
        assembly {
            mstore(0x00, caller())
            mstore(0x20, number())
            return(0, 0)
        }
    }

    function z5() external {
        address a;
        address b;

        assembly {
            a := sload(0x02)// get approved caller address
            b := caller()// msg.sender
        }

        if (a != b) {
            assembly {// Unapproved caller
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 0x1556e617574686f72697a656400000000000000000000000000000000000000)
                revert(0x00, 0x64)
            }
        }

        address t;
        bytes32 player = bytes32(uint256(uint160(a)));
        
        assembly {
            t := sload(0x01)
            // get pot address, pot addPoint()
            mstore(0x00, 0xad7b985e00000000000000000000000000000000000000000000000000000000)

            mstore(0x04, player)//@give point to player address
            
            let s := call(gas(), t, 0, 0x00, 0x24, 0, 0)

            if eq(s, 0) {
                revert(0, 0)
            }
        }
    }

    function z6() external view returns (address r) {
        assembly {
            r := sload(0x01)
        }
    }

    function z7() external view returns (address r) {
        assembly {
            r := sload(0x02)
        }
    }

    receive() external payable {}
}