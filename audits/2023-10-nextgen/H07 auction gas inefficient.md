
# Inefficient view bid `AuctionDemo.sol` cost user so much unnecessary gas fee. It is very easy to reach 30 millions block gas limit on `claimAuction()` after ~1930 bids participated

## LOC

<https://github.com/code-423n4/2023-10-nextgen/blob/4f22aa7fe992227d0b0f8db4e1e62f06c7560321/smart-contracts/AuctionDemo.sol#L65-L100>

## Impact

`returnHighestBid()` and `returnHighestBidder()` is extremely gas inefficient.

Using foundry test, for each new user bid, it increase the gas price to call `returnHighestBid()` and `returnHighestBidder()` by 1.5k gas. This compound very quickly.

Using 30 gwei as default gas price on mainnet.

By 100 bids, it cost all users `0.45 ETH` in gas fee for participating, it cost winner `0.04 ETH` in gas fee to claim winning bid.

By 500 bids, it cost all users `6.684 ETH` in gas fee for participating, it cost winner `0.235 ETH` in gas fee to claim winning bid.

By 1000 bids, it cost all users `24.43 ETH` in gas fee for participating, it cost winner `0.46 ETH` in gas fee to claim winning bid.

After ~1930 bids, the gas to call `AuctionDemo.claimAuction()` will exceed 30 millions block gas limit.
Make it impossible to claim NFT and withdraw ETH anymore. So funds will get locked.

For comparision, swap uniswap 1000 times only cost `10.69 ETH` in gas fee.

## Proof of Concept

This Foundry test file run with `forge test -vv --gas-report`

```js
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

```

## Tools Used

manual

## Recommended Mitigation Steps

Either rework auction to only cache the highest bid and bidder. Or using EnumerableList by OpenZeppelin.

Other fix is simply reverse linear search from bottom.
Because only the highest bidder got pushed to the top.

```js
    function returnHighestBid(uint256 _tokenid) public view returns (uint256) {        
        if (auctionInfoData[_tokenid].length > 0) {            
            uint lastIndex =auctionInfoData[_tokenid].length - 1;    
            for (uint256 i = lastIndex; i>0; i--) {    
                if (auctionInfoData[_tokenid][i].status == true) {
                    return auctionInfoData[_tokenid][i].bid;                    
                }
            }
        } else {
            return 0;
        }
    }

```
