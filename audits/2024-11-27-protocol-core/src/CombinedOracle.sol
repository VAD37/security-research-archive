// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import { BaseTakerOracle, ITakerOracle } from "./base/BaseTakerOracle.sol";

/**
 * @title CombinedOracle
 * @custom:security-contact security@collarprotocol.xyz
 * @notice Combines two other oracles that use a common asset into one
 *
 * Key Assumptions:
 * - Assets and intermediate assets are chosen such that resulting precision is satisfactory
 * - Combined price deviations (in case of CL oracles are taken into account)
 * - The sequencer feed (on L2 networks) on the the leaf oracles is checked (not checked here).
 *
 * @dev reference implementation:
 * https://github.com/euler-xyz/euler-price-oracle/blob/0572b45f6096f42f290b7cf7df584226815bfa52/src/adapter/CrossAdapter.sol
 */
contract CombinedOracle is BaseTakerOracle {
    string public constant VERSION = "0.2.0";

    /// @notice first oracle to be combined (A -> B)
    ITakerOracle public immutable oracle_1;
    /// @notice second oracle to be combined (C -> D)
    ITakerOracle public immutable oracle_2;
    /// @notice whether the first oracle's direction is reversed in the path
    bool public immutable invert_1;//false
    /// @notice whether the second oracle's direction is reversed in the path
    bool public immutable invert_2;//true

    // internal caching of fixed amounts
    uint internal immutable base1Amount;// WETH e18
    uint internal immutable base2Amount;// USDC e6
    uint internal immutable quote1Amount;// USD e18
    uint internal immutable quote2Amount;// USD e18

    constructor(//@oracle are ChainlinkOracle
        address _baseToken,//WETH 
        address _quoteToken,//USDC 
        address _oracle_1,//ETH/USD             3590.96000000
        bool _invert_1,//false for all oracles
        address _oracle_2,// USDC/USD           .99992702
        bool _invert_2//true
    ) BaseTakerOracle(_baseToken, _quoteToken, address(0)) {//@audit-ok does oracle WETH/USDC and WETH/USD -> USD/USDC differ?
        oracle_1 = ITakerOracle(_oracle_1);
        oracle_2 = ITakerOracle(_oracle_2);
        invert_1 = _invert_1;
        invert_2 = _invert_2;

        // check that all assets match: base, cross, and quote
        // assume 1 not inverted and invert if needed. If inverted, A->B turns into B->A
        (address base, address cross_1) = (oracle_1.baseToken(), oracle_1.quoteToken());//WETH/0xff..ff
        if (invert_1) (base, cross_1) = (cross_1, base);

        // assume 2 not inverted and invert if needed. If inverted, C->D turns into D->C
        (address cross_2, address quote) = (oracle_2.baseToken(), oracle_2.quoteToken());//USDC/0xff.ff
        if (invert_2) (quote, cross_2) = (cross_2, quote);//0xff.ff/USDC

        // check all match passed in tokens and implied cross token.
        // For example, if no inversion of was done for 1: A->B and 2: C->D
        // We expected that A == baseToken, D == quoteToken, and B == C
        require(base == baseToken, "CombinedOracle: base argument mismatch");//WETH = oracle1.WETH
        require(quote == quoteToken, "CombinedOracle: quote argument mismatch");//USDC = oracle2.USDC
        require(cross_1 == cross_2, "CombinedOracle: cross token mismatch");// 0xff..ff = 0xff..ff

        // cache amounts
        (base1Amount, quote1Amount) = (oracle_1.baseUnitAmount(), oracle_1.quoteUnitAmount());//WETH/USD e18,e18
        (base2Amount, quote2Amount) = (oracle_2.baseUnitAmount(), oracle_2.quoteUnitAmount());//USDC/USD e6,e18
    }

    /// @notice Current price of a unit of base tokens (i.e. 10**baseToken.decimals()) in quote tokens.
    /// For a path combination of (A->B, B->C), it quotes the price of A->C, of one unit of A in C units
    function currentPrice() external view override returns (uint) {
        // going from oracle 1 to 2
        uint price1 = invert_1 ? oracle_1.inversePrice() : oracle_1.currentPrice(); //currentPrice() = 3590_96000000 * 1e18/e8 = 3590e18
        uint divisor1 = invert_1 ? base1Amount : quote1Amount;// e18
        uint price2 = invert_2 ? oracle_2.inversePrice() : oracle_2.currentPrice(); // inversePrice() =  e6 * e8 / 0.99992702e8 = 0.999927e6
        // 1: ETH/USD_18, 2: inv USDC/USD_18. currentPrice() is for unit of ETH in USDC
        // p1=3000e18, d1=1e18, p2=1e6 -> 3000e18 * 1e6 / 1e18 -> 3000e6
        return price1 * price2 / divisor1;// 3590e18 * 0.999927e6 / 1e18 = 3590.69785992e6 USDC  = 1 WETH
    }

    /// @notice Current price of a unit of quote tokens (i.e. 10**quoteToken.decimals()) in base tokens.
    /// For a path combination of (A->B, B->C), it quotes the price of C->A, of one unit of C in A units
    function inversePrice() external view returns (uint) {
        // @dev the invert conditionals are flipped because of the reversed direction of trade
        // going from oracle 2 to 1
        uint price2 = invert_2 ? oracle_2.currentPrice() : oracle_2.inversePrice();// 0.999927e6
        uint divisor2 = invert_2 ? quote2Amount : base2Amount;//USD quote2amount = e18
        uint price1 = invert_1 ? oracle_1.currentPrice() : oracle_1.inversePrice(); // inversePrice() = e18 *e8 / 3590.96000000e8 = 1/3590.96e18 = 0.0002784771e18
        // 1: ETH/USD_18, 2: inv USDC/USD_18. inversePrice() is for unit of USDC in ETH
        // p2=1e18, d2=1e18, p1=(1/3000)e18 -> 1e18 * (1/3000)e18 / 1e18 -> (1/3000)e18
        return price2 * price1 / divisor2; //0.0002784567e18  WETH = 1 USDC
    }//@audit-ok I it seem like inversePrice have some minor precision lost. with e6 USDC-> USD
}
