// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import { Calls } from "./Calls.sol";

import { ReentrancyGuard } from "./ReentrancyGuard.sol";
import { IAccount, PackedUserOperation } from "./interfaces/IAccount.sol";
import { IERC1271_MAGIC_VALUE_HASH } from "./interfaces/IERC1271.sol";
import { IEntryPoint } from "./interfaces/IEntryPoint.sol";

/// @title ERC4337v07
/// @author Agustin Aguilar, Michael Standen
/// @notice ERC4337 v7 support
abstract contract ERC4337v07 is ReentrancyGuard, IAccount, Calls {
//@only ERC4337 interact with EntryPoint v0.7.0
  uint256 internal constant SIG_VALIDATION_FAILED = 1;//@audit where is the wallet owner? It have signature check against whom.

  address public immutable entrypoint;

  error InvalidEntryPoint(address _entrypoint);
  error ERC4337Disabled();

  constructor(
    address _entrypoint
  ) {
    entrypoint = _entrypoint;
  }
// @EntryPoint consider this contract as call sender. Same as EOA call a tx. Someone can mimic sender address though, except have signature.
  /// @inheritdoc IAccount
  function validateUserOp(//@simulation call still success and later call will revert when run initcode though. Not part of project
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
  ) external returns (uint256 validationData) {
    if (entrypoint == address(0)) {
      revert ERC4337Disabled();
    }

    if (msg.sender != entrypoint) {
      revert InvalidEntryPoint(msg.sender);
    }

    // userOp.nonce is validated by the entrypoint

    if (missingAccountFunds != 0) {//@paymaster are part of hash, so signature never change
      IEntryPoint(entrypoint).depositTo{ value: missingAccountFunds }(address(this));
    }//@do wallet have function to withdraw deposit? It can run any external calls though
//@this signature check also reuse old signature if approved to some address,caller.
    if (this.isValidSignature(userOpHash, userOp.signature) != IERC1271_MAGIC_VALUE_HASH) {//@signatureValidation(Payload.fromDigest(_hash), _signature);
      return SIG_VALIDATION_FAILED;//@hash include gas fee, gas limit, whom pay? nonce,sender to EntryPoint
    }//@entry can use signature signed by user and verify it. Then send and receive back cash to user.
    //@note Only abuser of EntryPoint can only be paymaster, transaction sender whom abuse to have max gas fee limit. which is unlikely to happen.
    return 0;
  }

  /// @notice Execute a user operation
  /// @param _payload The packed payload
  /// @dev This is the execute function for the EntryPoint to call.
  function executeUserOp(
    bytes calldata _payload//@fixed payload data. EntryPoint prevent weird data
  ) external nonReentrant {
    if (entrypoint == address(0)) {
      revert ERC4337Disabled();
    }

    if (msg.sender != entrypoint) {
      revert InvalidEntryPoint(msg.sender);
    }

    this.selfExecute(_payload);
  }

}
