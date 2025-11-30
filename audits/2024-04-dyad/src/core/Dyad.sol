// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IDyad}    from "../interfaces/IDyad.sol";
import {Licenser} from "./Licenser.sol";
import {ERC20}    from "@solmate/src/tokens/ERC20.sol";

contract Dyad is ERC20("DYAD Stable", "DYAD", 18), IDyad {
  Licenser public immutable licenser;  

  // vault manager => (dNFT ID => dyad)
  mapping (address => mapping (uint => uint)) public mintedDyad; 

  constructor(
    Licenser _licenser
  ) { 
    licenser = _licenser; //@0xd8bA5e720Ddc7ccD24528b9BA3784708528d0B85 DYAD licenser. vaultmanager have different licenser
  }

  modifier licensedVaultManager() {
    if (!licenser.isLicensed(msg.sender)) revert NotLicensed();
    _;
  }

  /// @inheritdoc IDyad
  function mint(
      uint    id, 
      address to,
      uint    amount
  ) external 
      licensedVaultManager //@audit-ok README @I cannot mint, borrow new DYAD right away after deployment. still wait for V1 to approve new vault license 
    {
      _mint(to, amount);
      mintedDyad[msg.sender][id] += amount;
  }

  /// @inheritdoc IDyad
  function burn(
      uint    id, 
      address from,
      uint    amount
  ) external 
      licensedVaultManager 
    {
      _burn(from, amount);
      mintedDyad[msg.sender][id] -= amount;
  }
}
