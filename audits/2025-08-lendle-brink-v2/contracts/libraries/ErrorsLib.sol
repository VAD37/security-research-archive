// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library ErrorsLib {
    /// @notice Error thrown when a zero address is provided
    error ZERO_ADDRESS();

    /// @notice Error thrown when a zero amount is provided
    error ZERO_AMOUNT();

    /// @notice Error thrown when a zero byte array is provided
    error ZERO_BYTES();

    /// @notice Error thrown when the number of strategies is zero
    error ZERO_STRATEGIES();

    /// @notice Error thrown when array lengths do not match
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Error thrown when the asset address does not match
    error ASSET_MISMATCH();

    /// @notice Error thrown when a strategy already exists
    error DUPLICATE_STRATEGY(address strategy);
}