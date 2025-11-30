# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 19 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 2 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 1 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 4 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 1 |
| [GAS-6](#GAS-6) | Use calldata instead of memory for function arguments that do not get mutated | 3 |
| [GAS-7](#GAS-7) | For Operations that will not overflow, you could use unchecked | 116 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 5 |
| [GAS-9](#GAS-9) | State variables only set in the constructor should be declared `immutable` | 2 |
| [GAS-10](#GAS-10) | Functions guaranteed to revert when called by normal users can be marked `payable` | 7 |
| [GAS-11](#GAS-11) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 6 |
| [GAS-12](#GAS-12) | Use shift right/left instead of division/multiplication if possible | 1 |
| [GAS-13](#GAS-13) | Increments/decrements can be unchecked in for-loops | 8 |
| [GAS-14](#GAS-14) | Use != 0 instead of > 0 for unsigned integer comparison | 3 |
| [GAS-15](#GAS-15) | `internal` functions not called by the contract should be removed | 8 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (19)*:
```solidity
File: HypoVault.sol

233:         queuedDeposit[msg.sender][currentEpoch] += assets;

235:         depositEpochState[currentEpoch].assetsDeposited += assets;

262:         withdrawalEpochState[_withdrawalEpoch].sharesWithdrawn += shares;

298:         userBasis[withdrawer] += currentPendingWithdrawal.basis;

333:         userBasis[user] += userAssetsDeposited;

340:         if (assetsRemaining > 0) queuedDeposit[user][epoch + 1] += uint128(assetsRemaining);

437:         userBasis[to] += basisToTransfer;

569:             balanceOf[to] += amount;

```

```solidity
File: accountants/PanopticVaultAccountant.sol

155:                             poolExposure0 += int256(amount0);

156:                             poolExposure1 += int256(amount1);

169:                 poolExposure0 += int256(longAmounts.rightSlot()) - int256(shortAmounts.rightSlot());

170:                 poolExposure1 += int256(longAmounts.leftSlot()) - int256(shortAmounts.leftSlot());

172:                 numLegs += positionLegs;

198:                 poolExposure0 += address(pools[i].token0) ==

202:             if (!skipToken1) poolExposure1 += int256(pools[i].token1.balanceOf(_vault));

205:             poolExposure0 += int256(

210:             poolExposure1 += int256(

250:             nav += uint256(Math.max(poolExposure0 + poolExposure1, 0));

258:         if (!skipUnderlying) nav += IERC20Partial(underlyingToken).balanceOf(_vault);

```

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`
*Saves 6 gas per instance*

*Instances (2)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

177:             if (address(pools[i].token0) == address(0))

188:                 if (underlyingTokens[j] == address(0)) {

```

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (1)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

71:     mapping(address vault => bool isLocked) public vaultLocked;

```

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (4)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

112:         for (uint256 i = 0; i < pools.length; i++) {

140:             for (uint256 j = 0; j < tokenIds[i].length; j++) {

184:             for (uint256 j = 0; j < underlyingTokens.length; j++) {

255:         for (uint256 i = 0; i < underlyingTokens.length; i++) {

```

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage
The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (1)*:
```solidity
File: HypoVault.sol

393:         SafeTransferLib.safeTransfer(underlyingToken, user, assetsToWithdraw);

```

### <a name="GAS-6"></a>[GAS-6] Use calldata instead of memory for function arguments that do not get mutated
When a function with a `memory` array is called externally, the `abi.decode()` step has to use a for-loop to copy each index of the `calldata` to the `memory` index. Each iteration of this for-loop costs at least 60 gas (i.e. `60 * <mem_array>.length`). Using `calldata` directly bypasses this loop. 

If the array is passed to an `internal` function which passes the array to another internal function where the array is modified and therefore `memory` is used in the `external` call, it's still more gas-efficient to use `calldata` when the `external` function uses modifiers, since the modifiers may prevent the internal functions from being called. Structs have the same overhead as an array of length one. 

 *Saves 60 gas per instance*

*Instances (3)*:
```solidity
File: HypoVault.sol

474:         bytes memory managerInput

519:         bytes memory managerInput

```

```solidity
File: interfaces/IVaultAccountant.sol

13:         bytes memory managerInput

```

### <a name="GAS-7"></a>[GAS-7] For Operations that will not overflow, you could use unchecked

*Instances (116)*:
```solidity
File: HypoVault.sol

5: import {ERC20Minimal} from "lib/panoptic-v1.1/contracts/tokens/ERC20Minimal.sol";

6: import {IERC20} from "lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

7: import {IVaultAccountant} from "./interfaces/IVaultAccountant.sol";

9: import {Multicall} from "lib/panoptic-v1.1/contracts/base/Multicall.sol";

10: import {Ownable} from "lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/access/Ownable.sol";

12: import {Address} from "lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/utils/Address.sol";

13: import {Math} from "lib/panoptic-v1.1/contracts/libraries/Math.sol";

14: import {SafeTransferLib} from "lib/panoptic-v1.1/contracts/libraries/SafeTransferLib.sol";

225:                           DEPOSIT/REDEEM LOGIC

233:         queuedDeposit[msg.sender][currentEpoch] += assets;

235:         depositEpochState[currentEpoch].assetsDeposited += assets;

253:         uint256 withdrawalBasis = (previousBasis * shares) / userBalance;

255:         userBasis[msg.sender] = previousBasis - withdrawalBasis;

258:             amount: pendingWithdrawal.amount + shares,

259:             basis: uint128(pendingWithdrawal.basis + withdrawalBasis)

262:         withdrawalEpochState[_withdrawalEpoch].sharesWithdrawn += shares;

279:         depositEpochState[currentEpoch].assetsDeposited -= uint128(queuedDepositAmount);

298:         userBasis[withdrawer] += currentPendingWithdrawal.basis;

300:         withdrawalEpochState[currentEpoch].sharesWithdrawn -= currentPendingWithdrawal.amount;

333:         userBasis[user] += userAssetsDeposited;

337:         uint256 assetsRemaining = queuedDepositAmount - userAssetsDeposited;

340:         if (assetsRemaining > 0) queuedDeposit[user][epoch + 1] += uint128(assetsRemaining);

356:         uint256 sharesToFulfill = (uint256(pendingWithdrawal.amount) *

357:             _withdrawalEpochState.sharesFulfilled) / _withdrawalEpochState.sharesWithdrawn;

365:         reservedWithdrawalAssets -= assetsToWithdraw;

367:         uint256 withdrawnBasis = (uint256(pendingWithdrawal.basis) *

368:             _withdrawalEpochState.sharesFulfilled) / _withdrawalEpochState.sharesWithdrawn;

370:             Math.max(0, int256(assetsToWithdraw) - int256(withdrawnBasis))

371:         ) * performanceFeeBps) / 10_000;

375:         uint256 sharesRemaining = pendingWithdrawal.amount - sharesToFulfill;

377:         uint256 basisRemaining = pendingWithdrawal.basis - withdrawnBasis;

380:         if (sharesRemaining + basisRemaining > 0) {

381:             PendingWithdrawal memory nextQueuedWithdrawal = queuedWithdrawal[user][epoch + 1];

382:             queuedWithdrawal[user][epoch + 1] = PendingWithdrawal({

383:                 amount: uint128(nextQueuedWithdrawal.amount + sharesRemaining),

384:                 basis: uint128(nextQueuedWithdrawal.basis + basisRemaining)

389:             assetsToWithdraw -= performanceFee;

434:         uint256 basisToTransfer = (fromBasis * amount) / fromBalance;

436:         userBasis[from] = fromBasis - basisToTransfer;

437:         userBasis[to] += basisToTransfer;

463:         for (uint256 i; i < targetsLength; ++i) {

480:         uint256 totalAssets = accountant.computeNAV(address(this), underlyingToken, managerInput) +

481:             1 -

482:             epochState.assetsDeposited -

489:         uint256 assetsRemaining = epochState.assetsDeposited - assetsToFulfill;

497:         currentEpoch++;

506:         totalSupply = _totalSupply + sharesReceived;

522:         uint256 totalAssets = accountant.computeNAV(address(this), underlyingToken, managerInput) +

523:             1 -

524:             depositEpochState[depositEpoch].assetsDeposited -

537:         uint256 sharesRemaining = epochState.sharesWithdrawn - sharesToFulfill;

545:         currentEpoch++;

555:         totalSupply = _totalSupply - sharesToFulfill;

557:         reservedWithdrawalAssets = _reservedWithdrawalAssets + assetsReceived;

569:             balanceOf[to] += amount;

579:         balanceOf[from] -= amount;

```

```solidity
File: accountants/PanopticVaultAccountant.sol

4: import {Ownable} from "lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/access/Ownable.sol";

6: import {Math} from "lib/panoptic-v1.1/contracts/libraries/Math.sol";

7: import {PanopticMath} from "lib/panoptic-v1.1/contracts/libraries/PanopticMath.sol";

9: import {IERC20Partial} from "lib/panoptic-v1.1/contracts/tokens/interfaces/IERC20Partial.sol";

10: import {IV3CompatibleOracle} from "lib/panoptic-v1.1/contracts/interfaces/IV3CompatibleOracle.sol";

11: import {PanopticPool} from "lib/panoptic-v1.1/contracts/PanopticPool.sol";

13: import {LeftRightUnsigned} from "lib/panoptic-v1.1/contracts/types/LeftRight.sol";

14: import {LeftRightSigned} from "lib/panoptic-v1.1/contracts/types/LeftRight.sol";

15: import {LiquidityChunk} from "lib/panoptic-v1.1/contracts/types/LiquidityChunk.sol";

16: import {PositionBalance} from "lib/panoptic-v1.1/contracts/types/PositionBalance.sol";

17: import {TokenId} from "lib/panoptic-v1.1/contracts/types/TokenId.sol";

107:         address[] memory underlyingTokens = new address[](pools.length * 2);

112:         for (uint256 i = 0; i < pools.length; i++) {

115:                     managerPrices[i].poolPrice -

132:                     int256(uint256(shortPremium.rightSlot())) -

135:                     int256(uint256(longPremium.leftSlot())) -

140:             for (uint256 j = 0; j < tokenIds[i].length; j++) {

143:                 for (uint256 k = 0; k < positionLegs; k++) {

155:                             poolExposure0 += int256(amount0);

156:                             poolExposure1 += int256(amount1);

160:                             poolExposure0 -= int256(amount0);

161:                             poolExposure1 -= int256(amount1);

169:                 poolExposure0 += int256(longAmounts.rightSlot()) - int256(shortAmounts.rightSlot());

170:                 poolExposure1 += int256(longAmounts.leftSlot()) - int256(shortAmounts.leftSlot());

172:                 numLegs += positionLegs;

184:             for (uint256 j = 0; j < underlyingTokens.length; j++) {

192:                         underlyingTokens[j + (skipToken0 ? 0 : 1)] = address(pools[i].token1);

198:                 poolExposure0 += address(pools[i].token0) ==

202:             if (!skipToken1) poolExposure1 += int256(pools[i].token1.balanceOf(_vault));

205:             poolExposure0 += int256(

210:             poolExposure1 += int256(

221:                     Math.abs(conversionTick - managerPrices[i].token0Price) >

226:                     pools[i].isUnderlyingToken0InOracle0 ? -conversionTick : conversionTick

238:                     Math.abs(conversionTick - managerPrices[i].token1Price) >

243:                     pools[i].isUnderlyingToken0InOracle1 ? conversionTick : -conversionTick

250:             nav += uint256(Math.max(poolExposure0 + poolExposure1, 0));

255:         for (uint256 i = 0; i < underlyingTokens.length; i++) {

258:         if (!skipUnderlying) nav += IERC20Partial(underlyingToken).balanceOf(_vault);

```

```solidity
File: libraries/AccountingMath.sol

5: import {Math} from "lib/panoptic-v1.1/contracts/libraries/Math.sol";

7: import {IV3CompatibleOracle} from "lib/panoptic-v1.1/contracts/interfaces/IV3CompatibleOracle.sol";

9: import {TokenId} from "lib/panoptic-v1.1/contracts/types/TokenId.sol";

10: import {LiquidityChunk} from "lib/panoptic-v1.1/contracts/types/LiquidityChunk.sol";

25:                 return Math.mulDiv192(amount, uint256(sqrtPriceX96) ** 2);

45:                 return Math.mulDiv192RoundingUp(amount, uint256(sqrtPriceX96) ** 2);

62:                 return Math.mulDiv(amount, 2 ** 192, uint256(sqrtPriceX96) ** 2);

64:                 return Math.mulDiv(amount, 2 ** 128, Math.mulDiv64(sqrtPriceX96, sqrtPriceX96));

82:                 return Math.mulDivRoundingUp(amount, 2 ** 192, uint256(sqrtPriceX96) ** 2);

87:                         2 ** 128,

105:                     .mulDiv192(Math.absUint(amount), uint256(sqrtPriceX96) ** 2)

107:                 return amount < 0 ? -absResult : absResult;

112:                 return amount < 0 ? -absResult : absResult;

128:                     .mulDiv(Math.absUint(amount), 2 ** 192, uint256(sqrtPriceX96) ** 2)

130:                 return amount < 0 ? -absResult : absResult;

135:                         2 ** 128,

139:                 return amount < 0 ? -absResult : absResult;

193:         uint256 amount = positionSize * tokenId.optionRatio(legIndex);

217:             for (uint256 i = 0; i < 20; ++i) {

218:                 secondsAgos[i] = uint32(((i + 1) * twapWindow) / 20);

225:             for (uint256 i = 0; i < 19; ++i) {

227:                     (tickCumulatives[i] - tickCumulatives[i + 1]) / int56(uint56(twapWindow / 20))

```

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls
Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (5)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

201:                     : int256(pools[i].token0.balanceOf(_vault));

202:             if (!skipToken1) poolExposure1 += int256(pools[i].token1.balanceOf(_vault));

204:             uint256 collateralBalance = pools[i].pool.collateralToken0().balanceOf(_vault);

209:             collateralBalance = pools[i].pool.collateralToken1().balanceOf(_vault);

258:         if (!skipUnderlying) nav += IERC20Partial(underlyingToken).balanceOf(_vault);

```

### <a name="GAS-9"></a>[GAS-9] State variables only set in the constructor should be declared `immutable`
Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (2)*:
```solidity
File: HypoVault.sol

186:         underlyingToken = _underlyingToken;

189:         performanceFeeBps = _performanceFeeBps;

```

### <a name="GAS-10"></a>[GAS-10] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (7)*:
```solidity
File: HypoVault.sol

206:     function setManager(address _manager) external onlyOwner {

213:     function setAccountant(IVaultAccountant _accountant) external onlyOwner {

220:     function setFeeWallet(address _feeWallet) external onlyOwner {

273:     function cancelDeposit(address depositor) external onlyManager {

290:     function cancelWithdrawal(address withdrawer) external onlyManager {

```

```solidity
File: accountants/PanopticVaultAccountant.sol

77:     function updatePoolsHash(address vault, bytes32 poolsHash) external onlyOwner {

85:     function lockVault(address vault) external onlyOwner {

```

### <a name="GAS-11"></a>[GAS-11] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
Pre-increments and pre-decrements are cheaper.

For a `uint256 i` variable, the following is true with the Optimizer enabled at 10k:

**Increment:**

- `i += 1` is the most expensive form
- `i++` costs 6 gas less than `i += 1`
- `++i` costs 5 gas less than `i++` (11 gas less than `i += 1`)

**Decrement:**

- `i -= 1` is the most expensive form
- `i--` costs 11 gas less than `i -= 1`
- `--i` costs 5 gas less than `i--` (16 gas less than `i -= 1`)

Note that post-increments (or post-decrements) return the old value before incrementing or decrementing, hence the name *post-increment*:

```solidity
uint i = 1;  
uint j = 2;
require(j == i++, "This will be false as i is incremented after the comparison");
```
  
However, pre-increments (or pre-decrements) return the new value:
  
```solidity
uint i = 1;  
uint j = 2;
require(j == ++i, "This will be true as i is incremented before the comparison");
```

In the pre-increment case, the compiler has to create a temporary variable (when used) for returning `1` instead of `2`.

Consider using pre-increments and pre-decrements where they are relevant (meaning: not where post-increments/decrements logic are relevant).

*Saves 5 gas per instance*

*Instances (6)*:
```solidity
File: HypoVault.sol

497:         currentEpoch++;

545:         currentEpoch++;

```

```solidity
File: accountants/PanopticVaultAccountant.sol

112:         for (uint256 i = 0; i < pools.length; i++) {

143:                 for (uint256 k = 0; k < positionLegs; k++) {

184:             for (uint256 j = 0; j < underlyingTokens.length; j++) {

255:         for (uint256 i = 0; i < underlyingTokens.length; i++) {

```

### <a name="GAS-12"></a>[GAS-12] Use shift right/left instead of division/multiplication if possible
While the `DIV` / `MUL` opcode uses 5 gas, the `SHR` / `SHL` opcode only uses 3 gas. Furthermore, beware that Solidity's division operation also includes a division-by-0 prevention which is bypassed using shifting. Eventually, overflow checks are never performed for shift operations as they are done for arithmetic operations. Instead, the result is always truncated, so the calculation can be unchecked in Solidity version `0.8+`
- Use `>> 1` instead of `/ 2`
- Use `>> 2` instead of `/ 4`
- Use `<< 3` instead of `* 8`
- ...
- Use `>> 5` instead of `/ 2^5 == / 32`
- Use `<< 6` instead of `* 2^6 == * 64`

TL;DR:
- Shifting left by N is like multiplying by 2^N (Each bits to the left is an increased power of 2)
- Shifting right by N is like dividing by 2^N (Each bits to the right is a decreased power of 2)

*Saves around 2 gas + 20 for unchecked per instance*

*Instances (1)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

107:         address[] memory underlyingTokens = new address[](pools.length * 2);

```

### <a name="GAS-13"></a>[GAS-13] Increments/decrements can be unchecked in for-loops
In Solidity 0.8+, there's a default overflow check on unsigned integers. It's possible to uncheck this in for-loops and save some gas at each iteration, but at the cost of some code readability, as this uncheck cannot be made inline.

[ethereum/solidity#10695](https://github.com/ethereum/solidity/issues/10695)

The change would be:

```diff
- for (uint256 i; i < numIterations; i++) {
+ for (uint256 i; i < numIterations;) {
 // ...  
+   unchecked { ++i; }
}  
```

These save around **25 gas saved** per instance.

The same can be applied with decrements (which should use `break` when `i == 0`).

The risk of overflow is non-existent for `uint256`.

*Instances (8)*:
```solidity
File: HypoVault.sol

463:         for (uint256 i; i < targetsLength; ++i) {

```

```solidity
File: accountants/PanopticVaultAccountant.sol

112:         for (uint256 i = 0; i < pools.length; i++) {

140:             for (uint256 j = 0; j < tokenIds[i].length; j++) {

143:                 for (uint256 k = 0; k < positionLegs; k++) {

184:             for (uint256 j = 0; j < underlyingTokens.length; j++) {

255:         for (uint256 i = 0; i < underlyingTokens.length; i++) {

```

```solidity
File: libraries/AccountingMath.sol

217:             for (uint256 i = 0; i < 20; ++i) {

225:             for (uint256 i = 0; i < 19; ++i) {

```

### <a name="GAS-14"></a>[GAS-14] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (3)*:
```solidity
File: HypoVault.sol

340:         if (assetsRemaining > 0) queuedDeposit[user][epoch + 1] += uint128(assetsRemaining);

380:         if (sharesRemaining + basisRemaining > 0) {

388:         if (performanceFee > 0) {

```

### <a name="GAS-15"></a>[GAS-15] `internal` functions not called by the contract should be removed
If the functions are required by an interface, the contract should inherit from that interface and use the `override` keyword

*Instances (8)*:
```solidity
File: libraries/AccountingMath.sol

20:     function convert0to1(uint256 amount, uint160 sqrtPriceX96) internal pure returns (uint256) {

37:     function convert0to1RoundingUp(

57:     function convert1to0(uint256 amount, uint160 sqrtPriceX96) internal pure returns (uint256) {

74:     function convert1to0RoundingUp(

99:     function convert0to1(int256 amount, uint160 sqrtPriceX96) internal pure returns (int256) {

122:     function convert1to0(int256 amount, uint160 sqrtPriceX96) internal pure returns (int256) {

161:         uint256 legIndex,

209:         uint32 twapWindow

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 4 |
| [NC-2](#NC-2) | Array indices should be referenced via `enum`s rather than via numeric literals | 4 |
| [NC-3](#NC-3) | `constant`s should be defined rather than using magic numbers | 15 |
| [NC-4](#NC-4) | Control structures do not follow the Solidity Style Guide | 22 |
| [NC-5](#NC-5) | Consider disabling `renounceOwnership()` | 2 |
| [NC-6](#NC-6) | Function ordering does not follow the Solidity style guide | 1 |
| [NC-7](#NC-7) | Functions should not be longer than 50 lines | 19 |
| [NC-8](#NC-8) | Lack of checks in setters | 3 |
| [NC-9](#NC-9) | Missing Event for critical parameters change | 4 |
| [NC-10](#NC-10) | Incomplete NatSpec: `@param` is missing on actually documented functions | 2 |
| [NC-11](#NC-11) | Incomplete NatSpec: `@return` is missing on actually documented functions | 2 |
| [NC-12](#NC-12) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 1 |
| [NC-13](#NC-13) | `address`s shouldn't be hard-coded | 2 |
| [NC-14](#NC-14) | Adding a `return` statement when the function defines a named return variable, is redundant | 2 |
| [NC-15](#NC-15) | Take advantage of Custom Error's return value property | 11 |
| [NC-16](#NC-16) | Contract does not follow the Solidity style guide's suggested layout ordering | 2 |
| [NC-17](#NC-17) | Internal and private variables and functions names should begin with an underscore | 8 |
| [NC-18](#NC-18) | Event is missing `indexed` fields | 8 |
| [NC-19](#NC-19) | Constants should be defined rather than using magic numbers | 2 |
| [NC-20](#NC-20) | Variables need not be initialized to zero | 7 |
### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (4)*:
```solidity
File: HypoVault.sol

186:         underlyingToken = _underlyingToken;

187:         manager = _manager;

207:         manager = _manager;

221:         feeWallet = _feeWallet;

```

### <a name="NC-2"></a>[NC-2] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (4)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

141:                 if (positionBalanceArray[j][1] == 0) revert IncorrectPositionList();

149:                             uint128(positionBalanceArray[j][1])

167:                     .computeExercisedAmounts(tokenIds[i][j], uint128(positionBalanceArray[j][1]));

```

```solidity
File: libraries/AccountingMath.sol

239: 

```

### <a name="NC-3"></a>[NC-3] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (15)*:
```solidity
File: HypoVault.sol

371:         ) * performanceFeeBps) / 10_000;

```

```solidity
File: accountants/PanopticVaultAccountant.sol

107:         address[] memory underlyingTokens = new address[](pools.length * 2);

```

```solidity
File: libraries/AccountingMath.sol

25:                 return Math.mulDiv192(amount, uint256(sqrtPriceX96) ** 2);

45:                 return Math.mulDiv192RoundingUp(amount, uint256(sqrtPriceX96) ** 2);

62:                 return Math.mulDiv(amount, 2 ** 192, uint256(sqrtPriceX96) ** 2);

64:                 return Math.mulDiv(amount, 2 ** 128, Math.mulDiv64(sqrtPriceX96, sqrtPriceX96));

82:                 return Math.mulDivRoundingUp(amount, 2 ** 192, uint256(sqrtPriceX96) ** 2);

87:                         2 ** 128,

105:                     .mulDiv192(Math.absUint(amount), uint256(sqrtPriceX96) ** 2)

128:                     .mulDiv(Math.absUint(amount), 2 ** 192, uint256(sqrtPriceX96) ** 2)

135:                         2 ** 128,

217:             for (uint256 i = 0; i < 20; ++i) {

218:                 secondsAgos[i] = uint32(((i + 1) * twapWindow) / 20);

225:             for (uint256 i = 0; i < 19; ++i) {

227:                     (tickCumulatives[i] - tickCumulatives[i + 1]) / int56(uint56(twapWindow / 20))

```

### <a name="NC-4"></a>[NC-4] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (22)*:
```solidity
File: HypoVault.sol

199:         if (msg.sender != manager) revert NotManager();

311:         if (epoch >= depositEpoch) revert EpochNotFulfilled();

340:         if (assetsRemaining > 0) queuedDeposit[user][epoch + 1] += uint128(assetsRemaining);

349:         if (epoch >= withdrawalEpoch) revert EpochNotFulfilled();

431:         if (fromBalance == 0) return;

535:         if (assetsReceived > maxAssetsReceived) revert WithdrawalNotFulfillable();

```

```solidity
File: accountants/PanopticVaultAccountant.sol

78:         if (vaultLocked[vault]) revert VaultLocked();

105:         if (keccak256(abi.encode(pools)) != vaultPools[vault]) revert InvalidPools();

113:             if (

141:                 if (positionBalanceArray[j][1] == 0) revert IncorrectPositionList();

175:             if (numLegs != pools[i].pool.numberOfLegs(_vault)) revert IncorrectPositionList();

177:             if (address(pools[i].token0) == address(0))

185:                 if (underlyingTokens[j] == address(pools[i].token0)) skipToken0 = true;

186:                 if (underlyingTokens[j] == address(pools[i].token1)) skipToken1 = true;

189:                     if (!skipToken0) underlyingTokens[j] = address(pools[i].token0);

191:                     if (!skipToken1)

197:             if (!skipToken0)

202:             if (!skipToken1) poolExposure1 += int256(pools[i].token1.balanceOf(_vault));

220:                 if (

237:                 if (

256:             if (underlyingTokens[i] == underlyingToken) skipUnderlying = true;

258:         if (!skipUnderlying) nav += IERC20Partial(underlyingToken).balanceOf(_vault);

```

### <a name="NC-5"></a>[NC-5] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (2)*:
```solidity
File: HypoVault.sol

18: contract HypoVault is ERC20Minimal, Multicall, Ownable {

```

```solidity
File: accountants/PanopticVaultAccountant.sol

20: contract PanopticVaultAccountant is Ownable {

```

### <a name="NC-6"></a>[NC-6] Function ordering does not follow the Solidity style guide
According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (1)*:
```solidity
File: HypoVault.sol

1: 
   Current order:
   external setManager
   external setAccountant
   external setFeeWallet
   external requestDeposit
   external requestWithdrawal
   external cancelDeposit
   external cancelWithdrawal
   external executeDeposit
   external executeWithdrawal
   public transfer
   public transferFrom
   internal _transferBasis
   external manage
   external manage
   external fulfillDeposits
   external fulfillWithdrawals
   internal _mintVirtual
   internal _burnVirtual
   
   Suggested order:
   external setManager
   external setAccountant
   external setFeeWallet
   external requestDeposit
   external requestWithdrawal
   external cancelDeposit
   external cancelWithdrawal
   external executeDeposit
   external executeWithdrawal
   external manage
   external manage
   external fulfillDeposits
   external fulfillWithdrawals
   public transfer
   public transferFrom
   internal _transferBasis
   internal _mintVirtual
   internal _burnVirtual

```

### <a name="NC-7"></a>[NC-7] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (19)*:
```solidity
File: HypoVault.sol

206:     function setManager(address _manager) external onlyOwner {

213:     function setAccountant(IVaultAccountant _accountant) external onlyOwner {

220:     function setFeeWallet(address _feeWallet) external onlyOwner {

230:     function requestDeposit(uint128 assets) external {

244:     function requestWithdrawal(uint128 shares) external {

273:     function cancelDeposit(address depositor) external onlyManager {

290:     function cancelWithdrawal(address withdrawer) external onlyManager {

310:     function executeDeposit(address user, uint256 epoch) external {

348:     function executeWithdrawal(address user, uint256 epoch) external {

406:     function transfer(address to, uint256 amount) public override returns (bool success) {

429:     function _transferBasis(address from, address to, uint256 amount) internal {

565:     function _mintVirtual(address to, uint256 amount) internal {

578:     function _burnVirtual(address from, uint256 amount) internal {

```

```solidity
File: accountants/PanopticVaultAccountant.sol

77:     function updatePoolsHash(address vault, bytes32 poolsHash) external onlyOwner {

85:     function lockVault(address vault) external onlyOwner {

```

```solidity
File: libraries/AccountingMath.sol

20:     function convert0to1(uint256 amount, uint160 sqrtPriceX96) internal pure returns (uint256) {

57:     function convert1to0(uint256 amount, uint160 sqrtPriceX96) internal pure returns (uint256) {

99:     function convert0to1(int256 amount, uint160 sqrtPriceX96) internal pure returns (int256) {

122:     function convert1to0(int256 amount, uint160 sqrtPriceX96) internal pure returns (int256) {

```

### <a name="NC-8"></a>[NC-8] Lack of checks in setters
Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (3)*:
```solidity
File: HypoVault.sol

206:     function setManager(address _manager) external onlyOwner {
             manager = _manager;

213:     function setAccountant(IVaultAccountant _accountant) external onlyOwner {
             accountant = _accountant;

220:     function setFeeWallet(address _feeWallet) external onlyOwner {
             feeWallet = _feeWallet;

```

### <a name="NC-9"></a>[NC-9] Missing Event for critical parameters change
Events help non-contract tools to track changes, and events prevent users from being surprised by changes.

*Instances (4)*:
```solidity
File: HypoVault.sol

206:     function setManager(address _manager) external onlyOwner {
             manager = _manager;

213:     function setAccountant(IVaultAccountant _accountant) external onlyOwner {
             accountant = _accountant;

220:     function setFeeWallet(address _feeWallet) external onlyOwner {
             feeWallet = _feeWallet;

```

```solidity
File: accountants/PanopticVaultAccountant.sol

77:     function updatePoolsHash(address vault, bytes32 poolsHash) external onlyOwner {
            if (vaultLocked[vault]) revert VaultLocked();
            vaultPools[vault] = poolsHash;

```

### <a name="NC-10"></a>[NC-10] Incomplete NatSpec: `@param` is missing on actually documented functions
The following functions are missing `@param` NatSpec comments.

*Instances (2)*:
```solidity
File: HypoVault.sol

444:     /// @notice Makes an arbitrary function call from this contract.
         /// @dev Can only be called by the manager.
         function manage(
             address target,
             bytes calldata data,
             uint256 value

454:     /// @notice Makes arbitrary function calls from this contract.
         /// @dev Can only be called by the manager.
         function manage(
             address[] calldata targets,
             bytes[] calldata data,
             uint256[] calldata values

```

### <a name="NC-11"></a>[NC-11] Incomplete NatSpec: `@return` is missing on actually documented functions
The following functions are missing `@return` NatSpec comments.

*Instances (2)*:
```solidity
File: HypoVault.sol

444:     /// @notice Makes an arbitrary function call from this contract.
         /// @dev Can only be called by the manager.
         function manage(
             address target,
             bytes calldata data,
             uint256 value
         ) external onlyManager returns (bytes memory result) {

454:     /// @notice Makes arbitrary function calls from this contract.
         /// @dev Can only be called by the manager.
         function manage(
             address[] calldata targets,
             bytes[] calldata data,
             uint256[] calldata values
         ) external onlyManager returns (bytes[] memory results) {

```

### <a name="NC-12"></a>[NC-12] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (1)*:
```solidity
File: HypoVault.sol

199:         if (msg.sender != manager) revert NotManager();

```

### <a name="NC-13"></a>[NC-13] `address`s shouldn't be hard-coded
It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (2)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

178:                 pools[i].token0 = IERC20Partial(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

199:                     address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)

```

### <a name="NC-14"></a>[NC-14] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (2)*:
```solidity
File: HypoVault.sol

402:     /// @notice Override transfer to handle basis transfer.
         /// @param to The recipient of the shares
         /// @param amount The amount of shares to transfer
         /// @return success True if the transfer was successful
         function transfer(address to, uint256 amount) public override returns (bool success) {
             _transferBasis(msg.sender, to, amount);
             return super.transfer(to, amount);

411:     /// @notice Override transferFrom to handle basis transfer.
         /// @param from The sender of the shares
         /// @param to The recipient of the shares
         /// @param amount The amount of shares to transfer
         /// @return success True if the transfer was successful
         function transferFrom(
             address from,
             address to,
             uint256 amount
         ) public override returns (bool success) {
             _transferBasis(from, to, amount);
             return super.transferFrom(from, to, amount);

```

### <a name="NC-15"></a>[NC-15] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (11)*:
```solidity
File: HypoVault.sol

199:         if (msg.sender != manager) revert NotManager();

311:         if (epoch >= depositEpoch) revert EpochNotFulfilled();

349:         if (epoch >= withdrawalEpoch) revert EpochNotFulfilled();

535:         if (assetsReceived > maxAssetsReceived) revert WithdrawalNotFulfillable();

```

```solidity
File: accountants/PanopticVaultAccountant.sol

78:         if (vaultLocked[vault]) revert VaultLocked();

105:         if (keccak256(abi.encode(pools)) != vaultPools[vault]) revert InvalidPools();

118:             ) revert StaleOraclePrice();

141:                 if (positionBalanceArray[j][1] == 0) revert IncorrectPositionList();

175:             if (numLegs != pools[i].pool.numberOfLegs(_vault)) revert IncorrectPositionList();

223:                 ) revert StaleOraclePrice();

240:                 ) revert StaleOraclePrice();

```

### <a name="NC-16"></a>[NC-16] Contract does not follow the Solidity style guide's suggested layout ordering
The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (2)*:
```solidity
File: HypoVault.sol

1: 
   Current order:
   UsingForDirective.Math
   UsingForDirective.Address
   StructDefinition.PendingWithdrawal
   StructDefinition.DepositEpochState
   StructDefinition.WithdrawalEpochState
   EventDefinition.DepositRequested
   EventDefinition.WithdrawalRequested
   EventDefinition.DepositCancelled
   EventDefinition.WithdrawalCancelled
   EventDefinition.DepositExecuted
   EventDefinition.WithdrawalExecuted
   EventDefinition.DepositsFulfilled
   EventDefinition.WithdrawalsFulfilled
   ErrorDefinition.NotManager
   ErrorDefinition.EpochNotFulfilled
   ErrorDefinition.WithdrawalNotFulfillable
   VariableDeclaration.underlyingToken
   VariableDeclaration.performanceFeeBps
   VariableDeclaration.feeWallet
   VariableDeclaration.manager
   VariableDeclaration.accountant
   VariableDeclaration.withdrawalEpoch
   VariableDeclaration.depositEpoch
   VariableDeclaration.reservedWithdrawalAssets
   VariableDeclaration.depositEpochState
   VariableDeclaration.withdrawalEpochState
   VariableDeclaration.queuedDeposit
   VariableDeclaration.queuedWithdrawal
   VariableDeclaration.userBasis
   FunctionDefinition.constructor
   ModifierDefinition.onlyManager
   FunctionDefinition.setManager
   FunctionDefinition.setAccountant
   FunctionDefinition.setFeeWallet
   FunctionDefinition.requestDeposit
   FunctionDefinition.requestWithdrawal
   FunctionDefinition.cancelDeposit
   FunctionDefinition.cancelWithdrawal
   FunctionDefinition.executeDeposit
   FunctionDefinition.executeWithdrawal
   FunctionDefinition.transfer
   FunctionDefinition.transferFrom
   FunctionDefinition._transferBasis
   FunctionDefinition.manage
   FunctionDefinition.manage
   FunctionDefinition.fulfillDeposits
   FunctionDefinition.fulfillWithdrawals
   FunctionDefinition._mintVirtual
   FunctionDefinition._burnVirtual
   
   Suggested order:
   UsingForDirective.Math
   UsingForDirective.Address
   VariableDeclaration.underlyingToken
   VariableDeclaration.performanceFeeBps
   VariableDeclaration.feeWallet
   VariableDeclaration.manager
   VariableDeclaration.accountant
   VariableDeclaration.withdrawalEpoch
   VariableDeclaration.depositEpoch
   VariableDeclaration.reservedWithdrawalAssets
   VariableDeclaration.depositEpochState
   VariableDeclaration.withdrawalEpochState
   VariableDeclaration.queuedDeposit
   VariableDeclaration.queuedWithdrawal
   VariableDeclaration.userBasis
   StructDefinition.PendingWithdrawal
   StructDefinition.DepositEpochState
   StructDefinition.WithdrawalEpochState
   ErrorDefinition.NotManager
   ErrorDefinition.EpochNotFulfilled
   ErrorDefinition.WithdrawalNotFulfillable
   EventDefinition.DepositRequested
   EventDefinition.WithdrawalRequested
   EventDefinition.DepositCancelled
   EventDefinition.WithdrawalCancelled
   EventDefinition.DepositExecuted
   EventDefinition.WithdrawalExecuted
   EventDefinition.DepositsFulfilled
   EventDefinition.WithdrawalsFulfilled
   ModifierDefinition.onlyManager
   FunctionDefinition.constructor
   FunctionDefinition.setManager
   FunctionDefinition.setAccountant
   FunctionDefinition.setFeeWallet
   FunctionDefinition.requestDeposit
   FunctionDefinition.requestWithdrawal
   FunctionDefinition.cancelDeposit
   FunctionDefinition.cancelWithdrawal
   FunctionDefinition.executeDeposit
   FunctionDefinition.executeWithdrawal
   FunctionDefinition.transfer
   FunctionDefinition.transferFrom
   FunctionDefinition._transferBasis
   FunctionDefinition.manage
   FunctionDefinition.manage
   FunctionDefinition.fulfillDeposits
   FunctionDefinition.fulfillWithdrawals
   FunctionDefinition._mintVirtual
   FunctionDefinition._burnVirtual

```

```solidity
File: accountants/PanopticVaultAccountant.sol

1: 
   Current order:
   StructDefinition.PoolInfo
   StructDefinition.ManagerPrices
   ErrorDefinition.InvalidPools
   ErrorDefinition.IncorrectPositionList
   ErrorDefinition.StaleOraclePrice
   ErrorDefinition.VaultLocked
   VariableDeclaration.vaultPools
   VariableDeclaration.vaultLocked
   FunctionDefinition.updatePoolsHash
   FunctionDefinition.lockVault
   FunctionDefinition.computeNAV
   
   Suggested order:
   VariableDeclaration.vaultPools
   VariableDeclaration.vaultLocked
   StructDefinition.PoolInfo
   StructDefinition.ManagerPrices
   ErrorDefinition.InvalidPools
   ErrorDefinition.IncorrectPositionList
   ErrorDefinition.StaleOraclePrice
   ErrorDefinition.VaultLocked
   FunctionDefinition.updatePoolsHash
   FunctionDefinition.lockVault
   FunctionDefinition.computeNAV

```

### <a name="NC-17"></a>[NC-17] Internal and private variables and functions names should begin with an underscore
According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (8)*:
```solidity
File: libraries/AccountingMath.sol

20:     function convert0to1(uint256 amount, uint160 sqrtPriceX96) internal pure returns (uint256) {

37:     function convert0to1RoundingUp(

57:     function convert1to0(uint256 amount, uint160 sqrtPriceX96) internal pure returns (uint256) {

74:     function convert1to0RoundingUp(

99:     function convert0to1(int256 amount, uint160 sqrtPriceX96) internal pure returns (int256) {

122:     function convert1to0(int256 amount, uint160 sqrtPriceX96) internal pure returns (int256) {

161:         uint256 legIndex,

209:         uint32 twapWindow

```

### <a name="NC-18"></a>[NC-18] Event is missing `indexed` fields
Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (8)*:
```solidity
File: HypoVault.sol

60:     event DepositRequested(address indexed user, uint256 assets);

65:     event WithdrawalRequested(address indexed user, uint256 shares);

70:     event DepositCancelled(address indexed user, uint256 assets);

75:     event WithdrawalCancelled(address indexed user, uint256 shares);

82:     event DepositExecuted(address indexed user, uint256 assets, uint256 shares, uint256 epoch);

90:     event WithdrawalExecuted(

102:     event DepositsFulfilled(

112:     event WithdrawalsFulfilled(

```

### <a name="NC-19"></a>[NC-19] Constants should be defined rather than using magic numbers

*Instances (2)*:
```solidity
File: libraries/AccountingMath.sol

211:         uint32[] memory secondsAgos = new uint32[](20);

213:         int256[] memory twapMeasurement = new int256[](19);

```

### <a name="NC-20"></a>[NC-20] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (7)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

112:         for (uint256 i = 0; i < pools.length; i++) {

140:             for (uint256 j = 0; j < tokenIds[i].length; j++) {

143:                 for (uint256 k = 0; k < positionLegs; k++) {

184:             for (uint256 j = 0; j < underlyingTokens.length; j++) {

255:         for (uint256 i = 0; i < underlyingTokens.length; i++) {

```

```solidity
File: libraries/AccountingMath.sol

217:             for (uint256 i = 0; i < 20; ++i) {

225:             for (uint256 i = 0; i < 19; ++i) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Use a 2-step ownership transfer pattern | 2 |
| [L-2](#L-2) | Missing checks for `address(0)` when assigning values to address state variables | 4 |
| [L-3](#L-3) | Division by zero not prevented | 5 |
| [L-4](#L-4) | Duplicate import statements | 2 |
| [L-5](#L-5) | External calls in an un-bounded `for-`loop may result in a DOS | 5 |
| [L-6](#L-6) | Prevent accidentally burning tokens | 3 |
| [L-7](#L-7) | Possible rounding issue | 2 |
| [L-8](#L-8) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 3 |
| [L-9](#L-9) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-10](#L-10) | Consider using OpenZeppelin's SafeCast library to prevent unexpected overflows when downcasting | 15 |
| [L-11](#L-11) | Unsafe ERC20 operation(s) | 2 |
### <a name="L-1"></a>[L-1] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: HypoVault.sol

18: contract HypoVault is ERC20Minimal, Multicall, Ownable {

```

```solidity
File: accountants/PanopticVaultAccountant.sol

20: contract PanopticVaultAccountant is Ownable {

```

### <a name="L-2"></a>[L-2] Missing checks for `address(0)` when assigning values to address state variables

*Instances (4)*:
```solidity
File: HypoVault.sol

186:         underlyingToken = _underlyingToken;

187:         manager = _manager;

207:         manager = _manager;

221:         feeWallet = _feeWallet;

```

### <a name="L-3"></a>[L-3] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (5)*:
```solidity
File: HypoVault.sol

253:         uint256 withdrawalBasis = (previousBasis * shares) / userBalance;

357:             _withdrawalEpochState.sharesFulfilled) / _withdrawalEpochState.sharesWithdrawn;

368:             _withdrawalEpochState.sharesFulfilled) / _withdrawalEpochState.sharesWithdrawn;

434:         uint256 basisToTransfer = (fromBasis * amount) / fromBalance;

```

```solidity
File: libraries/AccountingMath.sol

227:                     (tickCumulatives[i] - tickCumulatives[i + 1]) / int56(uint56(twapWindow / 20))

```

### <a name="L-4"></a>[L-4] Duplicate import statements

*Instances (2)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

13: import {LeftRightUnsigned} from "lib/panoptic-v1.1/contracts/types/LeftRight.sol";

14: import {LeftRightSigned} from "lib/panoptic-v1.1/contracts/types/LeftRight.sol";

```

### <a name="L-5"></a>[L-5] External calls in an un-bounded `for-`loop may result in a DOS
Consider limiting the number of iterations in for-loops that make external calls

*Instances (5)*:
```solidity
File: HypoVault.sol

464:             results[i] = targets[i].functionCallWithValue(data[i], values[i]);

```

```solidity
File: accountants/PanopticVaultAccountant.sol

142:                 uint256 positionLegs = tokenIds[i][j].countLegs();

142:                 uint256 positionLegs = tokenIds[i][j].countLegs();

153:                     if (tokenIds[i][j].isLong(k) == 0) {

153:                     if (tokenIds[i][j].isLong(k) == 0) {

```

### <a name="L-6"></a>[L-6] Prevent accidentally burning tokens
Minting and burning tokens to address(0) prevention

*Instances (3)*:
```solidity
File: HypoVault.sol

264:         _burnVirtual(msg.sender, shares);

302:         _mintVirtual(withdrawer, currentPendingWithdrawal.amount);

331:         _mintVirtual(user, sharesReceived);

```

### <a name="L-7"></a>[L-7] Possible rounding issue
Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator. Also, there is indication of multiplication and division without the use of parenthesis which could result in issues.

*Instances (2)*:
```solidity
File: HypoVault.sol

253:         uint256 withdrawalBasis = (previousBasis * shares) / userBalance;

434:         uint256 basisToTransfer = (fromBasis * amount) / fromBalance;

```

### <a name="L-8"></a>[L-8] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`
The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (3)*:
```solidity
File: HypoVault.sol

2: pragma solidity ^0.8.28;

```

```solidity
File: accountants/PanopticVaultAccountant.sol

2: pragma solidity ^0.8.28;

```

```solidity
File: libraries/AccountingMath.sol

2: pragma solidity ^0.8.28;

```

### <a name="L-9"></a>[L-9] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
Use [Ownable2Step.transferOwnership](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol) which is safer. Use it as it is more secure due to 2-stage ownership transfer.

**Recommended Mitigation Steps**

Use <a href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol">Ownable2Step.sol</a>
  
  ```solidity
      function acceptOwnership() external {
          address sender = _msgSender();
          require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
          _transferOwnership(sender);
      }
```

*Instances (2)*:
```solidity
File: HypoVault.sol

10: import {Ownable} from "lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/access/Ownable.sol";

```

```solidity
File: accountants/PanopticVaultAccountant.sol

4: import {Ownable} from "lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/access/Ownable.sol";

```

### <a name="L-10"></a>[L-10] Consider using OpenZeppelin's SafeCast library to prevent unexpected overflows when downcasting
Downcasting from `uint256`/`int256` in Solidity does not revert on overflow. This can result in undesired exploitation or bugs, since developers usually assume that overflows raise errors. [OpenZeppelin's SafeCast library](https://docs.openzeppelin.com/contracts/3.x/api/utils#SafeCast) restores this intuition by reverting the transaction when such an operation overflows. Using this library eliminates an entire class of bugs, so it's recommended to use it always. Some exceptions are acceptable like with the classic `uint256(uint160(address(variable)))`

*Instances (15)*:
```solidity
File: HypoVault.sol

259:             basis: uint128(pendingWithdrawal.basis + withdrawalBasis)

279:         depositEpochState[currentEpoch].assetsDeposited -= uint128(queuedDepositAmount);

340:         if (assetsRemaining > 0) queuedDeposit[user][epoch + 1] += uint128(assetsRemaining);

383:                 amount: uint128(nextQueuedWithdrawal.amount + sharesRemaining),

384:                 basis: uint128(nextQueuedWithdrawal.basis + basisRemaining)

493:             sharesReceived: uint128(sharesReceived),

494:             assetsFulfilled: uint128(assetsToFulfill)

498:         depositEpoch = uint128(currentEpoch);

501:             assetsDeposited: uint128(assetsRemaining),

540:             assetsReceived: uint128(assetsReceived),

542:             sharesFulfilled: uint128(sharesToFulfill)

547:         withdrawalEpoch = uint128(currentEpoch);

551:             sharesWithdrawn: uint128(sharesRemaining),

```

```solidity
File: accountants/PanopticVaultAccountant.sol

149:                             uint128(positionBalanceArray[j][1])

167:                     .computeExercisedAmounts(tokenIds[i][j], uint128(positionBalanceArray[j][1]));

```

### <a name="L-11"></a>[L-11] Unsafe ERC20 operation(s)

*Instances (2)*:
```solidity
File: HypoVault.sol

408:         return super.transfer(to, amount);

422:         return super.transferFrom(from, to, amount);

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Centralization Risk for trusted owners | 7 |
| [M-2](#M-2) | Fees can be set to be greater than 100%. | 1 |
| [M-3](#M-3) | Lack of EIP-712 compliance: using `keccak256()` directly on an array or struct variable | 1 |
### <a name="M-1"></a>[M-1] Centralization Risk for trusted owners

#### Impact:
Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (7)*:
```solidity
File: HypoVault.sol

18: contract HypoVault is ERC20Minimal, Multicall, Ownable {

206:     function setManager(address _manager) external onlyOwner {

213:     function setAccountant(IVaultAccountant _accountant) external onlyOwner {

220:     function setFeeWallet(address _feeWallet) external onlyOwner {

```

```solidity
File: accountants/PanopticVaultAccountant.sol

20: contract PanopticVaultAccountant is Ownable {

77:     function updatePoolsHash(address vault, bytes32 poolsHash) external onlyOwner {

85:     function lockVault(address vault) external onlyOwner {

```

### <a name="M-2"></a>[M-2] Fees can be set to be greater than 100%.
There should be an upper limit to reasonable fees.
A malicious owner can keep the fee rate at zero, but if a large value transfer enters the mempool, the owner can jack the rate up to the maximum and sandwich attack a user.

*Instances (1)*:
```solidity
File: HypoVault.sol

220:     function setFeeWallet(address _feeWallet) external onlyOwner {
             feeWallet = _feeWallet;

```

### <a name="M-3"></a>[M-3] Lack of EIP-712 compliance: using `keccak256()` directly on an array or struct variable
Directly using the actual variable instead of encoding the array values goes against the EIP-712 specification https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#definition-of-encodedata. 
**Note**: OpenSea's [Seaport's example with offerHashes and considerationHashes](https://github.com/ProjectOpenSea/seaport/blob/a62c2f8f484784735025d7b03ccb37865bc39e5a/reference/lib/ReferenceGettersAndDerivers.sol#L130-L131) can be used as a reference to understand how array of structs should be encoded.

*Instances (1)*:
```solidity
File: accountants/PanopticVaultAccountant.sol

105:         if (keccak256(abi.encode(pools)) != vaultPools[vault]) revert InvalidPools();

```

