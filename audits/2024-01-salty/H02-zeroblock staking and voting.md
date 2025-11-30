# zero block staking and voting. Allowing flashloan voting manipulation and steal DAO tokens

Project have no both staking and voting delay mechanism.

User can stake and vote on same block. Also allow free vote after ballot execution is ready.
So in single block, attacker can flashloan token, stake and vote on proposal and execute proposal to transfer DAO token to attacker. And then repay flashloan with stolen DAO token.

The only requirements are:

- 0.5% staked SALT to make proposal
- 5% of DAO SALT balance > required quorum and enough vote to win proposal (500K SALT minimum) + flash fee + double swap fee
- UNISWAP flashloan have enough WETH,WBTC to swap for SALT to vote on proposal

## Impact

Realistic, 5% DAO balance is not enough to win entire proposal or even half of proposal vote.
And DAO balance most of the time is spend on rewarding whitelist token. 400K minimum token for each new whitelist.

And it take 2-4 years before enough DAO vesting token release 5M-10M SALT token to have enough token to win proposal.

So this exploit only work for attacker who already own large amount SALT and staked SALT. Just not enough to win required quorum.

So if managed to pull through, attacker networth will increase by 5% of DAO token in xSALT token that will take 2 weeks to unstake.

## Proof of Concept

1. User with 0.5% of staked SALT can propose to send 5% of DAO token to attacker address. <https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/dao/Proposals.sol#L196-L209>
2. Voting will take place for a few days before execution ready.
3. Voting ballot can still happen when execution pass `ballotMinimumEndTime` <https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/dao/Proposals.sol#L383-L400>
4. User can stake and increase share of xSALT anytime. The only requirement is cooldown of 6 hours between staking.<https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/staking/Staking.sol#L39-L53>
5. flashloan UNISWAP for WBTC, WETH
6. Swap for SALT
7. Staking all SALT to get enought xSALT to vote yes on proposal
8. Ballot is still live when execution is ready. Attacker can `castVote()` with new increased xSALT share. <https://github.com/code-423n4/2024-01-salty/blob/53516c2cdfdfacb662cdea6417c52f23c94d5b5b/src/dao/Proposals.sol#L259-L293>
9. Vote yes on proposal. Now Yes vote > No vote. Proposal is ready to execute.
10. Execute proposal to transfer 5% of DAO token to attacker address.
11. swap SALT back to WBTC, WETH. Repay flashloan.
12. Profit on new staked xSALT token.

## Tools Used

manual

## Recommended Mitigation Steps

Staking Salt already cache `user.cooldownExpiration` in storage. Might as well use it to prevent voting after staking.

```solidity
File: Proposals.sol
259:  function castVote( uint256 ballotID, Vote vote ) external nonReentrant
260:   {
+++    require(block.timestamp >= stakingRewards.userCooldowns(msg.sender, poolsConfig.whitelistedPools()), "vote cooldown");
261:   Ballot memory ballot = ballots[ballotID];

```
