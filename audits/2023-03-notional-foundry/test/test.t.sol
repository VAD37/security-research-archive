// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.7.6;
pragma abicoder v2;

import "./Deployer.sol";
import "forge-std/Test.sol";
// import "../src/interfaces/IERC20.sol";
import "../src/interfaces/WETH9.sol";

contract DeployerTest is Test {
    Deployer deployer;
    MockERC20 DAI;
    uint testNumber = 290;
    function setUp() public {
        deployer = new Deployer();
        deployer.initTestEnvironment();
        DAI = deployer.DAI();
    }

    function test_DecimalNotWrong() public {
        assertEq(uint(DAI.decimals()), uint(18));
    }

    function test_number() public {
        assertEq(testNumber, 290);
    }

}