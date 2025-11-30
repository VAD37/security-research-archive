// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";

contract CounterTest is Test {
    struct StakedLock {
        uint256 unlockTime;
    }

    StakedLock[] userLocks;
    mapping(uint256 => StakedLock[]) public tl;

    function setUp() public {}

    function test_Increment() public {
        for (uint256 i = 1; i < 11; i++) {
            newLock(i * 3);
        }
        for (uint256 i = 0; i < userLocks.length; i++) {
            console.log("unlockTime[%d]: %d", i, userLocks[i].unlockTime);
        }
        newLock(4);

        for (uint256 i = 0; i < userLocks.length; i++) {
            console.log("unlockTime[%d]: %d", i, userLocks[i].unlockTime);
        }
    }

    function test_locklist() public {
        StakedLock[] storage t = tl[1];
        t.push(StakedLock(66));
        t.push(StakedLock(3));

        StakedLock[] memory t2 = tl[1];

        t.push(StakedLock(9));

        for (uint256 i = 0; i < t2.length; i++) {
            console.log("unlockTime[%d]: %d", i, t2[i].unlockTime);
        }
    }

    function newLock(uint256 unlockTime) internal {
        uint256 userLocksLength = userLocks.length;
        uint256 lockIndex = binarySearch(userLocks, userLocksLength, unlockTime); //@sorted list from low to high. earliest to longest lock
        StakedLock memory newLock = StakedLock({unlockTime: unlockTime});

        if (userLocksLength > 0) {
            //@lockIndex range from 0-> length. so it must reduce by 1 to get actual index
            uint256 indexToAggregate = lockIndex == 0 ? 0 : lockIndex - 1; //@audit M Out of sort list when lockIndex == 1 .this also result index 0 == index 1
            console.log("indexToAggregate: %d, lockIndex: %d", indexToAggregate, lockIndex);
            if (indexToAggregate < userLocksLength && userLocks[indexToAggregate].unlockTime == unlockTime) {
                // userLocks[indexToAggregate].unlockTime = unlockTime;
                console.log("eh");
                insertLock(newLock, lockIndex, userLocksLength);
            } else {
                insertLock(newLock, lockIndex, userLocksLength);
            }
        } else {
            //new lock
            insertLock(newLock, lockIndex, userLocksLength); //@audit M no locks limit per address to prevent out of gas issue
        }
    }

    function insertLock(StakedLock memory newLock, uint256 index, uint256 lockLength) private {
        userLocks.push();
        for (uint256 j = lockLength; j > index;) {
            userLocks[j] = userLocks[j - 1];
            unchecked {
                j--;
            }
        }
        userLocks[index] = newLock;
    }

    function binarySearch(StakedLock[] memory _locks, uint256 _length, uint256 _unlockTime)
        private
        pure
        returns (uint256)
    {
        uint256 low = 0;
        uint256 high = _length; //10
        while (low < high) {
            uint256 mid = (low + high) / 2; //5
            if (_locks[mid].unlockTime < _unlockTime) {
                //newLock time > middle lock
                low = mid + 1; // 6
            } else {
                high = mid; //5
            }
        }
        return low;
    }
}
