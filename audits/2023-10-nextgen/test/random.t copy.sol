// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";

// // 🚀 TEST
// contract TestFoundry is Test {
//     function setUp() public {}

//     struct collectionPhasesDataStructure {
//         uint allowlistStartTime; //2nd
//         uint allowlistEndTime; //2nd
//         uint publicStartTime; //2nd
//         uint publicEndTime; //2nd
//         bytes32 merkleRoot; //2nd
//         uint256 collectionMintCost; //1st
//         uint256 collectionEndMintCost; //1st
//         uint256 timePeriod; //1st
//         uint256 rate; //1st
//         uint8 salesOption; //1st
//         address delAddress; //1st
//     }

//     // mapping of collectionPhasesData struct
//     mapping(uint256 => collectionPhasesDataStructure) private collectionPhases;

//     function testPrice(uint _timePeriod, uint _skipTime) public {
//         vm.assume(_timePeriod > 0);
//         vm.assume(_timePeriod < 1 hours);
//         vm.assume(_skipTime > _timePeriod - 1);
//         vm.assume(_skipTime < 30 days);
//     // function testPrice() public {
//     //     uint _timePeriod = 10;
//     //     uint _skipTime = 4210;
//         uint _collectionId = 1;
//         uint timePeriod = _timePeriod;
//         uint skipTime = _skipTime;
//         console.log("rate: %s", timePeriod);

//         collectionPhases[_collectionId].allowlistStartTime = block.timestamp;
//         collectionPhases[_collectionId].collectionMintCost = 0.1 ether;
//         collectionPhases[_collectionId].timePeriod = timePeriod;

//         for (uint i = 0; i < 60; i++) {
//             console.log("--------------------");
//             uint tDiff = (block.timestamp -
//                 collectionPhases[_collectionId].allowlistStartTime) /
//                 collectionPhases[_collectionId].timePeriod; //

//             uint256 price = collectionPhases[_collectionId].collectionMintCost /
//                 (tDiff + 1); //@ price divide by 1 then 2,3,4,5,6, ...
//             // console.log(
//             //     "part1: ",
//             //     ((price -
//             //         (collectionPhases[_collectionId].collectionMintCost /
//             //             (tDiff + 2))) /
//             //         collectionPhases[_collectionId].timePeriod)
//             // );
//             // console.log(
//             //     "part2: ",
//             //     (
//             //         (block.timestamp -
//             //             (tDiff * collectionPhases[_collectionId].timePeriod) -
//             //             collectionPhases[_collectionId].allowlistStartTime)
//             //     )
//             // );
//             uint256 decreaserate = ((price -
//                 (collectionPhases[_collectionId].collectionMintCost /
//                     (tDiff + 2))) /
//                 collectionPhases[_collectionId].timePeriod) *
//                 (
//                     (block.timestamp -
//                         (tDiff * collectionPhases[_collectionId].timePeriod) -
//                         collectionPhases[_collectionId].allowlistStartTime)
//                 );
//             //@ tdiff = 15.55555  ~= 15
//             //@ price = 0.1e18 / 16 = 6.25e15
//             //@ 1 (price - 0.1e18 / 17 ) / 360
//             //@ 2 /

//             console.log("block timestamp: %s", block.timestamp);
//             console.log("tDiff: %s", tDiff);
//             console.log("price: %e", price);
//             console.log("decreaseRate: %e", decreaserate);
//             if (price >= decreaserate)
//                 console.log("finalprice: %e", price - decreaserate);
//             assertGe(
//                 price,
//                 decreaserate,
//                 "price always greater than decreaserate"
//             );
//             // assertEq(decreaserate, 0, "decreaserate always 0");

//             vm.warp(block.timestamp + skipTime);
//         }
//     }
// }
