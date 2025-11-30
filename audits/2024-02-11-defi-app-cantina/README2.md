Defi App is solving crypto’s main UX problem via a “SuperDapp” that will make CEXs obsolete. Through the use of account abstraction and integration to advanced DeFi infrastructure we can abstract complexity and let users have a delightful experience when swapping into any asset on any chain (including SOL) in <30 seconds, accessing DeFi best yield products, trading with leverage, farming points from the latest new protocols, and fiat on & off ramping.

The scope of this audit competition is reviewing a staking flywheel mechanism that will be launched along the TGE of the $HOME token of DefiApp. The staking mechanism is comprised of four main contracts:

    DefiAppStaker.sol: responsible for handling the core logic of staking (or so called user “locks”), including the logic of a reward distribution system for those stakers.
    DefiAppHomeCenter.sol: responsible for handling the logic of the distribution of $HOME emissions in an epoch mode, making use of merkleTrees. In the future this contract will be extended (and re-audited) to include bribe-and-voting mechanics.
    DLockZap.sol: responsible for facilitating “zapping” operations into DefiAppStaker.sol.
    VolatileAMMPoolHelper.sol: responsible for handling interfacing logic with Aerodrome.

Prize Distribution and Scoring

    Total Prize Pool: $25,000

Scoring described in the competition scoring page.

Findings Severities described in detail on our docs page.
Documentation

    Code walkthrough

DefiApp Staking Mechanics

    Goals of the Staking Mechanics
        Create DEX liquidity for the HOMEtokenandprogressivelyincreasetheHOMEtokenandprogressivelyincreasetheHOME token liquidity while distributing ownership of DeFiApp.
        Promote swapping volume within DefiApp.
        Promote increase of Total Value Locked (TVL) for DefiApp partner DeFi protocols.
        Future Goal: Implement bribing-voting mechanics that allow for boosting, which can incentivize performing “actions” that favor the DefiApp ecosystem of partners, including making use of specific partner DeFi protocol(s) or swapping of a specific token(s) as example.
        Distribute value to aligned $HOME token holders.

    Staking Mechanics Flywheel Diagram
        Defi-app

    Core Smart contract functionality

    Methods by actor: User
        DLockZap.zap(...): allows a user to "zap" tokens directly into the staker contract. The inner logic handles the lp-ing.
        DefiAppStaker.stake(...): allows a user to directly stake liquidity provision tokens (lp) in the staker contract. Each call creates a "lock". A “lock” consists of a specific amount of token locked for a specified amount of time with a known expiration.
        DefiAppStaker.claimRewards(...) or DefiAppStaker.claimAll(...): allows a user to claim any earned rewards distributed to stakers. Note that rewards are different than emissions; were emissions or Home token as specifically distributed in the DefiAppHomeCenter.sol contract.
        DefiAppStaker.relockExpiredLocks(...): allows a user to relock an expired lock. DefiAppStaker.withdrawExpiredLocks(...): allows a user to withdraw an expired lock and receive the lp token back.
        DefiAppHomeCenter.claim(...): allows a user to claim emission tokens for a specific epoch with option to directly stake.
        DefiAppHomeCenter.claimMulti(...): allows a user to claim emission tokens for multiple epochs with option to directly stake.

    Methods by actor: Admin (for all purpose consider Admin a multisig with various signers and an intermediary timelock to execute txs)
        DLockZap.setMfd(...): Sets reference to the active DefiAppStaker.sol contract.
        DLockZap.setPoolHelper(...): Sets reference to the VolatileAMMPoolHelper.sol that helps interfacing with Aerodrome pool and gauge.
        DefiAppStaker.setHomeCenter(...): Sets reference to the DefiAppHomeCenter.sol
        DefiAppStaker.setGauge(...): Sets reference to the DefiAppHomeCenter.sol
        DefiAppStaker.setDefaultLockIndex(...): Sets the standard lock durations available
        DefiAppStaker.setRewardDistributors(...): Sets the address(es) allowed to add and remove rewards to the DefiAppStaker.sol contract. Rewards are those to be distributed to stakers.
        DefiAppStaker.setRewardStreamParams(...): Sets the parameters for streaming rewards to stakers.
        DefiAppStaker.setOperationExpenses(...): Sets the address that receives and the percentage of rewards dedicated to operational expenses.
        DefiAppHomeCenter.setDefaultRps(...): Sets the rate at which emission token is distributed in the epoch.
        DefiAppHomeCenter.setDefaultEpochDuration(...): Sets the time length of an epoch. Only affecting the upcoming epoch. setVoting(...): Sets voting is active when features gets built and enabled.
        DefiAppHomeCenter.setMintingActive(...): Configuration param that indicates the DefiAppHomeCenter.sol contract that emission token is distributed by minting.
        DefiAppHomeCenter.setPoolHelper(...): Sets reference to the VolatileAMMPoolHelper.sol that helps interfacing with Aerodrome pool and gauge.
        DefiAppHomeCenter.settleEpoch(...): Sets the merkleroot to allow claiming of a finished epoch pending to distribute emission tokens to users who should be eligible.

    General Notes and remarks:
        DefiAppHomeCenter and DefiAppStaker are upgradeable to allow future implementation of a voting-bribing mechanism.
        VolatileAMMPoolHelper facilitates interfacing with Aerodrome’s VAMMs pools.
        Home is the token that will be launched on the Base L2 network.
        Home maintains bridge compatibility according to LayerZero OFT2 Token specification.
        DefiAppHomeCenter is a distribution system for the Home token and determination of epoch allocation is an off-chain system done via points.

Scope

    Repository: https://github.com/cantina-competitions/defi-app-contracts

    Files:

    src
        DefiAppHomeCenter.sol
        DefiAppStaker.sol
        dependencies
            DLockZap.sol
            MultiFeeDistribution
                MFDBase.sol
                MFDDataTypes.sol
                MFDLogic.sol
            UAccessControl.sol
            helpers
                DustRefunder.sol
                RecoverERC20.sol
                TransferHelper.sol
            everything in libraries
        everything in interfaces/
        libraries
            DefiAppDataTypes.sol
            EpochDistributor.sol
            StakeHelper.sol
        periphery
            VolatileAMMPoolHelper.sol
        token
            Home.sol
            PublicSale.sol
            VestingManager.sol

Build Instructions

Clone repository

git clone https://github.com/cantina-competitions/defi-app-contracts

Install dependencies

forge install

Compile contracts

forge build

Test a file, optionally a specific test in the file

forge test --mp <path-to-your-test-file> --mt <test-function-name>

Basic POC Test

Use the POC_Test.t.sol file to build a POC of the vulnerability, or build your own file using available fixtures of mocks shown below:

    test
        BasicFixture.t.sol
        POC_Test.t.sol
        PublicSaleFixture.t.sol
        StakingFixture.t.sol
        mocks
            MockOracleRouter.t.sol
            MockToken.t.sol
            MockUsdc.t.sol
            MockWeth9.t.sol
            aerodrome
                MockAerodromeFixture.t.sol
                MockFactoryRegistry.t.sol
                MockGauge.t.sol
                MockGaugeFactory.t.sol
                MockPool.t.sol
                MockPoolFactory.t.sol
                MockPoolFees.t.sol
                MockRouter.t.sol
                MockVe.t.sol
                MockVoter.t.sol
                libraries
                    ProtocolTimeLibrary.t.sol

Out of scope:

    Lightchaser report https://gist.github.com/ChaseTheLight01/00637b1b50647f1feced3ac0e72dd4ff

Contact Us

For any issues or concerns regarding this competition, please reach out to the Cantina core team through the Cantina Discord.