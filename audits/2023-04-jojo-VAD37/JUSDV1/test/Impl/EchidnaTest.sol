// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.9;

import "../../src/Impl/JUSDBank.sol";
import "../../src/Impl/JUSDExchange.sol";
import "../mocks/MockERC20.sol";
import "../mocks/TestERC20.sol";
import "../../src/token/JUSD.sol";
import "../../src/oracle/JOJOOracleAdaptor.sol";
import "../../src/Testsupport/SupportsSWAP.sol";
import "../mocks/MockUSDCPrice.sol";
import "../../src/lib/DataTypes.sol";
import "../../src/Impl/flashloanImpl/GeneralRepay.sol";
import "../mocks/MockJOJODealer.sol";
import "../../src/Impl/flashloanImpl/FlashLoanLiquidate.sol";
import "../mocks/MockChainLinkEditable.sol";

contract User {

}

contract JUSDEchidnaTest {
    uint256  constant ONE = 1e18;

    JUSDBank  jusdBank;
    TestERC20  mockToken2;//BTC

    MockERC20  mockToken1;//WETH
    JUSDExchange  jusdExchange;

    JUSD  jusd;
    JOJOOracleAdaptor  jojoOracle1;
    JOJOOracleAdaptor  jojoOracle2;
    MockChainLinkEditable  mockToken1ChainLink;
    MockChainLinkEditable  mockToken2ChainLink;
    MockJOJODealer  jojoDealer;
    MockUSDCPrice  usdcPrice;
    SupportsSWAP  swapContract;
    TestERC20  USDC;
    address  insurance = address(0x990000);


    uint value;

    constructor() payable {
        mockToken2 = new TestERC20("BTC", "BTC", 8);
        mockToken2.mint(address(this), 4000e8);
        mockToken1 = new MockERC20(5000e18);

        jusd = new JUSD(6);
        USDC = new TestERC20("USDC", "USDC", 6);
        mockToken1ChainLink = new MockChainLinkEditable();
        mockToken2ChainLink = new MockChainLinkEditable();
        mockToken1ChainLink.SetPrice(20000e8);
        mockToken2ChainLink.SetPrice(2000e8);
        usdcPrice = new MockUSDCPrice();
        jojoDealer = new MockJOJODealer();
        jojoOracle1 = new JOJOOracleAdaptor(
            address(mockToken1ChainLink),
            20,//ETH
            86400,
            address(usdcPrice)
        );
        jojoOracle2 = new JOJOOracleAdaptor(
            address(mockToken2ChainLink),
            10,//BTC
            86400,
            address(usdcPrice)
        );
        jusd.mint(200000e6);
        jusd.mint(100000e6);

        // initial
        jusdBank = new JUSDBank( // maxReservesAmount_
            10,
            insurance,
            address(jusd),
            address(jojoDealer),
            // maxBorrowAmountPerAccount_
            100000000000,
            // maxBorrowAmount_
            100000000001,
            // borrowFeeRate_
            2e16,
            address(USDC)
        );

        jusd.transfer(address(jusdBank), 200000e6);
        //  mockToken2 BTC mockToken1 ETH
        jusdBank.initReserve(
            // token
            address(mockToken2),
            // initialMortgageRate
            7e17,
            // maxDepositAmount
            300e8,
            // maxDepositAmountPerAccount
            210e8,
            // maxBorrowValue
            100000e6,
            // liquidateMortgageRate
            8e17,
            // liquidationPriceOff
            5e16,
            // insuranceFeeRate
            1e17,
            address(jojoOracle2)
        );

        jusdBank.initReserve(
            // token
            address(mockToken1),
            // initialMortgageRate
            8e17,
            // maxDepositAmount
            4000e18,
            // maxDepositAmountPerAccount
            2030e18,
            // maxBorrowValue
            100000e6,
            // liquidateMortgageRate
            825e15,
            // liquidationPriceOff
            5e16,
            // insuranceFeeRate
            1e17,
            address(jojoOracle1)
        );

        swapContract = new SupportsSWAP(
            address(USDC),
            address(mockToken1),
            address(jojoOracle1)
        );
        // address[] memory swapContractList = new address[](1);
        // swapContractList[0] = address(swapContract);
        // uint256[] memory amountList = new uint256[](1);
        // amountList[0] = 100000e6;
        USDC.mint(address(swapContract), 100000e6);

        jusdExchange = new JUSDExchange(address(USDC), address(jusd));
        jusd.transfer(address(jusdExchange), 100000e6);
    }

    function mintUSDC(uint amount) public {
        USDC.mint(address(this), amount);
    }

    function echina_balanceTest() public view returns (bool) {
        return USDC.balanceOf(address(this)) < 1e18;
    }
    function set_value(uint _value) public {
        value = _value;
    }

    function echidna_always_true() public view returns (bool) {
        return true;
    }

    function echidna_test_jusd_bank() public view returns (bool) {
        return value < 10000;
    }

    function echidna_test_jusd() public view returns (bool) {
        return value < 1e23;
    }
}
