// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.9;

import "./JUSDBankInit.t.sol";
import "../../src/Impl/flashloanImpl/FlashLoanLiquidate.sol";
import "../mocks/MockChainLinkEditable.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";

contract JUSDBankAuditTest is JUSDBankInitTest {
    function testBTCpartial() public {
        log_balance_watch(true);
        //Setup BTC with 20000 USD price
        vm.startPrank(address(this));
        MockChainLinkEditable btcOracle = new MockChainLinkEditable();
        btcOracle.SetPrice(20000e8);
        JOJOOracleAdaptor jojoOracle = new JOJOOracleAdaptor(
            address(btcOracle),
            10,
            86400,
            address(usdcPrice)
        );
        jusdBank.updateOracle(address(mockToken2), address(jojoOracle));
        swapContract.addTokenPrice(address(mockToken2), address(jojoOracle));
        vm.stopPrank();

        //alice 1 WBTC deposit. 7426e6 JUSD
        mockToken2.transfer(alice, 1e8);//BTC
        vm.startPrank(alice);
        mockToken2.approve(address(jusdBank), 1000e18);
        jusdBank.deposit(alice, address(mockToken2), 1e8, alice);
        jusdBank.borrow(13000e6, alice, false);
        vm.stopPrank();

        // bob liquidate alice
        vm.startPrank(bob);
        vm.warp(7 days);
        bytes memory data = swapContract.getSwapData(1e8, address(mockToken2));
        bytes memory param = abi.encode(
            swapContract,
            swapContract,
            address(bob),
            data
        );
        FlashLoanLiquidate flashloanRepay = new FlashLoanLiquidate(
            address(jusdBank),
            address(jusdExchange),
            address(USDC),
            address(jusd),
            insurance
        );
        bytes memory afterParam = abi.encode(address(flashloanRepay), param);
        // reduce BTC price to 15000$.
        btcOracle.SetPrice(15000e8);
        jusdBank.liquidate(
            alice,
            address(mockToken2),
            bob,
            1e8,
            afterParam,
            1e27 // 15000e6 * 0.95e18/1e18 // BTC expectPrice does not work
        );
        log_balance_watch(false);
    }
    // function testWETHpartialFuzz(uint depositWETH) public {
    //     vm.assume(depositWETH > 1e12 && depositWETH <= 20e18);

    //     //Setup WETH with 2000 USD price
    //     vm.startPrank(address(this));
    //     MockChainLinkEditable wethOracle = new MockChainLinkEditable();
    //     JOJOOracleAdaptor jojoOracle = new JOJOOracleAdaptor(
    //         address(wethOracle),
    //         20,
    //         86400,
    //         address(usdcPrice)
    //     );
    //     wethOracle.SetPrice(2000e8);
    //     jusdBank.updateOracle(address(mockToken1), address(jojoOracle));
    //     swapContract.addTokenPrice(address(mockToken1), address(jojoOracle));
    //     vm.stopPrank();

    //     //alice 10 WETH deposit. 7426e6 JUSD
    //     mockToken1.transfer(alice, depositWETH);//WETH
    //     vm.startPrank(alice);
    //     mockToken1.approve(address(jusdBank), depositWETH);
    //     jusdBank.deposit(alice, address(mockToken1), depositWETH, alice);
    //     jusdBank.borrow(depositWETH * 2000 * 0.75e18/1e18 / 1e12, alice, false);
    //     vm.stopPrank();

    //     // bob liquidate alice
    //     vm.startPrank(bob);
    //     vm.warp(7 days);
    //     bytes memory data = swapContract.getSwapData(depositWETH, address(mockToken1));
    //     bytes memory param = abi.encode(
    //         swapContract,
    //         swapContract,
    //         address(bob),
    //         data
    //     );
    //     FlashLoanLiquidate flashloanRepay = new FlashLoanLiquidate(
    //         address(jusdBank),
    //         address(jusdExchange),
    //         address(USDC),
    //         address(jusd),
    //         insurance
    //     );
    //     bytes memory afterParam = abi.encode(address(flashloanRepay), param);
    //     // reduce price to 500$.
    //     wethOracle.SetPrice(500e8);
    //     jusdBank.liquidate(
    //         alice,
    //         address(mockToken1),
    //         bob,
    //         depositWETH,
    //         afterParam,
    //         500e6 * 0.95e18/1e18
    //     );
    //     //log bob balance
    //     console.log("bob JUSD", jusd.balanceOf(bob));
    //     console.log("bob WETH", mockToken1.balanceOf(bob));
    //     console.log("bob USDC", USDC.balanceOf(bob)); //150$
    //     //log flashloanRepay balance
    //     console.log("fly JUSD", jusd.balanceOf(address(flashloanRepay)));
    //     console.log("fly WETH", mockToken1.balanceOf(address(flashloanRepay)));
    //     console.log("fly USDC", USDC.balanceOf(address(flashloanRepay)));
    //     assertGt(USDC.balanceOf(bob), 1);
    // }
    // function testBTCpartialFuzz(uint depositWBTC) public {
    //     vm.assume(depositWBTC > 100);
    //     vm.assume(depositWBTC <= 5e8);
    //     //Setup BTC with 20000 USD price
    //     vm.startPrank(address(this));
    //     MockChainLinkEditable btcOracle = new MockChainLinkEditable();
    //     btcOracle.SetPrice(20000e8);
    //     JOJOOracleAdaptor jojoOracle = new JOJOOracleAdaptor(
    //         address(btcOracle),
    //         10,
    //         86400,
    //         address(usdcPrice)
    //     );
    //     jusdBank.updateOracle(address(mockToken2), address(jojoOracle));
    //     swapContract.addTokenPrice(address(mockToken2), address(jojoOracle));
    //     vm.stopPrank();

    //     //alice 1 WBTC deposit. 7426e6 JUSD
    //     mockToken2.transfer(alice, depositWBTC);//BTC
    //     vm.startPrank(alice);
    //     mockToken2.approve(address(jusdBank), 1000e18);
    //     jusdBank.deposit(alice, address(mockToken2), depositWBTC, alice);
    //     jusdBank.borrow(depositWBTC*20000*0.7e18/1e18/1e2, alice, false);
    //     vm.stopPrank();

    //     // bob liquidate alice
    //     vm.startPrank(bob);
    //     vm.warp(7 days);
    //     bytes memory data = swapContract.getSwapData(depositWBTC, address(mockToken2));
    //     bytes memory param = abi.encode(
    //         swapContract,
    //         swapContract,
    //         address(bob),
    //         data
    //     );
    //     FlashLoanLiquidate flashloanRepay = new FlashLoanLiquidate(
    //         address(jusdBank),
    //         address(jusdExchange),
    //         address(USDC),
    //         address(jusd),
    //         insurance
    //     );
    //     bytes memory afterParam = abi.encode(address(flashloanRepay), param);
    //     // reduce BTC price to 12000$.
    //     btcOracle.SetPrice(12000e8);
    //     jusdBank.liquidate(
    //         alice,
    //         address(mockToken2),
    //         bob,
    //         depositWBTC,
    //         afterParam,
    //         1e27 // 15000e6 * 0.95e18/1e18 // BTC expectPrice does not work
    //     );
    //     //log bob balance
    //     console.log("bob JUSD", jusd.balanceOf(bob));
    //     console.log("bob WBTC", mockToken2.balanceOf(bob));
    //     console.log("bob USDC", USDC.balanceOf(bob)); //150$
    //     //log flashloanRepay balance
    //     console.log("fly JUSD", jusd.balanceOf(address(flashloanRepay)));
    //     console.log("fly WBTC", mockToken2.balanceOf(address(flashloanRepay)));
    //     console.log("fly USDC", USDC.balanceOf(address(flashloanRepay)));
    // }

    // function testWETH_full() public {
    //     log_balance_watch(true);
    //     //alice 10 WETH deposit. 7426e6 JUSD
    //     mockToken1.transfer(alice, 10e18); //WETH
    //     vm.startPrank(alice);
    //     mockToken1.approve(address(jusdBank), 10e18);
    //     jusdBank.deposit(alice, address(mockToken1), 10e18, alice);
    //     jusdBank.borrow((1000e6 * 10 * 0.8e18) / 1e18, alice, false);
    //     vm.stopPrank();

    //     //Setup WETH with 1000 USD price
    //     vm.startPrank(address(this));
    //     MockChainLinkEditable wethOracle = new MockChainLinkEditable();
    //     JOJOOracleAdaptor jojoOracle = new JOJOOracleAdaptor(
    //         address(wethOracle),
    //         20,
    //         86400,
    //         address(usdcPrice)
    //     );
    //     jusdBank.updateOracle(address(mockToken1), address(jojoOracle));
    //     swapContract.addTokenPrice(address(mockToken1), address(jojoOracle));
    //     vm.stopPrank();

    //     // bob liquidate alice
    //     vm.startPrank(bob);
    //     vm.warp(7 days);
    //     bytes memory data = swapContract.getSwapData(
    //         10e18,
    //         address(mockToken1)
    //     );
    //     bytes memory param = abi.encode(
    //         swapContract,
    //         swapContract,
    //         address(bob),
    //         data
    //     );
    //     FlashLoanLiquidate flashloanRepay = new FlashLoanLiquidate(
    //         address(jusdBank),
    //         address(jusdExchange),
    //         address(USDC),
    //         address(jusd),
    //         insurance
    //     );
    //     bytes memory afterParam = abi.encode(address(flashloanRepay), param);

    //     wethOracle.SetPrice(968e8);
    //     jusdBank.liquidate(
    //         alice,
    //         address(mockToken1),
    //         bob,
    //         10e18,
    //         afterParam,
    //         (1000e6 * 0.95e18) / 1e18
    //     );
    //     log_balance_watch(false);
    // }

    // function testBTC_full() public {        
    //     vm.warp(30 days);        
    //     //Setup WETH with 1000 USD price
    //     vm.startPrank(address(this));
    //     MockChainLinkEditable btcOracle = new MockChainLinkEditable();
    //     JOJOOracleAdaptor jojoOracle = new JOJOOracleAdaptor(
    //         address(btcOracle),
    //         10,
    //         86400,
    //         address(usdcPrice)
    //     );
    //     jusdBank.updateOracle(address(mockToken2), address(jojoOracle));
    //     swapContract.addTokenPrice(address(mockToken2), address(jojoOracle));
    //     vm.stopPrank();

    //     btcOracle.SetPrice(20000e8);
    //     uint deposit = 2.67e8;
    //     mockToken2.transfer(alice, deposit); //BTC
    //     vm.startPrank(alice);
    //     mockToken2.approve(address(jusdBank), deposit);
    //     jusdBank.deposit(alice, address(mockToken2), deposit, alice);
    //     jusdBank.borrow(20000e6 * deposit * 0.69e18 / 1e18 /1e8, alice, false);
    //     vm.stopPrank();
    //     log_balance_watch(true);
    //     // bob liquidate alice
    //     vm.startPrank(bob);
    //     vm.warp(1 days);
    //     bytes memory data = swapContract.getSwapData(
    //         deposit,
    //         address(mockToken2)
    //     );
    //     bytes memory param = abi.encode(
    //         swapContract,
    //         swapContract,
    //         address(bob),
    //         data
    //     );
    //     FlashLoanLiquidate flashloanRepay = new FlashLoanLiquidate(
    //         address(jusdBank),
    //         address(jusdExchange),
    //         address(USDC),
    //         address(jusd),
    //         insurance
    //     );
    //     bytes memory afterParam = abi.encode(address(flashloanRepay), param);
    //     btcOracle.SetPrice(17162e8);//45822.54
    //     jusdBank.liquidate(
    //         alice,
    //         address(mockToken2),
    //         bob,
    //         deposit,
    //         afterParam,
    //         1e27
    //     );
    //     log_balance_watch(false);
    //     //log alice deposit leftover and borrow balance from jusdbank
    //     console.log("alice deposit balance:", jusdBank.getDepositBalance(address(mockToken2), alice));
    //     console.log("alice borrow balance:", jusdBank.getBorrowBalance(alice));
    //     console.log("alice maxwithdraw:", jusdBank.getMaxWithdrawAmount(address(mockToken2), alice));
    //     console.log("alice depositMaxMint:", jusdBank.getDepositMaxMintAmount(alice));
    // }

    // function testBTC_fullpartial() public {
        
    //     vm.warp(30 days);        
    //     //Setup WETH with 1000 USD price
    //     vm.startPrank(address(this));
    //     MockChainLinkEditable btcOracle = new MockChainLinkEditable();
    //     JOJOOracleAdaptor jojoOracle = new JOJOOracleAdaptor(
    //         address(btcOracle),
    //         10,
    //         86400,
    //         address(usdcPrice)
    //     );
    //     jusdBank.updateOracle(address(mockToken2), address(jojoOracle));
    //     swapContract.addTokenPrice(address(mockToken2), address(jojoOracle));
    //     vm.stopPrank();

    //     btcOracle.SetPrice(20000e8);
    //     uint deposit = 2.67e8;
    //     mockToken2.transfer(alice, deposit); //BTC
    //     vm.startPrank(alice);
    //     mockToken2.approve(address(jusdBank), deposit);
    //     jusdBank.deposit(alice, address(mockToken2), deposit, alice);
    //     jusdBank.borrow(20000e6 * deposit * 0.69e18 / 1e18 /1e8, alice, false);
    //     vm.stopPrank();
    //     log_balance_watch(true);
    //     uint swapDeposit = 2.507072e8;
    //     // bob liquidate alice
    //     vm.startPrank(bob);
    //     vm.warp(1 days);
    //     bytes memory data = swapContract.getSwapData(
    //         swapDeposit,
    //         address(mockToken2)
    //     );
    //     bytes memory param = abi.encode(
    //         swapContract,
    //         swapContract,
    //         address(bob),
    //         data
    //     );
    //     FlashLoanLiquidate flashloanRepay = new FlashLoanLiquidate(
    //         address(jusdBank),
    //         address(jusdExchange),
    //         address(USDC),
    //         address(jusd),
    //         insurance
    //     );
    //     bytes memory afterParam = abi.encode(address(flashloanRepay), param);

    //     btcOracle.SetPrice(17162e8);//45822.54
    //     jusdBank.liquidate(
    //         alice,
    //         address(mockToken2),
    //         bob,
    //         swapDeposit,
    //         afterParam,
    //         1e27
    //     );
    //     log_balance_watch(false);
    //     //log alice deposit leftover and borrow balance from jusdbank
    //     console.log("alice deposit balance:", jusdBank.getDepositBalance(address(mockToken2), alice));
    //     console.log("alice borrow balance:", jusdBank.getBorrowBalance(alice));
    //     console.log("alice maxwithdraw:", jusdBank.getMaxWithdrawAmount(address(mockToken2), alice));
    //     console.log("alice depositMaxMint:", jusdBank.getDepositMaxMintAmount(alice));
    // }

    int before_bob_jusd;
    int before_bob_weth;
    int before_bob_wbtc;
    int before_bob_usdc;
    int before_ali_jusd;
    int before_ali_weth;
    int before_ali_wbtc;
    int before_ali_usdc;
    int before_bank_jusd;
    int before_bank_weth;
    int before_bank_wbtc;
    int before_bank_usdc;
    int before_insurance_jusd;
    int before_insurance_weth;
    int before_insurance_wbtc;
    int before_insurance_usdc;

    function log_balance_watch(bool cache) internal {
        //log bob balance
        console.log("bob JUSD", jusd.balanceOf(bob));
        console.log("bob WETH", mockToken1.balanceOf(bob));
        console.log("bob WBTC", mockToken2.balanceOf(bob));
        console.log("bob USDC", USDC.balanceOf(bob)); //467$
        //log alice balance
        console.log("ali JUSD", jusd.balanceOf(alice)); //8000$ JUSD
        console.log("ali WETH", mockToken1.balanceOf(alice));
        console.log("ali WBTC", mockToken2.balanceOf(alice));
        console.log("ali USDC", USDC.balanceOf(alice)); //338$ USDC // total 805 USDC
        //log bank balance
        console.log("bank JUSD", jusd.balanceOf(address(jusdBank)));
        console.log("bank WETH", mockToken1.balanceOf(address(jusdBank)));
        console.log("bank WBTC", mockToken2.balanceOf(address(jusdBank)));
        console.log("bank USDC", USDC.balanceOf(address(jusdBank)));
        //log insurance account balance
        console.log("ins JUSD", jusd.balanceOf(address(insurance)));
        console.log("ins WETH", mockToken1.balanceOf(address(insurance)));
        console.log("ins WBTC", mockToken2.balanceOf(address(insurance)));
        console.log("ins USDC", USDC.balanceOf(address(insurance)));
        if (cache) {
            // store balance into int variable
            before_bob_jusd = int(jusd.balanceOf(bob));
            before_bob_weth = int(mockToken1.balanceOf(bob));
            before_bob_wbtc = int(mockToken2.balanceOf(bob));
            before_bob_usdc = int(USDC.balanceOf(bob));
            before_ali_jusd = int(jusd.balanceOf(alice));
            before_ali_weth = int(mockToken1.balanceOf(alice));
            before_ali_wbtc = int(mockToken2.balanceOf(alice));
            before_ali_usdc = int(USDC.balanceOf(alice));
            before_bank_jusd = int(jusd.balanceOf(address(jusdBank)));
            before_bank_weth = int(mockToken1.balanceOf(address(jusdBank)));
            before_bank_wbtc = int(mockToken2.balanceOf(address(jusdBank)));
            before_bank_usdc = int(USDC.balanceOf(address(jusdBank)));
            before_insurance_jusd = int(jusd.balanceOf(address(insurance)));
            before_insurance_weth = int(
                mockToken1.balanceOf(address(insurance))
            );
            before_insurance_wbtc = int(
                mockToken2.balanceOf(address(insurance))
            );
            before_insurance_usdc = int(USDC.balanceOf(address(insurance)));
        } else {
            //console.log the different with the new value
            console2.log("bob change JUSD",int(jusd.balanceOf(bob)) - before_bob_jusd);
            console2.log("bob change WETH",int(mockToken1.balanceOf(bob)) - before_bob_weth);
            console2.log("bob change WBTC",int(mockToken2.balanceOf(bob)) - before_bob_wbtc);
            console2.log("bob change USDC",int(USDC.balanceOf(bob)) - before_bob_usdc);
            console2.log("ali change JUSD",int(jusd.balanceOf(alice)) - before_ali_jusd);
            console2.log("ali change WETH",int(mockToken1.balanceOf(alice)) - before_ali_weth);
            console2.log("ali change WBTC",int(mockToken2.balanceOf(alice)) - before_ali_wbtc);
            console2.log("ali change USDC",int(USDC.balanceOf(alice)) - before_ali_usdc);
            console2.log("bank change JUSD",int(jusd.balanceOf(address(jusdBank))) - before_bank_jusd);
            console2.log("bank change WETH",int(mockToken1.balanceOf(address(jusdBank))) - before_bank_weth);
            console2.log("bank change WBTC",int(mockToken2.balanceOf(address(jusdBank))) - before_bank_wbtc);
            console2.log("bank change USDC",int(USDC.balanceOf(address(jusdBank))) - before_bank_usdc);
            console2.log("ins change JUSD",int(jusd.balanceOf(address(insurance))) - before_insurance_jusd);
            console2.log("ins change WETH",int(mockToken1.balanceOf(address(insurance))) - before_insurance_weth);
            console2.log("ins change WBTC",int(mockToken2.balanceOf(address(insurance))) - before_insurance_wbtc);
            console2.log("ins change USDC",int(USDC.balanceOf(address(insurance))) - before_insurance_usdc);
        }
    }
}
