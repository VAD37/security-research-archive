// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, User} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {CreditPosition, DebtPosition, LoanLibrary, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {LimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";
import {VariablePoolBorrowRateParams} from "@src/libraries/YieldCurveLibrary.sol";

struct BuyCreditMarketParams {
    // The borrower
    // If creditPositionId is not RESERVED_ID, this value is ignored and the owner of the existing credit is used
    address borrower;
    // The credit position ID to buy
    // If RESERVED_ID, a new credit position will be created
    uint256 creditPositionId;
    // The amount of credit to buy
    uint256 amount;
    // The tenor of the loan
    // If creditPositionId is not RESERVED_ID, this value is ignored and the tenor of the existing loan is used
    uint256 tenor;
    // The deadline for the transaction
    uint256 deadline;
    // The minimum APR for the loan
    uint256 minAPR;
    // Whether amount means cash or credit
    bool exactAmountIn;
}

/// @title BuyCreditMarket
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for buying credit (lending) as a market order
library BuyCreditMarket {
    using OfferLibrary for LimitOrder;
    using OfferLibrary for State;
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using RiskLibrary for State;

    struct SwapDataBuyCreditMarket {
        CreditPosition creditPosition;
        address borrower;
        uint256 creditAmountOut;
        uint256 cashAmountIn;
        uint256 swapFee;
        uint256 fragmentationFee;
        uint256 tenor;
    }

    /// @notice Validates the input parameters for buying credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    function validateBuyCreditMarket(State storage state, BuyCreditMarketParams calldata params) external view {
        address borrower;
        uint256 tenor;

        // validate creditPositionId
        if (params.creditPositionId == RESERVED_ID) {//@new position based open matching offer
            borrower = params.borrower;
            tenor = params.tenor;

            // validate tenor
            if (tenor < state.riskConfig.minTenor || tenor > state.riskConfig.maxTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(tenor, state.riskConfig.minTenor, state.riskConfig.maxTenor);
            }
        } else {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            if (!state.isCreditPositionTransferrable(params.creditPositionId)) {
                revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                    params.creditPositionId,
                    uint8(state.getLoanStatus(params.creditPositionId)),
                    state.collateralRatio(debtPosition.borrower)
                );
            }
            User storage user = state.data.users[creditPosition.lender];
            if (user.allCreditPositionsForSaleDisabled || !creditPosition.forSale) {
                revert Errors.CREDIT_NOT_FOR_SALE(params.creditPositionId);
            }

            borrower = creditPosition.lender;
            tenor = debtPosition.dueDate - block.timestamp; // positive since the credit position is transferrable, so the loan must be ACTIVE
        }

        // validate borrower
        if (borrower == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate tenor
        // N/A //@remove check if open offer tenor is different from sender. This assume all offer now use fixed tenor

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minAPR
        uint256 borrowAPR = state.getBorrowOfferAPRByTenor(borrower, tenor);
        if (borrowAPR < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(borrowAPR, params.minAPR);
        }//@safety check to prevent offer change halfway

        // validate exactAmountIn
        // N/A

        // validate inverted curve
        try state.getLoanOfferAPRByTenor(borrower, tenor) returns (uint256 loanAPR) {
            if (borrowAPR >= loanAPR) {
                revert Errors.MISMATCHED_CURVES(borrower, tenor, loanAPR, borrowAPR);
            }//@this is new. return APR yield based on borrower offer, and tenor set by sender.
        } catch (bytes memory) {
            // N/A
        }
    }

    /// @notice Gets the swap data for buying credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    /// @return swapData The swap data for buying credit as a market order
    function getSwapData(State storage state, BuyCreditMarketParams memory params)
        public
        view
        returns (SwapDataBuyCreditMarket memory swapData)
    {
        if (params.creditPositionId == RESERVED_ID) {//@new position
            swapData.borrower = params.borrower;
            swapData.tenor = params.tenor;
        } else {//@use position already created. might be underwater
            DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);
            swapData.creditPosition = state.getCreditPosition(params.creditPositionId);

            swapData.borrower = swapData.creditPosition.lender;
            swapData.tenor = debtPosition.dueDate - block.timestamp;
        }

        uint256 ratePerTenor = state.getBorrowOfferRatePerTenor(swapData.borrower, swapData.tenor);//APR yield based on input

        if (params.exactAmountIn) {//@cash in
            swapData.cashAmountIn = params.amount;
            (swapData.creditAmountOut, swapData.swapFee, swapData.fragmentationFee) = state.getCreditAmountOut({
                cashAmountIn: swapData.cashAmountIn,
                maxCashAmountIn: params.creditPositionId == RESERVED_ID
                    ? swapData.cashAmountIn
                    : Math.mulDivUp(swapData.creditPosition.credit, PERCENT, PERCENT + ratePerTenor),
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? Math.mulDivDown(swapData.cashAmountIn, PERCENT + ratePerTenor, PERCENT)
                    : swapData.creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: swapData.tenor
            });
        } else {//@creditOut
            swapData.creditAmountOut = params.amount;
            (swapData.cashAmountIn, swapData.swapFee, swapData.fragmentationFee) = state.getCashAmountIn({
                creditAmountOut: swapData.creditAmountOut,
                maxCredit: params.creditPositionId == RESERVED_ID
                    ? swapData.creditAmountOut
                    : swapData.creditPosition.credit,
                ratePerTenor: ratePerTenor,
                tenor: swapData.tenor
            });
        }
    }//@no  change

    /// @notice Executes the buying of credit as a market order
    /// @param state The state
    /// @param params The input parameters for buying credit as a market order
    function executeBuyCreditMarket(State storage state, BuyCreditMarketParams memory params)
        external
        returns (uint256 netCashAmountIn)
    {
        emit Events.BuyCreditMarket(
            msg.sender,
            params.borrower,
            params.creditPositionId,
            params.amount,
            params.tenor,
            params.deadline,
            params.minAPR,
            params.exactAmountIn
        );

        SwapDataBuyCreditMarket memory swapData = getSwapData(state, params);//@got borrwer, credit to sender, cash out or inverse
        //@no  change above
        if (params.creditPositionId == RESERVED_ID) {
            // slither-disable-next-line unused-return
            state.createDebtAndCreditPositions({ //@new debt position to mapping. Using Id, we get original lender, total debt by due date, time
                lender: msg.sender,//@new credit position [unique ID]  to mapping. linked debtPosition,  totalAmount of credit received by borrower, forSale:true. 
                borrower: swapData.borrower,
                futureValue: swapData.creditAmountOut,//@for sale likely allow pay off debt early and split remainder into new debt and borrower get some of their money early.
                dueDate: block.timestamp + swapData.tenor
            });//@note borrower forced to receive debt through buyCreditMarket.
        } else {
            state.createCreditPosition({
                exitCreditPositionId: params.creditPositionId,
                lender: msg.sender,
                credit: swapData.creditAmountOut,
                forSale: true
            });
        }

        state.data.borrowATokenV1_5.transferFrom(
            msg.sender, swapData.borrower, swapData.cashAmountIn - swapData.swapFee - swapData.fragmentationFee
        );//@transfer wrapper of AAVE token to borrower.
        state.data.borrowATokenV1_5.transferFrom(
            msg.sender, state.feeConfig.feeRecipient, swapData.swapFee + swapData.fragmentationFee
        );

        uint256 exitCreditPositionId =
            params.creditPositionId == RESERVED_ID ? state.data.nextCreditPositionId - 1 : params.creditPositionId;

        emit Events.SwapData(//@new events
            exitCreditPositionId,
            swapData.borrower,
            msg.sender,
            swapData.creditAmountOut,
            swapData.cashAmountIn,
            swapData.cashAmountIn - swapData.swapFee - swapData.fragmentationFee,
            swapData.swapFee,
            swapData.fragmentationFee,
            swapData.tenor
        );

        return swapData.cashAmountIn - swapData.swapFee - swapData.fragmentationFee;
    }//@note Buy Credit now have fragmenationFee
}
