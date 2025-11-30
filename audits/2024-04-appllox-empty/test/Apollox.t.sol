// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./base.t.sol";

contract ApolloXTest is BaseTest {
    address testUser = 0xa1a16789955211C154ffEa6B2C73E3083B41320E;

    function testgPrint() public {
        _printALPManager();
        _printAPXReward();
        _printBrokerManager();
        _printBook();
        _printChainlinkPrice();
        _printDiamondCut();
        _printDiamondLoupe();
        _printFeeManager();
        _printLimitOrder();
        _printOraclePrice();
        _printOrderAndTradeHistory();
        _printPairsManager();
        _printPausable();
        _printPredictUpDown();
        _printPredictionManager();
        _printPriceFacade();
        _printSlippageManager();
        _printStakeReward();
        _printTimeLock();
        _printTrading();
        _printTradingChecker();
        _printTradingClose();
        _printTradingConfig();
        _printTradingCore();
        _printTradingOpen();
        _printTradingPortal();
        _printTradingReader();
        _printVault();
    }

    function _printALPManager() internal {
        console.log("apolloX: %s", apolloX);
        //get all view from ALPManager
        console.log("ALP: %s", alpManager.ALP());
        console.log("coolingDuration: %s", alpManager.coolingDuration());
        console.log("signer: %s", alpManager.getSigner());
        console.log("isFreeBurn: %s", alpManager.isFreeBurn(apolloX));
        console.log("lastMintedTimestamp: %s", alpManager.lastMintedTimestamp(apolloX));
        console.log("alpPrice: %e", alpManager.alpPrice()); //@why this fail to call
    }

    function _printAPXReward() internal {
        //IApxReward
        IApxReward.ApxPoolInfo memory info = apxReward.apxPoolInfo();
        console.log("pool totalStaked: %e", info.totalStaked);
        console.log("pool totalApx: %e", info.apxPerBlock);
        console.log("pool lastRewardBlock: %s", info.lastRewardBlock);
        console.log("pool accAPXPerShare: %e", info.accAPXPerShare);
        console.log("pool totalReward: %e", info.totalReward);
        console.log("pool reserves: %e", info.reserves);
        //pending apx
        console.log("pendingApx: %e", apxReward.pendingApx(testUser));
    }

    function _printBrokerManager() internal {
        //IBrokerManager
        IBrokerManager.BrokerInfo[] memory brokers = brokerManager.brokers(0, 100);
        for (uint256 i = 0; i < brokers.length; i++) {
            IBrokerManager.BrokerInfo memory broker = brokerManager.getBrokerById(brokers[i].id);
            console.log("broker id: %s", broker.id);
            console.log("broker name: %s", broker.name);
            console.log("broker url: %s", broker.url);
            console.log("broker receiver: %s", broker.receiver);
            console.log("broker commissionP: %s", broker.commissionP);
            console.log("broker daoShareP: %s", broker.daoShareP);
            console.log("broker alpPoolP: %s", broker.alpPoolP);
            for (uint256 j = 0; j < broker.commissions.length; j++) {
                CommissionInfo memory commission = broker.commissions[j];
                console.log("commission token: %s", commission.token);
                console.log("commission total: %s", commission.total);
                console.log("commission pending: %s", commission.pending);
            }
        }
    }

    function _printBook() internal {
        // TODO: Implement code to print book
    }

    function _printChainlinkPrice() internal {
        // TODO: Implement code to print chainlinkPrice
    }

    function _printDiamondCut() internal {
        // TODO: Implement code to print diamondCut
    }

    function _printDiamondLoupe() internal {
        // TODO: Implement code to print diamondLoupe
    }

    function _printFeeManager() internal {
        // TODO: Implement code to print feeManager
    }

    function _printLimitOrder() internal {
        // TODO: Implement code to print limitOrder
    }

    function _printOraclePrice() internal {
        // TODO: Implement code to print oraclePrice
    }

    function _printOrderAndTradeHistory() internal {
        // TODO: Implement code to print orderAndTradeHistory
    }

    function _printPairsManager() internal {
        // TODO: Implement code to print pairsManager
    }

    function _printPausable() internal {
        // TODO: Implement code to print pausable
    }

    function _printPredictUpDown() internal {
        // TODO: Implement code to print predictUpDown
    }

    function _printPredictionManager() internal {
        // TODO: Implement code to print predictionManager
    }

    function _printPriceFacade() internal {
        // TODO: Implement code to print priceFacade
    }

    function _printSlippageManager() internal {
        // TODO: Implement code to print slippageManager
    }

    function _printStakeReward() internal {
        // TODO: Implement code to print stakeReward
    }

    function _printTimeLock() internal {
        // TODO: Implement code to print timeLock
    }

    function _printTrading() internal {
        // TODO: Implement code to print trading
    }

    function _printTradingChecker() internal {
        // TODO: Implement code to print tradingChecker
    }

    function _printTradingClose() internal {
        // TODO: Implement code to print tradingClose
    }

    function _printTradingConfig() internal {
        // TODO: Implement code to print tradingConfig
    }

    function _printTradingCore() internal {
        // TODO: Implement code to print tradingCore
    }

    function _printTradingOpen() internal {
        // TODO: Implement code to print tradingOpen
    }

    function _printTradingPortal() internal {
        // TODO: Implement code to print tradingPortal
    }

    function _printTradingReader() internal {
        // TODO: Implement code to print tradingReader
    }

    function _printVault() internal {
        // TODO: Implement code to print vault
    }
    // List of all variable contract
    // alpManager
    // apxReward
    // book
    // brokerManager
    // chainlinkPrice
    // diamondCut
    // diamondLoupe
    // feeManager
    // limitOrder
    // oraclePrice
    // orderAndTradeHistory
    // pairsManager
    // pausable
    // predictUpDown
    // predictionManager
    // priceFacade
    // slippageManager
    // stakeReward
    // timeLock
    // trading
    // tradingChecker
    // tradingClose
    // tradingConfig
    // tradingCore
    // tradingOpen
    // tradingPortal
    // tradingReader
    // vault
}
