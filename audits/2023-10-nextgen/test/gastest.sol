// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../smart-contracts/RandomizerVRF.sol";
import "../smart-contracts/NextGenCore.sol";
import "../smart-contracts/NextGenAdmins.sol";
import "../smart-contracts/AuctionDemo.sol";
import "../smart-contracts/MinterContract.sol";

// 🚀 TEST
contract TestFoundry is Test {
    NextGenRandomizerVRF vrf;
    NextGenCore core;
    NextGenAdmins admin;
    auctionDemo demo;
    NextGenMinterContract minter;
    uint tokenId;
    uint collectionId;

    function setUp() public {
        admin = new NextGenAdmins();
        core = new NextGenCore("", "", address(admin));
        vrf = new NextGenRandomizerVRF(
            0,
            address(this),
            address(core),
            address(admin)
        );
        admin.registerAdmin(address(this), true);
        minter = new NextGenMinterContract(
            address(core),
            address(0),
            address(admin)
        );
        core.addMinterContract(address(minter));
        demo = new auctionDemo(address(minter), address(core), address(admin));

        // SETUP TOKEN NFT
        string memory collectionName = "";
        string memory collectionArtist = "";
        string memory collectionDescription = "";
        string memory collectionWebsite = "";
        string memory collectionLicense = "";
        string memory collectionBaseURI = "";
        string memory collectionLibrary = "";
        string[] memory collectionScript = new string[](0);
        uint timePeriod = 1 hours;
        collectionId = core.newCollectionIndex();
        vm.warp(block.timestamp + 30 days);
        vm.deal(address(this), 1 ether);

        core.createCollection(
            collectionName,
            collectionArtist,
            collectionDescription,
            collectionWebsite,
            collectionLicense,
            collectionBaseURI,
            collectionLibrary,
            collectionScript
        );
        core.addRandomizer(collectionId, address(this));

        core.setCollectionData(1, address(this), 10000, 10000, 10000);
        minter.setCollectionCosts(
            collectionId,
            0,
            0,
            0,
            timePeriod,
            3,
            address(0)
        );
        minter.setCollectionPhases(
            collectionId,
            block.timestamp,
            block.timestamp + 7 days,
            block.timestamp + 15 days,
            block.timestamp + 30 days,
            0
        );

        minter.mintAndAuction(
            address(this),
            "tokendata",
            0,
            collectionId,
            block.timestamp + 30 days
        );
        tokenId = 10000000000 * collectionId;
        core.approve(address(demo), tokenId);
    }

    function testFindGasLimit() public {
        uint cacheGas = gasleft();
        uint startBid = 1 wei;
        uint loopCount = 1930; //@1930 then claim gas cost higher block.
        uint gasCost = 30 gwei;
        console.log("gas gwei cost: %e", gasCost);
        console.log("Loop count: %s", loopCount); //@ compare gas price with uniswap
        console.log(
            "gas cost of swapping %s times: %e",
            loopCount,
            356190 * loopCount * gasCost
        );
        for (uint i = 0; i < loopCount; i++) {
            //@1475 gas increase per loop
            demo.participateToAuction{value: startBid + i}(tokenId);
        }
        console.log("bid gas spend: %s", cacheGas - gasleft());
        console.log("bid gas cost: %e", (cacheGas - gasleft()) * gasCost);
        demo.returnHighestBid(tokenId); //call for gas report
        demo.returnHighestBidder(tokenId); //call for gas report

        // claim auction
        vm.warp(block.timestamp + 31 days);
        cacheGas = gasleft();
        demo.claimAuction(tokenId);
        console.log("claim auction gas spend: %s", cacheGas - gasleft());
        console.log(
            "claim auction gas cost: %e",
            (cacheGas - gasleft()) * gasCost
        );
    }

    function isRandomizerContract() external pure returns (bool) {
        return true;
    }

    function calculateTokenHash(
        uint256 _collectionID,
        uint256 _mintIndex,
        uint256 _saltfun_o
    ) public {
        core.setTokenHash(_collectionID, _mintIndex, bytes32(uint(123)));
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external view returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
