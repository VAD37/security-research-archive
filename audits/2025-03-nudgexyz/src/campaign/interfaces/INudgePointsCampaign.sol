// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IBaseNudgeCampaign.sol";

interface INudgePointsCampaign is IBaseNudgeCampaign {
    error NativeTokenTransferFailed();
    error CampaignAlreadyPaused();
    error CampaignNotPaused();
    error InvalidInputArrayLengths();
    error InvalidTargetToken();
    error CampaignAlreadyExists();

    event PointsCampaignCreated(uint256 campaignId, uint32 holdingPeriodInSeconds, address targetToken);
    event CampaignsPaused(uint256[] campaigns);
    event CampaignsUnpaused(uint256[] campaigns);

    struct Campaign {
        uint32 holdingPeriodInSeconds;
        address targetToken;
        uint256 pID;
        uint256 totalReallocatedAmount;
    }

    function createPointsCampaign(
        uint256 campaignId,
        uint32 holdingPeriodInSeconds,
        address targetToken
    ) external returns (Campaign memory);

    function createPointsCampaigns(
        uint256[] calldata campaignIds,
        uint32[] calldata holdingPeriods,
        address[] calldata targetTokens
    ) external returns (Campaign[] memory);

    function pauseCampaigns(uint256[] calldata campaigns) external;
    function unpauseCampaigns(uint256[] calldata campaigns) external;
}
