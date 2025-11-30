# Report

- [Report](#report)
  - [Gas Optimizations](#gas-optimizations)
    - [\[GAS-1\] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)](#gas-1-a--a--b-is-more-gas-effective-than-a--b-for-state-variables-excluding-arrays-and-mappings)
    - [\[GAS-2\] Use assembly to check for `address(0)`](#gas-2-use-assembly-to-check-for-address0)
    - [\[GAS-3\] Using bools for storage incurs overhead](#gas-3-using-bools-for-storage-incurs-overhead)
    - [\[GAS-4\] Cache array length outside of loop](#gas-4-cache-array-length-outside-of-loop)
    - [\[GAS-5\] State variables should be cached in stack variables rather than re-reading them from storage](#gas-5-state-variables-should-be-cached-in-stack-variables-rather-than-re-reading-them-from-storage)
    - [\[GAS-6\] Use calldata instead of memory for function arguments that do not get mutated](#gas-6-use-calldata-instead-of-memory-for-function-arguments-that-do-not-get-mutated)
    - [\[GAS-7\] For Operations that will not overflow, you could use unchecked](#gas-7-for-operations-that-will-not-overflow-you-could-use-unchecked)
    - [\[GAS-8\] Avoid contract existence checks by using low level calls](#gas-8-avoid-contract-existence-checks-by-using-low-level-calls)
    - [\[GAS-9\] Stack variable used as a cheaper cache for a state variable is only used once](#gas-9-stack-variable-used-as-a-cheaper-cache-for-a-state-variable-is-only-used-once)
    - [\[GAS-10\] State variables only set in the constructor should be declared `immutable`](#gas-10-state-variables-only-set-in-the-constructor-should-be-declared-immutable)
    - [\[GAS-11\] Functions guaranteed to revert when called by normal users can be marked `payable`](#gas-11-functions-guaranteed-to-revert-when-called-by-normal-users-can-be-marked-payable)
    - [\[GAS-12\] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)](#gas-12-i-costs-less-gas-compared-to-i-or-i--1-same-for---i-vs-i---or-i---1)
    - [\[GAS-13\] Using `private` rather than `public` for constants, saves gas](#gas-13-using-private-rather-than-public-for-constants-saves-gas)
    - [\[GAS-14\] `uint256` to `bool` `mapping`: Utilizing Bitmaps to dramatically save on Gas](#gas-14-uint256-to-bool-mapping-utilizing-bitmaps-to-dramatically-save-on-gas)
    - [\[GAS-15\] Increments/decrements can be unchecked in for-loops](#gas-15-incrementsdecrements-can-be-unchecked-in-for-loops)
    - [\[GAS-16\] Use != 0 instead of \> 0 for unsigned integer comparison](#gas-16-use--0-instead-of--0-for-unsigned-integer-comparison)
  - [Non Critical Issues](#non-critical-issues)
    - [\[NC-1\] Missing checks for `address(0)` when assigning values to address state variables](#nc-1-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
    - [\[NC-2\] Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked`](#nc-2-use-stringconcat-or-bytesconcat-instead-of-abiencodepacked)
    - [\[NC-3\] `constant`s should be defined rather than using magic numbers](#nc-3-constants-should-be-defined-rather-than-using-magic-numbers)
    - [\[NC-4\] Control structures do not follow the Solidity Style Guide](#nc-4-control-structures-do-not-follow-the-solidity-style-guide)
    - [\[NC-5\] Event missing indexed field](#nc-5-event-missing-indexed-field)
    - [\[NC-6\] Events that mark critical parameter changes should contain both the old and the new value](#nc-6-events-that-mark-critical-parameter-changes-should-contain-both-the-old-and-the-new-value)
    - [\[NC-7\] Function ordering does not follow the Solidity style guide](#nc-7-function-ordering-does-not-follow-the-solidity-style-guide)
    - [\[NC-8\] Functions should not be longer than 50 lines](#nc-8-functions-should-not-be-longer-than-50-lines)
    - [\[NC-9\] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor](#nc-9-use-a-modifier-instead-of-a-requireif-statement-for-a-special-msgsender-actor)
    - [\[NC-10\] Constant state variables defined more than once](#nc-10-constant-state-variables-defined-more-than-once)
    - [\[NC-11\] Consider using named mappings](#nc-11-consider-using-named-mappings)
    - [\[NC-12\] `address`s shouldn't be hard-coded](#nc-12-addresss-shouldnt-be-hard-coded)
    - [\[NC-13\] Adding a `return` statement when the function defines a named return variable, is redundant](#nc-13-adding-a-return-statement-when-the-function-defines-a-named-return-variable-is-redundant)
    - [\[NC-14\] Take advantage of Custom Error's return value property](#nc-14-take-advantage-of-custom-errors-return-value-property)
    - [\[NC-15\] Contract does not follow the Solidity style guide's suggested layout ordering](#nc-15-contract-does-not-follow-the-solidity-style-guides-suggested-layout-ordering)
    - [\[NC-16\] Use Underscores for Number Literals (add an underscore every 3 digits)](#nc-16-use-underscores-for-number-literals-add-an-underscore-every-3-digits)
    - [\[NC-17\] Event is missing `indexed` fields](#nc-17-event-is-missing-indexed-fields)
    - [\[NC-18\] Constants should be defined rather than using magic numbers](#nc-18-constants-should-be-defined-rather-than-using-magic-numbers)
    - [\[NC-19\] Variables need not be initialized to zero](#nc-19-variables-need-not-be-initialized-to-zero)
  - [Low Issues](#low-issues)
    - [\[L-1\] Some tokens may revert when zero value transfers are made](#l-1-some-tokens-may-revert-when-zero-value-transfers-are-made)
    - [\[L-2\] Missing checks for `address(0)` when assigning values to address state variables](#l-2-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
    - [\[L-3\] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`](#l-3-abiencodepacked-should-not-be-used-with-dynamic-types-when-passing-the-result-to-a-hash-function-such-as-keccak256)
    - [\[L-4\] `decimals()` is not a part of the ERC-20 standard](#l-4-decimals-is-not-a-part-of-the-erc-20-standard)
    - [\[L-5\] Division by zero not prevented](#l-5-division-by-zero-not-prevented)
    - [\[L-6\] Empty `receive()/payable fallback()` function does not authenticate requests](#l-6-empty-receivepayable-fallback-function-does-not-authenticate-requests)
    - [\[L-7\] External call recipient may consume all transaction gas](#l-7-external-call-recipient-may-consume-all-transaction-gas)
    - [\[L-8\] Signature use at deadlines should be allowed](#l-8-signature-use-at-deadlines-should-be-allowed)
    - [\[L-9\] Loss of precision](#l-9-loss-of-precision)
    - [\[L-10\] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`](#l-10-solidity-version-0820-may-not-work-on-other-chains-due-to-push0)
    - [\[L-11\] Sweeping may break accounting if tokens with multiple addresses are used](#l-11-sweeping-may-break-accounting-if-tokens-with-multiple-addresses-are-used)
  - [Medium Issues](#medium-issues)
    - [\[M-1\] Contracts are vulnerable to fee-on-transfer accounting-related issues](#m-1-contracts-are-vulnerable-to-fee-on-transfer-accounting-related-issues)
    - [\[M-2\] `block.number` means different things on different L2s](#m-2-blocknumber-means-different-things-on-different-l2s)
    - [\[M-3\] Centralization Risk for trusted owners](#m-3-centralization-risk-for-trusted-owners)
      - [Impact](#impact)

## Gas Optimizations

| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 6 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 15 |
| [GAS-3](#GAS-3) | Using bools for storage incurs overhead | 5 |
| [GAS-4](#GAS-4) | Cache array length outside of loop | 8 |
| [GAS-5](#GAS-5) | State variables should be cached in stack variables rather than re-reading them from storage | 3 |
| [GAS-6](#GAS-6) | Use calldata instead of memory for function arguments that do not get mutated | 2 |
| [GAS-7](#GAS-7) | For Operations that will not overflow, you could use unchecked | 52 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 4 |
| [GAS-9](#GAS-9) | Stack variable used as a cheaper cache for a state variable is only used once | 2 |
| [GAS-10](#GAS-10) | State variables only set in the constructor should be declared `immutable` | 11 |
| [GAS-11](#GAS-11) | Functions guaranteed to revert when called by normal users can be marked `payable` | 10 |
| [GAS-12](#GAS-12) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 9 |
| [GAS-13](#GAS-13) | Using `private` rather than `public` for constants, saves gas | 9 |
| [GAS-14](#GAS-14) | `uint256` to `bool` `mapping`: Utilizing Bitmaps to dramatically save on Gas | 1 |
| [GAS-15](#GAS-15) | Increments/decrements can be unchecked in for-loops | 8 |
| [GAS-16](#GAS-16) | Use != 0 instead of > 0 for unsigned integer comparison | 4 |

### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)

This saves **16 gas per instance.**

*Instances (6)*:

```solidity
File: src/campaign/NudgeCampaign.sol

208:         totalReallocatedAmount += amountReceived;

218:         pendingRewards += userRewards;

219:         accumulatedFees += fees;

289:             distributedRewards += userRewards;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

266:             totalAmount += NudgeCampaign(payable(campaigns[i])).collectFees();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

162:         campaign.totalReallocatedAmount += amountReceived;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`

*Saves 6 gas per instance*

*Instances (15)*:

```solidity
File: src/campaign/NudgeCampaign.sol

80:         if (rewardToken_ == address(0) || campaignAdmin == address(0)) {

331:         address to = alternativeWithdrawalAddress == address(0) ? msg.sender : alternativeWithdrawalAddress;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

38:         if (treasury_ == address(0)) revert InvalidTreasuryAddress();

39:         if (admin_ == address(0)) revert ZeroAddress();

40:         if (operator_ == address(0)) revert ZeroAddress();

41:         if (swapCaller_ == address(0)) revert ZeroAddress();

78:         if (campaignAdmin == address(0)) revert ZeroAddress();

79:         if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();

144:         if (campaignAdmin == address(0)) revert ZeroAddress();

145:         if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();

239:         if (newTreasury == address(0)) revert InvalidTreasuryAddress();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

55:         if (targetToken == address(0)) {

59:         if (campaigns[campaignId].targetToken != address(0)) {

95:             if (targetTokens[i] == address(0)) {

99:             if (campaigns[campaignIds[i]].targetToken != address(0)) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-3"></a>[GAS-3] Using bools for storage incurs overhead

Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (5)*:

```solidity
File: src/campaign/NudgeCampaign.sol

38:     bool public isCampaignActive;

53:     bool private _manuallyDeactivated;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

27:     mapping(address => bool) public isCampaign;

29:     mapping(address => bool) public isCampaignPaused;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

23:     mapping(uint256 => bool) public isCampaignPaused;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-4"></a>[GAS-4] Cache array length outside of loop

If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (8)*:

```solidity
File: src/campaign/NudgeCampaign.sol

263:         for (uint256 i = 0; i < pIDs.length; i++) {

309:         for (uint256 i = 0; i < pIDs.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

264:         for (uint256 i = 0; i < campaigns.length; i++) {

276:         for (uint256 i = 0; i < campaigns.length; i++) {

290:         for (uint256 i = 0; i < campaigns.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

94:         for (uint256 i = 0; i < campaignIds.length; i++) {

188:         for (uint256 i = 0; i < campaignIds.length; i++) {

201:         for (uint256 i = 0; i < campaignIds.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-5"></a>[GAS-5] State variables should be cached in stack variables rather than re-reading them from storage

The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (3)*:

```solidity
File: src/campaign/NudgeCampaign.sol

151:         uint256 rewardAmountIn18Decimals = scaledAmount.mulDiv(rewardPPQ, PPQ_DENOMINATOR);

295:             _transfer(rewardToken, participation.userAddress, userRewards);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

105:             FEE_BPS,

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="GAS-6"></a>[GAS-6] Use calldata instead of memory for function arguments that do not get mutated

When a function with a `memory` array is called externally, the `abi.decode()` step has to use a for-loop to copy each index of the `calldata` to the `memory` index. Each iteration of this for-loop costs at least 60 gas (i.e. `60 * <mem_array>.length`). Using `calldata` directly bypasses this loop.

If the array is passed to an `internal` function which passes the array to another internal function where the array is modified and therefore `memory` is used in the `external` call, it's still more gas-efficient to use `calldata` when the `external` function uses modifiers, since the modifiers may prevent the internal functions from being called. Structs have the same overhead as an array of length one.

 *Saves 60 gas per instance*

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

169:         bytes memory data

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/IBaseNudgeCampaign.sol

47:         bytes memory data

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/IBaseNudgeCampaign.sol)

### <a name="GAS-7"></a>[GAS-7] For Operations that will not overflow, you could use unchecked

*Instances (52)*:

```solidity
File: src/campaign/NudgeCampaign.sol

4: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import "@openzeppelin/contracts/access/AccessControl.sol";

7: import "@openzeppelin/contracts/utils/math/Math.sol";

8: import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

9: import {INudgeCampaign} from "./interfaces/INudgeCampaign.sol";

10: import "./interfaces/INudgeCampaignFactory.sol";

99:         targetScalingFactor = 10 ** (18 - targetDecimals);

100:         rewardScalingFactor = 10 ** (18 - rewardDecimals);

148:         uint256 scaledAmount = toAmount * targetScalingFactor;

154:         return rewardAmountIn18Decimals / rewardScalingFactor;

199:             amountReceived = getBalanceOfSelf(toToken) - balanceBefore;

208:         totalReallocatedAmount += amountReceived;

218:         pendingRewards += userRewards;

219:         accumulatedFees += fees;

221:         pID++;

263:         for (uint256 i = 0; i < pIDs.length; i++) {

277:             if (block.timestamp < participation.startTimestamp + holdingPeriodInSeconds) {

288:             pendingRewards -= userRewards;

289:             distributedRewards += userRewards;

293:             availableBalance -= userRewards;

309:         for (uint256 i = 0; i < pIDs.length; i++) {

317:             pendingRewards -= participation.rewardAmount;

414:         return getBalanceOfSelf(rewardToken) - pendingRewards - accumulatedFees;

424:         fees = (rewardAmountIncludingFees * feeBps) / BPS_DENOMINATOR;

425:         userRewards = rewardAmountIncludingFees - fees;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

4: import "@openzeppelin/contracts/access/AccessControl.sol";

5: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

6: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

7: import "@openzeppelin/contracts/utils/Create2.sol";

8: import "./NudgeCampaign.sol";

9: import "./interfaces/INudgeCampaignFactory.sol";

24:     uint16 public FEE_BPS = 1000; // 10% by default

264:         for (uint256 i = 0; i < campaigns.length; i++) {

266:             totalAmount += NudgeCampaign(payable(campaigns[i])).collectFees();

276:         for (uint256 i = 0; i < campaigns.length; i++) {

290:         for (uint256 i = 0; i < campaigns.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

4: import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

5: import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

6: import "@openzeppelin/contracts/access/AccessControl.sol";

7: import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

8: import {INudgePointsCampaign} from "./interfaces/INudgePointsCampaign.sol";

9: import "./interfaces/INudgeCampaignFactory.sol";

94:         for (uint256 i = 0; i < campaignIds.length; i++) {

153:             amountReceived = getBalanceOfSelf(toToken) - balanceBefore;

162:         campaign.totalReallocatedAmount += amountReceived;

164:         uint256 newpID = ++campaign.pID;

188:         for (uint256 i = 0; i < campaignIds.length; i++) {

201:         for (uint256 i = 0; i < campaignIds.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaign.sol

4: import "./IBaseNudgeCampaign.sol";

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaignFactory.sol

4: import "@openzeppelin/contracts/access/IAccessControl.sol";

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaignFactory.sol)

```solidity
File: src/campaign/interfaces/INudgePointsCampaign.sol

4: import "./IBaseNudgeCampaign.sol";

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgePointsCampaign.sol)

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls

Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (4)*:

```solidity
File: src/campaign/NudgeCampaign.sol

194:             uint256 balanceOfSender = tokenReceived.balanceOf(msg.sender);

407:             return IERC20(token).balanceOf(address(this));

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

148:             uint256 balanceOfSender = tokenReceived.balanceOf(msg.sender);

222:             return IERC20(token).balanceOf(address(this));

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-9"></a>[GAS-9] Stack variable used as a cheaper cache for a state variable is only used once

If the variable is only accessed once, it's cheaper to use the state variable directly that one time, and save the **3 gas** the extra stack assignment would spend

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaignFactory.sol

241:         address oldTreasury = nudgeTreasuryAddress;

253:         uint16 oldFeeBps = FEE_BPS;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="GAS-10"></a>[GAS-10] State variables only set in the constructor should be declared `immutable`

Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (11)*:

```solidity
File: src/campaign/NudgeCampaign.sol

88:         factory = INudgeCampaignFactory(msg.sender);

90:         targetToken = targetToken_;

91:         rewardToken = rewardToken_;

92:         campaignId = campaignId_;

99:         targetScalingFactor = 10 ** (18 - targetDecimals);

100:         rewardScalingFactor = 10 ** (18 - rewardDecimals);

104:         startTimestamp = startTimestamp_ == 0 ? block.timestamp : startTimestamp_;

110:         rewardPPQ = rewardPPQ_;

111:         holdingPeriodInSeconds = holdingPeriodInSeconds_;

112:         feeBps = feeBps_;

113:         alternativeWithdrawalAddress = alternativeWithdrawalAddress_;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="GAS-11"></a>[GAS-11] Functions guaranteed to revert when called by normal users can be marked `payable`

If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (10)*:

```solidity
File: src/campaign/NudgeCampaign.sol

308:     function invalidateParticipations(uint256[] calldata pIDs) external onlyNudgeOperator {

326:     function withdrawRewards(uint256 amount) external onlyRole(CAMPAIGN_ADMIN_ROLE) {

341:     function collectFees() external onlyFactoryOrNudgeAdmin returns (uint256 feesToCollect) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

238:     function updateTreasuryAddress(address newTreasury) external onlyRole(NUDGE_ADMIN_ROLE) {

250:     function updateFeeSetting(uint16 newFeeBps) external onlyRole(NUDGE_ADMIN_ROLE) {

261:     function collectFeesFromCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_OPERATOR_ROLE) {

275:     function pauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {

289:     function unpauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

187:     function pauseCampaigns(uint256[] calldata campaignIds) external onlyRole(NUDGE_ADMIN_ROLE) {

200:     function unpauseCampaigns(uint256[] calldata campaignIds) external onlyRole(NUDGE_ADMIN_ROLE) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-12"></a>[GAS-12] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)

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

*Instances (9)*:

```solidity
File: src/campaign/NudgeCampaign.sol

221:         pID++;

263:         for (uint256 i = 0; i < pIDs.length; i++) {

309:         for (uint256 i = 0; i < pIDs.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

264:         for (uint256 i = 0; i < campaigns.length; i++) {

276:         for (uint256 i = 0; i < campaigns.length; i++) {

290:         for (uint256 i = 0; i < campaigns.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

94:         for (uint256 i = 0; i < campaignIds.length; i++) {

188:         for (uint256 i = 0; i < campaignIds.length; i++) {

201:         for (uint256 i = 0; i < campaignIds.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-13"></a>[GAS-13] Using `private` rather than `public` for constants, saves gas

If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (9)*:

```solidity
File: src/campaign/NudgeCampaign.sol

19:     bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");

24:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

17:     bytes32 public constant NUDGE_ADMIN_ROLE = keccak256("NUDGE_ADMIN_ROLE");

18:     bytes32 public constant NUDGE_OPERATOR_ROLE = keccak256("NUDGE_OPERATOR_ROLE");

19:     bytes32 public constant SWAP_CALLER_ROLE = keccak256("SWAP_CALLER_ROLE");

21:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

17:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

18:     bytes32 public constant NUDGE_ADMIN_ROLE = keccak256("NUDGE_ADMIN_ROLE");

19:     bytes32 public constant SWAP_CALLER_ROLE = keccak256("SWAP_CALLER_ROLE");

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-14"></a>[GAS-14] `uint256` to `bool` `mapping`: Utilizing Bitmaps to dramatically save on Gas

<https://soliditydeveloper.com/bitmaps>

<https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/BitMaps.sol>

- [BitMaps.sol#L5-L16](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/structs/BitMaps.sol#L5-L16):

```solidity
/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, provided the keys are sequential.
 * Largely inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 *
 * BitMaps pack 256 booleans across each bit of a single 256-bit slot of `uint256` type.
 * Hence booleans corresponding to 256 _sequential_ indices would only consume a single slot,
 * unlike the regular `bool` which would consume an entire slot for a single value.
 *
 * This results in gas savings in two ways:
 *
 * - Setting a zero value to non-zero only once every 256 times
 * - Accessing the same warm slot for every 256 _sequential_ indices
 */
```

*Instances (1)*:

```solidity
File: src/campaign/NudgePointsCampaigns.sol

23:     mapping(uint256 => bool) public isCampaignPaused;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-15"></a>[GAS-15] Increments/decrements can be unchecked in for-loops

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
File: src/campaign/NudgeCampaign.sol

263:         for (uint256 i = 0; i < pIDs.length; i++) {

309:         for (uint256 i = 0; i < pIDs.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

264:         for (uint256 i = 0; i < campaigns.length; i++) {

276:         for (uint256 i = 0; i < campaigns.length; i++) {

290:         for (uint256 i = 0; i < campaigns.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

94:         for (uint256 i = 0; i < campaignIds.length; i++) {

188:         for (uint256 i = 0; i < campaignIds.length; i++) {

201:         for (uint256 i = 0; i < campaignIds.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="GAS-16"></a>[GAS-16] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (4)*:

```solidity
File: src/campaign/NudgeCampaign.sol

190:             if (msg.value > 0) {

388:         if (amount > 0) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

165:             if (msg.value > 0) revert IncorrectEtherAmount();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

143:             if (msg.value > 0) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

## Non Critical Issues

| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [NC-2](#NC-2) | Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked` | 2 |
| [NC-3](#NC-3) | `constant`s should be defined rather than using magic numbers | 6 |
| [NC-4](#NC-4) | Control structures do not follow the Solidity Style Guide | 27 |
| [NC-5](#NC-5) | Event missing indexed field | 13 |
| [NC-6](#NC-6) | Events that mark critical parameter changes should contain both the old and the new value | 3 |
| [NC-7](#NC-7) | Function ordering does not follow the Solidity style guide | 2 |
| [NC-8](#NC-8) | Functions should not be longer than 50 lines | 46 |
| [NC-9](#NC-9) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 6 |
| [NC-10](#NC-10) | Constant state variables defined more than once | 7 |
| [NC-11](#NC-11) | Consider using named mappings | 4 |
| [NC-12](#NC-12) | `address`s shouldn't be hard-coded | 3 |
| [NC-13](#NC-13) | Adding a `return` statement when the function defines a named return variable, is redundant | 2 |
| [NC-14](#NC-14) | Take advantage of Custom Error's return value property | 48 |
| [NC-15](#NC-15) | Contract does not follow the Solidity style guide's suggested layout ordering | 5 |
| [NC-16](#NC-16) | Use Underscores for Number Literals (add an underscore every 3 digits) | 1 |
| [NC-17](#NC-17) | Event is missing `indexed` fields | 15 |
| [NC-18](#NC-18) | Constants should be defined rather than using magic numbers | 2 |
| [NC-19](#NC-19) | Variables need not be initialized to zero | 8 |

### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:

```solidity
File: src/campaign/NudgeCampaign.sol

113:         alternativeWithdrawalAddress = alternativeWithdrawalAddress_;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="NC-2"></a>[NC-2] Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked`

Solidity version 0.8.4 introduces `bytes.concat()` (vs `abi.encodePacked(<bytes>,<bytes>)`)

Solidity version 0.8.12 introduces `string.concat()` (vs `abi.encodePacked(<str>,<str>), which catches concatenation errors (in the event of a`bytes`data mixed in the concatenation)`)

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaignFactory.sol

111:         bytes memory bytecode = abi.encodePacked(type(NudgeCampaign).creationCode, constructorArgs);

230:         bytes memory bytecode = abi.encodePacked(type(NudgeCampaign).creationCode, constructorArgs);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="NC-3"></a>[NC-3] `constant`s should be defined rather than using magic numbers

Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (6)*:

```solidity
File: src/campaign/NudgeCampaign.sol

95:         uint256 targetDecimals = targetToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(targetToken_).decimals();

96:         uint256 rewardDecimals = rewardToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(rewardToken_).decimals();

99:         targetScalingFactor = 10 ** (18 - targetDecimals);

100:         rewardScalingFactor = 10 ** (18 - rewardDecimals);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

24:     uint16 public FEE_BPS = 1000; // 10% by default

251:         if (newFeeBps > 10_000) revert InvalidFeeSetting();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="NC-4"></a>[NC-4] Control structures do not follow the Solidity Style Guide

See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (27)*:

```solidity
File: src/campaign/NudgeCampaign.sol

118:         if (factory.isCampaignPaused(address(this))) revert CampaignPaused();

172:         _validateAndActivateCampaignIfReady();

480:             if (!sent) revert NativeTokenTransferFailed();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

38:         if (treasury_ == address(0)) revert InvalidTreasuryAddress();

39:         if (admin_ == address(0)) revert ZeroAddress();

40:         if (operator_ == address(0)) revert ZeroAddress();

41:         if (swapCaller_ == address(0)) revert ZeroAddress();

78:         if (campaignAdmin == address(0)) revert ZeroAddress();

79:         if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();

80:         if (holdingPeriodInSeconds == 0) revert InvalidParameter();

144:         if (campaignAdmin == address(0)) revert ZeroAddress();

145:         if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();

146:         if (holdingPeriodInSeconds == 0) revert InvalidParameter();

149:             if (msg.value != initialRewardAmount) revert IncorrectEtherAmount();

163:             if (!sent) revert NativeTokenTransferFailed();

165:             if (msg.value > 0) revert IncorrectEtherAmount();

239:         if (newTreasury == address(0)) revert InvalidTreasuryAddress();

251:         if (newFeeBps > 10_000) revert InvalidFeeSetting();

265:             if (!isCampaign[campaigns[i]]) revert InvalidCampaign();

277:             if (!isCampaign[campaigns[i]]) revert InvalidCampaign();

278:             if (isCampaignPaused[campaigns[i]]) revert CampaignAlreadyPaused();

291:             if (!isCampaign[campaigns[i]]) revert InvalidCampaign();

292:             if (!isCampaignPaused[campaigns[i]]) revert CampaignNotPaused();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

40:         if (isCampaignPaused[campaignId]) revert CampaignPaused();

189:             if (isCampaignPaused[campaignIds[i]]) revert CampaignAlreadyPaused();

202:             if (!isCampaignPaused[campaignIds[i]]) revert CampaignNotPaused();

238:             if (!sent) revert NativeTokenTransferFailed();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="NC-5"></a>[NC-5] Event missing indexed field

Index event fields make the field more quickly accessible [to off-chain tools](https://ethereum.stackexchange.com/questions/40396/can-somebody-please-explain-the-concept-of-event-indexing) that parse events. This is especially useful when it comes to filtering based on an address. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Where applicable, each `event` should use three `indexed` fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three applicable fields, all of the applicable fields should be indexed.

*Instances (13)*:

```solidity
File: src/campaign/interfaces/INudgeCampaign.sol

22:     event ParticipationInvalidated(uint256[] pIDs);

23:     event RewardsWithdrawn(address to, uint256 amount);

24:     event FeesCollected(uint256 amount);

25:     event CampaignStatusChanged(bool isActive);

26:     event NudgeRewardClaimed(uint256 pID, address userAddress, uint256 rewardAmount);

27:     event TokensRescued(address token, uint256 amount);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaignFactory.sol

31:     event CampaignsPaused(address[] campaigns);

32:     event CampaignsUnpaused(address[] campaigns);

33:     event FeesCollected(address[] campaigns, uint256 totalAmount);

34:     event FeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaignFactory.sol)

```solidity
File: src/campaign/interfaces/INudgePointsCampaign.sol

14:     event PointsCampaignCreated(uint256 campaignId, uint32 holdingPeriodInSeconds, address targetToken);

15:     event CampaignsPaused(uint256[] campaigns);

16:     event CampaignsUnpaused(uint256[] campaigns);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgePointsCampaign.sol)

### <a name="NC-6"></a>[NC-6] Events that mark critical parameter changes should contain both the old and the new value

This should especially be done if the new value is not required to be different from the old value

*Instances (3)*:

```solidity
File: src/campaign/NudgeCampaign.sol

353:     function setIsCampaignActive(bool isActive) external {
             if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {
                 revert Unauthorized();
             }
     
             if (isActive && block.timestamp < startTimestamp) {
                 revert StartDateNotReached();
             }
     
             isCampaignActive = isActive;
             // If deactivating, mark as manually deactivated
             if (!isActive) {
                 _manuallyDeactivated = true;
             } else {
                 // If activating, clear the manual deactivation flag
                 _manuallyDeactivated = false;
             }
     
             emit CampaignStatusChanged(isActive);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

238:     function updateTreasuryAddress(address newTreasury) external onlyRole(NUDGE_ADMIN_ROLE) {
             if (newTreasury == address(0)) revert InvalidTreasuryAddress();
     
             address oldTreasury = nudgeTreasuryAddress;
             nudgeTreasuryAddress = newTreasury;
     
             emit TreasuryUpdated(oldTreasury, newTreasury);

250:     function updateFeeSetting(uint16 newFeeBps) external onlyRole(NUDGE_ADMIN_ROLE) {
             if (newFeeBps > 10_000) revert InvalidFeeSetting();
     
             uint16 oldFeeBps = FEE_BPS;
             FEE_BPS = newFeeBps;
             emit FeeUpdated(oldFeeBps, newFeeBps);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="NC-7"></a>[NC-7] Function ordering does not follow the Solidity style guide

According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

1: 
   Current order:
   public getRewardAmountIncludingFees
   external handleReallocation
   internal _validateAndActivateCampaignIfReady
   external claimRewards
   external invalidateParticipations
   external withdrawRewards
   external collectFees
   external setIsCampaignActive
   external rescueTokens
   public getBalanceOfSelf
   public claimableRewardAmount
   public calculateUserRewardsAndFees
   external getCampaignInfo
   internal _transfer
   
   Suggested order:
   external handleReallocation
   external claimRewards
   external invalidateParticipations
   external withdrawRewards
   external collectFees
   external setIsCampaignActive
   external rescueTokens
   external getCampaignInfo
   public getRewardAmountIncludingFees
   public getBalanceOfSelf
   public claimableRewardAmount
   public calculateUserRewardsAndFees
   internal _validateAndActivateCampaignIfReady
   internal _transfer

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

1: 
   Current order:
   external getCampaignCount
   public deployCampaign
   external deployAndFundCampaign
   external getCampaignAddress
   external updateTreasuryAddress
   external updateFeeSetting
   external collectFeesFromCampaigns
   external pauseCampaigns
   external unpauseCampaigns
   
   Suggested order:
   external getCampaignCount
   external deployAndFundCampaign
   external getCampaignAddress
   external updateTreasuryAddress
   external updateFeeSetting
   external collectFeesFromCampaigns
   external pauseCampaigns
   external unpauseCampaigns
   public deployCampaign

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="NC-8"></a>[NC-8] Functions should not be longer than 50 lines

Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability

*Instances (46)*:

```solidity
File: src/campaign/NudgeCampaign.sol

141:     function getRewardAmountIncludingFees(uint256 toAmount) public view returns (uint256) {

236:     function _validateAndActivateCampaignIfReady() internal {

256:     function claimRewards(uint256[] calldata pIDs) external whenNotPaused {

308:     function invalidateParticipations(uint256[] calldata pIDs) external onlyNudgeOperator {

326:     function withdrawRewards(uint256 amount) external onlyRole(CAMPAIGN_ADMIN_ROLE) {

341:     function collectFees() external onlyFactoryOrNudgeAdmin returns (uint256 feesToCollect) {

353:     function setIsCampaignActive(bool isActive) external {

378:     function rescueTokens(address token) external returns (uint256 amount) {

403:     function getBalanceOfSelf(address token) public view returns (uint256) {

413:     function claimableRewardAmount() public view returns (uint256) {

477:     function _transfer(address token, address to, uint256 amount) internal {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

53:     function getCampaignCount() external view returns (uint256) {

238:     function updateTreasuryAddress(address newTreasury) external onlyRole(NUDGE_ADMIN_ROLE) {

250:     function updateFeeSetting(uint16 newFeeBps) external onlyRole(NUDGE_ADMIN_ROLE) {

261:     function collectFeesFromCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_OPERATOR_ROLE) {

275:     function pauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {

289:     function unpauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

187:     function pauseCampaigns(uint256[] calldata campaignIds) external onlyRole(NUDGE_ADMIN_ROLE) {

200:     function unpauseCampaigns(uint256[] calldata campaignIds) external onlyRole(NUDGE_ADMIN_ROLE) {

218:     function getBalanceOfSelf(address token) public view returns (uint256) {

235:     function _transfer(address token, address to, uint256 amount) internal {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

```solidity
File: src/campaign/interfaces/IBaseNudgeCampaign.sol

51:     function getBalanceOfSelf(address token) external view returns (uint256);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/IBaseNudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaign.sol

29:     function collectFees() external returns (uint256);

30:     function invalidateParticipations(uint256[] calldata pIDs) external;

31:     function withdrawRewards(uint256 amount) external;

32:     function setIsCampaignActive(bool isActive) external;

33:     function claimRewards(uint256[] calldata pIDs) external;

34:     function rescueTokens(address token) external returns (uint256);

37:     function getBalanceOfSelf(address token) external view returns (uint256);

38:     function claimableRewardAmount() external view returns (uint256);

39:     function getRewardAmountIncludingFees(uint256 toAmount) external view returns (uint256);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaignFactory.sol

7:     function NUDGE_ADMIN_ROLE() external view returns (bytes32);

8:     function NUDGE_OPERATOR_ROLE() external view returns (bytes32);

9:     function SWAP_CALLER_ROLE() external view returns (bytes32);

10:     function NATIVE_TOKEN() external view returns (address);

36:     function nudgeTreasuryAddress() external view returns (address);

37:     function isCampaign(address) external view returns (bool);

38:     function campaignAddresses(uint256) external view returns (address);

39:     function isCampaignPaused(address) external view returns (bool);

76:     function updateTreasuryAddress(address newTreasury) external;

77:     function updateFeeSetting(uint16 newFeeBps) external;

78:     function collectFeesFromCampaigns(address[] calldata campaigns) external;

79:     function pauseCampaigns(address[] calldata campaigns) external;

80:     function unpauseCampaigns(address[] calldata campaigns) external;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaignFactory.sol)

```solidity
File: src/campaign/interfaces/INudgePointsCampaign.sol

37:     function pauseCampaigns(uint256[] calldata campaigns) external;

38:     function unpauseCampaigns(uint256[] calldata campaigns) external;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgePointsCampaign.sol)

### <a name="NC-9"></a>[NC-9] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor

If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (6)*:

```solidity
File: src/campaign/NudgeCampaign.sol

124:         if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender) && msg.sender != address(factory)) {

132:         if (!factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), msg.sender)) {

174:         if (!factory.hasRole(factory.SWAP_CALLER_ROLE(), msg.sender)) {

272:             if (participation.userAddress != msg.sender) {

354:         if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {

379:         if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="NC-10"></a>[NC-10] Constant state variables defined more than once

Rather than redefining state variable constant, consider using a library to store all constants as this will prevent data redundancy

*Instances (7)*:

```solidity
File: src/campaign/NudgeCampaign.sol

24:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

17:     bytes32 public constant NUDGE_ADMIN_ROLE = keccak256("NUDGE_ADMIN_ROLE");

19:     bytes32 public constant SWAP_CALLER_ROLE = keccak256("SWAP_CALLER_ROLE");

21:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

17:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

18:     bytes32 public constant NUDGE_ADMIN_ROLE = keccak256("NUDGE_ADMIN_ROLE");

19:     bytes32 public constant SWAP_CALLER_ROLE = keccak256("SWAP_CALLER_ROLE");

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="NC-11"></a>[NC-11] Consider using named mappings

Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (4)*:

```solidity
File: src/campaign/NudgeCampaignFactory.sol

27:     mapping(address => bool) public isCampaign;

29:     mapping(address => bool) public isCampaignPaused;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

22:     mapping(uint256 => Campaign) public campaigns;

23:     mapping(uint256 => bool) public isCampaignPaused;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="NC-12"></a>[NC-12] `address`s shouldn't be hard-coded

It is often better to declare `address`es as `immutable`, and assign them via constructor arguments. This allows the code to remain the same across deployments on different networks, and avoids recompilation when addresses need to change.

*Instances (3)*:

```solidity
File: src/campaign/NudgeCampaign.sol

24:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

21:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

17:     address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="NC-13"></a>[NC-13] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

374:     /// @notice Rescues tokens that were mistakenly sent to the contract
         /// @param token Address of token to rescue
         /// @dev Only callable by NUDGE_ADMIN_ROLE, can't rescue the reward token
         /// @return amount Amount of tokens rescued
         function rescueTokens(address token) external returns (uint256 amount) {
             if (!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender)) {
                 revert Unauthorized();
             }
     
             if (token == rewardToken) {
                 revert CannotRescueRewardToken();
             }
     
             amount = getBalanceOfSelf(token);
             if (amount > 0) {
                 _transfer(token, msg.sender, amount);
                 emit TokensRescued(token, amount);
             }
     
             return amount;

428:     /// @notice Returns comprehensive information about the campaign
         /// @return _holdingPeriodInSeconds Duration users must hold tokens
         /// @return _targetToken Address of token users need to hold
         /// @return _rewardToken Address of token used for rewards
         /// @return _rewardPPQ Reward parameter in parts per quadrillion
         /// @return _startTimestamp When the campaign becomes active
         /// @return _isCampaignActive Whether the campaign is currently active
         /// @return _pendingRewards Total rewards pending claim
         /// @return _totalReallocatedAmount Total amount of tokens reallocated
         /// @return _distributedRewards Total rewards distributed
         /// @return _claimableRewards Amount of rewards available for distribution
         function getCampaignInfo()
             external
             view
             returns (
                 uint32 _holdingPeriodInSeconds,
                 address _targetToken,
                 address _rewardToken,
                 uint256 _rewardPPQ,
                 uint256 _startTimestamp,
                 bool _isCampaignActive,
                 uint256 _pendingRewards,
                 uint256 _totalReallocatedAmount,
                 uint256 _distributedRewards,
                 uint256 _claimableRewards
             )
         {
             return (

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="NC-14"></a>[NC-14] Take advantage of Custom Error's return value property

An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (48)*:

```solidity
File: src/campaign/NudgeCampaign.sol

81:             revert InvalidCampaignSettings();

85:             revert InvalidCampaignSettings();

118:         if (factory.isCampaignPaused(address(this))) revert CampaignPaused();

125:             revert Unauthorized();

133:             revert Unauthorized();

175:             revert UnauthorizedSwapCaller();

183:             revert InvalidCampaignId();

203:             revert InsufficientAmountReceived();

214:             revert NotEnoughRewardsAvailable();

245:                 revert StartDateNotReached();

248:                 revert InactiveCampaign();

258:             revert EmptyParticipationsArray();

328:             revert NotEnoughRewardsAvailable();

355:             revert Unauthorized();

359:             revert StartDateNotReached();

380:             revert Unauthorized();

384:             revert CannotRescueRewardToken();

480:             if (!sent) revert NativeTokenTransferFailed();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

38:         if (treasury_ == address(0)) revert InvalidTreasuryAddress();

39:         if (admin_ == address(0)) revert ZeroAddress();

40:         if (operator_ == address(0)) revert ZeroAddress();

41:         if (swapCaller_ == address(0)) revert ZeroAddress();

78:         if (campaignAdmin == address(0)) revert ZeroAddress();

79:         if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();

80:         if (holdingPeriodInSeconds == 0) revert InvalidParameter();

144:         if (campaignAdmin == address(0)) revert ZeroAddress();

145:         if (targetToken == address(0) || rewardToken == address(0)) revert ZeroAddress();

146:         if (holdingPeriodInSeconds == 0) revert InvalidParameter();

149:             if (msg.value != initialRewardAmount) revert IncorrectEtherAmount();

163:             if (!sent) revert NativeTokenTransferFailed();

165:             if (msg.value > 0) revert IncorrectEtherAmount();

239:         if (newTreasury == address(0)) revert InvalidTreasuryAddress();

251:         if (newFeeBps > 10_000) revert InvalidFeeSetting();

265:             if (!isCampaign[campaigns[i]]) revert InvalidCampaign();

277:             if (!isCampaign[campaigns[i]]) revert InvalidCampaign();

278:             if (isCampaignPaused[campaigns[i]]) revert CampaignAlreadyPaused();

291:             if (!isCampaign[campaigns[i]]) revert InvalidCampaign();

292:             if (!isCampaignPaused[campaigns[i]]) revert CampaignNotPaused();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

40:         if (isCampaignPaused[campaignId]) revert CampaignPaused();

56:             revert InvalidTargetToken();

60:             revert CampaignAlreadyExists();

89:             revert InvalidInputArrayLengths();

96:                 revert InvalidTargetToken();

100:                 revert CampaignAlreadyExists();

157:             revert InsufficientAmountReceived();

189:             if (isCampaignPaused[campaignIds[i]]) revert CampaignAlreadyPaused();

202:             if (!isCampaignPaused[campaignIds[i]]) revert CampaignNotPaused();

238:             if (!sent) revert NativeTokenTransferFailed();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="NC-15"></a>[NC-15] Contract does not follow the Solidity style guide's suggested layout ordering

The [style guide](https://docs.soliditylang.org/en/v0.8.16/style-guide.html#order-of-layout) says that, within a contract, the ordering should be:

1) Type declarations
2) State variables
3) Events
4) Modifiers
5) Functions

However, the contract(s) below do not follow this ordering

*Instances (5)*:

```solidity
File: src/campaign/NudgeCampaign.sol

1: 
   Current order:
   UsingForDirective.Math
   UsingForDirective.IERC20
   VariableDeclaration.CAMPAIGN_ADMIN_ROLE
   VariableDeclaration.BPS_DENOMINATOR
   VariableDeclaration.PPQ_DENOMINATOR
   VariableDeclaration.NATIVE_TOKEN
   VariableDeclaration.factory
   VariableDeclaration.holdingPeriodInSeconds
   VariableDeclaration.targetToken
   VariableDeclaration.rewardToken
   VariableDeclaration.rewardPPQ
   VariableDeclaration.startTimestamp
   VariableDeclaration.alternativeWithdrawalAddress
   VariableDeclaration.feeBps
   VariableDeclaration.isCampaignActive
   VariableDeclaration.campaignId
   VariableDeclaration.targetScalingFactor
   VariableDeclaration.rewardScalingFactor
   VariableDeclaration.pID
   VariableDeclaration.pendingRewards
   VariableDeclaration.totalReallocatedAmount
   VariableDeclaration.accumulatedFees
   VariableDeclaration.distributedRewards
   VariableDeclaration._manuallyDeactivated
   VariableDeclaration.participations
   FunctionDefinition.constructor
   ModifierDefinition.whenNotPaused
   ModifierDefinition.onlyFactoryOrNudgeAdmin
   ModifierDefinition.onlyNudgeOperator
   FunctionDefinition.getRewardAmountIncludingFees
   FunctionDefinition.handleReallocation
   FunctionDefinition._validateAndActivateCampaignIfReady
   FunctionDefinition.claimRewards
   FunctionDefinition.invalidateParticipations
   FunctionDefinition.withdrawRewards
   FunctionDefinition.collectFees
   FunctionDefinition.setIsCampaignActive
   FunctionDefinition.rescueTokens
   FunctionDefinition.getBalanceOfSelf
   FunctionDefinition.claimableRewardAmount
   FunctionDefinition.calculateUserRewardsAndFees
   FunctionDefinition.getCampaignInfo
   FunctionDefinition._transfer
   FunctionDefinition.receive
   FunctionDefinition.fallback
   
   Suggested order:
   UsingForDirective.Math
   UsingForDirective.IERC20
   VariableDeclaration.CAMPAIGN_ADMIN_ROLE
   VariableDeclaration.BPS_DENOMINATOR
   VariableDeclaration.PPQ_DENOMINATOR
   VariableDeclaration.NATIVE_TOKEN
   VariableDeclaration.factory
   VariableDeclaration.holdingPeriodInSeconds
   VariableDeclaration.targetToken
   VariableDeclaration.rewardToken
   VariableDeclaration.rewardPPQ
   VariableDeclaration.startTimestamp
   VariableDeclaration.alternativeWithdrawalAddress
   VariableDeclaration.feeBps
   VariableDeclaration.isCampaignActive
   VariableDeclaration.campaignId
   VariableDeclaration.targetScalingFactor
   VariableDeclaration.rewardScalingFactor
   VariableDeclaration.pID
   VariableDeclaration.pendingRewards
   VariableDeclaration.totalReallocatedAmount
   VariableDeclaration.accumulatedFees
   VariableDeclaration.distributedRewards
   VariableDeclaration._manuallyDeactivated
   VariableDeclaration.participations
   ModifierDefinition.whenNotPaused
   ModifierDefinition.onlyFactoryOrNudgeAdmin
   ModifierDefinition.onlyNudgeOperator
   FunctionDefinition.constructor
   FunctionDefinition.getRewardAmountIncludingFees
   FunctionDefinition.handleReallocation
   FunctionDefinition._validateAndActivateCampaignIfReady
   FunctionDefinition.claimRewards
   FunctionDefinition.invalidateParticipations
   FunctionDefinition.withdrawRewards
   FunctionDefinition.collectFees
   FunctionDefinition.setIsCampaignActive
   FunctionDefinition.rescueTokens
   FunctionDefinition.getBalanceOfSelf
   FunctionDefinition.claimableRewardAmount
   FunctionDefinition.calculateUserRewardsAndFees
   FunctionDefinition.getCampaignInfo
   FunctionDefinition._transfer
   FunctionDefinition.receive
   FunctionDefinition.fallback

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

1: 
   Current order:
   UsingForDirective.IERC20
   VariableDeclaration.NATIVE_TOKEN
   VariableDeclaration.NUDGE_ADMIN_ROLE
   VariableDeclaration.SWAP_CALLER_ROLE
   VariableDeclaration.campaigns
   VariableDeclaration.isCampaignPaused
   VariableDeclaration.participations
   FunctionDefinition.constructor
   ModifierDefinition.whenNotPaused
   FunctionDefinition.createPointsCampaign
   FunctionDefinition.createPointsCampaigns
   FunctionDefinition.handleReallocation
   FunctionDefinition.pauseCampaigns
   FunctionDefinition.unpauseCampaigns
   FunctionDefinition.getBalanceOfSelf
   FunctionDefinition._transfer
   
   Suggested order:
   UsingForDirective.IERC20
   VariableDeclaration.NATIVE_TOKEN
   VariableDeclaration.NUDGE_ADMIN_ROLE
   VariableDeclaration.SWAP_CALLER_ROLE
   VariableDeclaration.campaigns
   VariableDeclaration.isCampaignPaused
   VariableDeclaration.participations
   ModifierDefinition.whenNotPaused
   FunctionDefinition.constructor
   FunctionDefinition.createPointsCampaign
   FunctionDefinition.createPointsCampaigns
   FunctionDefinition.handleReallocation
   FunctionDefinition.pauseCampaigns
   FunctionDefinition.unpauseCampaigns
   FunctionDefinition.getBalanceOfSelf
   FunctionDefinition._transfer

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

```solidity
File: src/campaign/interfaces/IBaseNudgeCampaign.sol

1: 
   Current order:
   ErrorDefinition.CampaignPaused
   ErrorDefinition.UnauthorizedSwapCaller
   ErrorDefinition.Unauthorized
   ErrorDefinition.InsufficientAmountReceived
   ErrorDefinition.InvalidToTokenReceived
   EnumDefinition.ParticipationStatus
   StructDefinition.Participation
   EventDefinition.NewParticipation
   FunctionDefinition.handleReallocation
   FunctionDefinition.getBalanceOfSelf
   
   Suggested order:
   EnumDefinition.ParticipationStatus
   StructDefinition.Participation
   ErrorDefinition.CampaignPaused
   ErrorDefinition.UnauthorizedSwapCaller
   ErrorDefinition.Unauthorized
   ErrorDefinition.InsufficientAmountReceived
   ErrorDefinition.InvalidToTokenReceived
   EventDefinition.NewParticipation
   FunctionDefinition.handleReallocation
   FunctionDefinition.getBalanceOfSelf

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/IBaseNudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaignFactory.sol

1: 
   Current order:
   FunctionDefinition.NUDGE_ADMIN_ROLE
   FunctionDefinition.NUDGE_OPERATOR_ROLE
   FunctionDefinition.SWAP_CALLER_ROLE
   FunctionDefinition.NATIVE_TOKEN
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidTreasuryAddress
   ErrorDefinition.InvalidParameter
   ErrorDefinition.InvalidCampaign
   ErrorDefinition.CampaignAlreadyPaused
   ErrorDefinition.CampaignNotPaused
   ErrorDefinition.NativeTokenTransferFailed
   ErrorDefinition.IncorrectEtherAmount
   ErrorDefinition.InvalidFeeSetting
   EventDefinition.CampaignDeployed
   EventDefinition.TreasuryUpdated
   EventDefinition.CampaignsPaused
   EventDefinition.CampaignsUnpaused
   EventDefinition.FeesCollected
   EventDefinition.FeeUpdated
   FunctionDefinition.nudgeTreasuryAddress
   FunctionDefinition.isCampaign
   FunctionDefinition.campaignAddresses
   FunctionDefinition.isCampaignPaused
   FunctionDefinition.deployCampaign
   FunctionDefinition.deployAndFundCampaign
   FunctionDefinition.getCampaignAddress
   FunctionDefinition.updateTreasuryAddress
   FunctionDefinition.updateFeeSetting
   FunctionDefinition.collectFeesFromCampaigns
   FunctionDefinition.pauseCampaigns
   FunctionDefinition.unpauseCampaigns
   
   Suggested order:
   ErrorDefinition.ZeroAddress
   ErrorDefinition.InvalidTreasuryAddress
   ErrorDefinition.InvalidParameter
   ErrorDefinition.InvalidCampaign
   ErrorDefinition.CampaignAlreadyPaused
   ErrorDefinition.CampaignNotPaused
   ErrorDefinition.NativeTokenTransferFailed
   ErrorDefinition.IncorrectEtherAmount
   ErrorDefinition.InvalidFeeSetting
   EventDefinition.CampaignDeployed
   EventDefinition.TreasuryUpdated
   EventDefinition.CampaignsPaused
   EventDefinition.CampaignsUnpaused
   EventDefinition.FeesCollected
   EventDefinition.FeeUpdated
   FunctionDefinition.NUDGE_ADMIN_ROLE
   FunctionDefinition.NUDGE_OPERATOR_ROLE
   FunctionDefinition.SWAP_CALLER_ROLE
   FunctionDefinition.NATIVE_TOKEN
   FunctionDefinition.nudgeTreasuryAddress
   FunctionDefinition.isCampaign
   FunctionDefinition.campaignAddresses
   FunctionDefinition.isCampaignPaused
   FunctionDefinition.deployCampaign
   FunctionDefinition.deployAndFundCampaign
   FunctionDefinition.getCampaignAddress
   FunctionDefinition.updateTreasuryAddress
   FunctionDefinition.updateFeeSetting
   FunctionDefinition.collectFeesFromCampaigns
   FunctionDefinition.pauseCampaigns
   FunctionDefinition.unpauseCampaigns

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaignFactory.sol)

```solidity
File: src/campaign/interfaces/INudgePointsCampaign.sol

1: 
   Current order:
   ErrorDefinition.NativeTokenTransferFailed
   ErrorDefinition.CampaignAlreadyPaused
   ErrorDefinition.CampaignNotPaused
   ErrorDefinition.InvalidInputArrayLengths
   ErrorDefinition.InvalidTargetToken
   ErrorDefinition.CampaignAlreadyExists
   EventDefinition.PointsCampaignCreated
   EventDefinition.CampaignsPaused
   EventDefinition.CampaignsUnpaused
   StructDefinition.Campaign
   FunctionDefinition.createPointsCampaign
   FunctionDefinition.createPointsCampaigns
   FunctionDefinition.pauseCampaigns
   FunctionDefinition.unpauseCampaigns
   
   Suggested order:
   StructDefinition.Campaign
   ErrorDefinition.NativeTokenTransferFailed
   ErrorDefinition.CampaignAlreadyPaused
   ErrorDefinition.CampaignNotPaused
   ErrorDefinition.InvalidInputArrayLengths
   ErrorDefinition.InvalidTargetToken
   ErrorDefinition.CampaignAlreadyExists
   EventDefinition.PointsCampaignCreated
   EventDefinition.CampaignsPaused
   EventDefinition.CampaignsUnpaused
   FunctionDefinition.createPointsCampaign
   FunctionDefinition.createPointsCampaigns
   FunctionDefinition.pauseCampaigns
   FunctionDefinition.unpauseCampaigns

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgePointsCampaign.sol)

### <a name="NC-16"></a>[NC-16] Use Underscores for Number Literals (add an underscore every 3 digits)

*Instances (1)*:

```solidity
File: src/campaign/NudgeCampaignFactory.sol

24:     uint16 public FEE_BPS = 1000; // 10% by default

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="NC-17"></a>[NC-17] Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

*Instances (15)*:

```solidity
File: src/campaign/interfaces/IBaseNudgeCampaign.sol

31:     event NewParticipation(

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/IBaseNudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaign.sol

22:     event ParticipationInvalidated(uint256[] pIDs);

23:     event RewardsWithdrawn(address to, uint256 amount);

24:     event FeesCollected(uint256 amount);

25:     event CampaignStatusChanged(bool isActive);

26:     event NudgeRewardClaimed(uint256 pID, address userAddress, uint256 rewardAmount);

27:     event TokensRescued(address token, uint256 amount);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaignFactory.sol

22:     event CampaignDeployed(

31:     event CampaignsPaused(address[] campaigns);

32:     event CampaignsUnpaused(address[] campaigns);

33:     event FeesCollected(address[] campaigns, uint256 totalAmount);

34:     event FeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaignFactory.sol)

```solidity
File: src/campaign/interfaces/INudgePointsCampaign.sol

14:     event PointsCampaignCreated(uint256 campaignId, uint32 holdingPeriodInSeconds, address targetToken);

15:     event CampaignsPaused(uint256[] campaigns);

16:     event CampaignsUnpaused(uint256[] campaigns);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgePointsCampaign.sol)

### <a name="NC-18"></a>[NC-18] Constants should be defined rather than using magic numbers

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

99:         targetScalingFactor = 10 ** (18 - targetDecimals);

100:         rewardScalingFactor = 10 ** (18 - rewardDecimals);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="NC-19"></a>[NC-19] Variables need not be initialized to zero

The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (8)*:

```solidity
File: src/campaign/NudgeCampaign.sol

263:         for (uint256 i = 0; i < pIDs.length; i++) {

309:         for (uint256 i = 0; i < pIDs.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

264:         for (uint256 i = 0; i < campaigns.length; i++) {

276:         for (uint256 i = 0; i < campaigns.length; i++) {

290:         for (uint256 i = 0; i < campaigns.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

94:         for (uint256 i = 0; i < campaignIds.length; i++) {

188:         for (uint256 i = 0; i < campaignIds.length; i++) {

201:         for (uint256 i = 0; i < campaignIds.length; i++) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

## Low Issues

| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Some tokens may revert when zero value transfers are made | 5 |
| [L-2](#L-2) | Missing checks for `address(0)` when assigning values to address state variables | 1 |
| [L-3](#L-3) | `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 2 |
| [L-4](#L-4) | `decimals()` is not a part of the ERC-20 standard | 2 |
| [L-5](#L-5) | Division by zero not prevented | 1 |
| [L-6](#L-6) | Empty `receive()/payable fallback()` function does not authenticate requests | 2 |
| [L-7](#L-7) | External call recipient may consume all transaction gas | 3 |
| [L-8](#L-8) | Signature use at deadlines should be allowed | 2 |
| [L-9](#L-9) | Loss of precision | 1 |
| [L-10](#L-10) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 3 |
| [L-11](#L-11) | Sweeping may break accounting if tokens with multiple addresses are used | 2 |

### <a name="L-1"></a>[L-1] Some tokens may revert when zero value transfers are made

Example: <https://github.com/d-xo/weird-erc20#revert-on-zero-value-transfers>.

In spite of the fact that EIP-20 [states](https://github.com/ethereum/EIPs/blob/46b9b698815abbfa628cd1097311deee77dd45c5/EIPS/eip-20.md?plain=1#L116) that zero-valued transfers must be accepted, some tokens, such as LEND will revert if this is attempted, which may cause transactions that involve other tokens (such as batch operations) to fully revert. Consider skipping the transfer if the amount is zero, which will also save gas.

*Instances (5)*:

```solidity
File: src/campaign/NudgeCampaign.sol

197:             SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);

482:             SafeERC20.safeTransfer(IERC20(token), to, amount);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

177:             IERC20(rewardToken).safeTransferFrom(msg.sender, campaign, initialRewardAmount);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

151:             SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);

240:             SafeERC20.safeTransfer(IERC20(token), to, amount);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="L-2"></a>[L-2] Missing checks for `address(0)` when assigning values to address state variables

*Instances (1)*:

```solidity
File: src/campaign/NudgeCampaign.sol

113:         alternativeWithdrawalAddress = alternativeWithdrawalAddress_;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="L-3"></a>[L-3] `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`

Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaignFactory.sol

111:         bytes memory bytecode = abi.encodePacked(type(NudgeCampaign).creationCode, constructorArgs);

230:         bytes memory bytecode = abi.encodePacked(type(NudgeCampaign).creationCode, constructorArgs);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

### <a name="L-4"></a>[L-4] `decimals()` is not a part of the ERC-20 standard

The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

95:         uint256 targetDecimals = targetToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(targetToken_).decimals();

96:         uint256 rewardDecimals = rewardToken_ == NATIVE_TOKEN ? 18 : IERC20Metadata(rewardToken_).decimals();

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="L-5"></a>[L-5] Division by zero not prevented

The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (1)*:

```solidity
File: src/campaign/NudgeCampaign.sol

154:         return rewardAmountIn18Decimals / rewardScalingFactor;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="L-6"></a>[L-6] Empty `receive()/payable fallback()` function does not authenticate requests

If the intention is for the Ether to be used, the function should call another function, otherwise it should revert (e.g. require(msg.sender == address(weth))). Having no access control on the function means that someone may send Ether to the contract, and have no way to get anything back out, which is a loss of funds. If the concern is having to spend a small amount of gas to check the sender against an immutable address, the code should at least have a function to rescue unused Ether.

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

487:     receive() external payable {}

490:     fallback() external payable {}

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="L-7"></a>[L-7] External call recipient may consume all transaction gas

There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (3)*:

```solidity
File: src/campaign/NudgeCampaign.sol

479:             (bool sent, ) = to.call{value: amount}("");

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

162:             (bool sent, ) = campaign.call{value: initialRewardAmount}("");

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

237:             (bool sent, ) = to.call{value: amount}("");

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="L-8"></a>[L-8] Signature use at deadlines should be allowed

According to [EIP-2612](https://github.com/ethereum/EIPs/blob/71dc97318013bf2ac572ab63fab530ac9ef419ca/EIPS/eip-2612.md?plain=1#L58), signatures used on exactly the deadline timestamp are supposed to be allowed. While the signature may or may not be used for the exact EIP-2612 use case (transfer approvals), for consistency's sake, all deadlines should follow this semantic. If the timestamp is an expiration rather than a deadline, consider whether it makes more sense to include the expiration timestamp as a valid timestamp, as is done for deadlines.

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

84:         if (startTimestamp_ != 0 && startTimestamp_ <= block.timestamp) {

106:         isCampaignActive = startTimestamp <= block.timestamp;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="L-9"></a>[L-9] Loss of precision

Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (1)*:

```solidity
File: src/campaign/NudgeCampaign.sol

424:         fees = (rewardAmountIncludingFees * feeBps) / BPS_DENOMINATOR;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

### <a name="L-10"></a>[L-10] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`

The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (3)*:

```solidity
File: src/campaign/NudgeCampaign.sol

2: pragma solidity ^0.8.28;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

2: pragma solidity ^0.8.28;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

2: pragma solidity ^0.8.28;

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="L-11"></a>[L-11] Sweeping may break accounting if tokens with multiple addresses are used

There have been [cases](https://blog.openzeppelin.com/compound-tusd-integration-issue-retrospective/) in the past where a token mistakenly had two addresses that could control its balance, and transfers using one address impacted the balance of the other. To protect against this potential scenario, sweep functions should ensure that the balance of the non-sweepable token does not change after the transfer of the swept tokens.

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

378:     function rescueTokens(address token) external returns (uint256 amount) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaign.sol

34:     function rescueTokens(address token) external returns (uint256);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaign.sol)

## Medium Issues

| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Contracts are vulnerable to fee-on-transfer accounting-related issues | 2 |
| [M-2](#M-2) | `block.number` means different things on different L2s | 2 |
| [M-3](#M-3) | Centralization Risk for trusted owners | 15 |

### <a name="M-1"></a>[M-1] Contracts are vulnerable to fee-on-transfer accounting-related issues

Consistently check account balance before and after transfers for Fee-On-Transfer discrepancies. As arbitrary ERC20 tokens can be used, the amount here should be calculated every time to take into consideration a possible fee-on-transfer or deflation.
Also, it's a good practice for the future of the solution.

Use the balance before and after the transfer to calculate the received amount instead of assuming that it would be equal to the amount passed as a parameter. Or explicitly document that such tokens shouldn't be used and won't be supported

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

197:             SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

151:             SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="M-2"></a>[M-2] `block.number` means different things on different L2s

On Optimism, `block.number` is the L2 block number, but on Arbitrum, it's the L1 block number, and `ArbSys(address(100)).arbBlockNumber()` must be used. Furthermore, L2 block numbers often occur much more frequently than L1 block numbers (any may even occur on a per-transaction basis), so using block numbers for timing results in inconsistencies, especially when voting is involved across multiple chains. As of version 4.9, OpenZeppelin has [modified](https://blog.openzeppelin.com/introducing-openzeppelin-contracts-v4.9#governor) their governor code to use a clock rather than block numbers, to avoid these sorts of issues, but this still requires that the project [implement](https://docs.openzeppelin.com/contracts/4.x/governance#token_2) a [clock](https://eips.ethereum.org/EIPS/eip-6372) for each L2.

*Instances (2)*:

```solidity
File: src/campaign/NudgeCampaign.sol

229:             startBlockNumber: block.number

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

173:             startBlockNumber: block.number

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

### <a name="M-3"></a>[M-3] Centralization Risk for trusted owners

#### Impact

Contracts have owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds.

*Instances (15)*:

```solidity
File: src/campaign/NudgeCampaign.sol

14: contract NudgeCampaign is INudgeCampaign, AccessControl {

326:     function withdrawRewards(uint256 amount) external onlyRole(CAMPAIGN_ADMIN_ROLE) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaign.sol)

```solidity
File: src/campaign/NudgeCampaignFactory.sol

14: contract NudgeCampaignFactory is INudgeCampaignFactory, AccessControl {

238:     function updateTreasuryAddress(address newTreasury) external onlyRole(NUDGE_ADMIN_ROLE) {

250:     function updateFeeSetting(uint16 newFeeBps) external onlyRole(NUDGE_ADMIN_ROLE) {

261:     function collectFeesFromCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_OPERATOR_ROLE) {

275:     function pauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {

289:     function unpauseCampaigns(address[] calldata campaigns) external onlyRole(NUDGE_ADMIN_ROLE) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgeCampaignFactory.sol)

```solidity
File: src/campaign/NudgePointsCampaigns.sol

13: contract NudgePointsCampaigns is INudgePointsCampaign, AccessControl {

54:     ) external onlyRole(NUDGE_ADMIN_ROLE) returns (Campaign memory) {

86:     ) external onlyRole(NUDGE_ADMIN_ROLE) returns (Campaign[] memory) {

132:     ) external payable whenNotPaused(campaignId) onlyRole(SWAP_CALLER_ROLE) {

187:     function pauseCampaigns(uint256[] calldata campaignIds) external onlyRole(NUDGE_ADMIN_ROLE) {

200:     function unpauseCampaigns(uint256[] calldata campaignIds) external onlyRole(NUDGE_ADMIN_ROLE) {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/NudgePointsCampaigns.sol)

```solidity
File: src/campaign/interfaces/INudgeCampaignFactory.sol

6: interface INudgeCampaignFactory is IAccessControl {

```

[Link to code](https://github.com/code-423n4/2025-03-nudgexyz/blob/main/src/campaign/interfaces/INudgeCampaignFactory.sol)
