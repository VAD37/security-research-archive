// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.26;

contract ChallengeEasy3 {
    bytes32 private constant _Z1 = 0x000000000000000000000000000000000000000000000000FFFFF0000000FFFF;//@64 bitmask
    bytes32 private constant _Z2 = 0xDEADBEEFCAFEBABEFEEDFACEDEADC0DEBEEFCAFEBABEFEED0000000000000000;//@z3 poison

    uint256 public reenter = 1;

    modifier nonReentrant {
        reenter = 2;
        _;
        reenter = 1;
    }

    constructor(address x) {
        assembly {
            sstore(0x01, x)//slot 1 : x address
            sstore(0x02, 0x00)// slot 2 : zero address
        }
    }

    function z9(bytes8 a, address user) public {
        require(reenter == 2, "reentrant");
        require(msg.sender != user, "invalid b");

        bytes8 m = 0xFFFFF0000000FFFF;
        bytes8 t;
        bytes32 codeHash;
        bytes32 reqHash1 = bytes32(0);
        bytes32 reqHash2 = keccak256("");

        assembly {
            codeHash := extcodehash(user)
        }
        
        assembly {// 1) must not be an EOA direct call
            if eq(origin(), caller()) {
                invalid()
            }

            t := and(a, m)
            if iszero(eq(a, t)) { // 2) bitmask check: a & m == a            
                revert(0, 0)//input & 0xFFFFF0000000FFFF == input
            }

            if eq(eq(codeHash, reqHash1), 1) {  // 3) user must be a deployed contract
                revert(0, 0)
            }

            if eq(eq(codeHash, reqHash2), 1) {  // 3) user must be a deployed contract. non EOA check
                revert(0, 0)
            }

            sstore(0x02, user)// 4) all gates passed → record user as “approved caller”
        }
    }

    function z1(bytes8 x, address user) external nonReentrant {
        z9(x, user);//@entry point first call
    }

    function z3() external pure returns (bytes32) {
        return _Z2;// dead-beef constant
    }

    function z4() external view returns (address) {
        assembly {
            mstore(0x00, sload(0x01))//return pot address
            return(0x00, 0x20)
        }
    }

    fallback() external payable {//@do nothing
        assembly {
            mstore(0x00, caller())
            mstore(0x20, number())
            return(0, 0)
        }
    }

    function z5() external {
        address a;// stored secondary address
        address b;// msg.sender

        assembly {
            a := sload(0x02) //stored secondary address
            b := caller()
        }

        if (a != b) {// revert with custom “Unauthorized” string
            assembly {
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x04, 0x20)
                mstore(0x24, 0x1556e617574686f72697a656400000000000000000000000000000000000000)
                revert(0x00, 0x64)
            }
        }

        address t;
        bytes32 player = bytes32(uint256(uint160(a)));
        
        assembly {
            t := sload(0x01)// pot address
            //@add point // prepare: selector = 0xad7b985e == addPoints(address)
            mstore(0x00, 0xad7b985e00000000000000000000000000000000000000000000000000000000)

            mstore(0x04, player)
            // CALL t.addPoints(player)
            let s := call(gas(), t, 0, 0x00, 0x24, 0, 0)

            if eq(s, 0) {
                revert(0, 0)
            }
        }
    }
//reading pot address
    function z6() external view returns (address r) {
        assembly {
            r := sload(0x01)
        }
    }
//reading secondary address
    function z7() external view returns (address r) {
        assembly {
            r := sload(0x02)
        }
    }

    receive() external payable {}
}
