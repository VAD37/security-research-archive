
# Call  `depositEth()` and `depositWeth()` to predefined pool wstETH with 100% boost might revert due to stETH oracle

## Summary

Wrapping 1 ETH get 0.856 wstETH.
wstETH token price is depend on Lido stETH token price which depend on custom supply/demand oracle
If wrapping price increase due to new supply to ETH transfer to Lido pool.
The wrapping might increase tiny to 1 ETH get 0.857 wstETH.
If booster is called with 100%, this warp with 0.856 as booster value will always revert.
Due to slight delay in transaction causing price increase affect warp price.

## Vulnerability Detail

Here is warp price conversion for lido [stETH.](https://etherscan.io/address/0x17144556fd3424edc8fc8a4c940b2d04936d17eb#code)

```solidity
    /**
     * @return the amount of shares that corresponds to `_ethAmount` protocol-controlled Ether.
     */
    function getSharesByPooledEth(uint256 _ethAmount) public view returns (uint256) {
        return _ethAmount
            .mul(_getTotalShares())
            .div(_getTotalPooledEther());
    }
```

Supply and pooled ether changed when someone mint new stETH token. So its price convert from 1 ETH to wstETH change along too.

Because of mainnet condition transaction execution might be delay or affected by other user transaction.
Which might result in , Price 1 ETH to wstETH might increase from 0.856 to 0.857 when your transaction is executed.

For user calling `depositETH()` into `PredefinedPool.wstETH`. As seen here.
<https://github.com/sherlock-audit/2024-05-sophon-VAD37/blob/948a548b545fc35e5b9fc817384822e48b88c0f4/farming-contracts/contracts/farm/SophonFarming.sol#L504-L540>

It will wrapping ETH token to stETH then wstETH.

```solidity
    function _ethTOstEth(uint256 _amount) internal returns (uint256) {
        // submit function does not return exact amount of stETH so we need to check balances
        uint256 balanceBefore = IERC20(stETH).balanceOf(address(this));
        IstETH(stETH).submit{value: _amount}(address(this));
        return (IERC20(stETH).balanceOf(address(this)) - balanceBefore);
    }
```

`IstETH(stETH).submit()` will just call `getSharesByPooledEth()` to get accurate stETH token minted. Which is same rate as mentioned above.
 1 ETH = 0.856 wstETH. Subject to price oracle change.

Looking at how final booster value is calculated
```solidity
    function _depositPredefinedAsset(uint256 _amount, uint256 _initalAmount, uint256 _boostAmount, PredefinedPool _predefinedPool) internal {

        uint256 _finalAmount;

        if (_predefinedPool == PredefinedPool.sDAI) {
            _finalAmount = _daiTOsDai(_amount);
        } else if (_predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _stEthTOwstEth(_amount);//1 stETH = 0.856 wstETH /
        } else if (_predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _eethTOweEth(_amount);//1 eETH = 1.03897 weETH
        } else {
            revert InvalidDeposit();
        }

        // adjust boostAmount for the new asset
        _boostAmount = _boostAmount * _finalAmount / _initalAmount;

        _deposit(typeToId[_predefinedPool], _finalAmount, _boostAmount);
    }
```
If user want to boost 100% with 1 ETH. they will use boost value same as initial deposit

## Impact

## Code Snippet

<https://github.com/sherlock-audit/2024-05-sophon-VAD37/blob/948a548b545fc35e5b9fc817384822e48b88c0f4/farming-contracts/contracts/farm/SophonFarming.sol#L504-L540>

## Tool used

Manual Review

## Recommendation
