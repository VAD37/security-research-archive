# `FeeWrapper.sol` stuck token problem with `approve()`

## Impact

In case of incorrect input calculation, the 3rd party send more token than needed.
And, Rubicon does not spend all `approval` token due to wrong input `arg`.

This can cause stuck token in `FeeWrapper.sol` contract.

Any abuser can drain any leftover token in `FeeWrapper.sol` contract.

## Proof of Concept

- User make a call to `FeeWrapper.sol` with `totalAmount` of token
- Fee was taken and approve `Rubicon` contract to spend `totalAmount - fee` [token based on user input](https://github.com/code-423n4/2023-04-rubicon/blob/1cd6d4e84c510c70c9062e2d6f961502f50aa097/contracts/utilities/FeeWrapper.sol#L105)
- But the `seletor` and `args` params are incorrect.
- The rubicon contract does not spend all approval token.
- There will be left over token in `FeeWrapper.sol` contract that have no `sweepToken` method.
- Since approval amount still have some left over, next abuser can simply make a rubicall with no fee. And let `Rubicon` contracts spend the leftover token.

## Tools Used

Manual

## Recommended Mitigation Steps

Either add free `sweepTokens()` method for everyone. And let 3rd party handle faulty input.

Or implement zero-balance check after external call.

<https://github.com/code-423n4/2023-04-rubicon/blob/1cd6d4e84c510c70c9062e2d6f961502f50aa097/contracts/utilities/FeeWrapper.sol#L105>
