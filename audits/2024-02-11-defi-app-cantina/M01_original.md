## Summary

Rewards per epoch are distributed is based on unconvention `block.number` which require every block must produce every 2 seconds.
While this is true on Base chain deployment for now. Base EVM is based on Optimism OP stack, which have several fallback for L2 outage and mailbox that pause block production until chain online again. Also OP chain also failed to produce 2 seconds block consistently.
It also unclear if Base chain will upgrade in future and change block duration later on due to centralization chain.

An out of sync block compare to epoch duration will leads to unfair rewards duration because epoch not consistent to admin config.

## Finding Description

Here is snippet from `DefiAppHomeCenter.sol` on how new epoch is calculated:

```solidity
    /// Constants
    uint256 public constant BLOCK_CADENCE = 2; // seconds per block
    uint256 public constant NEXT_EPOCH_BLOCKS_PREFACE = 7 days / BLOCK_CADENCE;
    function initializeNextEpoch() public returns (bool) {//@no clue why this return boolean
        DefiAppHomeCenterStorage storage $ = _getDefiAppHomeCenterStorage();
        if ($.currentEpoch == 0) {//@only admin can init epoch
            require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), DefiAppHomeCenter_onlyAdmin());
            $.currentEpoch = _getNextEpoch($);//epoch:1
            _setEpochParams(
                $,
                $.currentEpoch,//1
                block.number + ($.defaultEpochDuration / BLOCK_CADENCE),//endBlock: now + 15 days
                block.timestamp.toUint96(),//startTime
                EpochDistributor.estimateDistributionAmount(
                    $.defaultRps, block.number, block.number + ($.defaultEpochDuration / BLOCK_CADENCE), BLOCK_CADENCE
                ).toUint128(),// = 1e18 * 30 days
                uint8(EpochStates.Ongoing)
            );//@audit-ok M epoch based on block.number counting is unrealiable. Use timestamp is better. It have multiple drawback. Most severe is not guanrantee epoch duration is correct.
            return true;
        }
        if (block.number >= ($.epochs[$.currentEpoch].endBlock - NEXT_EPOCH_BLOCKS_PREFACE)) {//@end - 3.5 days
            EpochParams memory previous = $.epochs[$.currentEpoch];
            uint8 stateToSet = block.number > previous.endBlock 
                ? uint8(EpochStates.Ongoing)//@set nextEpoch to ongoing. same as init above
                : $.votingActive == 1 ? uint8(EpochStates.Voting) : uint8(EpochStates.Initialized);// trigger update epoch before end in ~3 days.
            $.currentEpoch = _getNextEpoch($);//@if update epoch early. It set to voting/initalized for 3.5 days. while previous epoch still ongoing.
            uint256 nextEndBlock = previous.endBlock + ($.defaultEpochDuration / BLOCK_CADENCE);//@nextEpoch = endBlockNumber + 15 days
            uint96 nextEstimatedStartTimestamp = //@ = endBlockNumber + 15 days - block.number * 2 + now = left over epoch time + 15 days + now
                ((nextEndBlock - block.number) * BLOCK_CADENCE + block.timestamp).toUint96();
            _setEpochParams(
                $,
                $.currentEpoch,
                nextEndBlock,
                nextEstimatedStartTimestamp,
                EpochDistributor.estimateDistributionAmount(
                    $.defaultRps, previous.endBlock, nextEndBlock, BLOCK_CADENCE //@distribution same as init = 30 days * 1e18
                ).toUint128(),
                stateToSet
            );
            return true;
        } else {
            return false;
        }
    }
```

Based on above code and context, Default Epoch duration is 15 days.
When previous epoch about end, Anyone can move to next epoch 15 days from the last epoch.

Code use the `block.number >= current end block` to see check when epoch start and end.
Block duration `BLOCK_CADENCE` is fixed to 2 seconds.

It is expected `block.number` to always 2 seconds apart is not true even when Base chain seem like consitently produce block every 2 seconds.

### L2 Base/OP chain issue

It stated quite clear on their docs for BedRock that chain might have outage/downtime.
Due to centralization issue, chain will stop produce new block and queue all transaction to mailbox.
Then start order transactions when chain is online again.

While Base chain still new and have been produce 2 seconds block since its introdution.
Base is based on Optimism stack. It rely on evm upgrade and concensus might change on block production and time.
Also look back last 700 days with 2 second per block on optimism show that it only produce 670 days worth of block.

So time block production is already not consistent

## Impact Explanation

Medium: Rewards distribution time is not consistent and not realiable way to counting epoch. Some epoch might become longer than average if outage happen. Affect user claiming rewards on that specific epoch.

## Likelihood Explanation

Medium: Optimism L2 chain already failed to produce 2 seconds block before. It is unclear base chain build on top of optimism tech stack would also produce same result.

## Proof of Concept

Assume a block is 2 seconds. Epoch duration is 7 days.
Start from block number 131482800
<https://optimistic.etherscan.io/block/131482800>
rewind back at 21 days or 3 epoch at block 130572800 `=(131480000 - ((60*60*24*7) /2 * 3)`
<https://optimistic.etherscan.io/block/129665600>
The epoch time do not change.
But rewind back 700 days or 100 epoch. block number 101240000 `=(131480000 - ((60*60*24*7) /2 * 3)`.
https://optimistic.etherscan.io/block/101240000
Only 620 days have been passed.

## Recommendation

Use timestamp rounded down as more accurate way

`startEpoch = (block.timestamp / epochDuration * epochDuration) + DELAY_INITIAL_START_TIME`
`currentEpoch = (block.timestamp / epochDuration * epochDuration) - startEpoch`
