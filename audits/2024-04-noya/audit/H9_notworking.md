# `BaseConnector` force use `AccountingManager` as positionId. `AccountingManager` TVL is counted multiple times for base token

In `BaseConnector.sol`, it is required to hash positionId using `AccountingManager.sol` address and `positionTypeId = 0` for all connectors.
`BaseConnector` will call `Registry.updateHoldingPosition()` when token is deposited to create new holding position for `AccountingManager` to track how much value of all connectors.
`AccountingManager` totalAssets/getTVL function loop through all holding positions to calculate TVL for each token.
Each holding positions **must** point to `AccountingManager.sol` as logic code to find correct TVL.

Because each holding positions for each new type of token just point to `AccountingManager.sol`, it will count TVL again multiple times for base token.

## Impact

Incorrect TVL calculation leads to wrong vault share price calculation.
TVL is counted repeatedly multiple times for base token if vault has multiple token.

## Proof of Concept

`BaseConnector._updateTokenInRegistry()` use default positionTypeId = 0 as positionId and `AccountingManager` address for calculatorConnector for all connectors.
This result in all inherit connectors must use `AccountingManager` to hash positionId.
<https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/contracts/helpers/BaseConnector.sol#L138>

We can seen it through out test code, [Ref1](https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/testFoundry/PrismaConnector.t.sol#L48-L50),[Ref2](https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/testFoundry/BaseConnector.t.sol#L58-L59),[Ref3](https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/testFoundry/SNXConnector.t.sol#L47-L50). Vault maintainer must call `addTrustedPosition()` to registry to allow vault connector to interact with vault basic tokens.

The purpose of `Registry.updateHoldingPosition()` is just keeping track list of token holding by vault and who should be responsible for calculating TVL for these position.

The underlying problem is `AccountingManager.getUnderlyingTokens()` should ignore all positions holding by connectors if `positionTypeId != 0` and it will not duplicate counting TVL for base token again.
Because `BaseConnector._updateTokenInRegistry()` hardcode `positionTypeId = 0`, all position holdings must also use `positionTypeId = 0` despite some connectors have unique positionTypeId.

Looking at `TVLHelper.sol`, TVL is just looping through all holding positions to calculate TVL for each token.
calculatorConnector here is just `AccountingManager` which repeatedly called again.
<https://github.com/code-423n4/2024-04-noya/blob/9c79b332eff82011dcfa1e8fd51bad805159d758/contracts/helpers/TVLHelper.sol#L14-L34>

## Proof Test Code

Running below solidity test based on `BaseConnector.t.sol` show TVL is duplicated for base token.
Deposit 130000 USDC but got console log 260000 USDC TVL. This happen after vault manager deposit token into second connector.
<details>
  <summary>Click to expand!</summary>

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "./utils/testStarter.sol";
import "contracts/helpers/BaseConnector.sol";
import "contracts/accountingManager/NoyaFeeReceiver.sol";
import "./utils/resources/OptimismAddresses.sol";
import "contracts/governance/Keepers.sol";
import "./utils/mocks/EmergancyMock.sol";
import "./utils/mocks/ConnectorMock2.sol";
import { PositionRegistry, HoldingPI } from "contracts/accountingManager/Registry.sol";

contract TestDebug is testStarter, OptimismAddresses {
    using SafeERC20 for IERC20;

    address USD = address(840);
    address public constant _ETH = address(0); //this is for NoyaOracle and not to confused with Uniswap ETH

    address connector; //base
    address connector2; //mock2
    NoyaFeeReceiver managementFeeReceiver;
    NoyaFeeReceiver performanceFeeReceiver;
    address withdrawFeeReceiver = bob;

    uint256 privateKey1 = 0x99ba14aff4aba765903a41b48aacdf600b6fcdb2b0c2424cd2f8f2c089f20476;
    uint256 privateKey2 = 0x68ab62e784b873b929e98fc6b6696abcc624cf71af05bf8d88b4287e9b58ab99;
    uint256 privateKey3 = 0x952b55e8680117e6de5bde1d3e7902baa89bfde931538a5bb42ba392ef3464a4;
    uint256 privateKey4 = 0x885f1d08ebc23709517fedbec64418e4a09ac1e47e976c868fd8c93de0f88f09;

    function setUp() public {
        // --------------------------------- set env --------------------------------
        uint256 fork = vm.createFork(RPC_URL, startingBlock);
        vm.selectFork(fork);

        console.log("Test timestamp: %s", block.timestamp);

        // --------------------------------- deploy the contracts ---------------------------------
        vm.startPrank(owner);
        //baseTOken = USDC = optimism
        deployEverythingNormal(USDC); //new registry, noya Oracle,chainlink connector with 5days
        //deploy AM and set the registry with owner as handler,manager,keepers,
        //swapper handler is lifiImplementation with optimism mainnet lifiDiamond
        // --------------------------------- init connector ---------------------------------
        connector = address(new BaseConnector(BaseConnectorCP(registry, 0, swapHandler, noyaOracle)));
        connector2 = address(new ConnectorMock2(address(registry), 0));

        // ------------------- add connector to registry -------------------
        addConnectorToRegistry(vaultId, connector);
        addConnectorToRegistry(vaultId, connector2);
        console.log("AaveConnector added to registry");

        addTrustedTokens(vaultId, address(accountingManager), USDC);
        addTrustedTokens(vaultId, address(accountingManager), DAI);

        addTokenToChainlinkOracle(address(USDC), address(840), address(USDC_USD_FEED)); //token, base, source for chainlinkOracle
        addTokenToNoyaOracle(address(USDC), address(chainlinkOracle));

        addTokenToChainlinkOracle(address(DAI), address(840), address(DAI_USD_FEED)); // DAI, USD, chainlinkFeed
        addTokenToNoyaOracle(address(DAI), address(chainlinkOracle));

        console.log("Tokens added to registry");
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(USDC), "");
        registry.addTrustedPosition(vaultId, 0, address(accountingManager), false, false, abi.encode(DAI), "");
        console.log("Positions added to registry");

        managementFeeReceiver = new NoyaFeeReceiver(address(accountingManager), baseToken, owner);
        performanceFeeReceiver = new NoyaFeeReceiver(address(accountingManager), baseToken, owner);

        accountingManager.updateValueOracle(noyaOracle);
        vm.stopPrank();

        vm.label(address(connector), "BaseConnector1");
        vm.label(address(connector2), "MockConnector2");
        vm.label(address(managementFeeReceiver), "managementFeeReceiver");
        vm.label(address(performanceFeeReceiver), "performanceFeeReceiver");
        //optimism
        vm.label(address(ETH), "ETH");
        vm.label(address(WETH), "WETH");
        vm.label(address(USDC), "USDC");
        vm.label(address(DAI), "DAI");
        vm.label(address(USDC_USD_FEED), "USDC_USD_FEED");
        vm.label(address(DAI_USD_FEED), "DAI_USD_FEED");
        vm.label(address(ETH_USD_FEED), "ETH_USD_FEED");

        console.log("connector: %s", address(connector));
        console.log("connector2: %s", address(connector2));
        console.log("accountingManager: %s", address(accountingManager));
        console.log("---------------END SETUP --------------");
    }

    function testDebugDeposit() public {
        //fee for all operation is 0 for now

        //user operation on testDeposit only have
        //deposit,withdraw,burnShares,transfer,transferfrom,approve
        // first we get lots of USDC
        _dealWhale(baseToken, address(alice), address(0x1AB4973a48dc892Cd9971ECE8e01DcC7688f8F23), 100_000e6);
        // deal(address(USDC), address(alice), 100_000e6);

        vm.startPrank(alice);
        IERC20(USDC).approve(address(accountingManager), type(uint256).max);
        accountingManager.deposit(address(alice), 10_000e6, address(0));
        vm.stopPrank();

        manager_calculateDepositShares();
        manager_executeDeposit1(); //@

        vm.startPrank(alice);
        accountingManager.deposit(address(alice), 3000e6, address(0));
        vm.stopPrank();

        manager_calculateDepositShares();
        manager_executeDeposit2(); //@
        //try faking connectors to add new type of holdingPosition
        vm.prank(address(connector2));
        registry.updateHoldingPosition(
            vaultId, 0xc6bf91691f8338c1e9758c1144b806400c05929f3c5dad31b9f3f82f73b960ad, "", "", true
        );

        // we want to know current total share, TVl, and user share
        debugPrice();
        debugPosition();
        console.log("---------New Positions");

        // // update non exist position will faill
        // deal(address(USDT), connector, 1000e18);
        // vm.startPrank(owner);
        // BaseConnector(connector).updateTokenInRegistry(USDT);
        //update non exist token
    }

    function debugPrice() internal {
        console.log("-----PRICE-----");
        console.log("totalAssets/TVL: %e", accountingManager.totalAssets());
        console.log("totalSupply: %e", accountingManager.totalSupply());
        //USDC in pending. that have not been transfered to connector for investment
        console.log("USDC balance: %e", IERC20(USDC).balanceOf(address(accountingManager)));
        //noyaOracle price for USDC
        console.log("profit: %e", accountingManager.getProfit());
    }

    function debugPosition() internal {
        //USDC positionID 0xc6bf91691f8338c1e9758c1144b806400c05929f3c5dad31b9f3f82f73b960ad
        //DAI 0x0ed547bc38fd99999fb1cd49b23d2fddca7b6931fce0875757727d12c48faeea
        // position with non basetoken doing nothing at all. since nothing can update that position
        //TVL instead of using baseToken. this should use USD 840
        console.log("-----DEBUG POSITION-----");
        HoldingPI[] memory holdings = registry.getHoldingPositions(vaultId);
        console.log("holdingPOsitionLength: %s", holdings.length);
        for (uint256 i = 1; i < holdings.length; i++) {
            uint256 tvl = accountingManager.getPositionTVL(holdings[i], USD);
            emit log_named_bytes32("positionID:", holdings[i].positionId);
            console.log("holding [%s], TVL: %e", i, tvl);
            console.log("connector calculator: %s", holdings[i].calculatorConnector);
            console.log("connector owner: %s", holdings[i].ownerConnector);
            PositionBP memory p = registry.getPositionBP(vaultId, holdings[i].positionId);
            emit log_named_address("_calculatorConnector:", p.calculatorConnector); //@address own position
            emit log_named_uint("_positionTypeId:", p.positionTypeId); //@connector ID for positionType
            emit log_named_bytes("_trustedPositionData:", p.data); //USDC address
        }
        //holdingPosition 1: connector is AM, owner is baseConnector1
    }

    function manager_calculateDepositShares() internal {
        vm.prank(owner);
        accountingManager.calculateDepositShares(100);
    }

    function manager_executeDeposit1() internal {
        vm.warp(block.timestamp + 30 minutes + 17 seconds);
        vm.prank(owner);
        accountingManager.executeDeposit(100, connector, "");
    }
    function manager_executeDeposit2() internal {
        vm.warp(block.timestamp + 30 minutes + 17 seconds);
        vm.prank(owner);
        accountingManager.executeDeposit(100, connector2, "");
    }
}

```

</details>

## Tools Used

## Recommended Mitigation Steps

`IConnector` interface or `BaseConnector` need to become abstract.
Including get view `connectorPositionTypeId()` to return positionId for each unique connector would handle the problem.
`BaseConnector` should not force all connectors to use `AccountingManager` as positionId.
