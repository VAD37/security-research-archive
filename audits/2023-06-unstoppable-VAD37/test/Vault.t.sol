// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Counter.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
      IVault public vault;

    function setUp() public {
        vault = IVault(deployChild());
        console.log("Vault deployed at: %s", address(vault));
        // console.log(vault.swap_router());
    }

    function deployChild() public returns (address) {
        return deployCode("./src/Vaultvy.json");
        // address newContract;
        // bytes memory local_deploycode = vaultCode;
        // assembly {
        //     let codeSize := mload(local_deploycode)
        //     let data := add(local_deploycode, 0x20)
        //     newContract := create(0, data, codeSize)
        //     if iszero(extcodesize(newContract)) {
        //         revert(0, 0)
        //     }
        // }
        // return newContract;
    }

    function testAdminOwner() public {
        assertEq(vault.admin(), address(this));
    }
}
