forge test --fork-url "https://eth-mainnet.alchemyapi.io/v2/kIP2_euA9T6Z-e5MjHzTzRUmgqCLsHUA" --fork-block-number 17139005 --etherscan-api-key 64D8FMTIH1UG2BCD2A1BFMFZCTF6S2YG95 --match-contract MainnetTest -vv

## 4 tokens

`LibStorage.getTokenStorage()`
ID:1
nwETH: 0xaac5145f5286a3c6a06256fdfbf5b499aa965c9c
decimals: 100000000
ID:2
nwDAI: 0xdbbb034a50c436359fb6d87d3d669647e0fa24d5
underlying: DAI 0x6b175474e89094c44da98b954eedeac495271d0f
decimals: 100000000
ID:3
nwUSDC: 0xc91864be1b097c9c85565cdb013ba2307ffb492a
underlying: USDC 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
decimals: 100000000
ID:4
nwWBTC: 0x0f12b85a331acb515e1626f707aade62e9960187
underlying: WBTC 0x2260fac5e5542a773aa44fbcfedf7c193bc2c599
decimals: 100000000

## oracles

new oracle pcash is ``CompoundV2HoldingsOracle`` V3Environment.py#L67

## rates before migration v3

[PASS] test_getCurrencyAndRates() (gas: 346867)
Logs:
  currencyId: 1 nwETH
  assetToken: 0xaac5145f5286a3c6a06256fdfbf5b499aa965c9c
  underlyingToken: 0x0000000000000000000000000000000000000000
  rateDecimals: 1000000000000000000
  rate: 1000000000000000000
  buffer: 129
  haircut: 78
  liquidationDiscount: 106
  rateOracle: 0xaac5145f5286a3c6a06256fdfbf5b499aa965c9c
  rate: 200825311836614529014421066
  rateDecimals: 1000000000000000000

  currencyId: 2 nwDAI
  assetToken: 0xdbbb034a50c436359fb6d87d3d669647e0fa24d5
  underlyingToken: 0x6b175474e89094c44da98b954eedeac495271d0f
  rateDecimals: 1000000000000000000
  rate: 524466810565558
  buffer: 109
  haircut: 92
  liquidationDiscount: 104
  rateOracle: 0xdbbb034a50c436359fb6d87d3d669647e0fa24d5
  rate: 222144138814744557650665343
  rateDecimals: 1000000000000000000

  currencyId: 3 nwUSDC
  assetToken: 0xc91864be1b097c9c85565cdb013ba2307ffb492a
  underlyingToken: 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
  rateDecimals: 1000000000000000000
  rate: 524483332591853
  buffer: 109
  haircut: 92
  liquidationDiscount: 104
  rateOracle: 0xc91864be1b097c9c85565cdb013ba2307ffb492a
  rate: 228140207820062
  rateDecimals: 1000000
  
  currencyId: 4 nwWBTC
  assetToken: 0x0f12b85a331acb515e1626f707aade62e9960187
  underlyingToken: 0x2260fac5e5542a773aa44fbcfedf7c193bc2c599
  rateDecimals: 1000000000000000000
  rate: 15320294966792586216
  buffer: 129
  haircut: 78
  liquidationDiscount: 107
  rateOracle: 0x0f12b85a331acb515e1626f707aade62e9960187
  rate: 20074356395626757
  rateDecimals: 100000000
