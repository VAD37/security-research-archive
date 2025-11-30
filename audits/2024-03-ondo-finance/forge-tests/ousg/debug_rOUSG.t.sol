pragma solidity 0.8.16;

import "forge-tests/OUSG_BasicDeployment.t.sol";
import "lib/forge-std/src/console.sol";

contract Test_debug_rOUSG_ETH is OUSG_BasicDeployment {
    address constant NO_KYC_ADDRESS = 0x0000000000000000000000000000000000000Bad;
    address constant ALT_GUARDIAN = 0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa;

    function setUp() public override {
        super.setUp();
        // Initial State: OUSG Oracle returns price of $100 per OUSG
        oracleCheckHarnessOUSG.setPrice(50e18);
        CashKYCSenderReceiver ousgProxied = CashKYCSenderReceiver(address(ousg));
        vm.startPrank(OUSG_GUARDIAN);
        ousgProxied.grantRole(ousgProxied.MINTER_ROLE(), OUSG_GUARDIAN);
        vm.stopPrank();

        // Sanity Asserts
        assertEq(rOUSGToken.totalSupply(), 0);
        assertTrue(registry.getKYCStatus(OUSG_KYC_REQUIREMENT_GROUP, address(this)));
        assertTrue(registry.getKYCStatus(OUSG_KYC_REQUIREMENT_GROUP, address(rOUSGToken)));
        assertTrue(registry.getKYCStatus(OUSG_KYC_REQUIREMENT_GROUP, alice));
    }

    function dealROUSG(address target, uint256 ousgAmount) internal {
        _addAddressToKYC(OUSG_KYC_REQUIREMENT_GROUP, target);
        vm.prank(OUSG_GUARDIAN);
        ousg.mint(target, ousgAmount);
    }

    function testDeposit() public {
        oracleCheckHarnessOUSG.setPrice(0.12e18);
        uint256 ousgAmount = 98e18;
        address user = address(0x1001);
        dealROUSG(user, ousgAmount);

        vm.startPrank(user);
        ousg.approve(address(rOUSGToken), type(uint256).max);
        rOUSGToken.wrap(ousgAmount);
        //wrap use ousg TOken as input.
        // transfered in 98e18 token. get *10000 = 98e23 share.
        printBalance(user);

        rOUSGToken.unwrap(rOUSGToken.balanceOf(user));
        //unwrap use rOUSG as input. rOUSG is pegged to 1USDC by oracle.
        //@share = amount * 1e18 * OUSG_TO_ROUSG_SHARES_MULTIPLIER) / oraclePrice
        // ousg = share / 10000
        //convert USD to share. then convert share to ousg Token and transfer to user.
        printBalance(user);
        vm.stopPrank();
    }
    
    /// forge-config: default.fuzz.runs = 20000
    /// forge-config: default.fuzz.max-test-rejects = 20000000
    function test_Fuzz_Transfer(uint256 amount, uint256 oraclePrice) public {
        vm.assume(amount > 1e6 && amount < 1e30);     
        vm.assume(oraclePrice > 0.01e18);

        address user = address(0x1001);
        dealROUSG(user, amount);
        
        vm.startPrank(user);
        ousg.approve(address(rOUSGToken), type(uint256).max);
        rOUSGToken.wrap(amount);
        uint256 rousgOut = rOUSGToken.getROUSGByShares(amount * 10_000);
        rOUSGToken.transfer(address(alice), rousgOut);
        vm.stopPrank();
        require(rOUSGToken.balanceOf(user) == 0, "user balance should be 0");
        require(rOUSGToken.sharesOf(user) == 0, "user shares should be 0");
    }

    function printBalance(address user) internal {
        console.log("------%s balance------", user);
        console.log("ousg balance: %e", ousg.balanceOf(user));
        console.log("rOUSG balance: %e", rOUSGToken.balanceOf(user));
        console.log("rOUSG shareBalance: %e", rOUSGToken.sharesOf(user));
    }
}
//how the heck i got this result
// ROUSG deployed 0x7ff9C67c93D9f7318219faacB5c619a773AFeF6A
// OUSG Instant Manager deployed 0xa0Cb889707d426A7A386870A03bc70d1b0697598
// ------0x0000000000000000000000000000000000001001 balance------
// ousg balance: 9.8e19
// rOUSG balance: 9.8e21
// rOUSG shareBalance: 9.8e23
// ------0x0000000000000000000000000000000000001001 balance------
// ousg balance: 9.898e19
// rOUSG balance: 9.702e21
// rOUSG shareBalance: 9.702e23
