// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/interfaces/IERC20.sol";
import "../src/external/Router.sol";
import "../src/external/Views.sol";
import "../src/external/CalculationViews.sol";
import "../src/global/Types.sol";

contract MainnetTest is Test {

    address payable constant notional = 0x1344A36A1B56144C3Bc62E7757377D288fDE0369;
    IERC20 note = IERC20(0xCFEAead4947f0705A14ec42aC3D44129E1Ef3eD5);
    Router router = Router(notional);
    CalculationViews calculationView = CalculationViews(notional);    
    Views viewer = Views(notional);

    function setUp() public {
    }

    function test_listCurrency() public {
        // uint16 maxCurrencyId = viewer.getMaxCurrencyId();
        // assertTrue(maxCurrencyId> 0);
        // emit log_named_uint("maxCurrencyId", uint(maxCurrencyId));
        // // for loop (Token assetToken, Token underlyingToken) = getCurrency()
        // for (uint16 i = 1; i <= maxCurrencyId; i++) {
        //     emit log_named_uint("currencyId", uint(i));
        //     (Token memory assetToken, Token memory underlyingToken) = viewer.getCurrency(i);
        //     emit log_named_address("assetToken", assetToken.tokenAddress);
        //     emit log_named_address("underlyingToken", underlyingToken.tokenAddress);
        //     emit log_named_uint("decimals", uint(assetToken.decimals));
        //     emit log_named_uint("assetTokenType", uint(assetToken.tokenType));
        //     assertTrue(assetToken.tokenAddress != address(0));
        // }        
    }
    // function test_oracle() public {
    //     for (uint16 i = 1; i <= 4; i++) { 
    //         emit log_named_uint("currencyId", uint(i));
    //         address oracle = viewer.getPrimeCashHoldingsOracle(i);
    //         emit log_named_address("oracle", oracle);
    //     }        
    // }
    function test_getCurrencyAndRates() public {
        for (uint16 i = 1; i <= 4; i++) { 
            emit log_named_uint("currencyId", uint(i));
            (Token memory assetToken,
            Token memory underlyingToken,
            ETHRate memory ethRate,
            Deprecated_AssetRateParameters memory assetRate) = viewer.getCurrencyAndRates(i);
            emit log_named_address("assetToken", assetToken.tokenAddress);
            emit log_named_address("underlyingToken", underlyingToken.tokenAddress);
            emit log_named_uint("rateDecimals", uint(ethRate.rateDecimals));
            emit log_named_uint("rate", uint(ethRate.rate));
            emit log_named_uint("buffer", uint(ethRate.buffer));
            emit log_named_uint("haircut", uint(ethRate.haircut));
            emit log_named_uint("liquidationDiscount", uint(ethRate.liquidationDiscount));
            emit log_named_address("rateOracle", address(assetRate.rateOracle));
            emit log_named_uint("rate", uint(assetRate.rate));
            emit log_named_uint("rateDecimals", uint(assetRate.underlyingDecimals));            
        }
    }
}