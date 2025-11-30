# Consistent way to make `CoreChainlinkFeed` oracle return 0 price on `MAINNET`. Allowing oracle price manipulation. Chainlink feed use `MAX_ANSWER_DELAY` 60 minutes is too short

Chainlink offchain oracle refresh price **exactly** every 60 minutes. And `CoreChainlinkFeed` ignore chainlink feed if its price stale more than 60 minutes.

Looking at etherscan transactions, It is very easy to find chainlink feed price submission is delayed by a few blocks.
Causing price updating longer than 60 minutes by 10-20 seconds a few times per day.

So each day on some specific blocks, chainlink price is not available due to custom oracle implementation.
The protocol expect chainlink and uniswap oracle to be available at all time.

The oracle price always average 2 out of 3 different oracle price. Which most of the time is chainlink and uniswap.
With chainlink out of the picture, the fallback safety are `CoreSaltyFeed` oracle and 7% price different between oracle protection.

## Impact

Because chainlink oracle can easily leave out of price calculation entirely due to slight mistake in time check mechanism.
This open up a single block window to manipulate price.

`CoreSaltyFeed` can be manipulated, attacker can gain maximum 3.5% profit in two transactions by manipulating `CoreSaltyFeed` price during when chainlink oracle is disabled.

## Proof of Concept

Here is a sample contract of a chainlink aggregator update price to oracle feed.
<https://etherscan.io/address/0xE62B71cf983019BFf55bC83B48601ce8419650CC>

It update price every 60 minutes exactly, when there is no big price movement, otherwise it update price immediately for every 0.5% price change.
Most of the time, the timestamp aggregate between 2 rounds is exactly 60 minutes.
And then there is a few times, the timestamp different is more than 60 minutes.

Look at timestamp of these 2 transactions from above contract:
<https://etherscan.io/tx/0xc39df382dc6d8b137f92f15f8a10d777c9eed960ce885bc5333d936d6e39da86>
<https://etherscan.io/tx/0xbdf4ac46502a12f18a75aa279e469a1d159e792b909b823203e2df28bae3d9ed>

Both transmit to refresh price to oracle, it show the `block.timestamp` different is more than 60 minutes.
`03:55:47 AM +UTC vs 02:55:35 AM +UTC`.
And this is normal for price refresh, chainlink refresh price on-chain every hour.

So by frontrun chainlink oracle price submission on slow block every hour, `CoreChainlinkFeed` will return 0 price because `answerDelay > 60 minutes`.

`PriceAggregator` will relied average price of `CoreUniswapFeed` and `CoreSaltyFeed` price feed.

`CoreSaltyFeed` can be easily price manipulated.
So this is just matter what to do with price manipulation.

## Tools Used

<https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/price_feed/CoreChainlinkFeed.sol#L44-L49>

## Recommended Mitigation Steps

max answer delay should be 61-70 minutes instead of 60 minutes.
