// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import { PositionRegistry, HoldingPI } from "../accountingManager/Registry.sol";
import { IConnector } from "../interface/IConnector.sol";

library TVLHelper {
    /// @notice Get the total value locked in the vault
    /// @param vaultId The vault id
    /// @param registry The position registry
    /// @param baseToken The base token //@USDC,DAI, etc
    /// @return The total value locked based on the base token
    /// @dev This function gets the holding positions from the registry and loops through them to get the TVL
    function getTVL(uint256 vaultId, PositionRegistry registry, address baseToken) public view returns (uint256) {
        uint256 totalTVL;
        uint256 totalDebt;
        HoldingPI[] memory positions = registry.getHoldingPositions(vaultId);//@audit-ok max 40 positions TVL can only get 40 positions designed by admin M getTVL out of gas when loop through all positions.Does vault have max positions?
        for (uint256 i = 0; i < positions.length; i++) {//40 positions max. only AM can edit this
            if (positions[i].calculatorConnector == address(0)) {//@vaults[vaultId].trustedPositionsBP[_positionId].calculatorConnector 
                continue;//this is just connector address. including AccountingManager and empty first index array position
            }//@holding position can be sorted,change index, or removed with pop()
            uint256 tvl = IConnector(positions[i].calculatorConnector).getPositionTVL(positions[i], baseToken);//@calculatorConnector is AM most of the time.
            bool isPositionDebt = registry.isPositionDebt(vaultId, positions[i].positionId);
            if (isPositionDebt) {
                totalDebt += tvl;
            } else {
                totalTVL += tvl;
            }
        }
        if (totalTVL < totalDebt) {
            return 0;
        }
        return (totalTVL - totalDebt);
    }
    /// @notice Get the oldest update time of the holding positions
    /// @param vaultId The vault id
    /// @param registry The position registry
    /// @return The oldest update time
    /// @dev in case we have a position that we can't fetch the latest update at the moment, we get the oldest update time of all of them to avoid any issues with the TVL

    function getLatestUpdateTime(uint256 vaultId, PositionRegistry registry) public view returns (uint256) {
        uint256 latestUpdateTime;
        HoldingPI[] memory positions = registry.getHoldingPositions(vaultId);
        for (uint256 i = 0; i < positions.length; i++) {
            if (latestUpdateTime == 0 || positions[i].positionTimestamp < latestUpdateTime) {
                latestUpdateTime = positions[i].positionTimestamp;//@audit R need to check what oldest time for? latest update time return oldest time. due to comment error??
            }
        }
        if (latestUpdateTime == 0) {//@note all positions have latestUpdateTime==0 then return block.timestamp
            latestUpdateTime = block.timestamp;
        }
        return latestUpdateTime;
    }
}
