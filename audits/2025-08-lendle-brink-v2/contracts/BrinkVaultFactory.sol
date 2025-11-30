// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { BrinkVault } from "./BrinkVault.sol";
import { IBrinkVault } from "./interfaces/IBrinkVault.sol";
import { ErrorsLib } from "./libraries/ErrorsLib.sol";

/// @title BrinkVaultFactory
/// @notice Factory for creating BrinkVaults
/// @author b11a
contract BrinkVaultFactory is Ownable2Step {
    //////////////////////////////////////////////////////////////
    //                          EVENTS                          //
    //////////////////////////////////////////////////////////////

    /// @notice Emitted when a BrinkVault is created
    /// @param brinkVault The address of the created BrinkVault
    event BrinkVaultCreated(address indexed brinkVault);


    //////////////////////////////////////////////////////////////
    //                     STATE VARIABLES                      //
    //////////////////////////////////////////////////////////////

    /// @notice The array of registered BrinkVaults
    address[] public brinkVaults;

    //////////////////////////////////////////////////////////////
    //                       CONSTRUCTOR                        //
    //////////////////////////////////////////////////////////////

    /// @param _factoryOwner Address of the FactoryOwner
    constructor(address _factoryOwner) Ownable(_factoryOwner) {}

    //////////////////////////////////////////////////////////////
    //                    EXTERNAL WRITE FUNCTIONS              //
    //////////////////////////////////////////////////////////////
    
    /** @notice Creates a new BrinkVault
     * @param _asset Address of the asset token
     * @param _strategist Address of the strategist
     * @param _vaultManager Address of the vault manager
     * @param _name Name of the strategy
     * @param _symbol Symbol of the whole strategy
     * @param _depositLimit Maximum deposit limit
     */
    function createBrinkVault(
        address _asset,
        address _strategist,
        address _vaultManager,
        string memory _name,
        string memory _symbol,
        uint256 _depositLimit
    )
        external
        onlyOwner
        returns (address brinkVault)
    {
        bytes32 salt = keccak256(abi.encode(_asset, _name, "BrinkVault"));

        brinkVault = address(
            new BrinkVault{ salt: salt }(
                _asset, _strategist, _vaultManager, _name, _symbol, _depositLimit
            )
        );

        brinkVaults.push(brinkVault);

        emit BrinkVaultCreated(brinkVault);
    }

    //////////////////////////////////////////////////////////////
    //                  EXTERNAL VIEW FUNCTIONS                 //
    //////////////////////////////////////////////////////////////

    /// @notice Returns all BrinkVaults
    /// @return Number of BrinkVaults
    function getNumberOfBrinkVault() external view returns (uint256) {
        return brinkVaults.length;
    }
}