// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import "./Wallet.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/// @title Factory
/// @author Agustin Aguilar, Michael Standen https://github.com/0xsequence/live-contracts
/// @notice Factory for deploying wallets 0x00000000000018A77519fcCCa060c2537c9D6d3F 
contract Factory {

  /// @notice Error thrown when the deployment fails
  error DeployFailed(address _mainModule, bytes32 _salt);

  /// @notice Deploy a new wallet instance
  /// @param _mainModule Address of the main module to be used by the wallet
  /// @param _salt Salt used to generate the wallet, which is the imageHash of the wallet's configuration.
  /// @dev It is recommended to not have more than 200 signers as opcode repricing could make transactions impossible to execute as all the signers must be passed for each transaction.
  function deploy(address _mainModule, bytes32 _salt) public payable returns (address _contract) {
    bytes memory code = abi.encodePacked(Wallet.creationCode, uint256(uint160(_mainModule)));//#wallet is just a proxy deletegate to main module
    assembly {
      _contract := create2(callvalue(), add(code, 32), mload(code), _salt)//@allow create wallet with weird module. But so far it have SDK checks
    }
    // _contract = Clones.cloneDeterministic(address(_mainModule), _salt);
    if (_contract == address(0)) {
      revert DeployFailed(_mainModule, _salt);
    }
  }//@audit Factory allow create Module contract wallet, selfdestruct and while have same approval too. Delegate selfdestruct to unique contracts.

}
//Deploy 0x32c02a14
//0x32c02a14 00000000000000000000000000000000000084fa81809dd337311297c5594d62 9e605e57b90f14aa986a54ec32e1b58d87d06dc90c8018a281752166916d4e21
//| deploy | 32c02a14 | deploy(address,bytes32) |
//Stage1ModuleV3 0x00000000000084fA81809Dd337311297C5594d62 also look the same as this project though
//Stage1Module433707V3 0x0000000000005A02E3218e820EA45102F84A35C7  code similar to this project
//running diff see some different but unknown

