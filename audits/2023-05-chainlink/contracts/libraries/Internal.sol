// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Client} from "./Client.sol";
import {MerkleMultiProof} from "../libraries/MerkleMultiProof.sol";

// Library for CCIP internal definitions common to multiple contracts.
library Internal {
  struct PriceUpdates {
    TokenPriceUpdate[] tokenPriceUpdates;
    uint64 destChainSelector; // --┐ Destination chain Id
    uint192 usdPerUnitGas; // -----┘ USD per unit of destination chain gas
  }

  struct TokenPriceUpdate {
    address sourceToken; // Source token
    uint192 usdPerToken; // USD per unit of token
  }

  struct TimestampedUint192Value {
    uint192 value; // -------┐ The price, in USD with 18 decimals.
    uint64 timestamp; // ----┘ Timestamp of the most recent price update.
  }

  struct PoolUpdate {
    address token; // The IERC20 token address
    address pool; // The token pool address
  }

  struct ExecutionReport {
    uint64[] sequenceNumbers;
    bytes[] encodedMessages;//EVM2EVMMessage
    // Contains a bytes array for each message
    // each inner bytes array contains bytes per transferred token
    bytes[][] offchainTokenData;
    bytes32[] proofs;
    uint256 proofFlagBits;
  }

  // @notice The cross chain message that gets committed to EVM chains
  struct EVM2EVMMessage {
    uint64 sourceChainSelector;// OnRamp chainSelector
    uint64 sequenceNumber;//OnRamp unique per chain
    uint256 feeTokenAmount;// router calculation
    address sender;// msg.sender
    uint64 nonce;//OnRamp unique per sender increment counter
    uint256 gasLimit;//user input
    bool strict;//user input
    // User fields
    address receiver;// user input
    bytes data;// user input //@audit what is the data for EVM2EVMMessage
    Client.EVMTokenAmount[] tokenAmounts;// user input
    address feeToken;// user input.Fee already been pay onRamp. whitelisted by OnRamp for each chain
    bytes32 messageId;//hashed by OnRamp unique hash for each chain and onRamp address
  }

  function _toAny2EVMMessage(
    EVM2EVMMessage memory original,
    Client.EVMTokenAmount[] memory destTokenAmounts
  ) internal pure returns (Client.Any2EVMMessage memory message) {
    message = Client.Any2EVMMessage({
      messageId: original.messageId,
      sourceChainSelector: original.sourceChainSelector,
      sender: abi.encode(original.sender),
      data: original.data,
      destTokenAmounts: destTokenAmounts
    });
  }

  bytes32 internal constant EVM_2_EVM_MESSAGE_HASH = keccak256("EVM2EVMMessageEvent");

  function _hash(EVM2EVMMessage memory original, bytes32 metadataHash) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          MerkleMultiProof.LEAF_DOMAIN_SEPARATOR,
          metadataHash,//keccak ancode ( EVM_2_EVM_MESSAGE_HASH, onRampchainID,offRampChainID, onRampAddress)
          original.sequenceNumber,//onRamp unique per chain
          original.nonce,//onRamp sender unique 
          original.sender,//msg.sender
          original.receiver,//user
          keccak256(original.data),//user limited size
          keccak256(abi.encode(original.tokenAmounts)),//
          original.gasLimit,
          original.strict,
          original.feeToken,
          original.feeTokenAmount
        )// not hashing messageId struct
      );
  }

  /// @notice Enum listing the possible message execution states within
  /// the offRamp contract.
  /// UNTOUCHED never executed
  /// IN_PROGRESS currently being executed, used a replay protection
  /// SUCCESS successfully executed. End state
  /// FAILURE unsuccessfully executed, manual execution is now enabled.
  enum MessageExecutionState {
    UNTOUCHED,
    IN_PROGRESS,
    SUCCESS,
    FAILURE
  }
}
