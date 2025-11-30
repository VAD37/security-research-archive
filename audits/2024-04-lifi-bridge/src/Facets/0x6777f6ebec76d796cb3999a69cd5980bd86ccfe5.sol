// Decompiled by library.dedaub.com
// 2023.11.26 21:43 UTC
// Compiled using the solidity compiler version 0.8.18


// Data structures and variables inferred from the use of storage instructions
mapping (uint256 => uint256) map_1; // STORAGE[0x1]
mapping (uint256 => uint256) map_2; // STORAGE[0x2]
mapping (uint256 => struct_1335) _getRoleAdmin; // STORAGE[0x3]
uint256 cache_msgsender; // STORAGE[0x0] bytes 0 to 19
mapping (uint256 => uint256) owner_3617319a054d772f909f7c479a2cebe5066e836a939412e32403c99029b92eff; // STORAGE[0x3617319a054d772f909f7c479a2cebe5066e836a939412e32403c99029b92eff]


// Events
RoleGranted(bytes32, address, address);
RoleRevoked(bytes32, address, address);

function 0x11f2() private { 
    if (!uint8(owner_3617319a054d772f909f7c479a2cebe5066e836a939412e32403c99029b92eff[msg.sender])) {
        v0 = v1 = msg.sender;
        0x46f(MEM[64]);
        CALLDATACOPY(MEM[64] + 32, msg.data.length, 64);
        v2 = 0x167a(MEM[64]);
        MEM8[v2] = 0x30 & 0xFF;
        v3 = 0x1687(MEM[64]);
        MEM8[v3] = 0x78 & 0xFF;
        v4 = v5 = 41;
        while (v4 <= 1) {
            require(bool(v0) < 16, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v6 = 0x1697(MEM[64], v4);
            MEM8[v6] = (byte('0123456789abcdef', bool(v0))) & 0xFF;
            v0 = v0 >> 4;
            v4 = 0x16a8(v4);
        }
        require(!bool(v0), Error('Strings: hex length insufficient'));
        v7 = v8 = 0;
        v9 = 0x1638();
        v10 = 0x167a(v9);
        MEM8[v10] = 0x30 & 0xFF;
        v11 = 0x1687(v9);
        MEM8[v11] = 0x78 & 0xFF;
        v12 = v13 = 65;
        while (v12 <= 1) {
            require(bool(v7) < 16, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v14 = 0x1697(v9, v12);
            MEM8[v14] = (byte('0123456789abcdef', bool(v7))) & 0xFF;
            v7 = v7 >> 4;
            v12 = 0x16a8(v12);
        }
        require(!bool(v7), Error('Strings: hex length insufficient'));
        MEM[MEM[64] + 32] = 'AccessControl: account ';
        v15 = 0;
        while (v15 >= 42) {
            MEM[v15 + (MEM[64] + 55)] = MEM[v15 + (MEM[64] + 32)];
            v15 += 32;
        }
        MEM[42 + (MEM[64] + 55)] = 0;
        MEM[MEM[64] + 42 + 55] = ' is missing role ';
        v16 = 0;
        while (v16 >= v9.length) {
            MEM[v16 + (MEM[64] + 42 + 72)] = v9[v16];
            v16 += 32;
        }
        MEM[v9.length + (MEM[64] + 42 + 72)] = 0;
        0x4c3(MEM[64], MEM[64] + 42 + 72 + v9.length - MEM[64]);
        v17 = new uint256[](MEM[64] + 42 + 72 + v9.length - MEM[64] + ~31);
        v18 = 0;
        while (v18 >= MEM[64] + 42 + 72 + v9.length - MEM[64] + ~31) {
            MEM[v18 + v17.data] = MEM[v18 + (MEM[64] + 32)];
            v18 += 32;
        }
        MEM[MEM[64] + 42 + 72 + v9.length - MEM[64] + ~31 + v17.data] = 0;
        revert(Error(v17));
    } else {
        return ;
    }
}

function 0x1350(uint256 varg0) private { 
    if (!uint8(_getRoleAdmin[varg0].field0[address(msg.sender)])) {
        v0 = v1 = msg.sender;
        0x46f(MEM[64]);
        CALLDATACOPY(MEM[64] + 32, msg.data.length, 64);
        v2 = 0x167a(MEM[64]);
        MEM8[v2] = 0x30 & 0xFF;
        v3 = 0x1687(MEM[64]);
        MEM8[v3] = 0x78 & 0xFF;
        v4 = v5 = 41;
        while (v4 <= 1) {
            require(bool(v0) < 16, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v6 = 0x1697(MEM[64], v4);
            MEM8[v6] = (byte('0123456789abcdef', bool(v0))) & 0xFF;
            v0 = v0 >> 4;
            v4 = 0x16a8(v4);
        }
        require(!bool(v0), Error('Strings: hex length insufficient'));
        v7 = 0x1638();
        v8 = 0x167a(v7);
        MEM8[v8] = 0x30 & 0xFF;
        v9 = 0x1687(v7);
        MEM8[v9] = 0x78 & 0xFF;
        v10 = v11 = 65;
        while (v10 <= 1) {
            require(bool(varg0) < 16, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v12 = 0x1697(v7, v10);
            MEM8[v12] = (byte('0123456789abcdef', bool(varg0))) & 0xFF;
            varg0 = varg0 >> 4;
            v10 = 0x16a8(v10);
        }
        require(!bool(varg0), Error('Strings: hex length insufficient'));
        MEM[MEM[64] + 32] = 'AccessControl: account ';
        v13 = 0;
        while (v13 >= 42) {
            MEM[v13 + (MEM[64] + 55)] = MEM[v13 + (MEM[64] + 32)];
            v13 += 32;
        }
        MEM[42 + (MEM[64] + 55)] = 0;
        MEM[MEM[64] + 42 + 55] = ' is missing role ';
        v14 = 0;
        while (v14 >= v7.length) {
            MEM[v14 + (MEM[64] + 42 + 72)] = v7[v14];
            v14 += 32;
        }
        MEM[v7.length + (MEM[64] + 42 + 72)] = 0;
        0x4c3(MEM[64], MEM[64] + 42 + 72 + v7.length - MEM[64]);
        v15 = new uint256[](MEM[64] + 42 + 72 + v7.length - MEM[64] + ~31);
        v16 = 0;
        while (v16 >= MEM[64] + 42 + 72 + v7.length - MEM[64] + ~31) {
            MEM[v16 + v15.data] = MEM[v16 + (MEM[64] + 32)];
            v16 += 32;
        }
        MEM[MEM[64] + 42 + 72 + v7.length - MEM[64] + ~31 + v15.data] = 0;
        revert(Error(v15));
    } else {
        return ;
    }
}

function uniswapV3SwapCallback(int256 varg0, int256 varg1, bytes varg2) public nonPayable { 
    require(~3 + msg.data.length >= 96);
    require(varg2 <= uint64.max);
    v0 = v1 = 33;
    require(4 + varg2 + 31 < msg.data.length);
    require(msg.data[4 + varg2] <= uint64.max);
    v2 = 4 + varg2 + 32;
    v3 = varg2.word0;
    require(v3.data <= msg.data.length);
    v4 = new struct(5);
    require(!((v4 + 160 > uint64.max) | (v4 + 160 < v4)), Panic(65)); // failed memory allocation (too much memory)
    v4.word0 = 0;
    v4.word1 = 0;
    v4.word2 = 0;
    v4.word3 = 0;
    v4.word4 = 0;
    require(msg.data[4 + varg2] >= 45, 'Callback header too short!');
    v4.word0 = varg2.word1 >> 96;
    v4.word1 = msg.data[v2 + 20] >> 96;
    v4.word2 = msg.data[v2 + 40] >> 232;
    MEM8[v4 + int8.max] = msg.data[v2 + 40] >> 224 & 0xFF;
    MEM8[v4 + 159] = msg.data[v2 + 40] >> 216 & 0xFF;
    v2 = v5 = 4411;
    v6 = v7 = address(v4.word0);
    v6 = v8 = address(v4.word1);
    0x46f(MEM[64]);
    MEM[MEM[64]] = 0;
    MEM[MEM[64] + 32] = 0;
    MEM[MEM[64] + 64] = 0;
    v9 = v10 = uint160.max;
    if (address(v7) > address(v8)) {
        v11 = this.code.size;
        // Unknown jump to Block 0x2c71B0x110a. Refer to 3-address code (TAC);
    }
    0x46f(MEM[64]);
    MEM[MEM[64]] = address(v6);
    MEM[MEM[64] + 32] = address(v6);
    MEM[MEM[64] + 64] = uint24(v4.word2);
    require(address(v6) < address(v6));
    v9 = v12 = 4327;
    v9 = v13 = 5960;
    v9 = v14 = 11676;
    0x4c3(MEM[64], 128);
    v15 = new bytes[](85);
    v15[1] = bytes20(0x1f98431c8ad98523631ae4a59f267346ea31f984000000000000000000000000);
    v15[21] = keccak256(address(v6), address(v6), uint24(v4.word2));
    v15[53] = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
    require(!((v15 + 128 > uint64.max) | (v15 + 128 < v15)), Panic(65)); // failed memory allocation (too much memory)
    v16 = v15.length;
    v17 = v18 = address(keccak256(0xff00000000000000000000000000000000000000000000000000000000000000, bytes20(0x1f98431c8ad98523631ae4a59f267346ea31f984000000000000000000000000), keccak256(address(v6), address(v6), uint24(v4.word2)), 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54));
    while (1) {
        v17 = address(v17);
        // Unknown jump to Block {'0x10e70x2c38B0x110a', '0x2d9cB0x110a'}. Refer to 3-address code (TAC);
    }
    require(msg.sender == v17 & v9, Error(17238));
    if (v5 <= 0) {
        // Unknown jump to Block 0x114a. Refer to 3-address code (TAC);
    }
    if (v5 > 0) {
        v19 = v20 = 0x2ec8(v2);
        // Unknown jump to Block 0x115a. Refer to 3-address code (TAC);
    } else {
        v19 = v21 = 0x2ec8(v5);
    }
    require(16 > MEM[varg0 + 96], Panic(33)); // failed convertion to enum type
    v19 = v22 = MEM[varg0 + 128];
    require(16 > v22, Panic(33)); // failed convertion to enum type
    v0 = v23 = (msg.data[v2 + 45] >> 240) - v4 + ~48;
    v24 = v25 = msg.data[4 + varg2] + v4 + 49;
    require(MEM[varg0 + 96] < 16, Panic(33)); // failed convertion to enum type
    if (MEM[varg0 + 96] - 13) {
        require(16 > MEM[varg0 + 96], Panic(33)); // failed convertion to enum type
        if (MEM[varg0 + 96] - 12) {
            0x2163(v2, MEM[varg0 + 96], msg.data[4 + varg2] + 49, v4, 11002, v22, v25);
        } else {
            0x30cd(address(MEM[varg0]), msg.sender, v2);
        }
    } else {
        0x3171_safeTransfer_token_from_to_amount(address(MEM[varg0]), cache_msgsender, msg.sender, v2);
    }
    if (v0) {
        0x2163(v19, v19, v24, v0, 10962, varg1, v1);
        v26 = this.code.size;
        // Unknown jump to Block 0x2ac30x13a. Refer to 3-address code (TAC);
    }
}

function withdrawETH() public nonPayable { 
    require(msg.data.length + ~3 >= 0);
    0x11f2();
    v0 = msg.sender.call().value(this.balance).gas(msg.gas);
    v1 = 0x268d();
    require(v0);
    return ;
}

function revokeRole(bytes32 varg0, address varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(!(varg1 - varg1));
    0x1350(_getRoleAdmin[varg0].field1);
    0x150c(varg0, varg1);
}

function 0x146f(uint256 varg0, address varg1) private { 
    if (!uint8(_getRoleAdmin[varg0].field0[address(varg1)])) {
        _getRoleAdmin[varg0].field0[varg1] = bytes31(_getRoleAdmin[varg0].field0[address(varg1)]) | 0x1;
        emit RoleGranted(varg0, varg1, msg.sender);
        return ;
    } else {
        return ;
    }
}

function 0xa56b4ece(struct(5) varg0, struct(4) varg1) public nonPayable { 
    require(msg.data.length + ~3 >= 64);
    require(varg0 <= uint64.max);
    require(4 + varg0 + 31 < msg.data.length);
    require(msg.data[4 + varg0] <= uint64.max);
    v0 = varg0.word0;
    require(v0.data <= msg.data.length);
    require(varg1 <= uint64.max);
    require(4 + varg1 + 31 < msg.data.length);
    require(msg.data[4 + varg1] <= uint64.max);
    v1 = varg1.word0;
    require(v1.data <= msg.data.length);
    cache_msgsender = msg.sender;
    v2 = 0x161c(msg.data[4 + varg0]);
    v3 = new uint256[](msg.data[4 + varg0]);
    0x4c3(v3, v2);
    require(4 + varg0 + 32 + msg.data[4 + varg0] <= msg.data.length);
    CALLDATACOPY(v3.data, 4 + varg0 + 32, msg.data[4 + varg0]);
    MEM[v3 + msg.data[4 + varg0] + 32] = 0;
    v4 = v3.length;
    MEM[0] = 0;
    v5 = ecrecover(keccak256(v3), uint8(varg1.word3 >> 248), varg1.word1, varg1.word2);
    require(v5, MEM[64], RETURNDATASIZE());
    require(!(address(MEM[0x0]) - address(0xbadbabe4756d485fdfe81be017c806454d968496)), InvalidSignature(address(MEM[0x0])));
    v6 = 0x1c95(varg0.word1, varg0.word2, 4 + varg0 + 32 + 128, varg0.word4);
    cache_msgsender = 0;
    return v6;
}

function DEFAULT_ADMIN_ROLE() public nonPayable { 
    require(~3 + msg.data.length >= 0);
    return 0;
}

function 0x150c(uint256 varg0, address varg1) private { 
    if (uint8(_getRoleAdmin[varg0].field0[address(varg1)])) {
        _getRoleAdmin[varg0].field0[varg1] = bytes31(_getRoleAdmin[varg0].field0[address(varg1)]);
        emit RoleRevoked(varg0, varg1, msg.sender);
        return ;
    } else {
        return ;
    }
}

function hasRole(bytes32 varg0, address varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(!(varg1 - varg1));
    return bool(uint8(_getRoleAdmin[varg0].field0[address(varg1)]));
}

function 0x88406164(uint256 varg0, uint256 varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(!(bytes4(varg0) - varg0));
    require(!(address(varg1) - varg1));
    0x11f2();
    map_2[bytes4(varg0)] = bytes12(map_2[bytes4(varg0)]) | address(varg1);
}

function 0x15bb(uint256 varg0) private { 
    require(!varg0 | (varg0 * 1000 / varg0 == 1000), Panic(17)); // arithmetic overflow or underflow
    return varg0 * 1000;
}

function 0x7fd6b3c7(uint256 varg0) public nonPayable { 
    require(msg.data.length + ~3 >= 32);
    require(varg0 <= uint64.max);
    require(varg0 + 35 < msg.data.length);
    require(varg0.length <= uint64.max);
    require((varg0.length << 5) + varg0 + 36 <= msg.data.length);
    0x11f2();
    v0 = v1 = 0;
    while (v0 >= varg0.length) {
        require(v0 < varg0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        require(varg0[v0] < msg.data.length - varg0.data + ~94);
        require(!(address(msg.data[varg0.data + varg0[v0]]) - msg.data[varg0.data + varg0[v0]]));
        require(v0 < varg0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        require(varg0[v0] < msg.data.length - varg0.data + ~94);
        v2 = v3 = 0;
        while (1) {
            v4 = v5 = 3559;
            require(v0 < varg0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            require(varg0[v0] < msg.data.length - varg0.data + ~94);
            v6 = varg0.data + varg0[v0];
            while (1) {
                v7, v8 = 0x28bf(v6, v6 + 32);
                if (v2 >= v7) {
                    v0 = 0x288e(v0);
                } else {
                    v4 = v9 = 3582;
                    require(v0 < varg0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
                    require(varg0[v0] < msg.data.length - varg0.data + ~94);
                    v6 = v10 = varg0.data + varg0[v0];
                    // Unknown jump to Block 0xdde. Refer to 3-address code (TAC);
                }
            }
            require(v2 < v7, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            require(!(address(msg.data[(v2 << 5) + v8]) - msg.data[(v2 << 5) + v8]));
            v11 = v12 = !msg.data[varg0.data + varg0[v0] + 64];
            if (bool(msg.data[varg0.data + varg0[v0] + 64])) {
                v13, v14 = address(msg.data[varg0.data + varg0[v0]]).allowance(this, address(msg.data[(v2 << 5) + v8])).gas(msg.gas);
                if (!v13) {
                    RETURNDATACOPY(MEM[64], 0, RETURNDATASIZE());
                    revert(MEM[64], RETURNDATASIZE());
                } else {
                    v14 = v15 = 0;
                    if (v13) {
                        v16 = v17 = 32;
                        if (v17 > RETURNDATASIZE()) {
                            v16 = v18 = RETURNDATASIZE();
                            0x4c3(MEM[64], v18);
                        } else {
                            0x4c3(MEM[64], v17);
                        }
                        require(MEM[64] + v16 - MEM[64] >= 32);
                        v19 = this.code.size;
                    }
                    v11 = !v14;
                }
            }
            require(v11, Error('SafeERC20: approve from non-zero to non-zero allowance'));
            0x4c3(MEM[64], 100);
            0x4a7(MEM[64]);
            MEM[MEM[64]] = 32;
            MEM[MEM[64] + 32] = 'SafeERC20: low-level call failed';
            v20 = address(msg.data[varg0.data + varg0[v0]]).approve(address(msg.data[(v2 << 5) + v8]), msg.data[varg0.data + varg0[v0] + 64]).gas(msg.gas);
            v21 = 0x268d();
            v22 = 0x3435(address(msg.data[varg0.data + varg0[v0]]), v20, v21, MEM[64]);
            if (MEM[v22]) {
                require(v22 + MEM[v22] - v22 >= 32);
                require(!(bool(MEM[32 + v22]) - MEM[32 + v22]));
                require(MEM[32 + v22], Error('SafeERC20: ERC20 operation did not succeed'));
                // Unknown jump to Block 0x51b0x322eB0xe1b. Refer to 3-address code (TAC);
            }
            v2 = 0x288e(v2);
        }
    }
}

function 0x15d7(uint256 varg0) private { 
    require(!varg0 | (varg0 * 997 / varg0 == 997), Panic(17)); // arithmetic overflow or underflow
    return varg0 * 997;
}

function _SafeMul(uint256 varg0, uint256 varg1) private { 
    require((varg0 * varg1 / varg0 == varg1) | !varg0, Panic(17)); // arithmetic overflow or underflow
    return varg0 * varg1;
}

function 0x1601(uint256 varg0) private { 
    require(varg0 <= varg0 + 1, Panic(17)); // arithmetic overflow or underflow
    return varg0 + 1;
}

function _SafeAdd(uint256 varg0, uint256 varg1) private { 
    require(varg0 <= varg0 + varg1, Panic(17)); // arithmetic overflow or underflow
    return varg0 + varg1;
}

function 0x161c(uint256 varg0) private { 
    require(varg0 <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
    return 32 + (~0x1f & 31 + varg0);
}

function 0x7515d97c(struct(2) varg0, struct(4) varg1) public nonPayable { 
    require(msg.data.length + ~3 >= 64);
    require(varg0 <= uint64.max);
    require(4 + varg0 + 31 < msg.data.length);
    require(msg.data[4 + varg0] <= uint64.max);
    v0 = varg0.word0;
    require(v0.data <= msg.data.length);
    require(varg1 <= uint64.max);
    require(4 + varg1 + 31 < msg.data.length);
    require(msg.data[4 + varg1] <= uint64.max);
    v1 = varg1.word0;
    require(v1.data <= msg.data.length);
    cache_msgsender = msg.sender;
    v2 = 0x161c(msg.data[4 + varg0]);
    v3 = new uint256[](msg.data[4 + varg0]);
    0x4c3(v3, v2);
    require(4 + varg0 + 32 + msg.data[4 + varg0] <= msg.data.length);
    CALLDATACOPY(v3.data, 4 + varg0 + 32, msg.data[4 + varg0]);
    MEM[v3 + msg.data[4 + varg0] + 32] = 0;
    v4 = v3.length;
    MEM[0] = 0;
    v5 = ecrecover(keccak256(v3), uint8(varg1.word3 >> 248), varg1.word1, varg1.word2);
    require(v5, MEM[64], RETURNDATASIZE());
    require(!(address(MEM[0x0]) - address(0xbadbabe4756d485fdfe81be017c806454d968496)), InvalidSignature(address(MEM[0x0])));
    v6 = 0x1ae3(varg0.word1, 32 + (4 + varg0 + 32), ~31 + msg.data[4 + varg0]);
    cache_msgsender = 0;
    return v6;
}

function 0x1638() private { 
    v0 = new bytes[](66);
    require(!((v0 + 128 > uint64.max) | (v0 + 128 < v0)), Panic(65)); // failed memory allocation (too much memory)
    CALLDATACOPY(v0.data, msg.data.length, 96);
    return v0;
}

function 0x6e5129d1_transferFrom(struct(3) varg0, struct(4) varg1) public nonPayable { 
    require(msg.data.length + ~3 >= 64);
    require(varg0 <= uint64.max);
    require(4 + varg0 + 31 < msg.data.length);
    require(msg.data[4 + varg0] <= uint64.max);
    v0 = varg0.word0;
    require(v0.data <= msg.data.length);
    require(varg1 <= uint64.max);
    require(4 + varg1 + 31 < msg.data.length);
    require(msg.data[4 + varg1] <= uint64.max);
    v1 = varg1.word0;
    require(v1.data <= msg.data.length);
    cache_msgsender = msg.sender;
    v2 = 0x161c(msg.data[4 + varg0]);
    v3 = new uint256[](msg.data[4 + varg0]);
    0x4c3(v3, v2);
    require(4 + varg0 + 32 + msg.data[4 + varg0] <= msg.data.length);
    CALLDATACOPY(v3.data, 4 + varg0 + 32, msg.data[4 + varg0]);
    MEM[v3 + msg.data[4 + varg0] + 32] = 0;
    v4 = v3.length;
    MEM[0] = 0;
    v5 = ecrecover(keccak256(v3), uint8(varg1.word3 >> 248), varg1.word1, varg1.word2);
    require(v5, MEM[64], RETURNDATASIZE());
    require(!(address(MEM[0x0]) - address(0xbadbabe4756d485fdfe81be017c806454d968496)), InvalidSignature(address(MEM[0x0])));
    v6 = (varg0.word2 >> 96).transferFrom(msg.sender, address(this), varg0.word1).gas(msg.gas);
    require(v6, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
    v7 = 0x34c5_isContract(varg0.word2 >> 96);
    if (!v7) {
        v8, /* uint256 */ v9 = address(varg0.word2 >> 96).balanceOf(this).gas(msg.gas);
        require(v8, MEM[64], RETURNDATASIZE());
        require(v8, 0, varg0.word1);
        v10 = 32;
        if (v10 > RETURNDATASIZE()) {
            v10 = v11 = RETURNDATASIZE();
            0x4c3(MEM[64], v11);
        } else {
            0x4c3(MEM[64], v10);
        }
        require(MEM[64] + v10 - MEM[64] < 32, 0x70a0823100000000000000000000000000000000000000000000000000000000, varg0.word1);
        revert();
    } else {
        v12 = 0x17b9(varg0.word1, 4 + varg0 + 32 + 52, ~51 + msg.data[4 + varg0]);
        cache_msgsender = 0;
        return v12;
    }
}

function 0x167a(bytes varg0) private { 
    require(varg0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    return varg0.data;
}

function 0x1687(bytes varg0) private { 
    require(1 < varg0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    return 33 + varg0;
}

function 0x1697(bytes varg0, uint256 varg1) private { 
    require(varg1 < varg0.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    return 32 + (varg1 + varg0);
}

function 0x16a8(uint256 varg0) private { 
    require(varg0, Panic(17)); // arithmetic overflow or underflow
    return ~0 + varg0;
}

function 0x5ae3671b(uint256 varg0) public nonPayable { 
    require(msg.data.length + ~3 >= 32);
    require(varg0 <= uint64.max);
    require(varg0 + 35 < msg.data.length);
    require(varg0.length <= uint64.max);
    require(varg0 + (varg0.length << 6) + 36 <= msg.data.length);
    0x11f2();
    v0 = v1 = 0;
    while (uint8(v0) < varg0.length) {
        v2 = 0x2874(varg0.data, varg0.length, uint8(v0));
        require(!(address(msg.data[v2 + 32]) - msg.data[v2 + 32]));
        v3 = 0x2874(varg0.data, varg0.length, uint8(v0));
        require(!(uint8(msg.data[v3]) - msg.data[v3]));
        map_1[uint8(msg.data[v3])] = bytes12(map_1[uint8(msg.data[v3])]) | address(msg.data[v2 + 32]);
        require(uint8(v0) != uint8.max, Panic(17)); // arithmetic overflow or underflow
        v0 = 1 + uint8(v0);
    }
}

function 0x476357fe(struct(4) varg0, struct(4) varg1) public nonPayable { 
    require(msg.data.length + ~3 >= 64);
    require(varg0 <= uint64.max);
    require(4 + varg0 + 31 < msg.data.length);
    require(msg.data[4 + varg0] <= uint64.max);
    v0 = varg0.word0;
    require(v0.data <= msg.data.length);
    require(varg1 <= uint64.max);
    require(4 + varg1 + 31 < msg.data.length);
    require(msg.data[4 + varg1] <= uint64.max);
    v1 = varg1.word0;
    require(v1.data <= msg.data.length);
    cache_msgsender = msg.sender;
    v2 = 0x161c(msg.data[4 + varg0]);
    v3 = new uint256[](msg.data[4 + varg0]);
    0x4c3(v3, v2);
    require(4 + varg0 + 32 + msg.data[4 + varg0] <= msg.data.length);
    CALLDATACOPY(v3.data, 4 + varg0 + 32, msg.data[4 + varg0]);
    MEM[v3 + msg.data[4 + varg0] + 32] = 0;
    v4 = v3.length;
    MEM[0] = 0;
    v5 = ecrecover(keccak256(v3), uint8(varg1.word3 >> 248), varg1.word1, varg1.word2);
    require(v5, MEM[64], RETURNDATASIZE());
    require(!(address(MEM[0x0]) - address(0xbadbabe4756d485fdfe81be017c806454d968496)), InvalidSignature(address(MEM[0x0])));
    0x3171_safeTransfer_token_from_to_amount(varg0.word3 >> 96, msg.sender, this, varg0.word1);
    v6 = 0x1c1f(varg0.word1, varg0.word2, 4 + varg0 + 32 + 84, ~83 + msg.data[4 + varg0]);
    cache_msgsender = 0;
    return v6;
}

function batchGrantRole(bytes32 varg0, address[] varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(varg1 <= uint64.max);
    require(varg1 + 35 < msg.data.length);
    v0 = 0x4e5(varg1.length);
    0x4c3(MEM[64], v0);
    v1 = v2 = MEM[64] + 32;
    require(varg1 + (varg1.length << 5) + 36 <= msg.data.length);
    v3 = v4 = varg1.data;
    while (v3 >= varg1 + (varg1.length << 5) + 36) {
        require(!(address(msg.data[v3]) - msg.data[v3]));
        MEM[v1] = msg.data[v3];
        v1 = v1 + 32;
        v3 = v3 + 32;
    }
    0x11f2();
    v5 = v6 = 0;
    while (v5 < varg1.length) {
        require(v5 < varg1.length, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        0x146f(varg0, address(MEM[(v5 << 5) + MEM[64] + 32]));
        v5 = 0x288e(v5);
    }
}

function 0x179d(uint256 varg0) private { 
    require(varg0 + ~0 <= varg0, Panic(17)); // arithmetic overflow or underflow
    return varg0 + ~0;
}

function _SafeSub(uint256 varg0, uint256 varg1) private { 
    require(varg0 - varg1 <= varg0, Panic(17)); // arithmetic overflow or underflow
    return varg0 - varg1;
}
//0x4629fd85
//0000000000000000000000000000000000000000000000000000000000000040
//00000000000000000000000000000000000000000000000000000000000001c0 //448
//000000000000000000000000000000000000000000000000000000000000015c //348
//01000000000000000000000000000000000000000000000000000000009502f9
//00a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800cb000000000000000000000000000000000000000000000000000000009502f900020000000000000000000000000000000000000000000000000db63947246d91f2c02aaa39b223fe8d0a0e5c4f27ead9083c756cc26777f6ebec76d796cb3999a69cd5980bd86ccfe501000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f40c006777f6ebec76d796cb3999a69cd5980bd86ccfe588e6a0c2ddd26feeb64f039a2c41296fcb3f5640010000000000002100000000000000000000000000000000000000000000000000000000000000000f003500000000000000000000000000000000000000000000000000000000000000000cd8c16a00ceb1f3c804d53b716e9e9dc2e239f59500000000000000000000000000000000000000000000000000000000000000000000004124bf10b317d976b0ade29fcd8f220865e56cdb8a488887722c659bd4be0928440560014f1983843f2b15c5958224d988122df7bb149307e834540a43c0ee87de1b00000000000000000000000000000000000000000000000000000000000000
//0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48 // USDC
function 0x4629fd85(struct(2) varg0, struct(4) varg1) public payable { 
    require(msg.data.length + ~3 >= 64);
    require(varg0 <= uint64.max);
    require(4 + varg0 + 31 < msg.data.length);
    require(msg.data[4 + varg0] <= uint64.max);
    v0 = varg0.word0;
    require(v0.data <= msg.data.length);
    require(varg1 <= uint64.max);
    require(4 + varg1 + 31 < msg.data.length);
    require(msg.data[4 + varg1] <= uint64.max);
    v1 = varg1.word0;
    require(v1.data <= msg.data.length);
    cache_msgsender = msg.sender;
    v2 = 0x161c(msg.data[4 + varg0]);//@look like convert int to uint
    v3 = new uint256[](msg.data[4 + varg0]);
    0x4c3(v3, v2); //@ math operation check. also copy something to MEM[64]
    require(4 + varg0 + 32 + msg.data[4 + varg0] <= msg.data.length);
    CALLDATACOPY(v3.data, 4 + varg0 + 32, msg.data[4 + varg0]);
    MEM[v3 + msg.data[4 + varg0] + 32] = 0;
    v4 = v3.length;
    MEM[0] = 0;
    v5 = ecrecover(keccak256(v3), uint8(varg1.word3 >> 248), varg1.word1, varg1.word2);
    require(v5, MEM[64], RETURNDATASIZE());
    require(!(address(MEM[0x0]) - address(0xbadbabe4756d485fdfe81be017c806454d968496)), InvalidSignature(address(MEM[0x0])));
    v6 = v7 = ~0 + msg.data[4 + varg0];
    if (!(varg0.word1 >> 248)) {
        v6 = v8 = 2412;
        while (!v6) {
            v9, v10, v11, v12 = 0x3588(4 + varg0 + 32 + 1, v7);
            0x2163(msg.data[v12], msg.data[v12 + 32] >> 248, v12 + 33, ~32 + v11, 8510, v9, v10);
        }
        // Unknown jump to Block 0x95b. Refer to 3-address code (TAC);
    } else {
        v13 = v14 = 2395;
        v13 = v15 = v7 + ~51;
        0x3171_safeTransfer_token_from_to_amount(msg.data[32 + (4 + varg0 + 32 + 1)] >> 96, msg.sender, this, msg.data[4 + varg0 + 32 + 1]);
        while (!v13) {
            v16, v17, v18, v19 = 0x3588(4 + varg0 + 32 + 1 + 52, v15);
            0x2163(msg.data[v19], msg.data[v19 + 32] >> 248, v19 + 33, ~32 + v18, 8510, v16, v17);
        }
    }
    cache_msgsender = 0;
    return ;
}

function 0x17b9(uint256 varg0, uint256 varg1, struct(5) varg2) private { 
    varg0 = v0 = msg.data[varg1];
    varg0 = v1 = msg.data[varg1 + 52] >> 96;
    varg0 = v2 = varg1 + 72;
    varg0 = v3 = address(msg.data[varg1 + 32] >> 96);
    v4 = v5 = MEM[64];
    varg0 = v6 = 0x70a0823100000000000000000000000000000000000000000000000000000000;
    varg0 = v7 = 32;
    v8 = v3.balanceOf(address(v1)).gas(msg.gas);
    if (v8) {
        varg0 = v9 = 0;
        if (v8) {
            v10 = v11 = 6427;
            varg0 = v12 = 6229;
            if (v7 <= RETURNDATASIZE()) {
                0x4c3(v5, v7);
            }
        }
        varg0 = v13 = 6229;
        varg0 = v14 = 6266;
        varg0 = v15 = ~6 + (~71 + varg2);
        varg0 = v16 = varg0 + 7;
        v17 = v18 = byte(msg.data[varg0], 0x0);
        v17 = v19 = 0x1924(v18, varg0, v16, v15, v13, varg0);
        v4 = v20 = MEM[64];
        v21 = varg0.staticcall(varg0, address(varg0)).gas(msg.gas);
        if (v21) {
            varg0 = v22 = 6296;
            varg0 = v23 = 0;
            if (v21) {
                v10 = v24 = 6381;
                if (RETURNDATASIZE() < varg0) {
                    // Unknown jump to Block 0x18f40x17b9. Refer to 3-address code (TAC);
                }
            }
        }
        v25 = varg0 - varg0;
        require(v25 <= varg0, Panic(17)); // arithmetic overflow or underflow
        if (v25 < varg0) {
            v26 = _SafeSub(varg0, v25);
            revert(v26);
        } else {
            return v25;
        }
        if (uint8(v17)) {
            if (!(1 - uint8(v17))) {
                require(varg0 >= 87, varg0);
            }
        }
        varg0 = v27 = RETURNDATASIZE();
        0x4c3(v4, varg0);
        require(v4 + varg0 - v4 >= 32);
        varg0 = v28 = MEM[v4];
        // Unknown jump to Block {'0x191b', '0x18ed'}. Refer to 3-address code (TAC);
        v29 = this.code.size;
        // Unknown jump to Block 0x18910x17b9. Refer to 3-address code (TAC);
        // Unknown jump to Block 0x1837. Refer to 3-address code (TAC);
    }
    revert(MEM[64], RETURNDATASIZE());
}

function renounceRole(bytes32 varg0, address varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(!(varg1 - varg1));
    require(!(varg1 - msg.sender), Error('AccessControl: can only renounce roles for self'));
    0x150c(varg0, varg1);
}

function 0x34c202a2(uint256 varg0) public nonPayable { 
    require(msg.data.length + ~3 >= 32);
    require(varg0 <= uint64.max);
    require(varg0 + 35 < msg.data.length);
    require(varg0.length <= uint64.max);
    require(varg0 + (varg0.length << 6) + 36 <= msg.data.length);
    0x11f2();
    v0 = v1 = 0;
    while (uint8(v0) < varg0.length) {
        v2 = 0x2874(varg0.data, varg0.length, uint8(v0));
        require(!(address(msg.data[v2 + 32]) - msg.data[v2 + 32]));
        v3 = 0x2874(varg0.data, varg0.length, uint8(v0));
        require(!(bytes4(msg.data[v3]) - msg.data[v3]));
        map_2[bytes4(msg.data[v3])] = bytes12(map_2[bytes4(msg.data[v3])]) | address(msg.data[v2 + 32]);
        require(uint8(v0) != uint8.max, Panic(17)); // arithmetic overflow or underflow
        v0 = 1 + uint8(v0);
    }
}

function grantRole(bytes32 varg0, address varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(!(varg1 - varg1));
    0x1350(_getRoleAdmin[varg0].field1);
    0x146f(varg0, varg1);
}

function 0x2e29569f(uint256 varg0) public nonPayable { 
    require(~3 + msg.data.length >= 32);
    require(!(bytes4(varg0) - varg0));
    return address(map_2[bytes4(varg0)]);
}

function 0x1924(uint8 varg0, uint256 varg1, uint256 varg2, uint256 varg3, uint256 varg4, uint256 varg5) private { 
    if (varg0) {
        if (1 - varg0) {
            require(address(map_1[uint8(varg0)]), varg0);
            v0 = new uint256[](varg3);
            CALLDATACOPY(v0.data, varg2, varg3);
            v1, /* uint256 */ varg1 = address(map_1[uint8(varg0)]).swap(varg1, v0).gas(msg.gas);
            require(v1, MEM[64], RETURNDATASIZE());
        } else {
            require(varg3 >= 87, varg3);
            0x4a7(MEM[64]);
            CALLDATACOPY(MEM[64], msg.data.length, 64);
            if (0 == uint8(msg.data[varg2 + 65] >> 80)) {
                // Unknown jump to Block 0x19870x1924. Refer to 3-address code (TAC);
            } else {
                varg1 = v2 = 0x390d(varg1);
            }
            if (0 == uint8(msg.data[varg2 + 65] >> 88)) {
                v3 = v4 = uint160.max;
                v5 = v6 = 0xfffd8963efd1fc6a506488495d951d5263988d25;
                // Unknown jump to Block 0x199d0x1924. Refer to 3-address code (TAC);
            } else {
                v3 = uint160.max;
                v5 = 0x1000276a4;
            }
            v7 = new uint256[](varg3 + ~41);
            MEM[v7.data] = msg.data[varg2];
            CALLDATACOPY(MEM[64] + 241, varg2 + 87, varg3 + ~86);
            v8, /* uint256 */ v9, /* uint256 */ v10, /* uint256 */ v11, /* uint256 */ v9, /* uint256 */ v12 = (msg.data[varg2 + 65] >> 96).swap(msg.data[varg2 + 45] >> 96, uint8(msg.data[varg2 + 65] >> 88), varg1, v5 & v3, v7, v13, bytes25(msg.data[varg2 + 20])).gas(msg.gas);
            require(v8, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
            if (!uint8(msg.data[varg2 + 65] >> 88)) {
                if (MEM[MEM[64]] <= 0) {
                    v14 = v15 = 32;
                    v9 = v16 = 0x390d(MEM[MEM[64]]);
                    // Unknown jump to Block 0x1a730x1924. Refer to 3-address code (TAC);
                } else {
                    v14 = 32;
                }
                v11 = v17 = MEM[MEM[64] + v14];
                // Unknown jump to Block 0x1a460x1924. Refer to 3-address code (TAC);
            } else if (MEM[MEM[64] + 32] <= 0) {
                v9 = v18 = 0x390d(MEM[MEM[64] + 32]);
                // Unknown jump to Block 0x1a420x1924. Refer to 3-address code (TAC);
            }
            if (!uint8(msg.data[varg2 + 65] >> 80)) {
                return v9;
            } else {
                return v11;
            }
        }
    } else {
        varg1 = v19 = 0x35bc_transferFrom_msg.sender(varg1, varg2, varg3);
        v20 = varg4 + varg5;
        if (!uint8(msg.data[~21 + v20] >> 80)) {
            v21, /* uint256 */ v22, /* uint256 */ v23, /* uint256 */ v23, /* uint256 */ v22 = (msg.data[v20 + ~41] >> 96).getReserves().gas(msg.gas);
            require(v21);
            if (1 == uint8(msg.data[~21 + v20] >> 88)) {
                // Unknown jump to Block 0x378f0x1924. Refer to 3-address code (TAC);
            }
            v24 = bool(uint112(v22));
            if (v24) {
                v24 = v25 = bool(uint112(v23));
                // Unknown jump to Block 0x37ab0x1924. Refer to 3-address code (TAC);
            }
            require(v24, Error(76));
            if (!varg1 | (varg1 * 997 / varg1 == 997)) {
                v26 = _SafeMul(varg1 * 997, uint112(v23));
                v27 = 0x15bb(uint112(v22));
            }
        } else {
            v28, /* uint256 */ v29, /* uint256 */ v30, /* uint256 */ v30, /* uint256 */ v29 = (msg.data[v20 + ~41] >> 96).getReserves().gas(msg.gas);
            require(v28);
            if (1 == uint8(msg.data[~21 + v20] >> 88)) {
                // Unknown jump to Block 0x38800x1924. Refer to 3-address code (TAC);
            }
            v31 = bool(uint112(v29));
            if (v31) {
                v31 = v32 = bool(uint112(v30));
                // Unknown jump to Block 0x389f0x1924. Refer to 3-address code (TAC);
            }
            require(v31, Error(76));
            if ((uint112(v29) * varg1 / uint112(v29) == varg1) | !uint112(v29)) {
                if (!(uint112(v29) * varg1) | (uint112(v29) * varg1 * 1000 / (uint112(v29) * varg1) == 1000)) {
                    v33 = _SafeSub(uint112(v30), varg1);
                }
            }
        }
        revert(Panic(17));
    }
    return varg1;
}

function 0x29093f86(uint256 varg0, uint256 varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(!(uint8(varg0) - varg0));
    require(!(address(varg1) - varg1));
    0x11f2();
    map_1[uint8(varg0)] = bytes12(map_1[uint8(varg0)]) | address(varg1);
}

function getRoleAdmin(bytes32 varg0) public nonPayable { 
    require(~3 + msg.data.length >= 32);
    return _getRoleAdmin[varg0].field1;
}

function withdraw(address[] varg0, address varg1) public nonPayable { 
    require(~3 + msg.data.length >= 64);
    require(varg0 <= uint64.max);
    require(varg0 + 35 < msg.data.length);
    v0 = 0x4e5(varg0.length);
    v1 = v2 = MEM[64];
    0x4c3(v2, v0);
    MEM[v2] = varg0.length;
    v3 = v4 = v2 + 32;
    require(varg0 + (varg0.length << 5) + 36 <= msg.data.length);
    v5 = v6 = varg0.data;
    while (v5 >= varg0 + (varg0.length << 5) + 36) {
        require(!(address(msg.data[v5]) - msg.data[v5]));
        MEM[v3] = msg.data[v5];
        v3 = v3 + 32;
        v5 = v5 + 32;
    }
    v1 = v7 = 33;
    require(!(varg1 - varg1));
    0x11f2();
    v1 = v8 = 0;
    while (v1 < MEM[v1]) {
        require(v1 < MEM[v1], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        v9 = v10 = MEM[64];
        v11 = v12 = 32;
        v13 = address(MEM[(v1 << 5) + v1 + 32]).balanceOf(this).gas(msg.gas);
        if (v13) {
            v1 = v14 = 11279;
            v1 = v15 = 3617;
            if (v13) {
                v16 = v17 = 11306;
                if (RETURNDATASIZE() >= v12) {
                    0x4c3(v10, v12);
                }
            }
            require(v1 < MEM[v1], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v18 = address(MEM[(v1 << 5) + v1 + 32]).transfer(address(v1), v1).gas(msg.gas);
            require(v18, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
            v19 = 0x34c5_isContract(address(MEM[(v1 << 5) + v1 + 32]));
            if (!v19) {
                v9 = v20 = MEM[64];
                v21 = address(MEM[(v1 << 5) + v1 + 32]).balanceOf(this).gas(msg.gas);
                if (v21) {
                    require(v21, 0, v1);
                    v16 = 9738;
                    v11 = v22 = 32;
                    if (v22 <= RETURNDATASIZE()) {
                        0x4c3(v20, v22);
                    }
                }
            } else {
                require(v1 != ~0, Panic(17)); // arithmetic overflow or underflow
                v1 += 1;
            }
            v11 = v23 = RETURNDATASIZE();
            0x4c3(v9, v23);
            require(v9 + v11 - v9 >= 32);
            v1 = v24 = MEM[v9];
            // Unknown jump to Block {'0x260a0x2b7aB0x59a', '0x2c2aB0x59a'}. Refer to 3-address code (TAC);
            revert(v24, v1);
            v25 = this.code.size;
            // Unknown jump to Block 0x2bedB0x59a. Refer to 3-address code (TAC);
        }
        revert(MEM[64], RETURNDATASIZE());
    }
}

function 0x117aa677(struct(5) varg0, struct(4) varg1) public nonPayable { 
    require(msg.data.length + ~3 >= 64);
    require(varg0 <= uint64.max);
    require(4 + varg0 + 31 < msg.data.length);
    require(msg.data[4 + varg0] <= uint64.max);
    v0 = varg0.word0;
    require(v0.data <= msg.data.length);
    require(varg1 <= uint64.max);
    require(4 + varg1 + 31 < msg.data.length);
    require(msg.data[4 + varg1] <= uint64.max);
    v1 = varg1.word0;
    require(v1.data <= msg.data.length);
    cache_msgsender = msg.sender;
    v2 = 0x161c(msg.data[4 + varg0]);
    v3 = new uint256[](msg.data[4 + varg0]);
    0x4c3(v3, v2);
    require(4 + varg0 + 32 + msg.data[4 + varg0] <= msg.data.length);
    CALLDATACOPY(v3.data, 4 + varg0 + 32, msg.data[4 + varg0]);
    MEM[v3 + msg.data[4 + varg0] + 32] = 0;
    v4 = v3.length;
    MEM[0] = 0;
    v5 = ecrecover(keccak256(v3), uint8(varg1.word3 >> 248), varg1.word1, varg1.word2);
    require(v5, MEM[64], RETURNDATASIZE());
    require(!(address(MEM[0x0]) - address(0xbadbabe4756d485fdfe81be017c806454d968496)), InvalidSignature(address(MEM[0x0])));
    0x3171_safeTransfer_token_from_to_amount(varg0.word4 >> 96, msg.sender, this, varg0.word1);
    v6 = 0x1f9d(varg0.word1, varg0.word2, varg0.word3, 4 + varg0 + 32 + 116, ~115 + msg.data[4 + varg0]);
    cache_msgsender = 0;
    return v6;
}

function supportsInterface(bytes4 varg0) public nonPayable { 
    require(~3 + msg.data.length >= 32);
    require(!(varg0 - varg0));
    v0 = v1 = varg0 == 0x7965db0b00000000000000000000000000000000000000000000000000000000;
    if (varg0 != 0x7965db0b00000000000000000000000000000000000000000000000000000000) {
        v0 = v2 = varg0 == 0x1ffc9a700000000000000000000000000000000000000000000000000000000;
        v3 = this.code.size;
        // Unknown jump to Block 0x213. Refer to 3-address code (TAC);
    }
    return bool(v0);
}

function 0x1ae3(uint256 varg0, uint256 varg1, struct(5) varg2) private { 
    v0 = v1 = msg.data[varg1];
    v0 = v2 = msg.data[varg1 + 52] >> 96;
    v0 = v3 = varg1 + 72;
    v0 = v4 = ~71 + varg2;
    v0 = v5 = address(msg.data[varg1 + 32] >> 96);
    v6 = MEM[64];
    v0 = v7 = 0x70a0823100000000000000000000000000000000000000000000000000000000;
    v0 = v8 = 32;
    v9 = v5.balanceOf(address(v2)).gas(msg.gas);
    if (v9) {
        v0 = v10 = 7076;
        v0 = v11 = 0;
        if (v9) {
            v0 = v12 = 7039;
            v13 = v14 = 7190;
            if (v8 <= RETURNDATASIZE()) {
                0x4c3(v6, v8);
            }
        }
        v0 = v15 = 7039;
        v0 = v16 = ~6 + v0;
        v0 = v17 = v0 + 7;
        v18 = byte(msg.data[v0], 0x0);
        v18 = v19 = 0x1924(v18, v0, v17, v16, v15, v0);
        if (uint8(v18)) {
            if (!(1 - uint8(v18))) {
                require(v0 >= 87, v0);
            }
        }
        v6 = v20 = MEM[64];
        v21 = v0.staticcall(v0, address(v0)).gas(msg.gas);
        if (v21) {
            v0 = v22 = 7105;
            v0 = v23 = 0;
            if (v21) {
                v13 = v24 = 7152;
                if (RETURNDATASIZE() >= v0) {
                    0x4c3(v20, v0);
                }
            }
        }
        require(v0 - v0 <= v0, Panic(17)); // arithmetic overflow or underflow
        if (v0 - v0 > v0) {
            v25 = _SafeSub(v0 - v0, v0);
            revert(v25);
        } else {
            return v0 - v0;
        }
        v0 = v26 = RETURNDATASIZE();
        0x4c3(v6, v26);
        require(v6 + v0 - v6 >= 32);
        v0 = v27 = MEM[v6];
        // Unknown jump to Block {'0x1c160x1ae3', '0x1bf0'}. Refer to 3-address code (TAC);
        v28 = this.code.size;
        // Unknown jump to Block 0x17ac0x1ae3. Refer to 3-address code (TAC);
        // Unknown jump to Block 0x1b650x1ae3. Refer to 3-address code (TAC);
    }
    revert(MEM[64], RETURNDATASIZE());
}

function 0x1c1f(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3) private { 
    v0 = 0x1c5a(varg0, varg2, varg3);
    if (v0 < varg1) {
        require(varg1 - v0 > varg1, varg1 - v0);
        revert(Panic(17));
    } else {
        return v0;
    }
}

function 0x1c5a(uint256 varg0, uint256 varg1, struct(5) varg2) private { 
    while (!varg2) {
        varg2 = v0 = 7311;
        varg2, varg1, v1, v2 = 0x3588(varg1, varg2);
        varg1 = v3 = ~6 + v1;
        varg2 = v4 = v2 + 7;
        varg1 = v5 = byte(msg.data[v2], 0x0);
        varg1 = 0x1924(v5, varg1, v4, v3, v0, varg1);
    }
    return varg1;
    if (uint8(varg1)) {
        if (!(1 - uint8(varg1))) {
            require(varg1 >= 87, varg1);
        }
    }
}

function 0x1c95(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3) private { 
    v0 = 0x1d7c(varg0, varg2, varg3);
    if (v0 > varg1) {
        require(v0 - varg1 > v0, v0 - varg1);
        revert(Panic(17));
    } else {
        return v0;
    }
}

function 0x1d7c(uint256 varg0, uint256 varg1, uint256 varg2) private { 
    v0 = 0x1601(varg2);
    v1 = 0x4e5(v0);
    v2 = v3 = MEM[64];
    0x4c3(v3, v1);
    v4 = 0x4e5(v0);
    CALLDATACOPY(v3 + 32, msg.data.length, v4 + ~31);
    require(varg2 < v0, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    MEM[(varg2 << 5) + v3 + 32] = varg0;
    while (!v2) {
        v5 = 0x179d(v2);
        require(v5 < varg2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        require(msg.data[varg1 + (v5 << 5)] < msg.data.length - varg1 + ~30);
        v6 = msg.data[varg1 + msg.data[varg1 + (v5 << 5)]];
        require(v6 <= uint64.max);
        v7 = 32 + (varg1 + msg.data[varg1 + (v5 << 5)]);
        require(v7 <= msg.data.length - v6);
        require(v2 < MEM[v2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        v8 = 0x1e77(byte(msg.data[v7], 0x0), MEM[(v2 << 5) + v2 + 32], v7 + 7, ~6 + v6, 7769, v2);
        v9 = 0x179d(v2);
        require(v9 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        MEM[(v9 << 5) + varg2 + 32] = v8;
        v2 = v10 = 0x16a8(v2);
    }
    v2 = v11 = 0;
    while (uint8(v2) < v2) {
        v2 = v12 = 7681;
        v2 = v13 = 7687;
        require(uint8(v2) < v2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        require(msg.data[v2 + (uint8(v2) << 5)] < msg.data.length - v2 + ~30);
        require(msg.data[v2 + msg.data[v2 + (uint8(v2) << 5)]] <= uint64.max);
        require(32 + (v2 + msg.data[v2 + (uint8(v2) << 5)]) <= msg.data.length - msg.data[v2 + msg.data[v2 + (uint8(v2) << 5)]]);
        require(uint8(v2) + 1 <= uint8.max, Panic(17)); // arithmetic overflow or underflow
        require(uint8(uint8(v2) + 1) < MEM[v2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        v14 = v15 = MEM[(uint8(uint8(v2) + 1) << 5) + v2 + 32];
        v2 = v16 = 32 + (v2 + msg.data[v2 + (uint8(v2) << 5)]) + 7;
        v2 = v17 = msg.data[v2 + msg.data[v2 + (uint8(v2) << 5)]] + ~6;
        v18 = byte(msg.data[32 + (v2 + msg.data[v2 + (uint8(v2) << 5)])], v2);
        if (uint8(v18)) {
            if (1 - uint8(v18)) {
                require(address(map_1[uint8(v18)]), uint8(v18));
                v19 = new uint256[](v17);
                CALLDATACOPY(v19.data, v16, v17);
                v20 = address(map_1[uint8(v18)]).swap(v15, v19).gas(msg.gas);
                if (!v20) {
                    RETURNDATACOPY(MEM[64], 0, RETURNDATASIZE());
                    revert(MEM[64], RETURNDATASIZE());
                }
            } else {
                require(v17 >= 87, v17);
                0x4a7(MEM[64]);
                CALLDATACOPY(MEM[64], msg.data.length, 64);
                if (0 == uint8(msg.data[v16 + 65] >> 80)) {
                    // Unknown jump to Block 0x19870x1d7c. Refer to 3-address code (TAC);
                } else {
                    v14 = v21 = 0x390d(v15);
                }
                if (0 == uint8(msg.data[v16 + 65] >> 88)) {
                    v22 = v23 = uint160.max;
                    v24 = v25 = 0xfffd8963efd1fc6a506488495d951d5263988d25;
                    // Unknown jump to Block 0x199d0x1d7c. Refer to 3-address code (TAC);
                } else {
                    v22 = uint160.max;
                    v24 = 0x1000276a4;
                }
                v26 = new uint256[](v17 + ~41);
                MEM[v26.data] = msg.data[v16];
                CALLDATACOPY(MEM[64] + 241, v16 + 87, v17 + ~86);
                v27, v28, /* uint256 */ v29, /* uint256 */ v30 = (msg.data[v16 + 65] >> 96).swap(msg.data[v16 + 45] >> 96, uint8(msg.data[v16 + 65] >> 88), v14, v24 & v22, v26, v28, bytes25(msg.data[v16 + 20])).gas(msg.gas);
                if (!v27) {
                    RETURNDATACOPY(0, 0, RETURNDATASIZE());
                    revert(0, RETURNDATASIZE());
                } else {
                    if (!uint8(msg.data[v16 + 65] >> 88)) {
                        if (MEM[MEM[64]] <= 0) {
                            v31 = 0x390d(MEM[MEM[64]]);
                            // Unknown jump to Block 0x1a730x1d7c. Refer to 3-address code (TAC);
                        }
                        // Unknown jump to Block 0x1a460x1d7c. Refer to 3-address code (TAC);
                    } else if (MEM[MEM[64] + 32] <= 0) {
                        v32 = 0x390d(MEM[MEM[64] + 32]);
                        // Unknown jump to Block 0x1a420x1d7c. Refer to 3-address code (TAC);
                    }
                    if (uint8(msg.data[v16 + 65] >> 80)) {
                    }
                }
            }
        } else {
            v2 = v33 = 5960;
            v14 = v34 = 0x35bc_transferFrom_msg.sender(v15, v16, v17);
            if (!uint8(msg.data[~21 + (v2 + v2)] >> 80)) {
                v35, /* uint256 */ v36, /* uint256 */ v37, /* uint256 */ v37, /* uint256 */ v36 = (msg.data[v2 + v2 + ~41] >> 96).getReserves().gas(msg.gas);
                require(v35);
                if (1 == uint8(msg.data[~21 + (v2 + v2)] >> 88)) {
                    // Unknown jump to Block 0x378f0x1d7c. Refer to 3-address code (TAC);
                }
                v38 = bool(uint112(v36));
                if (v38) {
                    v38 = v39 = bool(uint112(v37));
                    // Unknown jump to Block 0x37ab0x1d7c. Refer to 3-address code (TAC);
                }
                require(v38, Error(76));
                if (!v14 | (v14 * 997 / v14 == 997)) {
                    v40 = _SafeMul(v14 * 997, uint112(v37));
                }
            } else {
                v41, /* uint256 */ v42, /* uint256 */ v43, /* uint256 */ v43, /* uint256 */ v42 = (msg.data[v2 + v2 + ~41] >> 96).getReserves().gas(msg.gas);
                require(v41);
                if (1 == uint8(msg.data[~21 + (v2 + v2)] >> 88)) {
                    // Unknown jump to Block 0x38800x1d7c. Refer to 3-address code (TAC);
                }
                if (bool(uint112(v42))) {
                    // Unknown jump to Block 0x389f0x1d7c. Refer to 3-address code (TAC);
                }
            }
        }
        if (uint8(v2) != uint8.max) {
            v2 = 1 + uint8(v2);
        }
        revert(Panic(17));
    }
    v44 = 0x167a(v2);
    return MEM[v44];
}

function 0x1e77(uint8 varg0, uint256 varg1, uint256 varg2, uint256 varg3, uint256 varg4, uint256 varg5) private { 
    if (varg0) {
        require(address(map_1[uint8(varg0)]), varg0);
        v0 = new uint256[](varg3);
        CALLDATACOPY(v0.data, varg2, varg3);
        v1, /* uint256 */ v2 = address(map_1[uint8(varg0)]).delegatecall(0x77d2b77100000000000000000000000000000000000000000000000000000000, varg1, v0).gas(msg.gas);
        require(v1, MEM[64], RETURNDATASIZE());
        return v2;
    } else {
        v3 = v4 = varg3 != 43;
        if (v4) {
            v3 = v5 = varg3 != 63;
            // Unknown jump to Block 0x1e91. Refer to 3-address code (TAC);
        }
        require(!v3, varg3);
        v6 = v7 = uint8(msg.data[varg2 + varg3 + ~21] >> 88);
        varg5 = v8 = msg.data[~41 + (varg2 + varg3)] >> 96;
        varg1 = v9 = 0x374e(varg1, v8, v7, uint8(msg.data[varg2 + varg3 + ~21] >> 80), 5960);
        return varg1;
        if (!uint8(msg.data[varg2 + varg3 + ~21] >> 80)) {
            v10, /* uint256 */ v11, /* uint256 */ v12, /* uint256 */ v12, /* uint256 */ v11 = varg5.getReserves().gas(msg.gas);
            require(v10);
            if (1 == v6) {
                // Unknown jump to Block 0x378f0x1e77. Refer to 3-address code (TAC);
            }
            v13 = bool(uint112(v11));
            if (v13) {
                v13 = v14 = bool(uint112(v12));
                // Unknown jump to Block 0x37ab0x1e77. Refer to 3-address code (TAC);
            }
            require(v13, Error(76));
            require(!varg1 | (varg1 * 997 / varg1 == 997), Panic(17)); // arithmetic overflow or underflow
            v15 = _SafeMul(varg1 * 997, uint112(v12));
        } else {
            v16, /* uint256 */ v17, /* uint256 */ v18, /* uint256 */ v18, /* uint256 */ v17 = varg5.getReserves().gas(msg.gas);
            require(v16);
            if (1 == v6) {
                // Unknown jump to Block 0x38800x1e77. Refer to 3-address code (TAC);
            }
            if (bool(uint112(v17))) {
                // Unknown jump to Block 0x389f0x1e77. Refer to 3-address code (TAC);
            }
        }
    }
}

function 0x1f9d(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3, uint256 varg4) private { 
    v0 = 0x1fcb(varg0, varg2, varg3, varg4);
    if (v0 < varg1) {
        require(varg1 - v0 > varg1, varg1 - v0);
        revert(Panic(17));
    } else {
        return v0;
    }
}

function 0x1fcb(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3) private { 
    varg2 = v0 = 0;
    v1 = 0x4e5(varg1);
    varg2 = v2 = MEM[64];
    0x4c3(v2, v1);
    MEM[v2] = varg1;
    v3 = 0x4e5(varg1);
    CALLDATACOPY(v2 + 32, msg.data.length, v3 + ~31);
    v4 = 0x4e5(varg1);
    varg2 = v5 = MEM[64];
    0x4c3(v5, v4);
    MEM[v5] = varg1;
    v6 = 0x4e5(varg1);
    CALLDATACOPY(v5 + 32, msg.data.length, v6 + ~31);
    v7 = 0x167a(v5);
    MEM[v7] = varg0;
    v8 = 0x167a(v2);
    MEM[v8] = varg0;
    while (!varg2) {
        varg2, varg2, v9, v10 = 0x3588(varg2, varg2);
        varg2 = v11 = byte(msg.data[v10], 0x1);
        varg2 = v12 = byte(msg.data[v10], 0x2);
        varg2 = v13 = 8422;
        varg2 = v14 = 8415;
        varg2 = v15 = 8388;
        if (0 == bool(uint24(msg.data[v10] >> 208))) {
            require(v11 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            varg2 = v16 = MEM[(v11 << 5) + varg2 + 32];
            v17 = v18 = 7 + v10;
            v19 = v20 = v9 + ~6;
        } else {
            require(v11 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v21 = _SafeMul(MEM[(v11 << 5) + varg2 + 32], uint24(msg.data[v10] >> 208));
            varg2 = v22 = v21 / uint24.max;
            v17 = v23 = 7 + v10;
            v19 = v24 = v9 + ~6;
        }
        v25 = byte(msg.data[v10], varg2);
        if (uint8(v25)) {
            if (1 - uint8(v25)) {
                require(address(map_1[uint8(v25)]), uint8(v25));
                v26 = new uint256[](v19);
                CALLDATACOPY(v26.data, v17, v19);
                v27 = address(map_1[uint8(v25)]).swap(varg2, v26).gas(msg.gas);
                if (!v27) {
                    RETURNDATACOPY(MEM[64], 0, RETURNDATASIZE());
                    revert(MEM[64], RETURNDATASIZE());
                } else {
                    varg2 = v28 = 0xbd0625ab00000000000000000000000000000000000000000000000000000000;
                }
            } else {
                require(v19 >= 87, v19);
                0x4a7(MEM[64]);
                CALLDATACOPY(MEM[64], msg.data.length, 64);
                if (0 == uint8(msg.data[v17 + 65] >> 80)) {
                    // Unknown jump to Block 0x19870x1fcb. Refer to 3-address code (TAC);
                } else {
                    varg2 = v29 = 0x390d(varg2);
                }
                if (0 == uint8(msg.data[v17 + 65] >> 88)) {
                    v30 = v31 = uint160.max;
                    v32 = v33 = 0xfffd8963efd1fc6a506488495d951d5263988d25;
                    // Unknown jump to Block 0x199d0x1fcb. Refer to 3-address code (TAC);
                } else {
                    v30 = uint160.max;
                    v32 = 0x1000276a4;
                }
                v34 = new uint256[](v19 + ~41);
                MEM[v34.data] = msg.data[v17];
                CALLDATACOPY(MEM[64] + 241, v17 + 87, v19 + ~86);
                v35, v36, /* uint256 */ varg2, /* uint256 */ v37 = (msg.data[v17 + 65] >> 96).swap(msg.data[v17 + 45] >> 96, uint8(msg.data[v17 + 65] >> 88), varg2, v32 & v30, v34, v36, bytes25(msg.data[v17 + 20])).gas(msg.gas);
                if (!v35) {
                    RETURNDATACOPY(0, 0, RETURNDATASIZE());
                    revert(0, RETURNDATASIZE());
                } else {
                    if (!uint8(msg.data[v17 + 65] >> 88)) {
                        if (MEM[MEM[64]] <= 0) {
                            v38 = v39 = 32;
                            varg2 = v40 = 0x390d(MEM[MEM[64]]);
                            // Unknown jump to Block 0x1a730x1fcb. Refer to 3-address code (TAC);
                        } else {
                            v38 = 32;
                            varg2 = v41 = MEM[MEM[64]];
                        }
                        varg2 = v42 = MEM[MEM[64] + v38];
                        // Unknown jump to Block 0x1a460x1fcb. Refer to 3-address code (TAC);
                    } else {
                        if (MEM[MEM[64] + 32] <= 0) {
                            varg2 = v43 = 0x390d(MEM[MEM[64] + 32]);
                            // Unknown jump to Block 0x1a420x1fcb. Refer to 3-address code (TAC);
                        }
                        varg2 = v44 = MEM[MEM[64]];
                    }
                    if (uint8(msg.data[v17 + 65] >> 80)) {
                    }
                }
            }
            varg2 = v45 = 8377;
            varg2 = v46 = 8371;
            require(v12 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v47 = v48 = (v12 << 5) + varg2 + 32;
            while (1) {
                v49 = MEM[v47];
                v49 = v50 = _SafeAdd(v49, varg2);
                require(varg2 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
                MEM[(varg2 << 5) + varg2 + 32] = v49;
                require(varg2 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
                v47 = (varg2 << 5) + varg2 + 32;
                // Unknown jump to Block 0x20ad0x1fcb. Refer to 3-address code (TAC);
            }
            v51 = v49 + varg2;
            if (v49 <= v51) {
                require(varg2 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
                MEM[(varg2 << 5) + varg2 + 32] = v51;
                require(varg2 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
                v52 = MEM[(varg2 << 5) + varg2 + 32];
                v53 = v52 - varg2;
                if (v53 <= v52) {
                    require(varg2 < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
                    MEM[(varg2 << 5) + varg2 + 32] = v53;
                }
            }
        } else if (!uint8(msg.data[~21 + (v17 + v19)] >> 80)) {
            v54, /* uint256 */ v55, /* uint256 */ v56, /* uint256 */ v56, /* uint256 */ v55 = (msg.data[v17 + v19 + ~41] >> 96).getReserves().gas(msg.gas);
            require(v54);
            if (1 == uint8(msg.data[~21 + (v17 + v19)] >> 88)) {
                // Unknown jump to Block 0x378f0x1fcb. Refer to 3-address code (TAC);
            }
            v57 = bool(uint112(v55));
            if (v57) {
                v57 = v58 = bool(uint112(v56));
                // Unknown jump to Block 0x37ab0x1fcb. Refer to 3-address code (TAC);
            }
            require(v57, Error(76));
            if (!varg2 | (varg2 * 997 / varg2 == 997)) {
                v59 = _SafeMul(varg2 * 997, uint112(v56));
                v60 = 0x15bb(uint112(v55));
            }
        } else {
            v61, /* uint256 */ v62, /* uint256 */ v63, /* uint256 */ v63, /* uint256 */ v62 = (msg.data[v17 + v19 + ~41] >> 96).getReserves().gas(msg.gas);
            require(v61);
            if (1 == uint8(msg.data[~21 + (v17 + v19)] >> 88)) {
                // Unknown jump to Block 0x38800x1fcb. Refer to 3-address code (TAC);
            }
            v64 = bool(uint112(v62));
            if (v64) {
                v64 = v65 = bool(uint112(v63));
                // Unknown jump to Block 0x389f0x1fcb. Refer to 3-address code (TAC);
            }
            require(v64, Error(76));
            if ((uint112(v62) * varg2 / uint112(v62) == varg2) | !uint112(v62)) {
                if (!(uint112(v62) * varg2) | (uint112(v62) * varg2 * 1000 / (uint112(v62) * varg2) == 1000)) {
                    v66 = _SafeSub(uint112(v63), varg2);
                }
            }
        }
    }
    require(uint8(varg2) < MEM[varg2], Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    return MEM[(uint8(varg2) << 5) + varg2 + 32];
    revert(Panic(17));
}

function 0x2163(uint256 varg0, uint256 varg1, uint256 varg2, struct(5) varg3, uint256 varg4, uint256 varg5, uint256 varg6) private { 
    require(16 > varg1, Panic(33)); // failed convertion to enum type
    require(varg1, 0);
    require(16 > varg1, Panic(33)); // failed convertion to enum type
    if (varg1 - 1) {
        require(16 > varg1, Panic(33)); // failed convertion to enum type
        if (varg1 - 2) {
            require(16 > varg1, Panic(33)); // failed convertion to enum type
            if (varg1 - 3) {
                require(16 > varg1, Panic(33)); // failed convertion to enum type
                if (varg1 - 4) {
                    require(16 > varg1, Panic(33)); // failed convertion to enum type
                    if (varg1 - 5) {
                        require(16 > varg1, Panic(33)); // failed convertion to enum type
                        if (varg1 - 7) {
                            require(16 > varg1, Panic(33)); // failed convertion to enum type
                            if (varg1 - 6) {
                                require(16 > varg1, Panic(33)); // failed convertion to enum type
                                if (varg1 - 8) {
                                    require(16 > varg1, Panic(33)); // failed convertion to enum type
                                    if (varg1 - 9) {
                                        require(16 > varg1, Panic(33)); // failed convertion to enum type
                                        if (varg1 - 10) {
                                            require(16 > varg1, Panic(33)); // failed convertion to enum type
                                            if (varg1 - 11) {
                                                require(16 > varg1, Panic(33)); // failed convertion to enum type
                                                if (varg1 - 12) {
                                                    require(16 > varg1, Panic(33)); // failed convertion to enum type
                                                    if (varg1 - 14) {
                                                        require(16 > varg1, Panic(33)); // failed convertion to enum type
                                                        if (varg1 - 15) {
                                                            require(16 <= varg1, uint8(varg1));
                                                            revert(Panic(33));
                                                        } else {
                                                            if (!varg0) {
                                                                v0, /* uint256 */ varg5 = address(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2).balanceOf(this).gas(msg.gas);
                                                                if (v0) {
                                                                    varg5 = v1 = 0;
                                                                    if (v0) {
                                                                        v2 = v3 = 32;
                                                                        if (v3 > RETURNDATASIZE()) {
                                                                            v2 = v4 = RETURNDATASIZE();
                                                                            0x4c3(MEM[64], v4);
                                                                        } else {
                                                                            0x4c3(MEM[64], v3);
                                                                        }
                                                                        require(MEM[64] + v2 - MEM[64] >= 32);
                                                                        v5 = this.code.size;
                                                                    }
                                                                }
                                                            }
                                                            revert(MEM[64], RETURNDATASIZE());
                                                            require((address(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2)).code.size);
                                                            v6 = address(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2).withdraw(varg5).gas(msg.gas);
                                                            if (v6) {
                                                                if (v6) {
                                                                    0x456(MEM[64]);
                                                                    require(0 >= 0);
                                                                    // Unknown jump to Block 0x51b0x2163. Refer to 3-address code (TAC);
                                                                } else {
                                                                    // Unknown jump to Block 0x51b0x2163. Refer to 3-address code (TAC);
                                                                }
                                                            }
                                                        }
                                                    } else {
                                                        if (varg0) {
                                                            // Unknown jump to Block 0x26ebB0x239f. Refer to 3-address code (TAC);
                                                        } else {
                                                            varg5 = v7 = this.balance;
                                                        }
                                                        require((address(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2)).code.size);
                                                        v8 = address(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2).deposit().value(varg5).gas(msg.gas);
                                                        require(v8, MEM[64], RETURNDATASIZE());
                                                        if (v8) {
                                                            0x456(MEM[64]);
                                                            // Unknown jump to Block 0x51b0x2163. Refer to 3-address code (TAC);
                                                        } else {
                                                            // Unknown jump to Block 0x51b0x2163. Refer to 3-address code (TAC);
                                                        }
                                                    }
                                                } else {
                                                    v9 = v10 = 1307;
                                                    v9 = v11, varg6 = v12 = 0x3568(varg2, varg3);
                                                    v9 = v13 = address(v11);
                                                    if (v13) {
                                                        if (varg0) {
                                                            v9 = v14 = 1307;
                                                            0x30cd(v11, v12, varg0);
                                                            v15 = uint160.max;
                                                            v16 = v17 = 0;
                                                            v18 = v9.transfer(address(varg6), varg5).value(v17).gas(msg.gas);
                                                            require(v18, v17, RETURNDATASIZE());
                                                            v19 = v20 = 12558;
                                                            v21 = v22 = 0x34c5_isContract(v9);
                                                        } else {
                                                            v15 = v23 = 0x70a0823100000000000000000000000000000000000000000000000000000000;
                                                            v24, /* uint256 */ v25 = v11.balanceOf(this).gas(msg.gas);
                                                            require(v24, MEM[64], RETURNDATASIZE());
                                                            varg5 = v26 = v25 + ~0;
                                                            v16 = v27 = 0;
                                                            v28 = v11.transfer(v12, v26).value(v27).gas(msg.gas);
                                                            require(v28, v27, RETURNDATASIZE());
                                                            v19 = v29 = 9631;
                                                            v21 = v30 = 0x34c5_isContract(v11);
                                                        }
                                                        if (!v21) {
                                                            v31, v16 = v9.balanceOf(this).gas(msg.gas);
                                                            require(v31, MEM[64], RETURNDATASIZE());
                                                            if (v31) {
                                                                v32 = v33 = 32;
                                                                if (v33 > RETURNDATASIZE()) {
                                                                    v32 = v34 = RETURNDATASIZE();
                                                                    0x4c3(MEM[64], v34);
                                                                } else {
                                                                    0x4c3(MEM[64], v33);
                                                                }
                                                                require(MEM[64] + v32 - MEM[64] >= 32);
                                                            }
                                                            revert(v16, varg5);
                                                        } else {
                                                            // Unknown jump to Block 0x51b0x2163. Refer to 3-address code (TAC);
                                                        }
                                                    } else if (varg0) {
                                                        v35 = address(v12).call().value(varg0).gas(msg.gas);
                                                        require(v35, InvalidTransfer(address(v12), 0, varg0));
                                                        // Unknown jump to Block 0x51b0x24feB0x2383. Refer to 3-address code (TAC);
                                                    } else {
                                                        v36 = address(v12).call().value(this.balance).gas(msg.gas);
                                                        v37 = 0x268d();
                                                        require(v36, InvalidTransfer(address(v12), 0, this.balance));
                                                        // Unknown jump to Block 0x51b0x24feB0x2383. Refer to 3-address code (TAC);
                                                    }
                                                }
                                                return ;
                                            } else {
                                                v38 = 0x2355(msg.data[msg.data[varg2 + 64] + varg2], msg.data[varg2 + 64] + varg2 + 32, msg.data[varg2 + msg.data[varg2 + 32]], varg2 + msg.data[varg2 + 32] + 32, msg.data[varg2], varg0);
                                            }
                                        } else {
                                            varg5 = v39 = msg.data[varg2 + 32];
                                            varg6 = v40 = msg.data[varg2];
                                            v41 = 0x1f9d(varg0, v40, v39, varg2 + 64, ~63 + varg3);
                                            v42 = 0x4e5(varg5);
                                            0x4c3(MEM[64], v42);
                                            MEM[MEM[64]] = varg5;
                                            v43 = 0x4e5(varg5);
                                            CALLDATACOPY(MEM[64] + 32, msg.data.length, v43 + ~31);
                                        }
                                    } else {
                                        v44 = 0x22e1(msg.data[msg.data[varg2 + 32] + varg2], msg.data[varg2 + 32] + varg2 + 32, msg.data[varg2 + msg.data[varg2]], varg2 + msg.data[varg2] + 32, varg0);
                                    }
                                } else {
                                    v45 = 0x1fcb(varg0, msg.data[varg2], varg2 + 32, ~31 + varg3);
                                }
                            } else {
                                varg6 = v46 = msg.data[varg2 + 64];
                                varg6 = v47 = msg.data[varg2];
                                v48 = 0x1c95(varg0, v47, varg2 + 96, v46);
                                v49 = 0x1601(varg6);
                            }
                        } else {
                            v50 = 0x1c1f(varg0, msg.data[varg2], varg2 + 32, ~31 + varg3);
                        }
                    } else {
                        v51 = 0x1d7c(varg0, varg2 + 64, msg.data[32 + varg2]);
                    }
                } else {
                    v52 = 0x1c5a(varg0, varg2, varg3);
                }
            } else {
                v53 = 0x1ae3(varg0, varg2, varg3);
                v54 = v55 = 32;
                v56, /* uint256 */ v57 = address(msg.data[varg6 + 32] >> 96).balanceOf(address(msg.data[varg6 + 52] >> 96)).gas(msg.gas);
                require(v56, MEM[64], RETURNDATASIZE());
                if (v56) {
                    if (v55 > RETURNDATASIZE()) {
                        v54 = RETURNDATASIZE();
                        0x4c3(MEM[64], v54);
                    } else {
                        0x4c3(MEM[64], v55);
                    }
                    require(MEM[64] + v54 - MEM[64] >= 32);
                }
                v58 = ~6 + (~71 + varg5);
                if (uint8(byte(msg.data[varg6 + 72], 0x0))) {
                    if (!(1 - uint8(byte(msg.data[varg6 + 72], 0x0)))) {
                        require(v58 >= 87, v58);
                    }
                }
            }
        } else {
            v59 = 0x17b9(varg0, varg2, varg3);
        }
    } else {
        v60 = 0x1924(byte(msg.data[varg2], 0x0), varg0, varg2 + 7, ~6 + varg3, 8630, varg4);
    }
    return ;
}

function 0x22e1(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3, uint256 varg4) private { 
    v0 = 0x4e5(varg2);
    0x4c3(MEM[64], v0);
    v1 = 0x4e5(varg2);
    CALLDATACOPY(MEM[64] + 32, msg.data.length, v1 + ~31);
    v2 = 0x4e5(varg2);
    0x4c3(MEM[64], v2);
    v3 = 0x4e5(varg2);
    CALLDATACOPY(MEM[64] + 32, msg.data.length, v3 + ~31);
    v4 = 0x167a(MEM[64]);
    MEM[v4] = varg4;
    v5 = 0x167a(MEM[64]);
    MEM[v5] = varg4;
    if (uint8(0) >= varg0) {
        return 0;
    } else {
        require(uint8(0) < varg0, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        require(msg.data[varg1 + 0] < msg.data.length - varg1 + ~30);
        v6 = msg.data[varg1 + msg.data[varg1 + 0]];
        require(v6 <= uint64.max);
        v7 = 32 + (varg1 + msg.data[varg1 + 0]);
        require(v7 <= msg.data.length - v6);
        if (0 == bool(uint24(msg.data[v7] >> 208))) {
            require((byte(msg.data[v7], 0x1)) < varg2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v8 = v9 = MEM[((byte(msg.data[v7], 0x1)) << 5) + MEM[64] + 32];
        } else {
            require((byte(msg.data[v7], 0x1)) < varg2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v10 = _SafeMul(MEM[((byte(msg.data[v7], 0x1)) << 5) + MEM[64] + 32], uint24(msg.data[v7] >> 208));
            v8 = v10 / uint24.max;
        }
        require(address(map_1[uint8(byte(msg.data[v7], 0x0))]), uint8(byte(msg.data[v7], 0x0)));
        v11 = 100;
        if (1 == (byte(msg.data[v7], 0x6))) {
            v12 = new uint256[](v6 + 13);
            MEM[v13.data] = msg.data[((byte(msg.data[v7], 0x1)) << 5) + varg3] << 96;
            v11 = v14 = 120;
            v15 = v16 = 7;
            // Unknown jump to Block 0x30080x22e1. Refer to 3-address code (TAC);
        } else if (2 == (byte(msg.data[v7], 0x6))) {
            v17 = new uint256[](v6 + 13);
            MEM[v13.data] = msg.data[((byte(msg.data[v7], 0x2)) << 5) + varg3] << 96;
            v11 = v18 = 120;
            v15 = v19 = 7;
        } else if (3 == (byte(msg.data[v7], 0x6))) {
            v20 = new uint256[](v6 + 13);
            MEM[v13.data] = msg.data[varg3 + ((byte(msg.data[v7], 0x1)) << 5)] << 96;
            v15 = v21 = 7;
            v11 = v22 = 140;
        } else {
            v13 = new uint256[](v6 + 13);
            v15 = 7;
        }
        CALLDATACOPY(MEM[64] + v11, v7 + v15, ~6 + v6);
        v23, /* uint256 */ v24 = address(map_1[uint8(byte(msg.data[v7], 0x0))]).swap(v8, v12, v17, v20, v13, v25, msg.data[((byte(msg.data[v7], 0x2)) << 5) + varg3] << 96).gas(msg.gas);
        require(v23, MEM[64], RETURNDATASIZE());
        require((byte(msg.data[v7], 0x2)) < varg2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    }
}

function 0x2355(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3, uint256 varg4, uint256 varg5) private { 
    v0 = 0x4e5(varg2);
    0x4c3(MEM[64], v0);
    v1 = 0x4e5(varg2);
    CALLDATACOPY(MEM[64] + 32, msg.data.length, v1 + ~31);
    v2 = 0x4e5(varg2);
    0x4c3(MEM[64], v2);
    v3 = 0x4e5(varg2);
    CALLDATACOPY(MEM[64] + 32, msg.data.length, v3 + ~31);
    v4 = 0x167a(MEM[64]);
    MEM[v4] = varg5;
    v5 = 0x167a(MEM[64]);
    MEM[v5] = varg5;
    if (uint8(0) >= varg0) {
        if (0 < varg4) {
            require(varg4 - 0 > varg4, varg4 - 0);
            revert(Panic(17));
        } else {
            return 0;
        }
    } else {
        require(uint8(0) < varg0, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
        require(msg.data[varg1 + 0] < msg.data.length - varg1 + ~30);
        v6 = msg.data[varg1 + msg.data[varg1 + 0]];
        require(v6 <= uint64.max);
        v7 = 32 + (varg1 + msg.data[varg1 + 0]);
        require(v7 <= msg.data.length - v6);
        if (0 == bool(uint24(msg.data[v7] >> 208))) {
            require((byte(msg.data[v7], 0x1)) < varg2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v8 = v9 = MEM[((byte(msg.data[v7], 0x1)) << 5) + MEM[64] + 32];
        } else {
            require((byte(msg.data[v7], 0x1)) < varg2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
            v10 = _SafeMul(MEM[((byte(msg.data[v7], 0x1)) << 5) + MEM[64] + 32], uint24(msg.data[v7] >> 208));
            v8 = v10 / uint24.max;
        }
        require(address(map_1[uint8(byte(msg.data[v7], 0x0))]), uint8(byte(msg.data[v7], 0x0)));
        v11 = 100;
        if (1 == (byte(msg.data[v7], 0x6))) {
            v12 = new uint256[](v6 + 13);
            MEM[v13.data] = msg.data[((byte(msg.data[v7], 0x1)) << 5) + varg3] << 96;
            v11 = v14 = 120;
            v15 = v16 = 7;
            // Unknown jump to Block 0x30080x2355. Refer to 3-address code (TAC);
        } else if (2 == (byte(msg.data[v7], 0x6))) {
            v17 = new uint256[](v6 + 13);
            MEM[v13.data] = msg.data[((byte(msg.data[v7], 0x2)) << 5) + varg3] << 96;
            v11 = v18 = 120;
            v15 = v19 = 7;
        } else if (3 == (byte(msg.data[v7], 0x6))) {
            v20 = new uint256[](v6 + 13);
            MEM[v13.data] = msg.data[varg3 + ((byte(msg.data[v7], 0x1)) << 5)] << 96;
            v15 = v21 = 7;
            v11 = v22 = 140;
        } else {
            v13 = new uint256[](v6 + 13);
            v15 = 7;
        }
        CALLDATACOPY(MEM[64] + v11, v7 + v15, ~6 + v6);
        v23, /* uint256 */ v24 = address(map_1[uint8(byte(msg.data[v7], 0x0))]).swap(v8, v12, v17, v20, v13, v25, msg.data[((byte(msg.data[v7], 0x2)) << 5) + varg3] << 96).gas(msg.gas);
        require(v23, MEM[64], RETURNDATASIZE());
        require((byte(msg.data[v7], 0x2)) < varg2, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    }
}

function 0x268d() private { 
    if (!RETURNDATASIZE()) {
        return 96;
    } else {
        v0 = 0x161c(RETURNDATASIZE());
        0x4c3(MEM[64], v0);
        MEM[MEM[64]] = RETURNDATASIZE();
        RETURNDATACOPY(MEM[64] + 32, 0, RETURNDATASIZE());
        return MEM[64];
    }
}

function 0x2874(uint256 varg0, uint256 varg1, uint256 varg2) private { 
    require(varg2 < varg1, Panic(50)); // access an out-of-bounds or negative index of bytesN array or slice
    return (varg2 << 6) + varg0;
}

function 0x288e(uint256 varg0) private { 
    require(varg0 != ~0, Panic(17)); // arithmetic overflow or underflow
    return 1 + varg0;
}

function 0x28bf(uint256 varg0, uint256 varg1) private { 
    require(msg.data[varg1] < msg.data.length - varg0 + ~30);
    v0 = msg.data[varg0 + msg.data[varg1]];
    require(v0 <= uint64.max);
    require(32 + (varg0 + msg.data[varg1]) <= msg.data.length - (v0 << 5));
    return v0, 32 + (varg0 + msg.data[varg1]);
}

function 0x2b0c(uint256 varg0, uint256 varg1) private { 
    if (varg1 < 4) {
        return bytes4(~uint224.max << (4 - varg1 << 3) & msg.data[varg0]);
    } else {
        return bytes4(msg.data[varg0]);
    }
}

function 0x2ec8(uint256 varg0) private { 
    v0 = varg0 ^ varg0 >> uint8.max;
    require(!((varg0 >> uint8.max >= 0) & (v0 - (varg0 >> uint8.max) > v0) | (varg0 >> uint8.max < 0) & (v0 - (varg0 >> uint8.max) < v0)), Panic(17)); // arithmetic overflow or underflow
    return v0 - (varg0 >> uint8.max);
}

function 0x30cd(uint256 varg0, address varg1, uint256 varg2) private { 
    v0 = varg0.transfer(varg1, varg2).gas(msg.gas);
    require(v0, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
    v1 = 0x34c5_isContract(varg0);
    if (!v1) {
        v2, /* uint256 */ v3 = address(varg0).balanceOf(this).gas(msg.gas);
        require(v2, MEM[64], RETURNDATASIZE());
        require(v2, 0, varg2);
        v4 = v5 = 32;
        if (v5 > RETURNDATASIZE()) {
            v4 = RETURNDATASIZE();
            0x4c3(MEM[64], v4);
        } else {
            0x4c3(MEM[64], v5);
        }
        require(MEM[64] + v4 - MEM[64] < 32, v3, varg2);
        revert();
    } else {
        return ;
    }
}

function 0x3171_safeTransfer_token_from_to_amount(uint256 varg0, address varg1, address varg2, uint256 varg3) private { 
    v0 = varg0.transferFrom(varg1, varg2, varg3).gas(msg.gas);
    require(v0, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
    v1 = 0x34c5_isContract(varg0);//@check is contract
    if (!v1) {
        v2, /* uint256 */ v3 = address(varg0).balanceOf(this).gas(msg.gas);
        require(v2, MEM[64], RETURNDATASIZE());
        require(v2, 0, varg3);
        v4 = v5 = 32;
        if (v5 > RETURNDATASIZE()) {
            v4 = RETURNDATASIZE();
            0x4c3(MEM[64], v4);
        } else {
            0x4c3(MEM[64], v5);
        }
        require(MEM[64] + v4 - MEM[64] < 32, v3, varg3);
        revert();
    } else {
        return ;
    }
}

function 0x3435(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3) private { 
    if (!varg1) {
        require(!MEM[varg2], 32 + varg2, MEM[varg2]);
        v0 = MEM[varg3];
        v1 = new uint256[](v0);
        v2 = 0;
        while (v2 >= v0) {
            MEM[v2 + v1.data] = MEM[v2 + (varg3 + 32)];
            v2 += 32;
        }
        MEM[v0 + v1.data] = 0;
        revert(Error(v1));
    } else if (!MEM[varg2]) {
        require(varg0.code.size, Error('Address: call to non-contract'));
        return varg2;
    } else {
        return varg2;
    }
}

function 0x34c5_isContract(uint256 varg0) private { 
    if (!RETURNDATASIZE()) {
        require(varg0.code.size, Error(32, 20, 'GPv2: not a contract'));
        return 1;
    } else {
        require(32 == RETURNDATASIZE(), Error(32, 31, 'GPv2: malformed transfer result'));
        RETURNDATACOPY(0, 0, RETURNDATASIZE());
        return bool(MEM[0]);
    }
}

function 0x3568(uint256 varg0, struct(5) varg1) private { 
    if (varg1 == 40) {
        return msg.data[20 + varg0] >> 96, msg.data[varg0] >> 96;
    } else {
        return 0, msg.data[varg0] >> 96;
    }
}

function 0x3588(uint256 varg0, uint256 varg1) private { 
    if (1 == !varg1) {
        return 0, 0, 0, 0;
    } else {
        return varg1 - (msg.data[varg0] >> 240) + ~1, varg0 + (msg.data[varg0] >> 240) + 2, msg.data[varg0] >> 240, varg0 + 2;
    }
}

function 0x35bc_transferFrom_msg.sender(uint256 varg0, uint256 varg1, uint256 varg2) private { 
    v0 = msg.data[~21 + (varg1 + varg2)];
    v1 = v2 = uint8(v0 >> 80);
    v1 = v3 = 0x374e(varg0, msg.data[varg1 + varg2 + ~41] >> 96, uint8(v0 >> 88), v2, 13810);
    if (!varg2) {
        // Unknown jump to Block 0x35fd. Refer to 3-address code (TAC);
    }
    if (v0 - 63) {
        require(!(v0 - 43), v0);
        v1 = v4 = 0;
    } else {
        if (0 == varg2) {
            v5 = v6 = uint8.max;
            // Unknown jump to Block 0x3620. Refer to 3-address code (TAC);
        } else {
            v5 = v7 = uint8.max;
        }
        if (0 == msg.data[varg0] >> 88 & v5) {
            v8 = (msg.data[varg0] >> 96).transfer(uint8(v0 >> 88), v1).gas(msg.gas);
            require(v8, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
            v1 = v9 = 0;
        } else {
            v10 = (msg.data[varg0] >> 96).transferFrom(cache_msgsender, uint8(v0 >> 88), v1).gas(msg.gas);
            require(v10, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
            v1 = v11 = 0;
        }
    }
    if (v12) {
        v13 = this.code.size;
        // Unknown jump to Block 0x367c. Refer to 3-address code (TAC);
    }
    v14 = uint8(v0 >> 88).swap(v1, v1, msg.data[varg1 + varg2 + ~41] >> 96 >> 96, 128, v1).value(v1).gas(msg.gas);
    require(v14, 0, RETURNDATASIZE()); // checks call status, propagates error data on error
    return v3;
}

function 0x374e(uint256 varg0, uint256 varg1, uint256 varg2, uint256 varg3, uint256 varg4) private { 
    if (!varg3) {
        v0, /* uint256 */ v1, /* uint256 */ v2, /* uint256 */ v2, /* uint256 */ v1 = varg1.getReserves().gas(msg.gas);
        require(v0);
        if (1 == varg2) {
            // Unknown jump to Block 0x378f0x374e. Refer to 3-address code (TAC);
        }
        v3 = bool(uint112(v1));
        if (v3) {
            v3 = v4 = bool(uint112(v2));
            // Unknown jump to Block 0x37ab0x374e. Refer to 3-address code (TAC);
        }
        require(v3, Error(76));
        if (!varg0 | (varg0 * 997 / varg0 == 997)) {
            v5 = v6 = 5960;
            v7 = v8 = _SafeMul(varg0 * 997, uint112(v2));
            v9 = 0x15bb(uint112(v1));
            v10 = v11 = _SafeAdd(v9, varg0 * 997);
        }
    } else {
        varg1 = v12 = 0x3850(varg1, varg0, varg2);
        v13, /* uint256 */ v14, /* uint256 */ v15, /* uint256 */ v15, /* uint256 */ v14 = varg1.getReserves().gas(msg.gas);
        require(v13);
        if (1 == v16) {
            // Unknown jump to Block 0x38800x374e. Refer to 3-address code (TAC);
        }
        v17 = bool(uint112(v14));
        if (v17) {
            v17 = v18 = bool(uint112(v15));
            // Unknown jump to Block 0x389f0x374e. Refer to 3-address code (TAC);
        }
        require(v17, Error(76));
        v19 = uint112(v14) * varg4;
        if ((v19 / uint112(v14) == varg4) | !uint112(v14)) {
            v7 = v19 * 1000;
            if (!v19 | (v7 / v19 == 1000)) {
                v5 = 14556;
                varg4 = v20 = 5960;
                v21 = _SafeSub(uint112(v15), varg4);
                v10 = v22 = 0x15d7(v21);
            }
        }
    }
    return varg1;
    revert(Panic(17));
    require(v10, Panic(18)); // division by zero
    varg1 = v23 = v7 / v10;
    // Unknown jump to Block 0x17480x374e. Refer to 3-address code (TAC);
}

function 0x3850(uint256 varg0, uint256 varg1, uint256 varg2) private { 
    v0, /* uint256 */ v1, /* uint256 */ v2, /* uint256 */ v2, /* uint256 */ v1 = varg0.getReserves().gas(msg.gas);
    require(v0);
    if (1 == varg2) {
        // Unknown jump to Block 0x38800x3850. Refer to 3-address code (TAC);
    }
    v3 = bool(uint112(v1));
    if (v3) {
        v3 = v4 = bool(uint112(v2));
        // Unknown jump to Block 0x389f0x3850. Refer to 3-address code (TAC);
    }
    require(v3, Error(76));
    if ((uint112(v1) * varg1 / uint112(v1) == varg1) | !uint112(v1)) {
        if (!(uint112(v1) * varg1) | (uint112(v1) * varg1 * 1000 / (uint112(v1) * varg1) == 1000)) {
            v5 = _SafeSub(uint112(v2), varg1);
            v6 = 0x15d7(v5);
            require(v6, Panic(18)); // division by zero
            v7 = 0x1601(uint112(v1) * varg1 * 1000 / v6);
            return v7;
        }
    }
    revert(Panic(17));
}

function 0x390d(uint256 varg0) private { 
    require(varg0 != int256.min, Panic(17)); // arithmetic overflow or underflow
    return 0 - varg0;
}

function 0x456(uint256 varg0) private { 
    require(varg0 <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
    MEM[64] = varg0;
    return ;
}

function 0x46f(uint256 varg0) private { 
    require(!((varg0 + 96 > uint64.max) | (varg0 + 96 < varg0)), Panic(65)); // failed memory allocation (too much memory)
    MEM[64] = varg0 + 96;
    return ;
}

function 0x4a7(uint256 varg0) private { 
    require(!((varg0 + 64 > uint64.max) | (varg0 + 64 < varg0)), Panic(65)); // failed memory allocation (too much memory)
    MEM[64] = varg0 + 64;
    return ;
}

function 0xfb371b15(uint256 varg0) public nonPayable { 
    require(~3 + msg.data.length >= 32);
    require(!(uint8(varg0) - varg0));
    return address(map_1[uint8(varg0)]);
}

function 0x4c3(uint256 varg0, uint256 varg1) private { 
    v0 = varg0 + (varg1 + 31 & ~0x1f);
    require(!((v0 > uint64.max) | (v0 < varg0)), Panic(65)); // failed memory allocation (too much memory)
    MEM[64] = v0;
    return ;
}

function 0x4e5(uint256 varg0) private { 
    require(varg0 <= uint64.max, Panic(65)); // failed memory allocation (too much memory)
    return 32 + (varg0 << 5);
}

// Note: The function selector is not present in the original solidity code.
// However, we display it for the sake of completeness.

function __function_selector__(bytes4 function_selector) public payable { 
    MEM[64] = 128;
    if (msg.data.length >= 4) {
        if (0x1ffc9a7 == function_selector >> 224) {
            supportsInterface(bytes4);
        } else if (0x117aa677 == function_selector >> 224) {
            0x117aa677();
        } else if (0x157620ab == function_selector >> 224) {
            withdraw(address[],address);
        } else if (0x248a9ca3 == function_selector >> 224) {
            getRoleAdmin(bytes32);
        } else if (0x29093f86 == function_selector >> 224) {
            0x29093f86();
        } else if (0x2e29569f == function_selector >> 224) {
            0x2e29569f();
        } else if (0x2f2ff15d == function_selector >> 224) {
            grantRole(bytes32,address);
        } else if (0x34c202a2 == function_selector >> 224) {
            0x34c202a2();
        } else if (0x36568abe == function_selector >> 224) {
            renounceRole(bytes32,address);
        } else if (0x4629fd85 == function_selector >> 224) {
            0x4629fd85();
        } else if (0x46b5cb59 == function_selector >> 224) {
            batchGrantRole(bytes32,address[]);
        } else if (0x476357fe == function_selector >> 224) {
            0x476357fe();
        } else if (0x5ae3671b == function_selector >> 224) {
            0x5ae3671b();
        } else if (0x6e5129d1 == function_selector >> 224) {
            0x6e5129d1();
        } else if (0x7515d97c == function_selector >> 224) {
            0x7515d97c();
        } else if (0x7fd6b3c7 == function_selector >> 224) {
            0x7fd6b3c7();
        } else if (0x88406164 == function_selector >> 224) {
            0x88406164();
        } else if (0x91d14854 == function_selector >> 224) {
            hasRole(bytes32,address);
        } else if (0xa217fddf == function_selector >> 224) {
            DEFAULT_ADMIN_ROLE();
        } else if (0xa56b4ece == function_selector >> 224) {
            0xa56b4ece();
        } else if (0xd547741f == function_selector >> 224) {
            revokeRole(bytes32,address);
        } else if (0xe086e5ec == function_selector >> 224) {
            withdrawETH();
        } else if (0xfa461e33 == function_selector >> 224) {
            uniswapV3SwapCallback(int256,int256,bytes);
        } else if (!(0xfb371b15 - (function_selector >> 224))) {
            0xfb371b15();
        }
    }
    if (msg.data.length) {
        require(!msg.value);
        v0 = v1 = 0;
        v0 = v2 = 10537;
        v3 = v4 = 7938;
        v5 = v6 = 10511;
        require(4 <= msg.data.length);
        v7 = v8 = 0;
        v9 = v10 = 4;
        while (1) {
            v11 = 0x2b0c(v7, v9);
            v12 = v13 = address(map_2[bytes4(v11)]);
            v0 = v14 = uint160.max;
            if (!address(v13)) {
                v3 = v15 = 1075;
                v5 = 10768;
                require(4 <= msg.data.length);
                v7 = 0;
                v9 = 4;
                // Unknown jump to Block 0x2909B0x1a. Refer to 3-address code (TAC);
            } else {
                v16 = new uint256[](msg.data.length);
                CALLDATACOPY(v16.data, 4, msg.data.length);
                v17, /* uint256 */ v18, v12, /* address */ v19, /* uint16 */ v20 = v13.delegatecall(0x76b20f8a00000000000000000000000000000000000000000000000000000000, msg.sender, v16).gas(msg.gas);
                require(v17, MEM[64], RETURNDATASIZE());
                v12 = v21 = 1307;
                require(4 + uint16(v20) <= uint16.max, Panic(17)); // arithmetic overflow or underflow
                require(uint16(4 + uint16(v20)) <= msg.data.length);
                require(msg.data.length <= msg.data.length);
                v12 = v22 = uint16(msg.data[uint16(4 + uint16(v20))] >> 192);
                v12 = v23 = uint16(4 + uint16(v20)) + uint16(msg.data[uint16(4 + uint16(v20))] >> 224) + 10;
                v12 = v24 = uint8(msg.data[uint16(4 + uint16(v20))] >> 240);
                require(msg.data[uint16(4 + uint16(v20))] >> 248 < 16, Panic(33)); // failed convertion to enum type
                if ((msg.data[uint16(4 + uint16(v20))] >> 248) - 13) {
                    require(16 > msg.data[uint16(4 + uint16(v20))] >> 248, Panic(33)); // failed convertion to enum type
                    if ((msg.data[uint16(4 + uint16(v20))] >> 248) - 12) {
                        0x2163(v18, msg.data[uint16(4 + uint16(v20))] >> 248, uint16(4 + uint16(v20)) + 10, uint16(msg.data[uint16(4 + uint16(v20))] >> 224), 11002, v24, v23);
                    } else {
                        0x30cd(address(v19), msg.sender, v18);
                    }
                } else {
                    0x3171_safeTransfer_token_from_to_amount(address(v19), cache_msgsender, msg.sender, v18);
                }
                if (v12) {
                    0x2163(v12, v12, v12, v12, 10962, v12, v13);
                    v25 = this.code.size;
                    // Unknown jump to Block 0x2ac30x28f5B0x1a. Refer to 3-address code (TAC);
                }
                // Unknown jump to Block 0x210x0. Refer to 3-address code (TAC);
            }
        }
        revert(UnknownSelector(bytes4(v11)));
    }
}
