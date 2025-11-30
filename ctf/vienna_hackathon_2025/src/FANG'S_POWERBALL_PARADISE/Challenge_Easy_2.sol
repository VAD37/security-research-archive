// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import {IPot} from "src/IPot.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract ChallengeEasy2 is ERC2771Context {
    struct Game {
        uint256 startblock;
        uint256 luckyNumber;
        uint256 winnings;
    }

    uint256 public constant MIN_WINS = 5;
    IPot public pot;
    mapping(address user => Game game) public games;

    constructor(address _pot, address _forwarder) ERC2771Context(_forwarder) {
        pot = IPot(_pot);
    }

    function onlyEOA(address sender) internal view {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(sender)
        }
        require(size == 0, "ONLY_EOA");
    }

    function winnings(address user) external view returns (uint256) {
        return games[user].winnings;
    }

    function start(uint256 luckyNumber) external {
        onlyEOA(_msgSender());
        require(luckyNumber < 26, "INVALID_NUMBER");

        Game storage powerballGame = games[_msgSender()];
        powerballGame.startblock = block.number;
        powerballGame.luckyNumber = luckyNumber;
    }

    function solve() external {
        onlyEOA(_msgSender());

        Game storage powerballGame = games[_msgSender()];

        require(powerballGame.startblock > 0, "NOT_STARTED");
        require(block.number > powerballGame.startblock, "NOT_ON_SAME_BLOCK");
        require(powerballGame.winnings < MIN_WINS, "ALREADY_SOLVED");
        powerballGame.startblock = 0;

        if (powerballGame.luckyNumber == (block.prevrandao % 26)) {
            powerballGame.winnings++;
        } else {
            powerballGame.winnings = 0;
        }

        if (powerballGame.winnings == MIN_WINS) {
            pot.addPoints(_msgSender());
        }
    }
}
