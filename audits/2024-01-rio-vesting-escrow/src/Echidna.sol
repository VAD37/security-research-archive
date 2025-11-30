// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "./VestingEscrow.sol";
import "./VestingEscrowFactory.sol";
import "./adaptors/OZVotingAdaptor.sol";

import {GovernorVotesMock} from '../test/lib/GovernorVotesMock.sol';
import {OZVotingToken} from '../test/lib/OZVotingToken.sol';

contract TestEchidna {

    event AssertionFailed(uint256);
    event AssertionFailed(uint256,uint256);
    event AssertionFailed(uint,uint256,uint256);
    event AssertionFailed();
    event AssertionFailed(string);


    struct VestingEscrowConfig {
        uint256 amount;
        address recipient;
        uint40 vestingDuration;
        uint40 vestingStart;
        uint40 cliffLength;
        bool isFullyRevokable;
        bytes initialDelegateParams;
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }


    VestingEscrowFactory  factory;
    OZVotingAdaptor  ozVotingAdaptor;

    GovernorVotesMock  governor;
    OZVotingToken  token;

    VestingEscrow  deployedVesting;

    uint256  amount;
    address  recipient;
    uint40  startTime;
    uint40  duration;
    uint40  cliffLength;
    bool  isFullyRevokable;
    bytes  initialDelegateParams = new bytes(0);

    uint testStartTime;

    address escrow;

    constructor() {
        address owner = address(this);
        address manager = address(this);
        // Setup Protocol
        token = new OZVotingToken();
        governor = new GovernorVotesMock(address(token));
        ozVotingAdaptor = new OZVotingAdaptor(address(governor), address(token), owner);
        factory = new VestingEscrowFactory(
            address(new VestingEscrow()), address(token), owner, manager, address(ozVotingAdaptor)
        );
        token.mint(owner, 100 ether);
        token.approve(address(factory), 100 ether);
        //setup vesting later     
        testStartTime = block.timestamp;   
    }

    function setAmount(uint256 _amount) public {
        require(_amount> 1e5);
        require(amount <= token.balanceOf(address(this)), "amount must be less than 100 ether");        
        amount = _amount;
    }

    function setStartTime(uint40 _startTime) public {
        startTime = _startTime;
    }

    function setStartTimeBlockTimeStamp() public {
        startTime = uint40(block.timestamp);
    }

    function setDuration(uint40 _endTime) public {
        duration = _endTime;
    }

    function setCliffLength(uint40 _cliffLength) public {
        require(_cliffLength < duration);
        cliffLength = _cliffLength;
    }
    function setFullyRevokable(bool _isFullyRevokable) public {
        isFullyRevokable = _isFullyRevokable;
    }

    function randomDeploy() public {
        require(escrow == address(0), "escrow already deployed");
        // Deploy Vesting Escrow
        // amount = 100 ether;
        recipient = address(this);
        // startTime = uint40(block.timestamp);
        // endTime = startTime + 1000;
        // cliffLength = 100;
        // isFullyRevokable = true;
        initialDelegateParams = new bytes(0);

        escrow = factory.deployVestingContract(
            amount, recipient, startTime, duration, cliffLength, isFullyRevokable, initialDelegateParams
        );

        deployedVesting = VestingEscrow(escrow);
    }

    function slowlyStealToken() public {
        require(escrow != address(0), "escrow not deployed");
        uint previousBalance = token.balanceOf(address(this));
        deployedVesting.recoverERC20(address(token), 9999e18);
        uint afterBalance = token.balanceOf(address(this));
        if(previousBalance != afterBalance) {
            emit AssertionFailed(previousBalance,afterBalance);
        }
    }

    function claimToken(uint _amount) public {
        require(escrow != address(0), "escrow not deployed");
        uint returnedToken =deployedVesting.claim(address(this),_amount);
    }

    function unclaimedAlwaysEqualAvailableToken() public {
        require(escrow != address(0), "escrow not deployed");
        uint unclaimed = deployedVesting.unclaimed();
        require(unclaimed>0);
        uint tokenBalance = token.balanceOf(address(deployedVesting));
        if(unclaimed != tokenBalance) {
            emit AssertionFailed(block.timestamp,unclaimed,tokenBalance);
        }
    }


    function unclaimedAlwaysBigger() public {
        require(escrow != address(0), "escrow not deployed");
        uint unclaimed = deployedVesting.unclaimed();
        require(unclaimed>0);
        uint tokenBalance = token.balanceOf(address(deployedVesting));
        if(unclaimed > tokenBalance) {
            emit AssertionFailed(unclaimed,tokenBalance);
        }
    }    

    function unclaimedAlwaysEqualLocked() public {
        require(escrow != address(0), "escrow not deployed");
        uint unclaimed = deployedVesting.unclaimed();
        require(unclaimed>0);
        uint tokenBalance = token.balanceOf(address(deployedVesting));
        uint locked = deployedVesting.locked();
        if(unclaimed < locked) {
            emit AssertionFailed(unclaimed,locked);
        }
    }

    function revokeUnvested() public {
        require(escrow != address(0), "escrow not deployed");
        deployedVesting.revokeUnvested();
    }
    function revokeAll() public {
        require(escrow != address(0), "escrow not deployed");
        deployedVesting.revokeAll();
    }
    
    // function checkStartTime() public  returns (bool) {
    //     assert(testStartTime + 1000 >= block.timestamp);
    //     return false;
    // }

    // function echidna_balance_check() public returns (bool) {
    //     return token.balanceOf(address(this)) > 0;
    // }

}