// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LaunchpadTestBase.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import "contracts/launchpad/libraries/RewardsTracker.sol";
import {UniswapV2Library, IUniswapV2Pair} from "@gte-univ2-periphery/UniswapV2Library.sol";
import {IUniswapV2Factory} from "@gte-univ2-core/interfaces/IUniswapV2Factory.sol";
import {GTELaunchpadV2PairFactory} from "contracts/launchpad/uniswap/GTELaunchpadV2PairFactory.sol";
import {GTELaunchpadV2Pair} from "contracts/launchpad/uniswap/GTELaunchpadV2Pair.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Distributor, IGTELaunchpadV2Pair} from "contracts/launchpad/Distributor.sol";

contract PoCLaunchpad is LaunchpadTestBase {
    using SafeTransferLib for address;

    GTELaunchpadV2PairFactory v2Factory;

    /// @notice Unit test for GTE Pair. Full integration test is not possible due to TestBase not using custom GTE uniswap yet.
    function test_debug_submissionValidity() external {
        GTELaunchpadV2Pair pair;
        //1. we create custom GTE pair with same config as LaunchPad uniswap pair
        // This only exist because full integration with GTE uniswap is not done yet
        {
            v2Factory = new GTELaunchpadV2PairFactory(
                address(0), address(launchpad), address(launchpadLPVault), address(distributor)
            );
            vm.prank(address(launchpad));
            v2Factory.createPair(token, address(quoteToken));

            address pairAddr = v2Factory.getPair(token, address(quoteToken));

            require(pairAddr != address(0), "Pair address should not be zero");
            require(IERC20(pairAddr).totalSupply() == 0, "Liquidity supply should be 0");

            //Mock LaunchPad graduate mint liquidity to the pair
            // 200M LaunchToken and 40 ETH
            deal(address(quoteToken), address(pairAddr), 40 ether);
            deal(token, address(pairAddr), 200_000_000 ether);

            IUniswapV2Pair(pairAddr).mint(address(launchpadLPVault));
            console.log("liquidity supply after mint %e", IERC20(pairAddr).balanceOf(address(launchpadLPVault)));
            pair = GTELaunchpadV2Pair(pairAddr);

            vm.assertEq(pair.rewardsPoolActive(), 1, "pair should be in reward pool active mode");
            vm.assertNotEq(
                pair.launchpadFeeDistributor(), address(0), "pair should have a valid launchpad fee distributor"
            );
        }
        //2. Create token pair from LaunchPad by graduate token
        // dev get 800M token shares
        // Distributor track rewards with users
        {
            fundAndApproveUser(dev, 100 ether);
            ILaunchpad.LaunchData memory launchdata = launchpad.launches(token);
            vm.assertTrue(launchdata.active, "Token is in launch/bonding mode");

            console.log("developer buy 800M token to graduate token pair to uniswap pair");
            // vm.prank(dev);
            buyLaunchToken(token, dev, 8e26); // buy all token so it graduate. already prank inside
            launchdata = launchpad.launches(token);

            RewardPoolDataMemory memory rpd = Distributor(distributor).getRewardsPoolData(token);
            vm.assertEq(rpd.totalShares, 8e26, "totalFeeShare should be 800M after graduate");
            vm.assertFalse(launchdata.active, "graduated so disable launch mode");
            vm.assertTrue(LaunchToken(token).unlocked(), "graduated so token unlocked");

            console.log("developer launchToken balance: %e", IERC20(token).balanceOf(dev));
        }
        //3. Developer sell all shares away
        {
            console.log("developer sell all stake to zero");
            //@ decrease stake from developer to zero. Developer can sell all token but uniswap currently have no liquidity
            vm.startPrank(address(launchpad));
            Distributor(distributor).decreaseStake(token, dev, uint96(LaunchToken(token).bondingShare(dev)));
            vm.stopPrank();

            //@we read Distributor pool. all token share is now empty
            RewardPoolDataMemory memory rpd = Distributor(distributor).getRewardsPoolData(token);
            vm.assertEq(rpd.totalShares, 0, "totalFeeShare should be zero after dev sell all");
        }
        //4. all attempt Distributor.addrewards() should fail
        // GTEPair have not been called end rewards yet.
        // now any attempt to swap will fail because it try to distribute asset with zero shares
        {
            vm.assertEq(pair.rewardsPoolActive(), 1, "pair should be in reward pool active mode");
            console.log("any attempt to swap will fail because it try to distribute asset with zero shares");
            skip(1 hours);
            deal(address(quoteToken), address(pair), 100 ether); // 100 eth for swap
            deal(token, address(pair), 100_000_000 ether); // 100M token for swap

            //@audit unexpected revert here
            console.log("--next call should not be revert--");
            vm.expectRevert(Distributor.NoSharesToIncentivize.selector);
            pair.swap(10 ether, 0, dev, new bytes(0)); // try to swap 1 ether of token0

            // pair.skim(dev);
        }
    }

    function fundAndApproveUser(address _user, uint256 amount) internal {
        vm.startPrank(_user);
        quoteToken.mint(_user, amount);
        quoteToken.approve(address(launchpad), type(uint256).max);
        ERC20Harness(token).approve(address(launchpad), type(uint256).max);
        quoteToken.approve(address(uniV2Router), type(uint256).max);
        ERC20Harness(token).approve(address(uniV2Router), type(uint256).max);
        vm.stopPrank();
    }

    function buyLaunchToken(address _token, address fromUser, uint256 amountOutBase) internal {
        vm.startPrank(fromUser);
        launchpad.buy(
            ILaunchpad.BuyData({
                account: fromUser,
                token: _token,
                recipient: fromUser,
                amountOutBase: amountOutBase,
                maxAmountInQuote: type(uint256).max
            })
        );
        vm.stopPrank();
    }

    function sellLaunchToken(address _token, address fromUser, uint256 amountInBase) internal {
        vm.startPrank(fromUser);
        launchpad.sell(fromUser, _token, fromUser, amountInBase, 0);
        vm.stopPrank();
    }
}
