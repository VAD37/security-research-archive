# Compound V2 `accrueInterest()` does not work on L2 network without changing `block.number` formula

## Impact

L2 `block.number` is not realiable like in L1. Interest Rate and borrow rate will be calculated incorrectly.

With current Optimism implementation, any user can fast forward block number time by sending new transaction in L2 network.
Basically, interest rate accrure everytime anyone send a new transaction to blockchain.

## Proof of Concept

CompoundV2 CToken use `block.number` or `blockDelta` as [time variable to calculate interest rate](https://github.com/code-423n4/2023-04-rubicon/blob/1cd6d4e84c510c70c9062e2d6f961502f50aa097/contracts/compound-v2-fork/CToken.sol#L348). This number is fixed as 15 second on mainnet or 2102400 blocks per year.

However, on L2 network like Optimism, block production is not constant. Time was much shorter and it was not created same way as L1.

On Optimism specifically, block was created for [every new transaction](https://community.optimism.io/docs/developers/build/differences/#block-production-is-not-constant). With possible new update will change this to [new block every 2 seconds](https://community.optimism.io/docs/developers/bedrock/differences/#block-production).

## Tools Used

Manual

## Recommended Mitigation Steps

Compound newer InterestRateModel have fixed block per year. They convert this rate into fixedRate per block. Or rate per 15 seconds.

The fastest way to fix is change `block.number` from L2 to L1 `block.number` using optimism [special contract opcode](https://community.optimism.io/docs/developers/bedrock/differences/#l1block).

Otherwise, change logic CToken from block number to timestamp.
