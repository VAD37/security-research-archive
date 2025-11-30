// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../smart-contracts/RandomizerVRF.sol";
import "../smart-contracts/NextGenCore.sol";
import "../smart-contracts/NextGenAdmins.sol";
import "../smart-contracts/AuctionDemo.sol";
import "../smart-contracts/MinterContract.sol";

contract NFTEnum is ERC721Enumerable {
    constructor() ERC721("NFTEnum", "NFTEnum") {}

    function mint() public {
        _mint(msg.sender, totalSupply());
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function burnTwice(uint256 tokenId) public {
        _burn(tokenId);
        _burn(tokenId);
    }
}

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

    // function testFindGasLimit() public {
    //     uint cacheGas = gasleft();
    //     uint startBid = 1 wei;
    //     uint loopCount = 100; //@1930 then claim gas cost higher block.
    //     uint gasCost = 30 gwei;
    //     console.log("Loop count: %s", loopCount); //@ compare gas price with uniswap
    //     console.log("gas cost of swapping %s times: %e", loopCount,  356190 * loopCount * gasCost);
    //     for (uint i = 0; i < loopCount; i++) {
    //         //@1475 gas increase per loop
    //         demo.participateToAuction{value: startBid + i}(tokenId); 
    //     } 
    //     console.log("bid gas spend: %s", cacheGas - gasleft());
    //     console.log("bid gas cost: %e", (cacheGas - gasleft()) * gasCost);
    //     demo.returnHighestBid(tokenId); //call for gas report
    //     demo.returnHighestBidder(tokenId); //call for gas report

    //     // claim auction
    //     vm.warp(block.timestamp + 31 days);
    //     console.log("claim auction");
    //     cacheGas = gasleft();
    //     demo.claimAuction(tokenId);
    //     console.log("claim auction gas spend: %s", cacheGas - gasleft());
    //     console.log("claim auction gas cost: %e", (cacheGas - gasleft()) * gasCost);
    // }

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

    // struct collectionPhasesDataStructure {
    //     uint allowlistStartTime; //2nd
    //     uint allowlistEndTime; //2nd
    //     uint publicStartTime; //2nd
    //     uint publicEndTime; //2nd
    //     bytes32 merkleRoot; //2nd
    //     uint256 collectionMintCost; //1st
    //     uint256 collectionEndMintCost; //1st
    //     uint256 timePeriod; //1st
    //     uint256 rate; //1st
    //     uint8 salesOption; //1st
    //     address delAddress; //1st
    // }

    // // mapping of collectionPhasesData struct
    // mapping(uint256 => collectionPhasesDataStructure) private collectionPhases;

    // function testDoubleBurn() public {
    //     uint[] memory array = new uint[](16);
    //     array[0] = block.prevrandao;
    //     array[2] = block.prevrandao;
    //     array[1] = block.prevrandao;

    //     console.log("array0:", array[0]);
    //     console.log("array1:", array[1]);
    //     console.log("array2:", array[2]);
    // }

    // function testPriceOverflow(uint _rate, uint _timeSkip ) public {
    //     vm.assume(_rate > 0);
    //     vm.assume(_timeSkip > 0);
    //     vm.assume(_timeSkip < 30 days);

    //     uint _collectionId = 1;
    //     uint mintCost = 0.1 ether;
    //     uint endMintCost = 0.01 ether;
    //     uint rate = _rate;
    //     collectionPhases[_collectionId].collectionMintCost = mintCost;
    //     collectionPhases[_collectionId].collectionEndMintCost = endMintCost;
    //     collectionPhases[_collectionId].rate = rate;
    //     collectionPhases[_collectionId].allowlistStartTime = block.timestamp;
    //     collectionPhases[_collectionId].timePeriod = 20 minutes;

    //     vm.warp(block.timestamp + _timeSkip);

    //     //@ tDiff is cycle count
    //     uint tDiff = (block.timestamp -
    //         collectionPhases[_collectionId].allowlistStartTime) /
    //         collectionPhases[_collectionId].timePeriod;
    //     uint price = 0;

    //     if (
    //         ((collectionPhases[_collectionId].collectionMintCost -
    //             collectionPhases[_collectionId].collectionEndMintCost) /
    //             (collectionPhases[_collectionId].rate)) > tDiff
    //     ) {
    //         price =
    //             collectionPhases[_collectionId].collectionMintCost -
    //             (tDiff * collectionPhases[_collectionId].rate);
    //         assertGt(price , collectionPhases[_collectionId].collectionEndMintCost );
    //         console.log("price: %e", price);
    //     }
    //     else {
    //         price = collectionPhases[_collectionId].collectionEndMintCost;
    //         // assertLt((collectionPhases[_collectionId].collectionMintCost -
    //         //     collectionPhases[_collectionId].collectionEndMintCost),collectionPhases[_collectionId].rate * tDiff);
    //         console.log("price: %e", price);
    //     }
    // }

    // function testPrice() public {
    //     uint _collectionId = 1;
    //     uint rate = 1 minutes;
    //     console.log("rate: %s", rate);

    //     collectionPhases[_collectionId].allowlistStartTime = block.timestamp;
    //     collectionPhases[_collectionId].collectionMintCost = 0.1 ether;
    //     collectionPhases[_collectionId].timePeriod = rate;

    //     for (uint i = 0; i < 16; i++) {
    //         console.log("--------------------");
    //         uint tDiff = (block.timestamp -
    //             collectionPhases[_collectionId].allowlistStartTime) /
    //             collectionPhases[_collectionId].timePeriod;

    //         uint256 price = collectionPhases[_collectionId].collectionMintCost /
    //             (tDiff + 1); //@ price divide by 1 then 2,3,4,5,6, ...
    //         uint256 decreaserate = ((price -
    //             (collectionPhases[_collectionId].collectionMintCost /
    //                 (tDiff + 2))) /
    //             collectionPhases[_collectionId].timePeriod) *
    //             (
    //                 (block.timestamp -
    //                     (tDiff * collectionPhases[_collectionId].timePeriod) -
    //                     collectionPhases[_collectionId].allowlistStartTime)
    //             );
    //         console.log("block timestamp: %s", block.timestamp);
    //         console.log("tDiff: %s", tDiff);
    //         console.log("price: %e", price);
    //         console.log("decreaseRate: %e", decreaserate);

    //         vm.warp(block.timestamp + 3 hours);
    //     }
    // }

    // function test_genGas() public {
    //     // core.createCollection("test", "test", "test", "test", "test", "test", "test", "test", "test", "test", "test");
    //     // core.setCollectionData(1, address(this), 1, 1,1);
    //     uint length = 3;
    //     uint256[] memory randomWords = new uint256[](length);
    //     for (uint i = 0; i < length; i++) {
    //         randomWords[i] = uint(
    //             keccak256(abi.encodePacked(uint(123), uint(i)))
    //         );
    //     }
    //     cacheRequestId = 1;
    //     vrf.updateCoreContract(address(this));
    //     vrf.calculateTokenHash(1, 1, 1);
    //     vrf.updateCoreContract(address(core));
    //     vrf.rawFulfillRandomWords(1, randomWords);
    // }

    // function testFuzz_genGas(uint length) public {
    //     vm.assume(length > 0);
    //     vm.assume(length < 100);

    //     uint256[] memory randomWords = new uint256[](length);
    //     for (uint i = 0; i < length; i++) {
    //         randomWords[i] = uint(
    //             keccak256(abi.encodePacked(uint(123), uint(i)))
    //         );
    //     }

    //     cacheRequestId = 1;
    //     vrf.updateCoreContract(address(this));
    //     vrf.calculateTokenHash(1, 1, 1);
    //     vrf.updateCoreContract(address(core));

    //     vrf.rawFulfillRandomWords(1, randomWords);
    // }

    // function requestRandomWords(
    //     bytes32 keyHash,
    //     uint64 subId,
    //     uint16 minimumRequestConfirmations,
    //     uint32 callbackGasLimit,
    //     uint32 numWords
    // ) external view returns (uint256 requestId) {
    //     return cacheRequestId;
    // }
}
