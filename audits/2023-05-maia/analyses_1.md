# Analyses: Guidelines and FAQ "Advanced"

## First impressions

- I do not found any information or contract related to V1. 4 different projects
- No original source code. Cannot compare different between commits. So reading previous Audit does nothing as it does not show what was changed.
- Automated finding found some simple typo error. It look like pass normal test case. Project seem like lacking serious testing. So I guess go through each test file to see what missing in between

Apprach strategy: lookout for testing fuzzing, each function test case might not work correctly.

## Scouting
-  found the [first audit repo](https://github.com/Maia-DAO/maia-ecosystem-monorepo/tree/739748de6e56a1806c73babb7cc9790d0a1e5d8e)
- Hermes say "soldily" fork. Only found [Fantom contracts](https://github.com/solidex-fantom/solidex) on github that have nothing in common
- No information about Maia tokennomic. I make educated guess vMaia as normal lock and rewards staker
- Hermes introduction is purely jargon and provide little useful information of how Hermes work.
- Talos is Uniswap porfolio contracts. Give rewards to staker for holding.
- Ulysses does not explain **Virtualized** and **Unified** Liquidity
- area of convern show omnichain keyword. That explain multichain part of unified liquidity. Look at how token transfered between chain and how protocol payback to user accross chain.
- The idea of holding uniswap token on multiple chain sound just dumb. Why dont let user just bridge token themself and deposit into Maya directly. Unless portfolio hold uniswap position in multiple chain.
- First time read about ve(3,3) model. There must be a reason why it was not more popular. If this come from Yearn and the only project exist is Fantom chain.
- Ulysses pools on one chain and receive token from multiple chain bridge?
### Thing to actively lookout for

- Hermes use uniswap staker logic. Q128 uniswap always have funny implemenation
- I do not know how uniswap staker v3 math work. Need to spend time look at it
- ve(3,3) curve model. User bond their token for locked hermes at discount price. Basiccaly staking and rewards
- No information where Hermes come from. Where user get it?
- Curve Locking basically just governent power. You have more money then you can choose where all rewards move to. If Hermes also include ve(3,3) then it raise the question where all rewards come from. What push up hermes value. The hype or uniswap rewards.
- "Lock gov token" to get OP inflation rewards? Where user get gov token then. what does rewards token do? Why user lock permanent position do not warry of inflation of new token in the market. I assume lock token price do not go down. So when it will go down.
- AnyCall implementation
- Any 3rd party app use Chainlink Oracle share price with TWAP oracle

## Audit

- From this order: Hermes -> Maia -> Talos -> Ulysses

###  Scouting
- Solady contract is written by a bunch student. Audit by a bunch of student in Czech. Writing test contract in Woke python test framework does not bode well.
- ẺC4626 use solady library assembly code instead of original solmate library. Solady is unaudited. Assembly code transfer and math library look like it is full of dirtybit. Solmate is known to have dirty bit leftover for some of function call. MultiToken call assembly code in a loop look like hot spot for assembly code dirty bit hack if it exist.
- Test case is only unit test. No system-testing
- Giveup on understanding minor change of Boost, Gauge base abstract contract. Wait till understand bigger picture before writing fuzzing test case working specifically with inflated vote manipulation.
### Basic

1. What did you learn from reviewing this codebase? Be specific.
2. What approach did you take in evaluating this codebase in order to help you grow your skills and code review resources?
3. How much time did you spend?

### Advanced

- Analysis of the codebase (What's unique? What's using existing patterns?)
- Architecture feedback
- Centralization risks
- Systemic risks
- Other recommendations
- How much time did you spend?
