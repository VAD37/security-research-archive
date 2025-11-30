// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../campaign/NudgePointsCampaigns.sol";
import {TestERC20} from "../mocks/TestERC20.sol";
import {INudgePointsCampaign, IBaseNudgeCampaign} from "../campaign/interfaces/INudgePointsCampaign.sol";

contract NudgePointsCampaignsTest is Test {
    NudgePointsCampaigns public campaigns;
    address public admin;
    address public swapCaller;
    TestERC20 public token1;
    TestERC20 public token2;
    address public token1Address;
    address public token2Address;
    uint256 campaignId = 1;
    uint256 campaignId2 = 2;
    uint32 holdingPeriod = 7 days;
    address nonAdmin = makeAddr("nonAdmin");

    function setUp() public {
        admin = address(this);
        swapCaller = makeAddr("swapCaller");
        campaigns = new NudgePointsCampaigns(swapCaller);
        token1 = new TestERC20("Test Token 1", "TT1");
        token2 = new TestERC20("Test Token 2", "TT2");
        token1Address = address(token1);
        token2Address = address(token2);
    }

    function test_CreatePointsCampaign_ReturnsCampaign() public {
        NudgePointsCampaigns.Campaign memory newCampaign = campaigns.createPointsCampaign(
            campaignId,
            holdingPeriod,
            token1Address
        );

        // Verify returned campaign
        assertEq(newCampaign.holdingPeriodInSeconds, holdingPeriod);
        assertEq(newCampaign.targetToken, token1Address);
        assertEq(newCampaign.pID, 0);
        assertEq(newCampaign.totalReallocatedAmount, 0);
    }

    function test_CreatePointsCampaign_StoresCampaign() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);

        (
            uint32 holdingPeriodInSeconds_,
            address targetToken_,
            uint256 pID_,
            uint256 totalReallocatedAmount_
        ) = campaigns.campaigns(campaignId);
        assertEq(holdingPeriodInSeconds_, holdingPeriod);
        assertEq(targetToken_, token1Address);
        assertEq(pID_, 0);
        assertEq(totalReallocatedAmount_, 0);
    }

    function test_CreatePointsCampaign_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit INudgePointsCampaign.PointsCampaignCreated(campaignId, holdingPeriod, token1Address);
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
    }

    function test_CreatePointsCampaign_UnauthorizedCallerReverts() public {
        vm.startPrank(nonAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonAdmin,
                campaigns.NUDGE_ADMIN_ROLE()
            )
        );
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        vm.stopPrank();
    }

    function test_CreatePointsCampaign_InvalidTargetTokenReverts() public {
        vm.expectRevert(INudgePointsCampaign.InvalidTargetToken.selector);
        campaigns.createPointsCampaign(campaignId, holdingPeriod, address(0));
    }

    function test_CreatePointsCampaign_ExistingCampaignIdReverts() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);

        vm.expectRevert(INudgePointsCampaign.CampaignAlreadyExists.selector);
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
    }

    function test_CreateBatchCampaigns() public {
        uint256[] memory campaignIds = new uint256[](2);
        campaignIds[0] = 1;
        campaignIds[1] = 2;

        uint32[] memory holdingPeriods = new uint32[](2);
        holdingPeriods[0] = 7 days;
        holdingPeriods[1] = 30 days;

        address[] memory targetTokens = new address[](2);
        targetTokens[0] = address(token1);
        targetTokens[1] = address(token2);

        NudgePointsCampaigns.Campaign[] memory newCampaigns = campaigns.createPointsCampaigns(
            campaignIds,
            holdingPeriods,
            targetTokens
        );

        // Verify returned campaigns array
        assertEq(newCampaigns.length, 2);
        assertEq(newCampaigns[0].holdingPeriodInSeconds, holdingPeriods[0]);
        assertEq(newCampaigns[0].targetToken, targetTokens[0]);
        assertEq(newCampaigns[1].holdingPeriodInSeconds, holdingPeriods[1]);
        assertEq(newCampaigns[1].targetToken, targetTokens[1]);

        // Verify stored campaigns
        (uint32 holdingPeriodInSeconds, address targetToken, uint256 pID, uint256 totalReallocatedAmount) = campaigns
            .campaigns(1);
        assertEq(holdingPeriodInSeconds, holdingPeriods[0]);
        assertEq(targetToken, targetTokens[0]);
        assertEq(pID, 0);
        assertEq(totalReallocatedAmount, 0);

        (
            uint32 holdingPeriodInSeconds2,
            address targetToken2,
            uint256 pID2,
            uint256 totalReallocatedAmount2
        ) = campaigns.campaigns(campaignIds[1]);
        assertEq(holdingPeriodInSeconds2, holdingPeriods[1]);
        assertEq(targetToken2, targetTokens[1]);
        assertEq(pID2, 0);
        assertEq(totalReallocatedAmount2, 0);
    }

    function test_RevertWhen_ArrayLengthsMismatch() public {
        uint256[] memory campaignIds = new uint256[](2);
        uint32[] memory holdingPeriods = new uint32[](1);
        address[] memory targetTokens = new address[](2);

        vm.expectRevert(INudgePointsCampaign.InvalidInputArrayLengths.selector);
        campaigns.createPointsCampaigns(campaignIds, holdingPeriods, targetTokens);
    }

    function test_RevertWhen_CallerNotAdmin() public {
        uint256[] memory campaignIds = new uint256[](1);
        uint32[] memory holdingPeriods = new uint32[](1);
        address[] memory targetTokens = new address[](1);

        vm.startPrank(nonAdmin);
        vm.expectRevert();
        campaigns.createPointsCampaigns(campaignIds, holdingPeriods, targetTokens);
        vm.stopPrank();
    }

    function test_RevertWhen_ExistingCampaignId() public {
        // First create a campaign with ID 1
        campaigns.createPointsCampaign(1, holdingPeriod, token1Address);

        // Try to create batch campaigns including ID 1
        uint256[] memory campaignIds = new uint256[](2);
        campaignIds[0] = 1; // existing ID
        campaignIds[1] = 2; // new ID

        uint32[] memory holdingPeriods = new uint32[](2);
        holdingPeriods[0] = 14 days;
        holdingPeriods[1] = 30 days;

        address[] memory targetTokens = new address[](2);
        targetTokens[0] = token2Address;
        targetTokens[1] = token1Address;

        vm.expectRevert(INudgePointsCampaign.CampaignAlreadyExists.selector);
        campaigns.createPointsCampaigns(campaignIds, holdingPeriods, targetTokens);
    }

    function test_CreateBatchCampaigns_EmptyArrays() public {
        uint256[] memory campaignIds = new uint256[](0);
        uint32[] memory holdingPeriods = new uint32[](0);
        address[] memory targetTokens = new address[](0);

        NudgePointsCampaigns.Campaign[] memory newCampaigns = campaigns.createPointsCampaigns(
            campaignIds,
            holdingPeriods,
            targetTokens
        );
        assertEq(newCampaigns.length, 0);
    }

    function test_PauseCampaigns() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        campaigns.createPointsCampaign(campaignId2, holdingPeriod, token2Address);
        uint256[] memory campaignIdsToPause = new uint256[](2);
        campaignIdsToPause[0] = campaignId;
        campaignIdsToPause[1] = campaignId2;
        campaigns.pauseCampaigns(campaignIdsToPause);

        assertTrue(campaigns.isCampaignPaused(campaignId));
        assertTrue(campaigns.isCampaignPaused(campaignId2));
    }

    function test_PauseCampaigns_EmitsEvent() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        campaigns.createPointsCampaign(campaignId2, holdingPeriod, token2Address);
        uint256[] memory campaignIdsToPause = new uint256[](2);
        campaignIdsToPause[0] = campaignId;
        campaignIdsToPause[1] = campaignId2;

        vm.expectEmit(true, true, true, true);
        emit INudgePointsCampaign.CampaignsPaused(campaignIdsToPause);
        campaigns.pauseCampaigns(campaignIdsToPause);
    }

    function test_PauseCampaigns_AlreadyPausedReverts() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        campaigns.createPointsCampaign(campaignId2, holdingPeriod, token2Address);
        // Only pause one campaign
        uint256[] memory oneCampaign = new uint256[](1);
        oneCampaign[0] = campaignId;
        campaigns.pauseCampaigns(oneCampaign);

        assertTrue(campaigns.isCampaignPaused(campaignId));

        uint256[] memory bothCampaigns = new uint256[](2);
        bothCampaigns[0] = campaignId;
        bothCampaigns[1] = campaignId2;

        vm.expectRevert(INudgePointsCampaign.CampaignAlreadyPaused.selector);
        campaigns.pauseCampaigns(bothCampaigns);

        assertTrue(campaigns.isCampaignPaused(campaignId));
        assertFalse(campaigns.isCampaignPaused(campaignId2));
    }

    function test_UnpauseCampaigns() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        campaigns.createPointsCampaign(campaignId2, holdingPeriod, token2Address);
        uint256[] memory campaignIdsToPause = new uint256[](2);
        campaignIdsToPause[0] = campaignId;
        campaignIdsToPause[1] = campaignId2;
        campaigns.pauseCampaigns(campaignIdsToPause);

        assertTrue(campaigns.isCampaignPaused(campaignId));
        assertTrue(campaigns.isCampaignPaused(campaignId2));

        campaigns.unpauseCampaigns(campaignIdsToPause);

        assertFalse(campaigns.isCampaignPaused(campaignId));
        assertFalse(campaigns.isCampaignPaused(campaignId2));
    }

    function test_UnpauseCampaigns_EmitsEvent() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        campaigns.createPointsCampaign(campaignId2, holdingPeriod, token2Address);
        uint256[] memory campaignIdsToPause = new uint256[](2);
        campaignIdsToPause[0] = campaignId;
        campaignIdsToPause[1] = campaignId2;
        campaigns.pauseCampaigns(campaignIdsToPause);

        vm.expectEmit(true, true, true, true);
        emit INudgePointsCampaign.CampaignsUnpaused(campaignIdsToPause);
        campaigns.unpauseCampaigns(campaignIdsToPause);
    }

    function test_UnpauseCampaigns_NotPausedReverts() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        campaigns.createPointsCampaign(campaignId2, holdingPeriod, token2Address);

        // Only pause one campaign
        uint256[] memory oneCampaign = new uint256[](1);
        oneCampaign[0] = campaignId;
        campaigns.pauseCampaigns(oneCampaign);

        uint256[] memory campaignIdsToUnpause = new uint256[](2);
        campaignIdsToUnpause[0] = campaignId;
        campaignIdsToUnpause[1] = campaignId2;

        vm.expectRevert(INudgePointsCampaign.CampaignNotPaused.selector);
        campaigns.unpauseCampaigns(campaignIdsToUnpause);

        assertTrue(campaigns.isCampaignPaused(campaignId));
        assertFalse(campaigns.isCampaignPaused(campaignId2));
    }

    function test_PauseCampaignsFromNonAdminReverts() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        uint256[] memory campaignIdsToPause = new uint256[](1);
        campaignIdsToPause[0] = campaignId;

        vm.prank(nonAdmin);
        vm.expectRevert();
        campaigns.pauseCampaigns(campaignIdsToPause);
    }

    function test_UnpauseCampaignsFromNonAdminReverts() public {
        campaigns.createPointsCampaign(campaignId, holdingPeriod, token1Address);
        uint256[] memory campaignIdsToPause = new uint256[](1);
        campaignIdsToPause[0] = campaignId;

        campaigns.pauseCampaigns(campaignIdsToPause);

        assertTrue(campaigns.isCampaignPaused(campaignId));

        vm.prank(nonAdmin);
        vm.expectRevert();
        campaigns.unpauseCampaigns(campaignIdsToPause);
    }
}
