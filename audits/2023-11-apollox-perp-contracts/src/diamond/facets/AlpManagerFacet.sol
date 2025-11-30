// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../utils/TransferHelper.sol";
import {ZeroAddress, IAlpManagerError} from "../../utils/Errors.sol";
import "../security/Pausable.sol";
import "../security/ReentrancyGuard.sol";
import {LpItem, IVault} from "../interfaces/IVault.sol";
import {ITradingCore} from "../interfaces/ITradingCore.sol";
import {IPriceFacade} from "../interfaces/IPriceFacade.sol";
import "../interfaces/IAlpManager.sol";
import "../libraries/LibAlpManager.sol";
import "../libraries/LibStakeReward.sol";
import "../libraries/LibAccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

interface IAlp {
    function mint(address to, uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

contract AlpManagerFacet is ReentrancyGuard, Pausable, IAlpManager, IAlpManagerError {

    using TransferHelper for address;
    using SignatureChecker for address;

    struct MintAlpTuple {
        address tokenIn;
        uint256 amountIn;
        uint256 minAlp;
        bool stake;
        int256 lpUnPnlUsd;
        int256 lpTokenUnPnlUsd;
    }

    struct BurnAlpTuple {
        address tokenOut;
        uint256 alpAmount;
        uint256 minOut;
        address receiver;
        int256 lpUnPnlUsd;
        int256 lpTokenUnPnlUsd;
    }

    function initAlpManagerFacet(address alpToken, address signer) external {
        LibAccessControlEnumerable.checkRole(Constants.DEPLOYER_ROLE);
        if (alpToken == address(0) || signer == address(0)) {
            revert ZeroAddress();
        }
        LibAlpManager.initialize(alpToken, signer);
    }

    function ALP() public view override returns (address) {
        return LibAlpManager.alpManagerStorage().alp;
    }

    function coolingDuration() external view override returns (uint256) {
        return LibAlpManager.alpManagerStorage().coolingDuration;
    }

    function setCoolingDuration(uint256 coolingDuration_) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibAlpManager.AlpManagerStorage storage ams = LibAlpManager.alpManagerStorage();
        ams.coolingDuration = coolingDuration_;
    }

    function getSigner() external view override returns (address) {
        return LibAlpManager.alpManagerStorage().signer;
    }

    function setSigner(address signer) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        if (signer == address(0)) {
            revert ZeroAddress();
        }
        LibAlpManager.AlpManagerStorage storage ams = LibAlpManager.alpManagerStorage();
        ams.signer = signer;
    }

    function mintAlp(address tokenIn, uint256 amountIn, uint256 minAlp, bool stake) external whenNotPaused nonReentrant override {
        (int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = ITradingCore(address(this)).lpUnrealizedPnlUsd(tokenIn);
        _mintAlp(LibAlpManager.alpManagerStorage(), MintAlpTuple(tokenIn, amountIn, minAlp, stake, lpUnPnlUsd, lpTokenUnPnlUsd));
    }

    function mintAlpBNB(uint256 minAlp, bool stake) external payable whenNotPaused nonReentrant override {
        address tokenIn = TransferHelper.nativeWrapped();
        uint256 amountIn = msg.value;
        (int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = ITradingCore(address(this)).lpUnrealizedPnlUsd(tokenIn);
        _mintAlp(LibAlpManager.alpManagerStorage(), MintAlpTuple(tokenIn, amountIn, minAlp, stake, lpUnPnlUsd, lpTokenUnPnlUsd));
    }

    /// @param message (chainId, deadline, tokenIn, lpUnPnlUsd, lpTokenUnPnlUsd)
    function mintAlpWithSignature(
        uint256 amountIn, uint256 minAlp, bool stake, bytes calldata message, bytes calldata signature
    ) external payable whenNotPaused nonReentrant override {
        LibAlpManager.AlpManagerStorage storage ams = LibAlpManager.alpManagerStorage();
        (address tokenIn, int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = _verifySignature(ams.signer, message, signature);
        _mintAlp(ams, MintAlpTuple(tokenIn, amountIn, minAlp, stake, lpUnPnlUsd, lpTokenUnPnlUsd));
    }//@audit mint with signature bypass trading core safety check.

    function _verifySignature(
        address signer, bytes calldata message, bytes calldata signature
    ) private view returns (address token, int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) {
        if (!signer.isValidSignatureNow(ECDSA.toEthSignedMessageHash(keccak256(message)), signature)) {
            revert InvalidSignature();
        }
        uint256 chainId;
        uint256 deadline;//@note signature deadline have 60s repeats
        (chainId, deadline, token, lpUnPnlUsd, lpTokenUnPnlUsd) = abi.decode(message, (uint256, uint256, address, int256, int256));
        if (chainId != block.chainid) {
            revert UnsupportedChain(block.chainid, chainId);
        }
        if (block.timestamp > deadline) {
            revert ExpiredSignature(block.timestamp, deadline);
        }//@audit can reuse signature. 1 person sign and other people can use it too.
        return (token, lpUnPnlUsd, lpTokenUnPnlUsd);
    }

    function _mintAlp(LibAlpManager.AlpManagerStorage storage ams, MintAlpTuple memory tuple) private {
        if (tuple.amountIn == 0) revert InvalidAmount();
        LpItem memory item = IVault(address(this)).itemValue(tuple.tokenIn);
        if (item.tokenAddress == address(0)) revert UnsupportedToken(tuple.tokenIn);
        int256 totalValueUsd = IVault(address(this)).getTotalValueUsd() + tuple.lpUnPnlUsd;
        if (totalValueUsd < 0) revert InsufficientLiquidityPool(totalValueUsd);

        uint256 tokenInPrice;
        if (item.valueUsd == 0 || item.value == 0) {
            tokenInPrice = IPriceFacade(address(this)).getPrice(item.tokenAddress);
        } else {
            tokenInPrice = uint256(item.valueUsd) * (10 ** item.decimals) / (uint256(item.value) * 1e10);
        }
        uint256 amountInUsd = tokenInPrice * tuple.amountIn * 1e10 / (10 ** item.decimals);
        uint256 feePoint = LibAlpManager.getFeePoint(item, uint256(totalValueUsd), int256(item.valueUsd) + tuple.lpTokenUnPnlUsd, amountInUsd, true);
        // amountInUsd * (10000 - feePoint) / 10000
        uint256 afterTaxAmountInUsd = amountInUsd * (1e4 - feePoint) / 1e4;
        uint256 alpAmount = afterTaxAmountInUsd * 1e8 / LibAlpManager.alpPrice(totalValueUsd);
        if (alpAmount < tuple.minAlp) revert InsufficientALPOutput(tuple.minAlp, alpAmount);
        emit MintFee(
            msg.sender, tuple.tokenIn, tuple.amountIn, tokenInPrice, amountInUsd - afterTaxAmountInUsd, alpAmount
        );
        tuple.tokenIn.transferFrom(msg.sender, tuple.amountIn);
        IVault(address(this)).increase(tuple.tokenIn, tuple.amountIn);
        emit MintAddLiquidity(msg.sender, tuple.tokenIn, tuple.amountIn);
        ams.lastMintedAt[msg.sender] = block.timestamp;
        _mint(msg.sender, tuple.tokenIn, tuple.amountIn, alpAmount, tuple.stake);
    }

    function _mint(address account, address tokenIn, uint256 amount, uint256 alpAmount, bool stake) private {
        IAlp(ALP()).mint(account, alpAmount);
        emit MintAlp(account, tokenIn, amount, alpAmount);
        if (stake) {
            LibStakeReward.stake(alpAmount);
        }
    }

    function burnAlp(address tokenOut, uint256 alpAmount, uint256 minOut, address receiver) external whenNotPaused nonReentrant override {
        (int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = ITradingCore(address(this)).lpUnrealizedPnlUsd(tokenOut);
        _burnAlp(LibAlpManager.alpManagerStorage(), BurnAlpTuple(tokenOut, alpAmount, minOut, receiver, lpUnPnlUsd, lpTokenUnPnlUsd));
    }

    function burnAlpBNB(uint256 alpAmount, uint256 minOut, address payable receiver) external whenNotPaused nonReentrant override {
        address tokenOut = TransferHelper.nativeWrapped();
        (int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = ITradingCore(address(this)).lpUnrealizedPnlUsd(tokenOut);
        _burnAlp(LibAlpManager.alpManagerStorage(), BurnAlpTuple(tokenOut, alpAmount, minOut, receiver, lpUnPnlUsd, lpTokenUnPnlUsd));
    }

    /// @param message (chainId, deadline, tokenOut, lpUnPnlUsd, lpTokenUnPnlUsd)
    function burnAlpWithSignature(
        uint256 alpAmount, uint256 minOut, address receiver, bytes calldata message, bytes calldata signature
    ) external whenNotPaused nonReentrant override {
        LibAlpManager.AlpManagerStorage storage ams = LibAlpManager.alpManagerStorage();
        (address tokenOut, int256 lpUnPnlUsd, int256 lpTokenUnPnlUsd) = _verifySignature(ams.signer, message, signature);
        _burnAlp(ams, BurnAlpTuple(tokenOut, alpAmount, minOut, receiver, lpUnPnlUsd, lpTokenUnPnlUsd));
    }

    function _burnAlp(LibAlpManager.AlpManagerStorage storage ams, BurnAlpTuple memory tuple) private {
        if (tuple.alpAmount == 0) revert InvalidAmount();
        if (!ams.freeBurnWhitelists[msg.sender] && ams.lastMintedAt[msg.sender] + ams.coolingDuration >= block.timestamp) {
            revert CoolingOffPeriod(msg.sender, ams.lastMintedAt[msg.sender] + ams.coolingDuration);
        }
        LpItem memory item = IVault(address(this)).itemValue(tuple.tokenOut);
        if (item.tokenAddress == address(0)) revert UnsupportedToken(tuple.tokenOut);
        int256 totalValueUsd = IVault(address(this)).getTotalValueUsd() + tuple.lpUnPnlUsd;
        int256 poolTokenOutUsd = int256(item.valueUsd) + tuple.lpTokenUnPnlUsd;
        uint256 amountOutUsd = LibAlpManager.alpPrice(totalValueUsd) * tuple.alpAmount / 1e8;
        if (totalValueUsd < 0 || int256(amountOutUsd) >= poolTokenOutUsd || int256(amountOutUsd) > totalValueUsd) {
            revert InsufficientLiquidityPool(totalValueUsd);
        }
        uint256 feePoint = LibAlpManager.getFeePoint(item, uint256(totalValueUsd), poolTokenOutUsd, amountOutUsd, false);
        uint256 afterTaxAmountOutUsd = amountOutUsd * (1e4 - feePoint) / 1e4;
        uint256 tokenOutPrice;
        if (item.valueUsd == 0 || item.value == 0) {
            tokenOutPrice = IPriceFacade(address(this)).getPrice(item.tokenAddress);
        } else {
            tokenOutPrice = uint256(item.valueUsd) * (10 ** item.decimals) / (uint256(item.value) * 1e10);
        }
        uint256 amountOut = afterTaxAmountOutUsd * 10 ** item.decimals / (tokenOutPrice * 1e10);
        if (amountOut < tuple.minOut) revert InsufficientTokenOutput(tuple.tokenOut, tuple.minOut, amountOut);
        emit BurnFee(
            msg.sender, tuple.tokenOut, amountOut, tokenOutPrice, amountOutUsd - afterTaxAmountOutUsd, tuple.alpAmount
        );
        IAlp(ALP()).burnFrom(msg.sender, tuple.alpAmount);
        IVault(address(this)).decrease(tuple.tokenOut, amountOut);
        emit BurnRemoveLiquidity(msg.sender, tuple.tokenOut, amountOut);
        tuple.tokenOut.transfer(tuple.receiver, amountOut);
        emit BurnAlp(msg.sender, tuple.receiver, tuple.tokenOut, tuple.alpAmount, amountOut);
    }

    function addFreeBurnWhitelist(address account) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibAlpManager.AlpManagerStorage storage ams = LibAlpManager.alpManagerStorage();
        ams.freeBurnWhitelists[account] = true;
        emit SupportedFreeBurn(account, true);
    }

    function removeFreeBurnWhitelist(address account) external override {
        LibAccessControlEnumerable.checkRole(Constants.ADMIN_ROLE);
        LibAlpManager.AlpManagerStorage storage ams = LibAlpManager.alpManagerStorage();
        ams.freeBurnWhitelists[account] = false;
        emit SupportedFreeBurn(account, false);
    }

    function isFreeBurn(address account) external view override returns (bool) {
        return LibAlpManager.alpManagerStorage().freeBurnWhitelists[account];
    }

    function alpPrice() external view override returns (uint256) {
        int256 totalValueUsd = IVault(address(this)).getTotalValueUsd();
        (int256 lpUnPnlUsd,) = ITradingCore(address(this)).lpUnrealizedPnlUsd();
        return LibAlpManager.alpPrice(totalValueUsd + lpUnPnlUsd);
    }

    function lastMintedTimestamp(address account) external view override returns (uint256) {
        return LibAlpManager.alpManagerStorage().lastMintedAt[account];
    }
}