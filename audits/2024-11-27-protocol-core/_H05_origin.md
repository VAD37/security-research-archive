# Core Mechanism Exploit: Provider Offers with Non-Asymmetrical Put/Strike Ratios

## Summary

Look at desmos graph below, you can see long/short position gain between Taker and Provider have "Disproportionate Payouts" if put/strike call percentage is not Asymmetrical.

In practice, Provider can open "non-asymmetrical" offer for Rolls/Loans system where unfair bet might make sense.
But because anyone use Taker contract to instantly take on unfair offer because benefit Taker more than Provider, this can result in huge loss for Provider due to unnessary risk.

Because I cannot found revelant Docs or examples explain how Provider supplier offer work, I consider this both as an overlook design choice and a potential exploit on misconfiguration issue. Because Provider/Taker system suppose to work along side with Loans/Rolls system. Because this is optional, anyone can simply use Taker contract to instantly take on Provider offer and benefit on unfair bet.
Assuming User is familiar with "Variable Prepaid Forward Contract" but not Collar protocol on blockchain run with different mechanism.
Project allow Provider to set themself for failure, Provider can easily find themself in a situation they always lose money bet.

## Finding Description

Look at how much token is locked when open new position.
<https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/CollarTakerNFT.sol#L185-L186>
<https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/CollarTakerNFT.sol#L119-L130>
Simplified formula to:

```js
providerLocker = takerLocked * (call - 100%) / (100% - put)
```

Where:

- `takerLocked` is the amount of token Taker locked in the position.
- `providerLocker` is the amount of token Provider locked in the position.
- `call` is the strike percentage of the Provider Offer.
- `put` is the put percentage of the Provider Offer.

Because only Taker can take on Provider Offer. Any offer with `(call - 100%) > (100% - put)` will result in Provider taking on a bigger risk.
Look at: <https://github.com/CollarNetworks/protocol-core/blob/3eadf114e72ff49b3096c221f0d8d31951a38292/src/CollarTakerNFT.sol#L362-L394>
When settlement is calculated as follow

```js
providerGain = takerLocked * (startPrice * priceDeviationPercentage) / (startPrice * 100% - put)
takerGain = -providerGain
```

Example: 95% put and 120% call offer.
Taker lock in 100 USDC
Provider lock in 400 USDC
If price drop 5%, Provider gain 100 USDC from taker.
If price increase 5%, Taker gain 100 USDC from provider.
If price increase 20%, Taker gain 400 USDC from provider.

As Provider it is unnessary to take on such risk. So therefore, the config to allow provider create an offer with suck unfair risk is unnessary and potentially exploitable.
Because Rolls/Loans system is optional, any Provider

###

Link to Desmos Graph. Left side is Taker gain, right side is Provider gain.
<https://www.desmos.com/calculator/msjnts5qdm>
2 examples images is 90% put and 110% strike in comparision with 90% put and 120% strike.
90/120 ratio show taker put in 100 to gain 200 from provider if price increase by 20%.
While 90/110 ratio show taker put in 100 to gain 100 from provider if price increase by 10%.

## Impact Explanation

Provider might want to create unfair offer that not benefit themself for Loans/Rolls system.
Because Taker contract allow anyone to openly take on Provider offer.
Offer with non-asymmetrical put/strike price is exploitable.

## Likelihood Explanation

Allowing misconfigure offer with unfair gain, Provider can found themself in a situation making a huge loss.

## Proof of Concept (if required)

## Recommendation

There is zero benefit from Provider perspective to open up offer that is not asymmetrical.
Either add a warning on UI how offer show how much user lost or remove the ability to create non-asymmetrical offer.
