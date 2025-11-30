// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import { IChainalysisSanctionsList } from './interfaces/IChainalysisSanctionsList.sol';
import { IWildcatArchController } from './interfaces/IWildcatArchController.sol';
import { IWildcatSanctionsSentinel } from './interfaces/IWildcatSanctionsSentinel.sol';
import { SanctionsList } from './libraries/Chainalysis.sol';
import { WildcatSanctionsEscrow } from './WildcatSanctionsEscrow.sol';

contract WildcatSanctionsSentinel is IWildcatSanctionsSentinel {
  bytes32 public constant override WildcatSanctionsEscrowInitcodeHash =
    keccak256(type(WildcatSanctionsEscrow).creationCode);

  address public immutable override chainalysisSanctionsList;

  address public immutable override archController;

  TmpEscrowParams public override tmpEscrowParams;//@borrower,account,asset
  //@audit-ok WTF tmpEscrowParams use for?
  mapping(address borrower => mapping(address account => bool sanctionOverride))
    public
    override sanctionOverrides;

  constructor(address _archController, address _chainalysisSanctionsList) {
    archController = _archController;
    chainalysisSanctionsList = _chainalysisSanctionsList;//@santion list is 3rd party blacklist
    _resetTmpEscrowParams();
  }

  function _resetTmpEscrowParams() internal {
    tmpEscrowParams = TmpEscrowParams(address(1), address(1), address(1));
  }

  /**
   * @dev Returns boolean indicating whether `account` is sanctioned
   *      on Chainalysis and that status has not been overridden by
   *      `borrower`.
   */
  function isSanctioned(address borrower, address account) public view override returns (bool) {//@note how sanctioned work? why only sanctioned per borrower?
    return
      !sanctionOverrides[borrower][account] &&
      IChainalysisSanctionsList(chainalysisSanctionsList).isSanctioned(account);//@audit-ok L chain analysis can prevent withdraw of escrow too. is it ok?
  }

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
  function removeSanctionOverride(address account) public override {//@audit-ok H borrower can prevent lenders escrow from withdrawing?
    sanctionOverrides[msg.sender][account] = false;
    emit SanctionOverrideRemoved(msg.sender, account);
  }

  /**
   * @dev Calculate the create2 escrow address for the combination
   *      of `borrower`, `account`, and `asset`.
   */
  function getEscrowAddress(//@audit-ok verify of create2 address is correct
    address borrower,
    address account,
    address asset
  ) public view override returns (address escrowAddress) {
    return
      address(
        uint160(
          uint256(
            keccak256(
              abi.encodePacked(
                bytes1(0xff),
                address(this),
                keccak256(abi.encode(borrower, account, asset)),
                WildcatSanctionsEscrowInitcodeHash
              )
            )
          )
        )
      );
  }

  /**
   * @dev Creates a new WildcatSanctionsEscrow contract for `borrower`,
   *      `account`, and `asset` or returns the existing escrow contract
   *      if one already exists.
   *
   *      The escrow contract is added to the set of sanction override
   *      addresses for `borrower` so that it can not be blocked.
   */
  function createEscrow(//@audit-ok is it possible to createEscrow for anyaccount and blacklist anyone?
    address borrower,//blacklist lender
    address account,//borrower //@audit-ok H creating escrow call send wrong function variable
    address asset//address(this) == WildcatMarket
  ) public override returns (address escrowContract) {
    if (!IWildcatArchController(archController).isRegisteredMarket(msg.sender)) {//@note only market can create escrow. only for block case. when user is blacklisted
      revert NotRegisteredMarket();
    }

    escrowContract = getEscrowAddress(borrower, account, asset);

    if (escrowContract.codehash != bytes32(0)) return escrowContract;

    tmpEscrowParams = TmpEscrowParams(borrower, account, asset);

    new WildcatSanctionsEscrow{ salt: keccak256(abi.encode(borrower, account, asset)) }();

    emit NewSanctionsEscrow(borrower, account, asset);

    sanctionOverrides[borrower][escrowContract] = true;//@audit-ok why sanction escrow contract?

    emit SanctionOverride(borrower, escrowContract);

    _resetTmpEscrowParams();
  }
}
