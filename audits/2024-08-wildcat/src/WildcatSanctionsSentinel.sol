// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.20;

import { IChainalysisSanctionsList } from './interfaces/IChainalysisSanctionsList.sol';
import { IWildcatSanctionsSentinel } from './interfaces/IWildcatSanctionsSentinel.sol';
import { WildcatSanctionsEscrow } from './WildcatSanctionsEscrow.sol';

contract WildcatSanctionsSentinel is IWildcatSanctionsSentinel {
  // ========================================================================== //
  //                                  Constants                                 //
  // ========================================================================== //

  bytes32 public constant override WildcatSanctionsEscrowInitcodeHash =
    keccak256(type(WildcatSanctionsEscrow).creationCode);//@audit R Unexpected behaviour.this init must be checked if this is generated before deploy with constant variable. Is this same as deployed on mainnet?

  address public immutable override chainalysisSanctionsList;//@note sanction list is deprecated. but can still be used for abuse

  address public immutable override archController;

  // ========================================================================== //
  //                                   Storage                                  //
  // ========================================================================== //

  TmpEscrowParams public override tmpEscrowParams;

  mapping(address borrower => mapping(address account => bool sanctionOverride))
    public
    override sanctionOverrides;

  // ========================================================================== //
  //                                 Constructor                                //
  // ========================================================================== //

  constructor(address _archController, address _chainalysisSanctionsList) {
    archController = _archController;
    chainalysisSanctionsList = _chainalysisSanctionsList;
    _resetTmpEscrowParams();
  }

  // ========================================================================== //
  //                              Internal Helpers                              //
  // ========================================================================== //

  function _resetTmpEscrowParams() internal {
    tmpEscrowParams = TmpEscrowParams(address(1), address(1), address(1));
  }

  /**
   * @dev Derive create2 salt for an escrow given the borrower, account and asset.
   *      name prefix and symbol prefix.
   */
  function _deriveSalt(
    address borrower,
    address account,
    address asset
  ) internal pure returns (bytes32 salt) {
    assembly {//@ why?
      // Cache free memory pointer
      let freeMemoryPointer := mload(0x40)
      // `keccak256(abi.encode(borrower, account, asset))`//@not encode packed.
      mstore(0x00, borrower)//@audit M dirty bit exist. Did this pass-through into internal function?
      mstore(0x20, account)
      mstore(0x40, asset)
      salt := keccak256(0, 0x60)//@audit R double check keccak result and abi.encode due to zero padding with memory
      // Restore free memory pointer
      mstore(0x40, freeMemoryPointer)
    }
  }

  // ========================================================================== //
  //                              Sanction Queries                              //
  // ========================================================================== //

  /**
   * @dev Returns boolean indicating whether `account` is sanctioned on Chainalysis.
   */
  function isFlaggedByChainalysis(address account) public view override returns (bool) {
    return IChainalysisSanctionsList(chainalysisSanctionsList).isSanctioned(account);
  }

  /**
   * @dev Returns boolean indicating whether `account` is sanctioned on Chainalysis
   *      and that status has not been overridden by `borrower`.
   */
  function isSanctioned(address borrower, address account) public view override returns (bool) {
    return !sanctionOverrides[borrower][account] && isFlaggedByChainalysis(account);
  }

  // ========================================================================== //
  //                             Sanction Overrides                             //
  // ========================================================================== //

  /**
   * @dev Overrides the sanction status of `account` for `borrower`.
   */
  function overrideSanction(address account) public override {
    sanctionOverrides[msg.sender][account] = true;
    emit SanctionOverride(msg.sender, account);
  }

  /**
   * @dev Removes the sanction override of `account` for `borrower`.
   */
  function removeSanctionOverride(address account) public override {
    sanctionOverrides[msg.sender][account] = false;
    emit SanctionOverrideRemoved(msg.sender, account);
  }

  // ========================================================================== //
  //                              Escrow Deployment                             //
  // ========================================================================== //

  /**
   * @dev Creates a new WildcatSanctionsEscrow contract for `borrower`,
   *      `account`, and `asset` or returns the existing escrow contract
   *      if one already exists.
   *
   *      The escrow contract is added to the set of sanction override
   *      addresses for `borrower` so that it can not be blocked.
   */
  function createEscrow(
    address borrower,
    address account,
    address asset
  ) public override returns (address escrowContract) {//@audit M why create Escrow can be used by anyone for any address.
    escrowContract = getEscrowAddress(borrower, account, asset);

    // Skip creation if the address code size is non-zero
    if (escrowContract.code.length != 0) return escrowContract;

    tmpEscrowParams = TmpEscrowParams(borrower, account, asset);

    new WildcatSanctionsEscrow{ salt: _deriveSalt(borrower, account, asset) }();

    emit NewSanctionsEscrow(borrower, account, asset);

    sanctionOverrides[borrower][escrowContract] = true;//@audit M why automatically revoke sanction when creating new escrow? what happen if chainlink suddenlly add new sanction

    emit SanctionOverride(borrower, escrowContract);

    _resetTmpEscrowParams();
  }

  /**
   * @dev Calculate the create2 escrow address for the combination
   *      of `borrower`, `account`, and `asset`.
   */
  function getEscrowAddress(
    address borrower,
    address account,
    address asset
  ) public view override returns (address escrowAddress) {
    bytes32 salt = _deriveSalt(borrower, account, asset);
    bytes32 initCodeHash = WildcatSanctionsEscrowInitcodeHash;
    assembly {
      // Cache the free memory pointer so it can be restored at the end
      let freeMemoryPointer := mload(0x40)//@ to stack

      // Write 0xff + address(this) to bytes 11:32
      mstore(0x00, or(0xff0000000000000000000000000000000000000000, address()))//32bytes = 0x20, 20 bytea ddress = 0x14, 1 byte = 2 hex string, 32bytes have 64 hex string,
  // with 0xff prefix, we have 0x15 bytes length inside first memory slot //  0-11 range empty, 11-12 :0xff, 12-32: address 20 bytes
      // Write salt to bytes 32:64
      mstore(0x20, salt)

      // Write initcode hash to bytes 64:96
      mstore(0x40, initCodeHash)// we have packed data range 11-96, 85 bytes length

      // Calculate create2 hash. //@keccak start from 0x0b == 11, length 0x55 == 85
      escrowAddress := and(keccak256(0x0b, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)//kecckak 74 bytes length, and operation read address value, remove padding zero and other value

      // Restore the free memory pointer
      mstore(0x40, freeMemoryPointer)//restore from stack to memory storage
    }
  }
}
