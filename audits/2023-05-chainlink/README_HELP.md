# RAMP

The terms "onRamp" and "offRamp" in the context of blockchain technology often refer to methods of getting assets or data into and out of a blockchain network. They are specifically relevant in the field of cross-chain interoperability, which is the ability for different blockchain networks to interact with each other.

In the context of the Cross-Chain Interoperability Protocol (CCIP) you mentioned, "onRamp" and "offRamp" refer to specific contract components that help facilitate cross-chain communication and transactions. Here's a more detailed look at each:

**EVM2EVM OnRamp**

- This contract is lane-specific, meaning there is an onRamp instance for every lane, where a lane represents a path for a message to be securely sent from one blockchain (Chain A) to another (Chain B).
- The OnRamp contract's responsibilities include keeping track of sequence numbers and nonces, performing destination chain-specific validity checks, calculating and charging fees, and interacting with the TokenPool contract if the message includes tokens. It also emits an event (`CCIPSendRequested`) when a cross-chain message is sent.

**EVM2EVM OffRamp**

- The OffRamp contract is also lane-specific. It is the entry point for the Executing Decentralized Oracle Network (DON).
- The OffRamp contract checks if a report is transmitted by an executing DON node, verifies the message authenticity against the committed merkle root in the CommitStore, and ensures that the Active Risk Management Network (ARM) is not stopping message execution.
- It also ensures that the message execution state is valid, releases or mints sent tokens to the receiver, and invokes the destination router.

In summary, the OnRamp is responsible for preparing and initiating cross-chain transactions, while the OffRamp ensures the execution of these transactions on the destination chain.

# Summary

The Cross-Chain Interoperability Protocol (CCIP) provides a standard for developers to create applications that can transmit messages and transfer value across multiple blockchains. It uses a set of contracts and Decentralized Oracle Networks (DONs) to facilitate secure communication from one blockchain to another. Key components of CCIP include:

1. **Source Router**: This serves as the entry and exit point for all CCIP transactions. It initiates the `ccipSend` and handles token approvals.

2. **EVM2EVM OnRamp**: This contract is responsible for maintaining sequenceNumbers and nonces. It also verifies destination chain-specific validity checks and handles fee calculations and token operations.

3. **TokenPools**: These act as an abstraction layer over ERC20 tokens to facilitate token-related operations.

4. **Decentralized Oracle Network (DON)**: This is a Chainlink Decentralized Oracle Network that runs Chainlink OCR2, a BFT protocol among participants.

5. **CommitStore**: This checks if every report is transmitted by a valid Committing DON node and signed by the right number of nodes in the DON. It also stores merkle roots on the destination chain.

6. **EVM2EVM OffRamp**: This checks if a report is transmitted by an executing DON node, ensures that the message is authentic, and that the ARM (Active Risk Management Network) is not stopping message execution.

7. **Destination Router**: This is a fixed address from which ccipReceive calls are made.

Additional components include the PriceRegistry, which keeps pricing information for any token in the system, and the Active Risk Management Network (ARM) which is able to halt the entire CCIP protocol using DON voting. Libraries such as RateLimiter are also included.

The message lifecycle involves approvals, message sending, DON consensus, and message execution. Trust assumptions for this system include owner contracts being controlled by a Committing DON, tokens being audited before being whitelisted, and careful handling of token prices and decimals. The protocol includes detailed specifications for price format and fee calculation. The execution of the message may involve some latency and the gas limit specifies the maximum amount of gas that can be consumed to execute the ccipReceive implementation on the destination blockchain. Unspent gas is not refunded.


- 1 IN-PROGRESS -> 2 FAILURE -> 2 SUCCESS 
- 1 IN-PROGRESS -> 3
