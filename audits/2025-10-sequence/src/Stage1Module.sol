// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import { Stage2Module } from "./Stage2Module.sol";
import { Calls } from "./modules/Calls.sol";

import { ERC4337v07 } from "./modules/ERC4337v07.sol";
import { Hooks } from "./modules/Hooks.sol";
import { Stage1Auth } from "./modules/auth/Stage1Auth.sol";
import { IAuth } from "./modules/interfaces/IAuth.sol";

/// @title Stage1Module
/// @author Agustin Aguilar
/// @notice The initial stage of the wallet
contract Stage1Module is Calls, Stage1Auth, Hooks, ERC4337v07 {
//https://github.com/0xsequence/wallet-contracts-v3/blob/master/docs/CHAINED.md
  constructor(
    address _factory,
    address _entryPoint//EntryPoint 0.7.0 v0.8.23   https://etherscan.io/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032#code
  ) Stage1Auth(_factory, address(new Stage2Module(_entryPoint))) ERC4337v07(_entryPoint) { }

  /// @inheritdoc IAuth
  function _isValidImage(
    bytes32 _imageHash
  ) internal view virtual override(IAuth, Stage1Auth) returns (bool) {
    return super._isValidImage(_imageHash);//@contract salt is hash too
  }

}
