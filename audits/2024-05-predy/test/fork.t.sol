// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/PredyPool.sol";

contract ForkTestPool is Test {
    PredyPool predyPool = PredyPool(payable(0x9215748657319B17fecb2b5D086A3147BFBC8613));

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://arb-mainnet.g.alchemy.com/v2/PxqMNBxAITOvMuJn_KmVI8XtGj337Arm");
        vm.selectFork(mainnetFork);
    }

    // function testOne() public {
    //     address operator = predyPool.operator();
    //     console.log("Operator: ", operator);
    //     (uint256 paisCount, uint256 vaultCount, address uniswapFactory,) = predyPool.globalData();
    //     console.log("UniSwap Factory: ", uniswapFactory);
    //     console.log("Pairs Count: ", paisCount);
    //     console.log("Vaults Count: ", vaultCount);
    //     vm.prank(operator);
    //     predyPool.initialize(uniswapFactory);
    //     console.log("Operator: ", predyPool.operator());
    // }

    function testCreatePool() public {
        address operator = predyPool.operator();
        console.log("Operator: ", operator);
        (uint256 paisCount, uint256 vaultCount, address uniswapFactory,) = predyPool.globalData();
        console.log("UniSwap Factory: ", uniswapFactory);
        console.log("Pairs Count: ", paisCount);
        console.log("Vaults Count: ", vaultCount);
        vm.prank(operator);
        predyPool.initialize(uniswapFactory);
        console.log("Operator: ", predyPool.operator());
    }
}
