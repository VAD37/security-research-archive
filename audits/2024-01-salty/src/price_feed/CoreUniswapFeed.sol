// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "v3-core/interfaces/IUniswapV3Pool.sol";
import "v3-core/libraries/FixedPoint96.sol";
import "v3-core/libraries/TickMath.sol";
import "v3-core/libraries/FullMath.sol";
import "./interfaces/IPriceFeed.sol";

import {console} from "forge-std/Test.sol";
// Returns TWAPs for WBTC and WETH for associated Uniswap v3 pools.
// Prices are returned with 18 decimals.
contract CoreUniswapFeed is IPriceFeed
    {
    // 30 minute TWAP period to resist price manipulation
    uint256 public constant TWAP_PERIOD = 30 minutes;


	// Uniswap v3 pool addresses
    IUniswapV3Pool immutable public UNISWAP_V3_WBTC_WETH;
	IUniswapV3Pool immutable public UNISWAP_V3_WETH_USDC;

	IERC20 immutable public wbtc;
    IERC20 immutable public weth;
    IERC20 immutable public usdc;

    bool immutable public wbtc_wethFlipped;
    bool immutable public weth_usdcFlipped;


	constructor( IERC20 _wbtc, IERC20 _weth, IERC20 _usdc, address _UNISWAP_V3_WBTC_WETH, address _UNISWAP_V3_WETH_USDC )
		{
		UNISWAP_V3_WBTC_WETH = IUniswapV3Pool(_UNISWAP_V3_WBTC_WETH);
		UNISWAP_V3_WETH_USDC = IUniswapV3Pool(_UNISWAP_V3_WETH_USDC);

		usdc = _usdc;
		wbtc = _wbtc;
		weth = _weth;

		// Non-flipped is WBTC/WETH order
		wbtc_wethFlipped = address(weth) < address(wbtc);

		// Non-flipped is WETH/USDC order
		weth_usdcFlipped = address(usdc) < address(weth);
		}

	//@note uniswap oracle return arithmeticMeanTick  price not harmonicMeanLiquidity 
	// Returns amount of token0 * (10**18) given token1
    function _getUniswapTwapWei( IUniswapV3Pool pool, uint256 twapInterval ) public view returns (uint256)
    	{
		uint32[] memory secondsAgo = new uint32[](2);
		secondsAgo[0] = uint32(twapInterval); // from (before) 30mins
		secondsAgo[1] = 0; // to (now)
		//@ compare with https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol#L16
        // Get the historical tick data using the observe() function
         (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);
		//@tick = arithmeticMeanTick. //@audit L tick is not rounded down. like official library
		int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)));
		console.log("tick int:");
		console.logInt(int(tick));
		uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick( tick );//@getQuoteAtTick() //@audit missing sqrtPriceX96 check for overflow uint128. This happen with WBTC and WETH. when WBTC drop signifcant value. this need to be doubled checked
		console.log("sqrtPriceX96:",sqrtPriceX96, type(uint128).max);
		console.log("comparision",FixedPoint96.Q96, 1 << 64 );
		uint256 p = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96 );

		//@audit this price p is not precise. https://github.com/Uniswap/v3-periphery/blob/697c2474757ea89fec12a4e6db16a574fe259610/contracts/libraries/OracleLibrary.sol#L57
		uint8 decimals0 = ( ERC20( pool.token0() ) ).decimals();
		uint8 decimals1 = ( ERC20( pool.token1() ) ).decimals();

		if ( decimals1 > decimals0 )
			return FullMath.mulDiv( 10 ** ( 18 + decimals1 - decimals0 ), FixedPoint96.Q96, p );

		if ( decimals0 > decimals1 )
			return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / ( p * ( 10 ** ( decimals0 - decimals1 ) ) );

		return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / p;
    	}


	// Wrap the _getUniswapTwapWei function in a public function that includes a try/catch.
	// Returns zero on any type of failure.
	// virtual - really just needed for the derived unit tests
    function getUniswapTwapWei( IUniswapV3Pool pool, uint256 twapInterval ) public virtual view returns (uint256)
		{
		// Initialize return value to 0
		uint256 twap = 0;
		try this._getUniswapTwapWei(pool, twapInterval) returns (uint256 result)
			{
			twap = result;
			}
		catch (bytes memory)
			{
			// In case of failure, twap will remain 0
			}

		return twap;
		}


	// Uses WBTC/WETH and WETH/USDC pools because they have much higher TVL than just the Uniswap v3 WBTC/USD pool.
	function getTwapWBTC( uint256 twapInterval ) public virtual view returns (uint256)
		{
    	uint256 uniswapWBTC_WETH = getUniswapTwapWei( UNISWAP_V3_WBTC_WETH, twapInterval );
        uint256 uniswapWETH_USDC = getUniswapTwapWei( UNISWAP_V3_WETH_USDC, twapInterval );

		// Return zero if either is invalid
        if ((uniswapWBTC_WETH == 0) || (uniswapWETH_USDC == 0 ))
	        return 0;

		if ( wbtc_wethFlipped )
			uniswapWBTC_WETH = 10**36 / uniswapWBTC_WETH;

		if ( ! weth_usdcFlipped )
			uniswapWETH_USDC = 10**36 / uniswapWETH_USDC;

		return ( uniswapWETH_USDC * 10**18) / uniswapWBTC_WETH;
		}


	// virtual - really just needed for the derived unit tests
	function getTwapWETH( uint256 twapInterval ) public virtual view returns (uint256)
		{
        uint256 uniswapWETH_USDC = getUniswapTwapWei( UNISWAP_V3_WETH_USDC, twapInterval );

		// Return zero if invalid
        if ( uniswapWETH_USDC == 0 )
	        return 0;

        if ( ! weth_usdcFlipped )
        	return 10**36 / uniswapWETH_USDC;
        else
        	return uniswapWETH_USDC;
		}


	// Returned price is the 30 minutes TWAP by default
	function getPriceBTC() external view returns (uint256)
		{
		return getTwapWBTC( TWAP_PERIOD );
		}


	// Returned price is the 30 minutes TWAP by default.
	// For this to be changed the DAO needs to use a new CoreUniswapFeed contract (or other contract that implements IPriceFeed.sol)
	function getPriceETH() external view returns (uint256)
		{
		return getTwapWETH( TWAP_PERIOD );
		}
    }