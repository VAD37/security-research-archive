// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LpItem} from "../interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibAlpManager {

    bytes32 constant ALP_MANAGER_STORAGE_POSITION = keccak256("apollox.alp.manager.storage.v2");
    uint8 constant  ALP_DECIMALS = 18;

    struct AlpManagerStorage {
        mapping(address => uint256) lastMintedAt;
        uint256 coolingDuration;
        address alp;
        mapping(address account => bool) freeBurnWhitelists;
        address signer;
    }

    function alpManagerStorage() internal pure returns (AlpManagerStorage storage ams) {
        bytes32 position = ALP_MANAGER_STORAGE_POSITION;
        assembly {
            ams.slot := position
        }
    }

    function initialize(address alpToken, address signer) internal {
        AlpManagerStorage storage ams = alpManagerStorage();
        require(ams.alp == address(0) && ams.signer == address(0), "LibAlpManager: Already initialized");
        ams.alp = alpToken;
        ams.coolingDuration = 30 minutes;
        ams.signer = signer;
    }

    function alpPrice(int256 totalValueUsd) internal view returns (uint256) {
        uint256 totalSupply = IERC20(alpManagerStorage().alp).totalSupply();
        if (totalValueUsd <= 0 && totalSupply > 0) {
            return 0;
        }
        if (totalSupply == 0) {
            return 1e8;
        } else {
            return uint256(totalValueUsd) * 1e8 / totalSupply;
        }
    }

    function getFeePoint(
        LpItem memory item, uint256 totalValueUsd,
        int256 poolTokenUsd, uint256 amountUsd, bool increase
    ) internal pure returns (uint256) {
        if (!item.dynamicFee) {
            return increase ? item.feeBasisPoints : item.taxBasisPoints;
        }
        uint256 targetValueUsd = totalValueUsd * item.targetWeight / 1e4;
        int256 nextValueUsd = poolTokenUsd + int256(amountUsd);
        if (!increase) {
            // ∵ poolTokenUsd >= amountUsd && amountUsd > 0
            // ∴ poolTokenUsd > 0
            nextValueUsd = poolTokenUsd - int256(amountUsd);
        }

        uint256 initDiff = poolTokenUsd > int256(targetValueUsd)
            ? uint256(poolTokenUsd) - targetValueUsd  // ∵ (poolTokenUsd > targetValueUsd && targetValueUsd > 0) ∴ (poolTokenUsd > 0)
            : uint256(int256(targetValueUsd) - poolTokenUsd);

        uint256 nextDiff = nextValueUsd > int256(targetValueUsd)
            ? uint256(nextValueUsd) - targetValueUsd
            : uint256(int256(targetValueUsd) - nextValueUsd);

        if (nextDiff < initDiff) {
            uint256 feeAdjust = item.taxBasisPoints * initDiff / targetValueUsd;
            return item.feeBasisPoints > feeAdjust ? item.feeBasisPoints - feeAdjust : 0;
        }

        uint256 avgDiff = (initDiff + nextDiff) / 2;
        return item.feeBasisPoints + (avgDiff > targetValueUsd ? item.taxBasisPoints : (item.taxBasisPoints * avgDiff) / targetValueUsd);
    }
}