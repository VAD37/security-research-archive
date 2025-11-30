// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./fork/v1.7/ForkReinitializeV1_7.t.sol";
import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import "forge-std/Test.sol";

import "src/market/SizeViewData.sol";
import "src/market/libraries/actions/Initialize.sol";
import {PriceFeed} from "src/oracle/v1.5.1/PriceFeed.sol";
import {IPriceFeedV1_5_3} from "src/oracle/v1.5.3/IPriceFeedV1_5_3.sol";
import "./BaseTest.sol";

contract DebugFork is ForkTest, GetV1_7ReinitializeDataScript, Networks, SafeUtils {
    // uint256 constant CREDIT_POSITION_ID_START = type(uint256).max / 2;
IERC20Metadata internal debtToken;
NonTransferrableScaledTokenV1_5 internal bToken;
    function setUp() public override {
        //From Fork test
        string memory network = "base-production";
        vm.createSelectFork(network, 26674900);
        ISize isize;
        (isize, priceFeed,) = importDeployments("base-production-weth-usdc");
        size = SizeMock(address(isize));
        usdc = USDC(address(size.data().underlyingBorrowToken));
        weth = WETH(payable(address(size.data().underlyingCollateralToken)));
        variablePool = size.data().variablePool;
        aToken = IAToken(variablePool.getReserveData(address(usdc)).aTokenAddress);

        //@Copy from ForkReinitializeV1_7Test
        sizeFactory = importSizeFactory(string.concat(network, "-size-factory"));
        IMultiSendCallOnly _multiSendCallOnly = multiSendCallOnly(network);
        owner = OwnableUpgradeable(address(sizeFactory)).owner();
        vm.label(address(sizeFactory), "SizeFactory");
        vm.label(address(_multiSendCallOnly), "MultiSendCallOnly");
        vm.label(owner, "owner");

        (address to, bytes memory data) = getV1_7ReinitializeData(sizeFactory, _multiSendCallOnly);
        //upgrade UUPS
        _simulateSafeMultiSendCallOnly(ISafe(owner), to, data);
        (bool success,) = address(sizeFactory).call(
            abi.encodeWithSelector(ISizeFactoryV1_7.setAuthorization.selector, address(0x1000), 1)
        );
        assertTrue(success, "setAuthorization failed");

        // replace local contracts with forked contracts based on Deployment networks
        implementation = sizeFactory.sizeImplementation();
        collateralToken = IERC20Metadata(size.data().collateralToken);
        borrowToken = IERC20Metadata(size.data().borrowAToken);
        bToken = NonTransferrableScaledTokenV1_5(size.data().borrowAToken);
        debtToken = IERC20Metadata(size.data().debtToken);

        _labels();
    }

    function _test_basic_debug() public view {
        console.log("feed:", address(priceFeed));
        console.log("feed usd/weth price: %e", priceFeed.getPrice()); // 2791.6788e18
        //List descriptions
        string[] memory descs = sizeFactory.getMarketDescriptions();
        console.log("--------------------");
        for (uint256 i = 0; i < descs.length; i++) {
            console.log("market %d: %s", i, descs[i]);
        }
        string[] memory borrowDescs = sizeFactory.getBorrowATokenV1_5Descriptions();
        console.log("--------------------");
        for (uint256 i = 0; i < borrowDescs.length; i++) {
            console.log("borrowAToken %d: %s", i, borrowDescs[i]);
        }
        //list all markets
        ISize[] memory markets = sizeFactory.getMarkets();
        for (uint256 i = 0; i < markets.length; i++) {
            ISize market = markets[i];
            console.log("---------MARKET %d-----------", i);
            console.log("market %d: %s", i, address(market));
            console.log("version: %s", market.version());
            console.log("--Fee--");
            InitializeFeeConfigParams memory feeConfig = market.feeConfig();
            console.log("swapFeeAPR: %e", feeConfig.swapFeeAPR);
            console.log("fragmentationFee: %e", feeConfig.fragmentationFee);
            console.log("liquidationRewardPercent: %e", feeConfig.liquidationRewardPercent);
            console.log("overdueCollateralProtocolPercent: %e", feeConfig.overdueCollateralProtocolPercent);
            console.log("collateralProtocolPercent: %e", feeConfig.collateralProtocolPercent);
            console.log("feeRecipient: %s", feeConfig.feeRecipient);
            console.log("--Risk--");
            InitializeRiskConfigParams memory riskConfig = market.riskConfig();
            console.log("crOpening: %e", riskConfig.crOpening);
            console.log("crLiquidation: %e", riskConfig.crLiquidation);
            console.log("minimumCreditBorrowAToken: %e", riskConfig.minimumCreditBorrowAToken);
            console.log("borrowATokenCap: %e", riskConfig.borrowATokenCap);
            console.log("minTenor: %e", riskConfig.minTenor);
            console.log("maxTenor: %e", riskConfig.maxTenor);
            console.log("--Oracle--");
            InitializeOracleParams memory oracle = market.oracle();
            console.log("priceFeed: %s", oracle.priceFeed);
            console.log("variablePoolBorrowRateStaleRateInterval: %e", oracle.variablePoolBorrowRateStaleRateInterval);
            console.log("--Data--");
            DataView memory data = market.data();
            console.log("nextDebtPositionId: %d", data.nextDebtPositionId);
            console.log("nextCreditPositionId: %d", data.nextCreditPositionId - CREDIT_POSITION_ID_START);
            console.log("underlyingCollateralToken: %s", address(data.underlyingCollateralToken));
            console.log("underlyingBorrowToken: %s", address(data.underlyingBorrowToken));
            console.log("collateralToken: %s", address(data.collateralToken));
            console.log("borrowAToken: %s", address(data.borrowAToken));
            console.log("debtToken: %s", address(data.debtToken));
            console.log("variablePool: %s", address(data.variablePool));
        }
        PriceFeed[] memory _priceFeeds = sizeFactory.getPriceFeeds();
        for (uint256 i = 0; i < _priceFeeds.length; i++) {
            PriceFeed feed = _priceFeeds[i];
            console.log("---------FEED-----------");
            console.log("priceFeed %d: %s", i, address(feed));
            console.log("price: %e", feed.getPrice());
            if (i == 6) {
                //@oracle 6 is not a feed. just UNISWAP TWAP of single token
                console.log("desc: %s", IPriceFeedV1_5_3(address(feed)).description());
            } else {
                console.log("base: %s", address(feed.base()));
                console.log("base: %s", feed.base().description());
                console.log("quote: %s", address(feed.quote()));
                console.log("quote: %s", feed.quote().description());
            }
        }
    }

    function test_debug0() public {
        console.log("borrow supply: %e", bToken.totalSupply());
        console.log("borrow scaled: %e", bToken.scaledTotalSupply());
        //prepare cash for user and deposit
        address lender = makeAddr("lender");
        address borrower = makeAddr("borrower");
        address bot = makeAddr("onBehalfOf_Admin");
        fund(lender);
        fund(borrower);
        fund(bot);

        vm.startPrank(lender);
        size.deposit(DepositParams({token: address(usdc), amount: 10_000e6, to: lender}));
        print(lender);

        vm.startPrank(borrower);
        size.deposit(DepositParams({token: address(weth), amount: 1e18, to: borrower}));
        print(borrower);

        
        console.log("post deposit");
        console.log("aaveIndex: %e",bToken.liquidityIndex());
        console.log("borrow supply: %e", bToken.totalSupply());
        console.log("borrow scaled: %e", bToken.scaledTotalSupply());
        //skip time will increase index thus supply
        skip(10 days);
        console.log("aaveIndex: %e",bToken.liquidityIndex());
        console.log("borrow supply: %e", bToken.totalSupply());
        console.log("borrow scaled: %e", bToken.scaledTotalSupply());

        print(lender);

        console.log("new offers");
    }
    function fund(address addr) public {
        deal(address(usdc),addr, 10_000e6);
        deal(address(weth),addr,10e18);
        vm.startPrank(addr);
        usdc.approve(address(size), type(uint).max);
        weth.approve(address(size), type(uint).max);
        vm.stopPrank();
    }

    function print(address addr) public view{
        console.log("--- address : %s", addr);
        console.log("collateral  : %e",collateralToken.balanceOf(addr));
        console.log("borrowAToken: %e",borrowToken.balanceOf(addr));
        console.log("borrowAToken_scaled: %e",bToken.scaledBalanceOf(addr));
    }
}
