# analyzing

Do an audit on current smart contract project.
Does not follow read Readme.md first, but follow wild picking search for pattern first.

## Checklist

- [ ] follow GIP test file. Going through each smart contract one by one to see each one how it work.
- [ ] contract need initialization by Governor. Can contracts run without init? Is there enough check to prevent init error

## Notes

- 2 token. GUILD Token for control and CREDIT token for loan
- access control use immutable singleton. Both Role and singleton can change later by governor.
- Governor/multisig have payable multicall on all contracts.

## Contracts

- `Library` CoreRoles: keccak role for OZ access control
- `Main` Core: Setup role
- `abstract` CoreRef: inherit to get access control from Core.
- `Main` ProfitManager: config profit distribution. Holding token.

## Access control

```mermaid
graph LR
%% comment {{}} for role inside coreRoles
%% comment () for contract, [] for EOA
Governor{{Governor}}
Governor --> Guardian{{Guardian}}
%% TokenSupply
Governor --> CreditMinter{{CreditMinter}}
Governor --> GuildMinter{{GuildMinter}}
Governor --> RateLimitedCreditMinter{{RateLimitedCreditMinter}}
Governor --> RateLimitedGuildMinter{{RateLimitedGuildMinter}}
%% GUILD token manager
Governor --> GaugeAdder{{GaugeAdder}}
Governor --> GaugeRemover{{GaugeRemover}}
Governor --> GaugeParameterManager{{GaugeParameterManager}}
Governor --> GaugePNLNotifier{{GaugePNLNotifier}}
Governor --> GuildGovernanceManager{{GuildGovernanceManager}}
Governor --> GuildSurplusBufferWithdraw{{GuildSurplusBufferWithdraw}}
%% Credit token manager
Governor --> CreditGovernanceManager{{CreditGovernanceManager}}
Governor --> CreditRebaseParameters{{CreditRebaseParameters}}
%% timelock
Governor --> TimelockProposer{{TimelockProposer}}
Governor --> TimelockExecutor{{TimelockExecutor}}
Governor --> TimelockCanceller{{TimelockCanceller}}


%% contract controller

DAO((DAOtimeLock)) --> Governor
GuildTimelockController2((DAOonboardTimelock)) --> Governor
LendingTermOffboarding((LendingTermOffboarding)) --> Governor
Gnosis((Gnosis)) --> Guardian
%% CREDIT_MINTER
RateLimitedMinterCredit((RateLimitedMinterCredit)) --> CreditMinter
RateLimitedMinterCredit-->CreditToken
SimplePSM((SimplePSM)) --> CreditMinter
%% RATE_LIMITED_CREDIT_MINTER
TermSDAI((LendingTermOnboarding_SDAI)) --> RateLimitedCreditMinter

%% GUILD_MINTER
RateLimitedMinterGuild((RateLimitedMinterGuild)) --> GuildMinter
RateLimitedMinterGuild-->GuildToken

%% RATE_LIMITED_GUILD_MINTER
SurplusGuildMinter((SurplusGuildMinter)) --> RateLimitedGuildMinter
Gnosis-->RateLimitedGuildMinter
%% Gauge
DAO-->GaugeAdder
GuildTimelockController2-->GaugeAdder

DAO-->GaugeRemover
LendingTermOffboarding-->GaugeRemover

DAO-->GaugeParameterManager
TermSDAI-->GaugePNLNotifier
%% GUILD
DAO-->GuildGovernanceManager
SurplusGuildMinter --> GuildSurplusBufferWithdraw
%% CREDIT
DAO-->CreditGovernanceManager
DAO-->CreditRebaseParameters
SimplePSM --> CreditRebaseParameters
%% timelock
GuildGovernor --> TimelockProposer
LendingTermOnboarding --> TimelockProposer

address_zero --> TimelockExecutor

GuildVetoGovernor_GUSDC --> TimelockCanceller
GuildVetoGovernor_GUSDC_Onboard --> TimelockCanceller
GuildVetoGovernor_GUILD --> TimelockCanceller
GuildVetoGovernor_GUILD_Onboard --> TimelockCanceller
GuildGovernor --> TimelockCanceller
LendingTermOnboarding --> TimelockCanceller
LendingTermOnboarding -.- GuildGovernor_Onboard
```
