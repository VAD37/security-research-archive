// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// base contracts
import "../../src/InterestRateModel.sol";

contract InterestRateModelIntegrationTest is Test {
    uint256 constant Q32 = 2 ** 32;
    uint256 constant Q96 = 2 ** 96;

    uint256 constant YEAR_SECS = 31557600; // taking into account leap years

    uint256 mainnetFork;
    InterestRateModel interestRateModel;

    function setUp() external {
        // 5% base rate - after 80% - 109% (like in compound v2 deployed)
        interestRateModel = new InterestRateModel(0, Q96 * 5 / 100, Q96 * 109 / 100, Q96 * 80 / 100);
    }

    function testUtilizationRates() external {
        assertEq(interestRateModel.getUtilizationRateX96(10, 0), 0);
        assertEq(interestRateModel.getUtilizationRateX96(10, 10), Q96 / 2);
        assertEq(interestRateModel.getUtilizationRateX96(0, 10), Q96);
    }

    function testInterestRates() external {
        (uint256 borrowRateX96, uint256 lendRateX96) = interestRateModel.getRatesPerSecondX96(10, 0);
        assertEq(borrowRateX96 * YEAR_SECS, 0); // 0% for 0% utilization
        assertEq(lendRateX96 * YEAR_SECS, 0); // 0% for 0% utilization

        (borrowRateX96, lendRateX96) = interestRateModel.getRatesPerSecondX96(10000000, 10000000);
        assertEq(borrowRateX96 * YEAR_SECS, 1980704062856608439809600800); // 2.5% per year for 50% utilization
        assertEq(lendRateX96 * YEAR_SECS, 990352031428304219889021600); // 1.25% for 50% utilization

        (borrowRateX96, lendRateX96) = interestRateModel.getRatesPerSecondX96(0, 10);
        assertEq(borrowRateX96 * YEAR_SECS, 20440865928680199099069868800); // 25.8% per year for 100% utilization
        assertEq(lendRateX96 * YEAR_SECS, 20440865928680199099069868800); // 25.8% per year for 100% utilization 
    }//rate is 2e28 

    function testPrintInterestRates() external {
        //Print interest rates for % utilization. utilization% = debt / (debt + cash)
        // 10%,20%,50%,70%,80%,85%,90%,95%,100%
        (uint256 _b1, uint256 _l1) = interestRateModel.getRatesPerSecondX96(0, 1e8);
        console.log("100% utilization: borrowRate: %e, SupplyRate: %e", _b1, _l1);
        (uint256 _b2, uint256 _l2) = interestRateModel.getRatesPerSecondX96(1e8 - 0.95e8, 0.95e8);
        console.log("95% utilization: borrowRate: %e, SupplyRate: %e", _b2, _l2);
        (uint256 _b3, uint256 _l3) = interestRateModel.getRatesPerSecondX96(1e8 - 0.9e8, 0.9e8);
        console.log("90% utilization: borrowRate: %e, SupplyRate: %e", _b3, _l3);
        (uint256 _b4, uint256 _l4) = interestRateModel.getRatesPerSecondX96(1e8 - 0.85e8, 0.85e8);
        console.log("85% utilization: borrowRate: %e, SupplyRate: %e", _b4, _l4);
        (uint256 _b5, uint256 _l5) = interestRateModel.getRatesPerSecondX96(1e8 - 0.8e8, 0.8e8);
        console.log("80% utilization: borrowRate: %e, SupplyRate: %e", _b5, _l5);
        (uint256 _b6, uint256 _l6) = interestRateModel.getRatesPerSecondX96(1e8 - 0.7e8, 0.7e8);
        console.log("70% utilization: borrowRate: %e, SupplyRate: %e", _b6, _l6);
        (uint256 _b7, uint256 _l7) = interestRateModel.getRatesPerSecondX96(1e8 - 0.5e8, 0.5e8);
        console.log("50% utilization: borrowRate: %e, SupplyRate: %e", _b7, _l7);
        (uint256 _b8, uint256 _l8) = interestRateModel.getRatesPerSecondX96(1e8 - 0.2e8, 0.2e8);
        console.log("20% utilization: borrowRate: %e, SupplyRate: %e", _b8, _l8);
        (uint256 _b9, uint256 _l9) = interestRateModel.getRatesPerSecondX96(1e8 - 0.1e8, 0.1e8);
        console.log("10% utilization: borrowRate: %e, SupplyRate: %e", _b9, _l9);
        (uint256 _b10, uint256 _l10) = interestRateModel.getRatesPerSecondX96(1e8, 0);
        console.log("0% utilization: borrowRate: %e, SupplyRate: %e", _b10, _l10);
        

        // 99%,88%,66%,77%,82%,85%,88%,91%,94%
        (uint256 _b11, uint256 _l11) = interestRateModel.getRatesPerSecondX96(1e8 - 0.99e8, 0.99e8);
        console.log("99% utilization: borrowRate: %e, SupplyRate: %e", _b11, _l11);
        (uint256 _b12, uint256 _l12) = interestRateModel.getRatesPerSecondX96(1e8 - 0.88e8, 0.88e8);
        console.log("88% utilization: borrowRate: %e, SupplyRate: %e", _b12, _l12);
        (uint256 _b13, uint256 _l13) = interestRateModel.getRatesPerSecondX96(1e8 - 0.66e8, 0.66e8);
        console.log("66% utilization: borrowRate: %e, SupplyRate: %e", _b13, _l13);
        (uint256 _b14, uint256 _l14) = interestRateModel.getRatesPerSecondX96(1e8 - 0.77e8, 0.77e8);
        console.log("77% utilization: borrowRate: %e, SupplyRate: %e", _b14, _l14);
        (uint256 _b15, uint256 _l15) = interestRateModel.getRatesPerSecondX96(1e8 - 0.82e8, 0.82e8);
        console.log("82% utilization: borrowRate: %e, SupplyRate: %e", _b15, _l15);
        (uint256 _b16, uint256 _l16) = interestRateModel.getRatesPerSecondX96(1e8 - 0.85e8, 0.85e8);
        console.log("85% utilization: borrowRate: %e, SupplyRate: %e", _b16, _l16);
        (uint256 _b17, uint256 _l17) = interestRateModel.getRatesPerSecondX96(1e8 - 0.88e8, 0.88e8);
        console.log("88% utilization: borrowRate: %e, SupplyRate: %e", _b17, _l17);
        (uint256 _b18, uint256 _l18) = interestRateModel.getRatesPerSecondX96(1e8 - 0.91e8, 0.91e8);
        console.log("91% utilization: borrowRate: %e, SupplyRate: %e", _b18, _l18);
        (uint256 _b19, uint256 _l19) = interestRateModel.getRatesPerSecondX96(1e8 - 0.94e8, 0.94e8);
        console.log("94% utilization: borrowRate: %e, SupplyRate: %e", _b19, _l19);
    }
}
//   100 utilization: borrowRate: 6.47731954542810578088e20, SupplyRate: 6.47731954542810578088e20
//   95 utilization: borrowRate: 5.10904855618069583879e20, SupplyRate: 4.85359612837166104685e20 
//   90 utilization: borrowRate: 3.7407775669332858967e20, SupplyRate: 3.36669981023995730702e20  
//   85 utilization: borrowRate: 2.37250657768587595461e20, SupplyRate: 2.01663059103299456141e20 
//   80 utilization: borrowRate: 1.00423558843846601253e20, SupplyRate: 8.0338847075077281002e19  
//   70 utilization: borrowRate: 8.7870613988365776096e19, SupplyRate: 6.1509429791856043267e19   
//   50 utilization: borrowRate: 6.2764724277404125783e19, SupplyRate: 3.1382362138702062891e19   
//   20 utilization: borrowRate: 2.5105889710961650313e19, SupplyRate: 5.021177942192330062e18    
//   10 utilization: borrowRate: 1.2552944855480825156e19, SupplyRate: 1.255294485548082515e18    
//   0 utilization: borrowRate: 0e0, SupplyRate: 0e0
//   99 utilization: borrowRate: 6.20366534757862379246e20, SupplyRate: 6.14162869410283755453e20 
//   88 utilization: borrowRate: 3.19346917123432191987e20, SupplyRate: 2.81025287068620328948e20 
//   66 utilization: borrowRate: 8.2849436046173446034e19, SupplyRate: 5.4680627790474474382e19   
//   77 utilization: borrowRate: 9.6657675387202353706e19, SupplyRate: 7.4426410048145812353e19   
//   82 utilization: borrowRate: 1.55154398413742998936e20, SupplyRate: 1.27226606699269259127e20 
//   85 utilization: borrowRate: 2.37250657768587595461e20, SupplyRate: 2.01663059103299456141e20 
//   88 utilization: borrowRate: 3.19346917123432191987e20, SupplyRate: 2.81025287068620328948e20 
//   91 utilization: borrowRate: 4.01443176478276788512e20, SupplyRate: 3.65313290595231877545e20 
//   94 utilization: borrowRate: 4.83539435833121385037e20, SupplyRate: 4.54527069683134101934e20 

// for 1 year seconds. Q96 ~= 8e28 (7.922e28)
//  100 utilization: borrowRate: 2.04408659286801990990698688e28, SupplyRate: 2.04408659286801990990698688e28
//  90 utilization: borrowRate: 1.1804996214625386301369992e28, SupplyRate: 1.06244965931628476712014352e28
//  70 utilization: borrowRate: 2.7729856879992518157271296e27, SupplyRate: 1.9410899815994762710026792e27