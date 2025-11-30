// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import { Calls } from "./modules/Calls.sol";
import { Payload } from "./modules/Payload.sol";

import { LibBytes } from "./utils/LibBytes.sol";
import { LibOptim } from "./utils/LibOptim.sol";

/// @title Guest
/// @author Agustin Aguilar, William Hua, Michael Standen
/// @notice Guest for dispatching calls https://etherscan.io/address/0x0000000000601fca38f0cca649453f6739436d6c#code
contract Guest {

  using LibBytes for bytes;

  /// @notice Error thrown when a delegate call is not allowed
  error DelegateCallNotAllowed(uint256 index);

  /// @notice Fallback function
  /// @dev Dispatches the guest call
  fallback() external payable {
    Payload.Decoded memory decoded = Payload.fromPackedCalls(msg.data);
    bytes32 opHash = Payload.hash(decoded);
    _dispatchGuest(decoded, opHash);
  }

  function _dispatchGuest(Payload.Decoded memory _decoded, bytes32 _opHash) internal {
    bool errorFlag = false;

    uint256 numCalls = _decoded.calls.length;
    for (uint256 i = 0; i < numCalls; i++) {//1. call factory to deploy wallet with salt
      Payload.Call memory call = _decoded.calls[i];//2. execute call to wallet. wallet proxy to Stage1Module.execute()
                                                    //3. wallet execute call to TrailsMulticall3Router. this transaction just pay relay
      // Skip onlyFallback calls if no error occurred //4. wallet execute Sweep token through delegate
      if (call.onlyFallback && !errorFlag) {
        emit Calls.CallSkipped(_opHash, i);
        continue;
      }

      // Reset the error flag
      // onlyFallback calls only apply when the immediately preceding transaction fails
      errorFlag = false;

      uint256 gasLimit = call.gasLimit;
      if (gasLimit != 0 && gasleft() < gasLimit) {
        revert Calls.NotEnoughGas(_decoded, i, gasleft());
      }

      if (call.delegateCall) {
        revert DelegateCallNotAllowed(i);
      }

      bool success = LibOptim.call(call.to, call.value, gasLimit == 0 ? gasleft() : gasLimit, call.data);
      if (!success) {
        if (call.behaviorOnError == Payload.BEHAVIOR_IGNORE_ERROR) {
          errorFlag = true;
          emit Calls.CallFailed(_opHash, i, LibOptim.returnData());
          continue;
        }

        if (call.behaviorOnError == Payload.BEHAVIOR_REVERT_ON_ERROR) {
          revert Calls.Reverted(_decoded, i, LibOptim.returnData());
        }

        if (call.behaviorOnError == Payload.BEHAVIOR_ABORT_ON_ERROR) {
          emit Calls.CallAborted(_opHash, i, LibOptim.returnData());
          break;
        }
      }

      emit Calls.CallSucceeded(_opHash, i);
    }
  }

}//Multicall https://etherscan.io/address/0xcA11bde05977b3631167028862bE2a173976CA11#code
//0x174dea71 Call3Value
//0000000000000000000000000000000000000000000000000000000000000020
//0000000000000000000000000000000000000000000000000000000000000001
//0000000000000000000000000000000000000000000000000000000000000020
//000000000000000000000000a5f565650890fba1824ee0f21ebbbf660a179934 target // Relay receiver
//0000000000000000000000000000000000000000000000000000000000000000
//0000000000000000000000000000000000000000000000000003f8ec787e636b //value
//0000000000000000000000000000000000000000000000000000000000000080
//0000000000000000000000000000000000000000000000000000000000000020
//97b4ef8092ec3101b13584912deb3f0f5a34582edc95b7be25128b8b21194855 calldata