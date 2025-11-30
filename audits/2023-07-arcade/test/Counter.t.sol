// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/Test.sol";
import "../contracts/ArcadeGSCCoreVoting.sol";
import "../contracts/ARCDVestingVault.sol";
import "../contracts/test/MockERC20Reentrancy.sol";
using stdStorage for StdStorage;
contract CounterTest is Test {
    ArcadeGSCCoreVoting public voting;
        struct Member {
        // vaults used by the member to gain membership
        address[] vaults;
        // timestamp when the member joined
        uint256 joined;
    }
    mapping(address => Member) public members;
        function getUserVaults(address who) public view returns (address[] memory) {
        return members[who].vaults;
    }


    ARCDVestingVault public vestingVault;
    MockERC20Reentrancy public token;

    function setUp() public {
        // address timelock = address(0x9);
        // uint baseQuorum = 3;
        // uint min = 1;
        // address gsc;
        // address[] memory vaults = new address[](1);
        // voting = new ArcadeGSCCoreVoting(timelock,baseQuorum,min,gsc,vaults);

        token = new MockERC20Reentrancy();
        vestingVault = new ARCDVestingVault(IERC20(token), 1, address(this), address(this));
        token.setVesting(IARCDVestingVault(address(0x312)));
        token.mint(address(this), 1e27);
        token.approve(address(vestingVault), 1e27);
    }

    function testVault() public {

        vestingVault.deposit(1e20);
        vestingVault.withdraw(1e18,address(this));

        address who = address(0x100);
        uint128 amount = 1e18;
        uint128 cliffAmount = 5e17;
        uint128 startTime = uint128(block.timestamp);
        uint128 expiration = uint128(block.timestamp + 100);
        uint128 cliff = 100;
        address delegatee = address(0x200);
        console.log("vote1", vestingVault.debug_getVotingPower(who));
        console.log("vote2", vestingVault.debug_getVotingPower(delegatee));
        vestingVault.addGrantAndDelegate(who, amount, cliffAmount, startTime, expiration, cliff, delegatee);
        console.log("vote1", vestingVault.debug_getVotingPower(who));
        console.log("vote2 %e", vestingVault.debug_getVotingPower(delegatee));
    }

    function testMembers() public {
        
        // address target = address(0x6);
        // address[] memory vaults = new address[](3);
        // vaults[0] = address(0x200);
        // vaults[1] = address(0x300);
        // vaults[2] = address(0x400);
        // vm.record();
        // emit log_named_bytes32("special mem", vm.load(address(this), 0xaa9d6b878347abc8a737844ebe1b4b187b92d372738307fc7c4c7b1bec679309));
        // members[target] = Member(vaults,block.timestamp + 123456789);
        // logAccesses(address(this));
        // emit log_named_bytes32("special mem", vm.load(address(this), 0xaa9d6b878347abc8a737844ebe1b4b187b92d372738307fc7c4c7b1bec679309));
        // address[] memory result = getUserVaults(target);
        // console.log("length: %s", result.length);
        // console.log("result: %s", result[0]);
        // console.log("result: %s", result[1]);
        // console.log("result: %s", result[2]);
        // delete members[target];
        // emit log_named_bytes32("special mem", vm.load(address(this), 0xaa9d6b878347abc8a737844ebe1b4b187b92d372738307fc7c4c7b1bec679309));
        // //check vaults address again
        // result = getUserVaults(target);
        // console.log("length: %s", result.length);
        // // console.log("result: %s", result[0]);
        // // console.log("result: %s", result[1]);
        // vaults = new address[](2);
        // vaults[0] = address(0x300);
        // vaults[1] = address(0x200);
        // members[target] = Member(vaults,block.timestamp);
        // result = getUserVaults(target);
        // console.log("length: %s", result.length);
        // console.log("result: %s", result[0]);
        // console.log("result: %s", result[1]);
        // emit log_named_bytes32("special mem", vm.load(address(this), 0xaa9d6b878347abc8a737844ebe1b4b187b92d372738307fc7c4c7b1bec679309));
    }
    function logAccesses(address target) private {
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(target);
        console.log("Reading");
        for (uint i = 0; i < reads.length; i++) {
            emit log_named_bytes32(Strings.toString(i),reads[i]);
            emit log_named_bytes32(Strings.toString(i),vm.load(target, reads[i]));
        }
        console.log("Writing");
        for (uint i = 0; i < writes.length; i++) {
            emit log_named_bytes32(Strings.toString(i),writes[i]);
            emit log_named_bytes32(Strings.toString(i),vm.load(target, writes[i]));
        }
    }


    function testIncrement() public {
        // assertEq(voting.baseQuorum(), 3);
        // console.log("owner: %s", voting.owner());
    }

    function testHjack() public {
        // address[] memory targets = new address[](3);
        // bytes[] memory calldatas = new bytes[](4);
        // targets[0] = address(0x100);
        // targets[1] = address(0x300);
        
        // // printSlice(abi.encode(uint(1562),targets));
        // bytes memory call1= abi.encodeWithSignature("set(uint,uint)",1,1);
        // calldatas[1] = call1;
        // printSlice(abi.encode(calldatas));
        //array abi. 0: skip how manybytes before reading. 1: length of array. reading next amount of length

    }
    function printSlice(bytes memory _bytes) internal {
        emit log_named_bytes("0", slice(_bytes, 0, 32));
        emit log_named_bytes("1", slice(_bytes, 32, 32));
        emit log_named_bytes("2", slice(_bytes, 64, 32));
        emit log_named_bytes("3", slice(_bytes, 96, 32));
        emit log_named_bytes("4", slice(_bytes, 128, 32));
        emit log_named_bytes("5", slice(_bytes, 160, 32));
        emit log_named_bytes("6", slice(_bytes, 192, 32));
        emit log_named_bytes("7", slice(_bytes, 224, 32));
        emit log_named_bytes("8", slice(_bytes, 256, 32));
        emit log_named_bytes("9", slice(_bytes, 288, 32));
        emit log_named_bytes("10", slice(_bytes, 320, 32));
        emit log_named_bytes("11", slice(_bytes, 352, 32));
        emit log_named_bytes("12", slice(_bytes, 384, 32));
        emit log_named_bytes("13", slice(_bytes, 416, 32));
        emit log_named_bytes("14", slice(_bytes, 448, 32));
        emit log_named_bytes("15", slice(_bytes, 480, 32));
        console.log("_______");
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    )
        internal
        pure
        returns (bytes memory tempBytes)
    {
        if(_length + 31 < _length) return tempBytes;
        if(_bytes.length < _start + _length) return tempBytes;
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");


        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}
//0x8b55ea6694e510e3f52fd81d601d292ee2765892f68f7e4cd499cb40318b64f4
//8b55ea6694e510e3f52fd81d601d292ee2765892f68f7e4cd499cb40318b64f4
//0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000641ab06ee500000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001123456780000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002460fe47b1000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000
//0x0000000000000000000000000000000000000000000000000000000000000020 0x20 = 32 . start reading from 0x20. skip first 32 bytes
//0000000000000000000000000000000000000000000000000000000000000002 // 2 length of calldata
//0000000000000000000000000000000000000000000000000000000000000040 // 64 // reading first calladata bytes. it said start reading from 0x40
//00000000000000000000000000000000000000000000000000000000000000e0 // 224 = 256-32 //length
//0000000000000000000000000000000000000000000000000000000000000064 // 100
//1ab06ee500000000000000000000000000000000000000000000000000000000 // 0x1ab06ee5 set(uint,uint)
//0000000100000000000000000000000000000000000000000000000000000000 // 1 result
//0000000112345678000000000000000000000000000000000000000000000000 // 1 result + special bytes4
//0000000000000000000000000000000000000000000000000000000000000000 // empty
//0000000000000000000000000000000000000000000000000000000000000024 // 0x24 = 36
//60fe47b100000000000000000000000000000000000000000000000000000000 // 0x60fe47b1 set(uint)
//0000000200000000000000000000000000000000000000000000000000000000 // 2 result + filler