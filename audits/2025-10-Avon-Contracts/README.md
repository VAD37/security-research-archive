# avon-monorepo

Avon is building an entirely new way to borrow and lend on chain via lending infrastructure designed for efficiency, composability, and real-time dynamics. We combine the granularity of an order book with programmable lending markets (strategies), bringing true market dynamics to onchain lending. Avon enables competitive rates, real-time price discovery and flexible lending terms (expressivity).
Note

To participate in this competition please sign the following NDA: Avon NDA
Prize distribution and scoring

    Total Prize Pool: $36,000

    The total prize pool distribution has 2 possible triggers:
        If one or more valid medium severity findings are found, the total pot size is $10,000
        If one or more valid high severity findings are found, the total pot size is $36,000

    Scoring described in the competition scoring page.

    Findings Severities described in detail on our docs page.

Documentation

    [Overview](http://docs.avon.xyz)
    Core readme
    Core other docs
    Periphery readme
    Periphery other docs

Scope

Avon Periphery

    Repository: https://cantina.xyz/code/708eecf5-a6a0-46c1-a949-277f7408decc/avon-periphery/README.md
    Total LOC: 2360
    Files: Everything included in ./src/

Avon Core

    Repository: https://cantina.xyz/code/708eecf5-a6a0-46c1-a949-277f7408decc/avon-core/README.md
    Total LOC: 1740
    Files: Everything included in ./src/

Out of scope

    Core out of scope: avon-core/audit
    Periphery out of scope: avon-periphery/audit
    Known Issues
    LightChaser Findings

Build Instructions

Avon-periphery

cd avon-periphery	forge build	forge test

Avon-core

cd avon-core	forge build	forge test

Basic POC test

Mandatory POC rule applies for this competition ./test/POC.t.sol Can be used for creating poc
Contact Us

For any issues or concerns regarding this competition, please reach out to the Cantina core team through the Cantina Discord.