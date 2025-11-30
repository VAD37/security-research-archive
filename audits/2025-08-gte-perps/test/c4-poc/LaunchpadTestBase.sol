// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Distributor} from "contracts/launchpad/Distributor.sol";
import {Launchpad} from "contracts/launchpad/Launchpad.sol";
import {ILaunchpad} from "contracts/launchpad/interfaces/ILaunchpad.sol";
import {SimpleBondingCurve} from "contracts/launchpad/BondingCurves/SimpleBondingCurve.sol";
import {IBondingCurveMinimal} from "contracts/launchpad/BondingCurves/IBondingCurveMinimal.sol";
import {LaunchToken} from "contracts/launchpad/LaunchToken.sol";
import {LaunchpadLPVault} from "contracts/launchpad/LaunchpadLPVault.sol";
import {IDistributor} from "contracts/launchpad/interfaces/IDistributor.sol";

import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";

import {ERC20Harness} from "../harnesses/ERC20Harness.sol";

import {MockUniV2Router} from "../mocks/MockUniV2Router.sol";

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {ICLOBManager} from "contracts/clob/ICLOBManager.sol";
import {IOperatorPanel} from "contracts/utils/interfaces/IOperatorPanel.sol";

import {UniV2Bytecode} from "../launchpad/integration/UniV2Bytecode.t.sol";

import "forge-std/Test.sol";

// Implements the LaunchpadTest setup
contract LaunchpadTestBase is Test {
    using FixedPointMathLib for uint256;

    ERC1967Factory factory;
    Launchpad launchpad;
    address distributor;
    IBondingCurveMinimal curve;
    LaunchpadLPVault launchpadLPVault;

    ERC20Harness quoteToken;
    MockUniV2Router uniV2Router;

    address owner = makeAddr("owner");
    address user = makeAddr("user");
    address dev = makeAddr("dev");

    uint256 constant MIN_BASE_AMOUNT = 100_000_000;

    address token;

    uint256 BONDING_SUPPLY;
    uint256 TOTAL_SUPPLY;

    function setUp() public virtual {
        quoteToken = new ERC20Harness("Quote", "QTE");

        factory = new ERC1967Factory();

        address uniV2Factory = makeAddr("factory");
        vm.etch(uniV2Factory, UniV2Bytecode.UNIV2_FACTORY);

        uniV2Router = new MockUniV2Router(makeAddr("factory"));

        bytes32 launchpadSalt = bytes32(abi.encode("GTE.V1.TESTNET.LAUNCHPAD", owner));

        launchpad = Launchpad(factory.predictDeterministicAddress(launchpadSalt));

        address c_logic = address(new SimpleBondingCurve(address(launchpad)));
        address v_logic = address(new LaunchpadLPVault());

        curve = SimpleBondingCurve(factory.deploy(address(c_logic), owner));
        launchpadLPVault = LaunchpadLPVault(factory.deploy(address(v_logic), owner));

        address clobManager = makeAddr("clob manager");
        address operatorAddr = makeAddr("operator");
        vm.mockCall(
            operatorAddr,
            abi.encodeWithSelector(IOperatorPanel.getOperatorRoleApprovals.selector, user, address(0)),
            abi.encode(0)
        );

        distributor = address(new Distributor());
        Distributor(distributor).initialize(address(launchpad));

        address l_logic =
            address(new Launchpad(address(uniV2Router), address(0), clobManager, operatorAddr, distributor));

        vm.prank(owner);
        Launchpad(
            factory.deployDeterministicAndCall({
                implementation: l_logic,
                admin: owner,
                salt: launchpadSalt,
                data: abi.encodeCall(
                    Launchpad.initialize,
                    (
                        owner,
                        address(quoteToken),
                        address(curve),
                        address(launchpadLPVault),
                        abi.encode(200_000_000 ether, 10 ether)
                    )
                )
            })
        );

        token = _launchToken();

        BONDING_SUPPLY = curve.bondingSupply(token);
        TOTAL_SUPPLY = curve.totalSupply(token);

        vm.startPrank(user);
        quoteToken.approve(address(launchpad), type(uint256).max);
        ERC20Harness(token).approve(address(launchpad), type(uint256).max);
        vm.stopPrank();

        vm.label(address(launchpad), "Launchpad");
        vm.label(address(curve), "BondingCurve");
        vm.label(address(launchpadLPVault), "LaunchpadLPVault");
        vm.label(address(distributor), "Distributor");
        vm.label(address(quoteToken), "QuoteToken");
        vm.label(address(uniV2Router), "UniV2Router");
        vm.label(token, "LaunchToken");
        vm.label(owner, "Owner");
        vm.label(user, "User");
        vm.label(dev, "Dev");
    }

    function _launchToken() internal returns (address) {
        uint256 fee = launchpad.launchFee();
        deal(dev, 30 ether);

        vm.prank(dev);
        return launchpad.launch{value: fee}("TestToken", "TST", "https://testtoken.com");
    }

    function _test_debug() external {
        console.log("BONDING_SUPPLY %e", BONDING_SUPPLY); //supply and for sale is based on fixed code in Launchpad
        console.log("TOTAL_SUPPLY %e", TOTAL_SUPPLY);
        //virtual reserve is 200M and 10 ether
        console.log("Curve Supply %e", curve.bondingSupply(token));
        console.log("Curve totalSupply %e", curve.totalSupply(token));
        console.log("Curve baseSoldFromCurve %e", curve.baseSoldFromCurve(token));
        console.log("Curve quoteBoughtByCurve %e", curve.quoteBoughtByCurve(token));
        (uint256 quoteReserve, uint256 baseReserve) = SimpleBondingCurve(address(curve)).getReserves(token);
        console.log("Curve quoteReserve %e", quoteReserve);
        console.log("Curve baseReserve %e", baseReserve);

        //virtual reserve affect price exchange rate. It exist because fair price based on real reserve have not been exist and stablize yet.
        console.log("Initial Price (quote/base) %e", quoteReserve / baseReserve); //10/200M = 0.00000005 ether per base
        console.log("Initial Price (base/quote) %e", baseReserve / quoteReserve); //200M/10 = 20_000_000 base per ether
        console.log("1e18 Quote -> Base %e", curve.quoteQuoteForBase(token, 1 ether, true));
        console.log("out 800M base from Quote -> Base %e", curve.quoteQuoteForBase(token, 8e26, true));
        console.log("out 1B base from Quote -> Base %e", curve.quoteQuoteForBase(token, 1e27 - 1, true));
        console.log("1e18 Base -> Quote %e", curve.quoteQuoteForBase(token, 1 ether, false));

        console.log("1e10 Quote -> Base %e", curve.quoteBaseForQuote(token, 1e10, false));
        console.log("1e10 Base -> Quote %e", curve.quoteBaseForQuote(token, 1e10, true));

        //launch token create 1B supply on launchpad waiting for buy/sell before transfer to custom uniswap pair
        //User can use router to buy/sell new token
        uint256 count = 10;
        vm.startPrank(address(launchpad));
        for (uint256 i = 0; i < count; i++) {
            uint256 baseOut = 8e26 / count; //80M
            uint256 quoteIn = curve.buy(token, baseOut);
            console.log("buy %e quote -> base %e", quoteIn, baseOut);
            console.log("-Curve baseSoldFromCurve %e", curve.baseSoldFromCurve(token));
            console.log("-Curve quoteBoughtByCurve %e", curve.quoteBoughtByCurve(token));
        }
        (quoteReserve, baseReserve) = SimpleBondingCurve(address(curve)).getReserves(token);
        console.log("Curve quoteReserve %e", quoteReserve); //40 ETH for 800M bond from 10 ETH as virtual reserve
        console.log("Curve baseReserve %e", baseReserve);
        for (uint256 i = 0; i < 50; i++) {
            uint256 baseIn = 8e26 / 50; //80M
            uint256 quoteOut = curve.sell(token, baseIn);
            console.log("sell %e quote -> base %e", quoteOut, baseIn);
            console.log("-Curve baseSoldFromCurve %e", curve.baseSoldFromCurve(token));
            console.log("-Curve quoteBoughtByCurve %e", curve.quoteBoughtByCurve(token));
        }
                (quoteReserve, baseReserve) = SimpleBondingCurve(address(curve)).getReserves(token);
        console.log("Curve quoteReserve %e", quoteReserve); //40 ETH for 800M bond from 10 ETH as virtual reserve
        console.log("Curve baseReserve %e", baseReserve);
    }
}
