// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { IMinter } from "../../interfaces/IMinter.sol";
import { IOracle } from "../../interfaces/IOracle.sol";
import { IVault } from "../../interfaces/IVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title Amount Out Logic
/// @author kexley, Cap Labs
/// @notice Amount out logic for exchanging underlying assets with cap tokens
library MinterLogic {
    /// @dev Ray precision
    uint256 constant RAY_PRECISION = 1e27;

    /// @dev Share precision
    uint256 constant SHARE_PRECISION = 1e33;

    /// @notice Calculate the amount out from a swap including fees
    /// @param $ Storage pointer
    /// @param params Parameters for a swap
    /// @return amount Amount out from a swap
    /// @return fee Fee applied
    function amountOut(IMinter.MinterStorage storage $, IMinter.AmountOutParams memory params)
        external
        view
        returns (uint256 amount, uint256 fee)
    {//called from MinterLogic.amountOut(getMinterStorage(), AmountOutParams({ mint: true, asset: _asset, amount: _amountIn }));
        (uint256 amountOutBeforeFee, uint256 newRatio) = _amountOutBeforeFee($.oracle, params);//amountIn is ERC20 asset transfer from user to CapToken contract

        if ($.whitelist[msg.sender]) {
            amount = amountOutBeforeFee;
        } else {
            (amount, fee) = _applyFeeSlopes(
                $.fees[params.asset],
                IMinter.FeeSlopeParams({ mint: params.mint, amount: amountOutBeforeFee, ratio: newRatio })
            );
        }
    }

    /// @notice Calculate the output amounts for redeeming a cap token for a proportional weighting
    /// @param $ Storage pointer
    /// @param params Parameters for redeeming
    /// @return amounts Amount of underlying assets withdrawn
    /// @return fees Amount of fees applied
    function redeemAmountOut(IMinter.MinterStorage storage $, IMinter.RedeemAmountOutParams memory params)
        external
        view
        returns (uint256[] memory amounts, uint256[] memory fees)
    {
        uint256 redeemFee = $.whitelist[msg.sender] ? 0 : $.redeemFee;//0.1% redeem fee
        uint256 shares = params.amount * SHARE_PRECISION / IERC20(address(this)).totalSupply();
        address[] memory assets = IVault(address(this)).assets();
        uint256 assetLength = assets.length;
        amounts = new uint256[](assetLength);
        fees = new uint256[](assetLength);
        for (uint256 i; i < assetLength; ++i) {
            address asset = assets[i];
            uint256 withdrawAmount = IVault(address(this)).totalSupplies(asset) * shares / SHARE_PRECISION;

            fees[i] = withdrawAmount * redeemFee / RAY_PRECISION;
            amounts[i] = withdrawAmount - fees[i];
        }
    }

    /// @notice Calculate the amount out for a swap before fees
    /// @param _oracle Oracle address
    /// @param params Parameters for a swap
    /// @return amount Amount out from a swap before fees
    /// @return newRatio New ratio of an asset to the overall basket after swap. in e27. ratio = total asset value(USDC) / total cap value (USDC + USDT)
    function _amountOutBeforeFee(address _oracle, IMinter.AmountOutParams memory params)
        internal
        view
        returns (uint256 amount, uint256 newRatio)
    {
        (uint256 assetPrice,) = IOracle(_oracle).getPrice(params.asset);// price of USDT,USDC, 8 decimals
        (uint256 capPrice,) = IOracle(_oracle).getPrice(address(this));//price of cUSD in USD, 8 decimals . capPrice = totalUSD /totalCapSupply
        //cUSD_price = total USD / total cUSD_supply. @
        uint256 assetDecimalsPow = 10 ** IERC20Metadata(params.asset).decimals();
        uint256 capDecimalsPow = 10 ** IERC20Metadata(address(this)).decimals();

        uint256 capSupply = IERC20(address(this)).totalSupply();
        uint256 capValue = capSupply * capPrice / capDecimalsPow;//total cap value in USD
        uint256 allocationValue = IVault(address(this)).totalSupplies(params.asset) * assetPrice / assetDecimalsPow;//total this specific asset value in USD

        uint256 assetValue;//@new incoming asset value in USD
        if (params.mint) {//@mint from Minter. amountOut is cUSD or cETH
            assetValue = params.amount * assetPrice / assetDecimalsPow;//@asset value in USD_e8
            if (capSupply == 0) {
                newRatio = 0;
                amount = assetValue * capDecimalsPow / assetPrice;//this fixed cUSD price to first asset deposit price of USD. which is true
            } else {
                newRatio = (allocationValue + assetValue) * RAY_PRECISION / (capValue + assetValue);//post_ratio = (new total asset value) *1e27 / (all USD + new asset) = ratio of asset USDC in pool after deposit
                amount = assetValue * capDecimalsPow / capPrice;//mint amount = assetValue_USD * 1e18 / 0.9995e8 = amount of cUSD_e18 to mint
            }
        } else {//@burn from Minter. amountOut is asset USDC, ETH,USDT
            assetValue = params.amount * capPrice / capDecimalsPow;//@audit R amount burn always cUSD_e18 .capPrice in 8 decimals while capToken is 18 decimals.
            if (params.amount == capSupply) {//@ assetIn might be cUSD. we are burning cUSD right?
                newRatio = RAY_PRECISION;
                amount = assetValue * assetDecimalsPow / assetPrice;
            } else {
                if (allocationValue < assetValue || capValue <= assetValue) {
                    newRatio = 0;
                } else {
                    newRatio = (allocationValue - assetValue) * RAY_PRECISION / (capValue - assetValue);//@can burn everything. oracle price of cap same as asset. if there is single asset
                }
                amount = assetValue * assetDecimalsPow / assetPrice;
            }
        }
    }

    /// @notice Apply fee slopes to a mint or burn
    /// @dev Fees only apply to mints or burns that over-allocate the basket to one asset
    /// @param fees Fee slopes and ratio kinks
    /// @param params Fee slope parameters
    /// @return amount Remaining amount after fee applied
    /// @return fee Fee applied
    function _applyFeeSlopes(IMinter.FeeData memory fees, IMinter.FeeSlopeParams memory params)
        internal
        pure
        returns (uint256 amount, uint256 fee)
    {
        uint256 rate;//ratio <=100%. no ratio if first deposit
        if (params.mint) {
            rate = fees.minMintFee;//0.005e27 = 0.5%
            if (params.ratio > fees.optimalRatio) {//ratio of single asset weight in basket > 0.33e27 or 33%
                if (params.ratio > fees.mintKinkRatio) {//0.85e27 or 85%
                    uint256 excessRatio = params.ratio - fees.mintKinkRatio;//slope0: 0.0001e27 = 0.01%. slope1: 0.1e27 = 10%
                    rate += fees.slope0 + (fees.slope1 * excessRatio / (RAY_PRECISION - fees.mintKinkRatio)); //max rate = 0.5% + 0.01% + 10% = 10.51%
                } else { // < 85%. with ratio = 50%.
                    rate += fees.slope0 * (params.ratio - fees.optimalRatio) / (fees.mintKinkRatio - fees.optimalRatio);// rate += slope0 * (50% - 33%) / (85% - 33%)= slope0 * range(0,100)
                }
            }//else small default fee 0.5% if asset weight ratio < 33%
        } else {//@burn ,redeem. if redeem all single asset from pool. it take serious maximum 10% fee on total deposit. user can avoid by split redeem pieces by piece
            if (params.ratio < fees.optimalRatio) {// ratio < 33%
                if (params.ratio < fees.burnKinkRatio) { //< 0.15e27 or 15%
                    uint256 excessRatio = fees.burnKinkRatio - params.ratio;//@audit M test if user withdraw 1% of asset slowly, does it affect total redeem fee?
                    rate = fees.slope0 + (fees.slope1 * excessRatio / fees.burnKinkRatio);//@ok rate = 0.01% + 10% * range(0,100) 
                } else {// ratio > 15% and < 33%
                    rate = fees.slope0 * (fees.optimalRatio - params.ratio) / (fees.optimalRatio - fees.burnKinkRatio);
                }//@audit M Fee discrimination. fee is based on post withdraw/mint ratio. This include full liquidity of asset in pool. so fee is taken based on final fee not linear fee taken based on slope. 
            }// ratio > 33%, no fee on redeem. already 0.5% fee on mint
        }//@audit M frontrun attack where it force one asset to have over 85% ratio, and next person will have pay 10% fee. also meaning they deposit lots of asset to mint but total value drop. as cUSD can depeg to 91% of USDC instantly due to fee go to insurance

        if (rate > RAY_PRECISION) rate = RAY_PRECISION;
        fee = params.amount * rate / RAY_PRECISION;
        amount = params.amount - fee;
    }
}
