// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Invalid Insufficient Nonexistent Existent Unsupported

error ZeroAddress();

interface IPriceFacadeError {
    error NonexistentRequestId(bytes32 requestId);
}

interface ITradingCoreError {
    error UnsupportedMarginToken(address token);
}

interface ISlippageManagerError {
    error InvalidSlippage(uint16 slippageLongP, uint16 slippageShortP);
    error InvalidOnePercentDepthUsd(uint256 onePercentDepthAboveUsd, uint256 onePercentDepthBelowUsd);
    error ExistentSlippage(uint16 index, string name);
    error NonexistentSlippage(uint16 index);
    error SlippageInUse(uint16 index, string name);
}

interface ITradingPortalError {
    error NonexistentTrade();
    error UnauthorizedOperation(address operator);
    error MarketClosed();
    error PairClosed(address pairBase);
    error InvalidStopLoss(bytes32 tradeHash, uint64 entryPrice, uint64 newStopLoss);
    error InsufficientMarginAmount(bytes32 tradeHash, uint256 amount);
    error BelowDegenModeMinLeverage(bytes32 tradeHash, uint256 minRequiredLeverage, uint256 newLeverage);
}

interface IAlpManagerError {
    error InvalidSignature();
    error UnsupportedChain(uint256 currentChainId, uint256 unsupportedChainId);
    error ExpiredSignature(uint256 current, uint256 deadline);
    error UnsupportedToken(address token);
    error InsufficientLiquidityPool(int256 amountUsd);
    error InsufficientALPOutput(uint256 target, uint256 actual);
    error InsufficientTokenOutput(address token, uint256 target, uint256 actual);
    error InvalidAmount();
    error CoolingOffPeriod(address user, uint256 dueDate);
}

interface IHookManagerError {
    error ExistentPartner(address protocolAddress, string name, string url);
    error NonexistentPartner(address protocolAddress);
}