# SuiDEX

A comprehensive decentralized exchange (DEX) ecosystem built on the Sui blockchain featuring automated market makers (AMM), yield farming, token locking mechanisms, and sophisticated emission controls.

## 🚀 Overview

SuiDEX is a full-featured DeFi protocol that provides:

- **Automated Market Maker (AMM)** - Uniswap V2-style liquidity pools
- **Yield Farming** - Stake LP tokens and single assets to earn Victory tokens
- **Token Locking** - Lock Victory tokens for enhanced rewards with multiple time periods
- **Global Emission Controller** - Sophisticated 156-week emission schedule with decay mechanics
- **Revenue Sharing** - SUI revenue distribution to token lockers based on lock periods

## 🏗️ Architecture

### Core Contracts

1. **Factory** (`factory.move`) - Creates and manages trading pairs
2. **Pair** (`pair.move`) - Individual AMM pools with swap functionality
3. **Router** (`router.move`) - User-friendly interface for swaps and liquidity operations
4. **Library** (`library.move`) - Mathematical utilities for AMM calculations
5. **Farm** (`suifarm.move`) - Yield farming with LP and single asset staking
6. **Victory Token** (`victorytoken.move`) - Native reward token (6 decimals)
7. **Token Locker** (`token_locker.move`) - Lock Victory tokens for enhanced rewards
8. **Global Emission Controller** (`global_emission_controller.move`) - Controls emission schedules
9. **Fixed Point Math** (`fixed_point_math.move`) - High-precision mathematical operations

### Key Features

#### 🔄 Trading & Liquidity
- **Constant Product AMM** with 0.3% trading fees
- **Multi-hop swaps** through intermediate tokens
- **Slippage protection** and deadline enforcement
- **Dynamic fee distribution** (LP providers, team, locker, buyback)

#### 🌾 Yield Farming
- **LP Token Staking** - Earn Victory tokens by providing liquidity
- **Single Asset Staking** - Stake individual tokens (phases out over time)
- **Dynamic Allocation System** - Adjustable reward distribution
- **Anti-gaming Mechanisms** - Prevents manipulation and ensures fair distribution

#### 🔒 Token Locking
- **Multiple Lock Periods**: 7 days, 90 days, 365 days, 1095 days (3 years)
- **Enhanced Rewards** - Longer locks receive higher allocation percentages
- **SUI Revenue Sharing** - Weekly distribution based on protocol fees
- **Presale Integration** - Admin functions for automatic lock creation

#### 📈 Emission System
- **156-Week Schedule** - 3-year emission program
- **Bootstrap Phase** - Higher initial rewards (weeks 1-4)
- **Decay Mechanism** - 1% weekly reduction after week 5
- **Phase Transitions** - Gradual shift from single asset to LP focus

## 🛠️ Installation & Setup

### Prerequisites

```bash
# Install Sui CLI (version 1.49.1-3b1d6b3bd63f or later)
curl -fLJO https://github.com/MystenLabs/sui/releases/download/mainnet-v1.49.1/sui-mainnet-v1.49.1-ubuntu-x86_64.tgz
tar -xzf sui-mainnet-v1.49.1-ubuntu-x86_64.tgz
sudo mv sui /usr/local/bin/
```

### Clone and Build

```bash
git clone <repository-url>
cd suidex_contract
sui move build
```

### Running Tests

```bash
# Run all tests (127 test cases)
sui move test

# Run specific test module
sui move test --filter farm_emission_integration_test

# Run with verbose output
sui move test -v
```

### Deployment

```bash
# Deploy to devnet
sui client publish --gas-budget 500000000

# Setup pools and admin configuration
chmod +x complete_dex_setup.sh
./complete_dex_setup.sh
```

## 📊 Emission Schedule

### Phase 1: Bootstrap (Weeks 1-4)
- **Rate**: 6.6 Victory/second
- **Allocations**: 
  - LP Staking: 65%
  - Single Staking: 15%
  - Victory Locking: 17.5%
  - Development: 2.5%

### Phase 2: Post-Bootstrap (Weeks 5-156)
- **Initial Rate**: 5.47 Victory/second (Week 5)
- **Decay**: 1% per week
- **Dynamic Allocations**: Gradually phases out single asset rewards

### Lock Period Allocations (Victory Rewards)
- **7-day locks**: 2% of Victory emissions
- **90-day locks**: 8% of Victory emissions  
- **365-day locks**: 25% of Victory emissions
- **1095-day locks**: 65% of Victory emissions

### SUI Revenue Distribution
- **7-day locks**: 10% of weekly SUI revenue
- **90-day locks**: 20% of weekly SUI revenue
- **365-day locks**: 30% of weekly SUI revenue
- **1095-day locks**: 40% of weekly SUI revenue

## 🔧 Configuration

### Fee Structure
```
Trading Fees: 0.3% total
├── LP Providers: 0.15%
├── Team Fees: 0.06%
├── Locker Fees: 0.03%
└── Buyback Fees: 0.03%
```

### Farm Deposit/Withdrawal Fees
- Configurable per pool (max 10%)
- Distribution: 40% burn, 40% locker, 10% team, 10% dev

## 🔐 Security Features

### Access Controls
- **Admin Capabilities** - Multi-signature recommended for production
- **Timelock Mechanisms** - Prevents immediate parameter changes
- **Emission Validation** - Strict checks on reward calculations

### Anti-Gaming Measures
- **Full Week Staking** - Must stake before epoch starts for SUI rewards
- **Minimum Claim Intervals** - Prevents spam claiming
- **Balance Validation** - Comprehensive vault integrity checks

### Overflow Protection
- **Safe Arithmetic** - Uses u128 intermediates for large calculations
- **Bounds Checking** - Validates all inputs and state transitions
- **Fixed Point Math** - High-precision calculations prevent rounding errors

## 📚 Usage Examples

### Trading

```move
// Swap exact tokens for tokens
router::swap_exact_tokens0_for_tokens1<TokenA, TokenB>(
    &router,
    &factory,
    &mut pair,
    coin_a,
    min_amount_out,
    deadline,
    ctx
);
```

### Liquidity Provision

```move
// Add liquidity to pool
router::add_liquidity<TokenA, TokenB>(
    &router,
    &mut factory,
    &mut pair,
    coin_a,
    coin_b,
    amount_a_desired,
    amount_b_desired,
    amount_a_min,
    amount_b_min,
    token_a_name,
    token_b_name,
    deadline,
    ctx
);
```

### Farming

```move
// Stake LP tokens
farm::stake_lp<TokenA, TokenB>(
    &mut farm,
    &mut vault,
    lp_tokens,
    amount,
    &global_config,
    &clock,
    ctx
);
```

### Token Locking

```move
// Lock Victory tokens
token_locker::lock_tokens(
    &mut locker,
    &mut locked_vault,
    victory_tokens,
    lock_period, // WEEK_LOCK, THREE_MONTH_LOCK, YEAR_LOCK, THREE_YEAR_LOCK
    &global_config,
    &clock,
    ctx
);
```

## 🧪 Testing

The project includes comprehensive test coverage:

```bash
Test result: OK. Total tests: 127; passed: 127; failed: 0
```

### Test Categories
- **Unit Tests** - Individual contract functionality
- **Integration Tests** - Cross-contract interactions
- **Emission Tests** - Complex reward calculations
- **Edge Case Tests** - Boundary conditions and error handling

## 📈 Monitoring & Analytics

### Key Metrics to Track
- **Total Value Locked (TVL)** - Across all pools and farms
- **Daily Trading Volume** - Per pair and aggregate
- **Emission Rate** - Current Victory tokens per second
- **Lock Distribution** - Percentage across different time periods
- **Revenue Generation** - SUI fees collected for distribution

### Events for Indexing
All contracts emit comprehensive events for off-chain tracking:
- `Swap`, `LPMint`, `LPBurn` - Trading activity
- `Staked`, `Unstaked`, `RewardClaimed` - Farming activity  
- `TokensLocked`, `TokensUnlocked` - Locking activity
- `WeeklyRevenueAdded` - Revenue distribution

## 🚨 Important Disclaimers

### ⚠️ PRODUCTION DEPLOYMENT WARNING

**CRITICAL NOTICE**: This smart contract code is provided as-is for educational and development purposes. 

### Risk Acknowledgment

By deploying, using, or interacting with these contracts on mainnet or any production environment, you acknowledge and accept the following risks:

#### 🔴 Financial Risk
- **TOTAL LOSS OF FUNDS**: Smart contracts may contain bugs, vulnerabilities, or design flaws that could result in permanent loss of all deposited assets
- **NO INSURANCE**: There is no deposit insurance or guarantee of fund recovery
- **MARKET RISK**: Token values can fluctuate dramatically, potentially resulting in significant financial losses

#### 🔴 Technical Risk  
- **AUDIT STATUS**: These contracts have NOT undergone professional security audits
- **BUG BOUNTY**: No formal bug bounty program exists
- **COMPLEXITY RISK**: The protocol involves complex mathematical operations and cross-contract interactions that increase the risk of unexpected behavior

#### 🔴 Operational Risk
- **ADMIN KEYS**: Admin capabilities exist that could be compromised or misused
- **UPGRADE RISK**: Contract upgrades or parameter changes could negatively impact your position
- **ORACLE RISK**: Any external data dependencies could fail or be manipulated

### Limitation of Liability

**Stack Meridian and all contributors to this codebase explicitly disclaim all liability for:**

- Any financial losses incurred through use of these contracts
- Any bugs, exploits, or vulnerabilities discovered in the code
- Any failure of the protocol to perform as expected
- Any losses due to user error, network issues, or external factors
- Any regulatory or legal issues arising from protocol usage

### Use at Your Own Risk

**YOU ASSUME ALL RISKS** associated with using this protocol. This includes but is not limited to:
- Smart contract risk
- Economic risk  
- Technical risk
- Regulatory risk
- Operational risk

### Recommendation

Before using in production:
1. **Conduct thorough security audits** with reputable firms
2. **Implement comprehensive testing** on testnets
3. **Start with limited funds** to test functionality
4. **Have emergency procedures** for fund recovery
5. **Obtain proper legal advice** regarding regulations in your jurisdiction

### No Support Guarantee

While we strive to maintain and improve the codebase, we provide **NO GUARANTEE** of ongoing support, maintenance, or bug fixes.

## 📜 License

### MIT License

Copyright (c) 2024 Stack Meridian

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

### Additional Terms

1. **Attribution Required**: Any deployment or fork must maintain attribution to Stack Meridian
2. **Disclaimer Preservation**: The risk disclaimers must be preserved in any distribution
3. **No Trademark License**: This license does not grant rights to use Stack Meridian trademarks

## 🤝 Contributing

We welcome contributions! Please:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Run all tests** (`sui move test`)
4. **Commit changes** (`git commit -m 'Add amazing feature'`)
5. **Push to branch** (`git push origin feature/amazing-feature`)
6. **Open a Pull Request**

### Code Standards
- Follow Move coding conventions
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure all tests pass before submitting

## 📞 Contact & Support

### Stack Meridian
- **Website**: [[Stack Meridian](https://stackmeridian.com/)]
- **Documentation**: [Repository Wiki]
- **Issues**: Use GitHub Issues for bug reports
- **Discussions**: Use GitHub Discussions for questions

### Community
- **Telegram**: [Coming Soon]
- **Discord**: [Coming Soon]  
- **Twitter**: [Coming Soon]

## 🗺️ Roadmap

### Phase 1: Core Infrastructure ✅
- [x] AMM with multi-hop swaps
- [x] Yield farming system
- [x] Token locking mechanisms
- [x] Emission controller

### Phase 2: Advanced Features 🚧
- [ ] Governance system
- [ ] Advanced order types
- [ ] Cross-chain bridges
- [ ] Mobile application

### Phase 3: Enterprise Features 🔮
- [ ] Institutional tools
- [ ] Advanced analytics
- [ ] API for integrators
- [ ] White-label solutions

---

## ⭐ Acknowledgments

Special thanks to:
- **Sui Foundation** for the excellent blockchain infrastructure
- **Uniswap Labs** for pioneering AMM design patterns
- **OpenZeppelin** for security best practices
- **Move Language Community** for comprehensive documentation

---

**Built with ❤️ by Stack Meridian**

*Making DeFi accessible, secure, and profitable for everyone.*