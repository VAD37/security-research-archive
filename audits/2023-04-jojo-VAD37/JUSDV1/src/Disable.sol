pragma solidity 0.8.9;

import "../test/mocks/MockChainLinkEditable.sol";
import "./Impl/JUSDBank.sol";
import "./Impl/JUSDExchange.sol";
import "../test/mocks/MockERC20.sol";
import "../test/mocks/TestERC20.sol";
import "./token/JUSD.sol";
import "./oracle/JOJOOracleAdaptor.sol";
import "../test/mocks/MockChainLink.t.sol";
import "../test/mocks/MockChainLink2.sol";
import "./Testsupport/SupportsSWAP.sol";
import "../test/mocks/MockChainLink500.sol";
import "../test/mocks/MockJOJODealer.sol";
import "../test/mocks/MockUSDCPrice.sol";
import "../test/mocks/MockChainLinkBadDebt.sol";
import "./lib/DataTypes.sol";
import "./Impl/flashloanImpl/GeneralRepay.sol";

contract Setup {
 JUSDBank public jusdBank;
    TestERC20 public mockToken2;//BTC
    MockERC20 public mockToken1;//WETH
    JUSDExchange public jusdExchange;
    JUSD public jusd;
    JOJOOracleAdaptor public jojoOracle1;
    JOJOOracleAdaptor public jojoOracle2;
    MockChainLink public mockToken1ChainLink;
    MockChainLink2 public mockToken2ChainLink;
    MockUSDCPrice public usdcPrice;
    MockJOJODealer public jojoDealer;
    SupportsSWAP public swapContract;
    TestERC20 public USDC;
    GeneralRepay public generalRepay;
}

/// @dev To run this contract: $ npx hardhat clean && npx hardhat compile --force && echidna-test . --contract TestNaiveReceiverEchidna --config contracts/naive-receiver/config.yaml
contract TestNaiveReceiverEchidna {

    // Setup echidna test by deploying the flash loan pool and receiver and sending them some ether.
    constructor() payable {
    }
}