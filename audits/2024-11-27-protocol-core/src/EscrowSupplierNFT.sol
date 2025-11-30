// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {console2} from "forge-std/Test.sol";
import { BaseNFT, ConfigHub } from "./base/BaseNFT.sol";
import { IEscrowSupplierNFT } from "./interfaces/IEscrowSupplierNFT.sol";

/**
 * @title EscrowSupplierNFT
 * @notice Manages escrows and escrow offers for LoansNFT.
 * @custom:security-contact security@collarprotocol.xyz
 *
 * Main Functionality:
 * 1. Allows suppliers to create and manage escrow offers for multiple loans contracts.
 * 2. Mints NFTs representing escrow positions when offers are taken.
 * 3. Handles starting, ending, and switching of escrow positions.
 * 4. Manages withdrawals of released escrows and last-resort emergency seizures.
 *
 * Difference vs. CollarProviderNFT:
 * - Asset: Escrow is "supplied" in underlying tokens (e.g., ETH), while "providers"
 * provide cash (e.g., USDC).
 * - Risk: "Suppliers" (as opposed to "providers") have no downside, and no exposure to price,
 * and have fixed / limited upside (interest and late fees).
 * - Optional: only used for escrow backed loans for specific tax reasons, not for regular loans.
 *
 * Key Assumptions and Prerequisites:
 * 1. Escrow suppliers must be able to receive ERC-721 to use this contract.
 * 2. The associated Loans contracts are trusted and properly implemented.
 * 3. ConfigHub contract correctly manages protocol parameters and authorization.
 * 4. Asset (ERC-20) contracts are simple (non rebasing), do not allow reentrancy. Balance
 *    changes corresponds to transfer arguments.
 *
 * Post-Deployment Configuration:
 * - ConfigHub: Set valid collar duration range
 * - ConfigHub: Set setCanOpenPair() to authorize this contract for its asset
 * - ConfigHub: Set setCanOpenPair() to authorize its loans contracts
 * - This Contract: Set loans that can open escrows
 */
contract EscrowSupplierNFT is IEscrowSupplierNFT, BaseNFT {
    using SafeERC20 for IERC20;

    uint internal constant BIPS_BASE = 10_000;
    uint internal constant YEAR = 365 days;

    uint public constant MAX_INTEREST_APR_BIPS = BIPS_BASE; // 100% APR
    uint public constant MAX_LATE_FEE_APR_BIPS = BIPS_BASE * 12; // 1200% APR (100% for a max period of 30 days)
    uint public constant MIN_GRACE_PERIOD = 1 days;
    uint public constant MAX_GRACE_PERIOD = 30 days;
    // @notice max percentage of refunded interest fee, prevents free cancellation issues
    uint public constant MAX_FEE_REFUND_BIPS = 9500; // 95%

    string public constant VERSION = "0.2.0";

    // ----- IMMUTABLES ----- //
    IERC20 public immutable asset; // corresponds to Loans' underlying

    // ----- STATE ----- //
    // @dev this is NOT the NFT id, this is a  separate non transferrable ID
    uint public nextOfferId = 1; // starts from 1 so that 0 ID is not used

    // loans contracts allowed to start or switch escrows
    mapping(address loans => bool allowed) public loansCanOpen;

    mapping(uint offerId => OfferStored) internal offers;

    mapping(uint escrowId => EscrowStored) internal escrows;

    constructor(
        address initialOwner,
        ConfigHub _configHub,
        IERC20 _asset, //WETH WBTC
        string memory _name,//Escrow WETH
        string memory _symbol//EWETH , EWBTC
    ) BaseNFT(initialOwner, _name, _symbol) {
        asset = _asset;
        _setConfigHub(_configHub);
    }

    // ----- VIEWS ----- //

    /// @notice Returns the NFT ID of the next escrow to be minted
    function nextEscrowId() external view returns (uint) {
        return nextTokenId;
    }

    /// @notice Retrieves the details of a specific non-transferrable offer.
    function getOffer(uint offerId) public view returns (Offer memory) {
        OfferStored memory stored = offers[offerId];
        return Offer({
            supplier: stored.supplier,
            available: stored.available,
            duration: stored.duration,
            interestAPR: stored.interestAPR,
            maxGracePeriod: stored.maxGracePeriod,
            lateFeeAPR: stored.lateFeeAPR,
            minEscrow: stored.minEscrow
        });
    }

    /// @notice Retrieves the details of a specific escrow (corresponds to the NFT token ID)
    function getEscrow(uint escrowId) public view returns (Escrow memory) {
        EscrowStored memory stored = escrows[escrowId];
        // @dev this is checked because expiration is used in several places, and it's better to add
        // this check here instead of in each such place
        require(stored.expiration != 0, "escrow: position does not exist");
        Offer memory offer = getOffer(stored.offerId);
        return Escrow({
            offerId: stored.offerId,//EscrowOffer Id. created by another user
            loans: stored.loans,//LoansNFT
            loanId: stored.loanId,//takerID, LoanID match same id. created at the same time
            escrowed: stored.escrowed,// underlying amount when open loan. Collateral. 1 WETH
            maxGracePeriod: offer.maxGracePeriod,//7 days 
            lateFeeAPR: offer.lateFeeAPR,//10_000 , 100%
            duration: offer.duration,//5min
            expiration: stored.expiration,// 5min + now
            interestHeld: stored.interestHeld,// 5% APR taken right away when created
            released: stored.released,
            withdrawable: stored.withdrawable
        });
    }

    /**
     * @notice Returns the total owed including late fees for an escrow.
     * Uses a MIN_GRACE_PERIOD "cliff": Overdue time is counted from expiry, but during
     * the MIN_GRACE_PERIOD late fees are returned as 0 (even though are "accumulating" for it).
     * @param escrowId The ID of the escrow to calculate late fees for
     * @return totalOwed Total owed: escrowed amount + late fee
     * @return lateFee The calculated late fee
     */
    function currentOwed(uint escrowId) external view returns (uint totalOwed, uint lateFee) {
        Escrow memory escrow = getEscrow(escrowId);
        lateFee = _lateFee(escrow);
        return (escrow.escrowed + lateFee, lateFee);
    }

    /**
     * @notice Calculates the grace period based on available late fee amount. This is the grace period
     * the maxLateFee "can afford" before causing an shortfall of late fees. This view should be used to
     * enforce a reduced gracePeriod in available case funds are insufficient for the full grace period.
     * Grace period returned is between MIN_GRACE_PERIOD and the offer's `gracePeriod`.
     * @param escrowId The ID of the escrow to calculate for
     * @param maxLateFee The available fee amount
     * @return The calculated grace period in seconds
     */
    function cappedGracePeriod(uint escrowId, uint maxLateFee) external view returns (uint) { //@maxLateFee = swapped WETH amount from CASH inside Taker position. should be 10% of original amount.
        Escrow memory escrow = getEscrow(escrowId);//@worst case, max late fee is very tiny due to price drop. could be 0
        // initialize with max according to terms
        uint period = escrow.maxGracePeriod;//3-30 days
        // avoid div-zero
        if (escrow.escrowed != 0 && escrow.lateFeeAPR != 0) {
            // Calculate the grace period that can be "afforded" by maxLateFee according to few APR.
            //  fee = escrowed * time * APR / year / 100bips, so
            //  time = fee * year * 100bips / escrowed / APR;
            // rounding down, against the user
            uint timeAfforded = maxLateFee * YEAR * BIPS_BASE / escrow.escrowed / escrow.lateFeeAPR;//for basic APR 100%. timeAffored = 36.5 days = 10%/ 100% depend on put strike percent. and gain.
            // cap to timeAfforded
            period = Math.min(timeAfforded, period);
        }
        // ensure MIN_GRACE_PERIOD, which means that even if no funds are available, min grace period
        // is available.
        return Math.max(period, MIN_GRACE_PERIOD);
    }

    /**
     * @notice Calculates the interest fee (to be deposited upfront) for an offer and escrow amount.
     * @param offerId The offer Id to use for calculations
     * @param escrowed The escrowed amount
     * @return fee The calculated interest fee
     */
    function interestFee(uint offerId, uint escrowed) public view returns (uint) {
        Offer memory offer = getOffer(offerId);
        // rounds up against the user
        return Math.ceilDiv(escrowed * offer.interestAPR * offer.duration, BIPS_BASE * YEAR); //@max 100% APR
    }

    /**
     * @notice Previews the result of releasing an escrow if it is done now.
     * @param escrowId The ID of the escrow to preview
     * @param fromLoans The amount repaid from loans
     * @return withdrawal The amount to be withdrawn by the supplier
     * @return toLoans The amount to be returned to loans (includes refund)
     * @return refund The refunded interest amount
     */
    function previewRelease(uint escrowId, uint fromLoans)
        external
        view
        returns (uint withdrawal, uint toLoans, uint refund)
    {
        (withdrawal, toLoans, refund) = _releaseCalculations(getEscrow(escrowId), fromLoans);
    }

    // ----- MUTATIVE ----- //

    // ----- Offer actions ----- //

    /**
     * @notice Creates a new escrow offer
     * @param amount The offered amount
     * @param duration The offer duration in seconds
     * @param interestAPR The annual interest rate in basis points
     * @param maxGracePeriod The maximum grace period duration in seconds
     * @param lateFeeAPR The annual late fee rate in basis points
     * @param minEscrow The minimum escrow amount. Protection from dust mints.
     * @return offerId The ID of the created offer
     */
    function createOffer(
        uint amount,// 1 WETH
        uint duration,// 5 min -> 5 years max
        uint interestAPR,//5% APR , 500
        uint maxGracePeriod,// 7 days
        uint lateFeeAPR,// 10_000 ,100%
        uint minEscrow//0
    ) external whenNotPaused returns (uint offerId) {
        // sanity checks
        require(interestAPR <= MAX_INTEREST_APR_BIPS, "escrow: interest APR too high");
        require(lateFeeAPR <= MAX_LATE_FEE_APR_BIPS, "escrow: late fee APR too high");
        require(maxGracePeriod >= MIN_GRACE_PERIOD, "escrow: grace period too short");
        require(maxGracePeriod <= MAX_GRACE_PERIOD, "escrow: grace period too long");
        console2.log("--- Create Escrow Offer --- amount: %e, apr: %e", amount, interestAPR);
        offerId = nextOfferId++;
        offers[offerId] = OfferStored({
            supplier: msg.sender,
            duration: SafeCast.toUint32(duration),
            maxGracePeriod: SafeCast.toUint32(maxGracePeriod),
            interestAPR: SafeCast.toUint24(interestAPR),//5% per year
            lateFeeAPR: SafeCast.toUint24(lateFeeAPR),
            minEscrow: minEscrow,
            available: amount
        });
        asset.safeTransferFrom(msg.sender, address(this), amount);
        emit OfferCreated(
            msg.sender, interestAPR, duration, maxGracePeriod, lateFeeAPR, amount, offerId, minEscrow
        );
    }

    /**
     * @notice Updates the total available amount of an existing offer. Update to 0 to fully withdraw.
     * @dev Can increase or decrease the offer amount. Must be from original offer supplier
     * @param offerId The ID of the offer to update
     * @param newAmount The new offer amount
     *
     * A "non-zero update frontrunning attack" (similar to the never-exploited ERC-20 approval issue),
     * can be a low likelihood concern on a network that exposes a public mempool.
     * Avoid it by not granting excessive ERC-20 approvals.
     */
    function updateOfferAmount(uint offerId, uint newAmount) external whenNotPaused {
        OfferStored storage offer = offers[offerId];
        require(msg.sender == offer.supplier, "escrow: not offer supplier");

        uint previousAmount = offer.available;
        if (newAmount > previousAmount) {
            // deposit more
            uint toAdd = newAmount - previousAmount;
            offer.available += toAdd;
            asset.safeTransferFrom(msg.sender, address(this), toAdd);
        } else if (newAmount < previousAmount) {
            // withdraw
            uint toRemove = previousAmount - newAmount;
            offer.available -= toRemove;
            asset.safeTransfer(msg.sender, toRemove);
        } else { } // no change
        emit OfferUpdated(offerId, msg.sender, previousAmount, newAmount);
    }

    // ----- Escrow actions ----- //

    // ----- actions through loans contract ----- //

    /**
     * @notice Starts a new escrow from an existing offer. Transfer the full amount in, escrow + fee,
     * and then transfers out the escrow amount back.
     * @dev Can only be called by allowed Loans contracts. Use `interestFee` view to calculate the
     * required fee. Fee is specified explicitly for interface clarity, because is on top of the
     * escrowed amount, so the amount to approve is escrowed + fee.
     * @param offerId The ID of the offer to use
     * @param escrowed The amount to escrow
     * @param fee The upfront interest fee amount. Checked to be sufficient.
     *   Will be partially refunded if escrow is released before expiration.
     * @param loanId The associated loan ID
     * @return escrowId The ID of the created escrow
     */
    function startEscrow(uint offerId, uint escrowed, uint fee, uint loanId)
        external
        whenNotPaused
        returns (uint escrowId)//@audit-ok check comments they seem ok I can input higher fee amount and it still work. although APR is fixed. fee is fixed based on escrowed amount
    {
        // @dev msg.sender auth is checked vs. loansCanOpen in _startEscrow
        escrowId = _startEscrow(offerId, escrowed, fee, loanId);//@ fee is prepaid. can pay more fee than necessary. although APR is fixed.

        // @dev despite the fact that they partially cancel out, so can be done as just fee transfer,
        // these transfers are the whole point of this contract from product point of view.
        // The transfer events for the full amounts are needed such that the tokens used for the swap
        // in Loans should be "supplier's", and not "borrower's" from CGT tax lows perspective.
        // transfer "borrower's" funds in
        asset.safeTransferFrom(msg.sender, address(this), escrowed + fee);//from LoansNFT.openLoan()
        // transfer "supplier's" funds out
        asset.safeTransfer(msg.sender, escrowed);
    }

    /**
     * @notice Ends an escrow
     * @dev Can only be called by the Loans contract that started the escrow
     * @param escrowId The ID of the escrow to end
     * @param repaid The amount repaid, can be more or less than original escrow amount, depending on
     * late fees (enforced by the loans contract), or position / slippage / default shortfall. The
     * supplier is guaranteed to withdraw at least the escrow amount regardless.
     * @return toLoans Amount to be returned to loans including potential refund and deducing shortfalls
     */
    function endEscrow(uint escrowId, uint repaid) external whenNotPaused returns (uint toLoans) { //@ repaid = Math.min(fromSwap, totalOwed);
        // @dev msg.sender auth is checked vs. stored loans in _endEscrow
        toLoans = _endEscrow(escrowId, getEscrow(escrowId), repaid);//@only LoansNFT can start and EndEscrow

        // transfer in the repaid assets in: original supplier's assets, plus any late fee
        asset.safeTransferFrom(msg.sender, address(this), repaid);
        // release the escrow (with possible loss to the borrower): user's assets + refund - shortfall
        asset.safeTransfer(msg.sender, toLoans);//@toLoans = repiad + escrowed + interest-prepaid - escrowed - interest-prepaid -lateFee + interestRefund=
    }//@toloans = repaid + interestRefund - lateFee //@audit-ok info transfer 0 amount. Some token do not accept this.

    /**
     * @notice Switches an escrow to a new escrow.
     * @dev While it is basically startEscrow + endEscrow, calling these methods externally
     * is not possible: startEscrow pulls the escrow amount in and transfers it out,
     * which is not possible when switching escrows because the caller (loans) has no underlying for
     * such a transfer at that point. So instead this method is needed to "move" funds internally.
     * @dev Can only be called by the Loans contract that started the original escrow
     * @dev durations can theoretically be different (is not problematic within this contract),
     * but Loans - the only caller of this - should check the new offer duration / new escrow
     * expiration is as is needed for its use.
     * @param releaseEscrowId The ID of the escrow to release
     * @param offerId The ID of the new offer
     * @param newFee The new interest fee amount
     * @param newLoanId The new loan ID
     * @return newEscrowId The ID of the new escrow
     * @return feeRefund The refunded fee amount from the old escrow's upfront interest
     */
    function switchEscrow(uint releaseEscrowId, uint offerId, uint newFee, uint newLoanId)
        external
        whenNotPaused
        returns (uint newEscrowId, uint feeRefund)//@still only LoansNFT can switch
    {
        Escrow memory previousEscrow = getEscrow(releaseEscrowId);
        // do not allow expired escrow to be switched since 0 fromLoans is used for _endEscrow
        require(block.timestamp <= previousEscrow.expiration, "escrow: expired");

        /*
        1. initially user's escrow "E" secures old ID, "O". O's supplier's funds are away.
        2. E is then "transferred" to secure new ID, "N". N's supplier's funds are taken, to release O.
        3. O is released (with N's funds). N's funds are now secured by E (user's escrow).

        Interest is accounted separately by transferring the full N's interest fee
        (held until release), and refunding O's interest held.
        */

        // "O" (old escrow): Release funds to the supplier.
        // The withdrawable for O's supplier comes from the N's offer, not from Loans repayment.
        // The escrowed loans-funds (E) move into the new escrow of the new supplier.
        // fromLoans must be 0, otherwise escrow will be sent to Loans instead of only the fee refund.
        feeRefund = _endEscrow(releaseEscrowId, previousEscrow, 0);//@early refund fee 0-95%. @feeRefund = interestRefund to LoansNFT. up to 95% of original APR fee 
        //@withdrawal = escrowed + interestHeld - interestRefund. //@toloans = repaid + interestRefund - lateFee = interestRefund
        // N (new escrow): Mint a new escrow from the offer (can be old or new offer). 
        // The escrow funds are funds that have been escrowed in the ID being released ("O").
        // The offer is reduced (which is used to repay the previous supplier)
        // A new escrow ID is minted. //@below is same startEscrow(); without sending new escrow though. just reuse same old locked escrow
        newEscrowId = _startEscrow(offerId, previousEscrow.escrowed, newFee, newLoanId);

        // fee transfers
        asset.safeTransferFrom(msg.sender, address(this), newFee);
        asset.safeTransfer(msg.sender, feeRefund);

        emit EscrowsSwitched(releaseEscrowId, newEscrowId);
    }

    // ----- actions by escrow owner ----- //

    /// @notice Withdraws funds from a released escrow. Burns the NFT.
    /// @param escrowId The ID of the escrow to withdraw from
    function withdrawReleased(uint escrowId) external whenNotPaused {
        require(msg.sender == ownerOf(escrowId), "escrow: not escrow owner"); // will revert for burned

        Escrow memory escrow = getEscrow(escrowId);
        require(escrow.released, "escrow: not released");

        uint withdrawable = escrow.withdrawable;
        // store zeroed out withdrawable
        escrows[escrowId].withdrawable = 0;
        // burn token
        _burn(escrowId);
        // transfer tokens
        asset.safeTransfer(msg.sender, withdrawable);

        emit WithdrawalFromReleased(escrowId, msg.sender, withdrawable);
    }

    /**
     * @notice Emergency function to seize escrow funds after max grace period. Burns the NFT.
     * WARNING: DO NOT use this is normal circumstances, instead use LoansNFT.forecloseLoan().
     * This method is only for extreme scenarios to ensure suppliers can always withdraw even if
     * original LoansNFT is broken / disabled / disallowed by admin.
     * This method can only be used after the max grace period is elapsed, and does not pay any late fees.
     * @dev Ideally the owner of the NFT will call LoansNFT.forecloseLoan() which is callable earlier
     * or pays late fees (or both). If they do that, "released" will be set to true, disabling this method.
     * In the opposite situation, if the NFT owner chooses to call this method by mistake,
     * the LoansNFT method will not be callable, because "released" will true (+NFT will be burned).
     * @param escrowId The ID of the escrow to seize
     */
    function lastResortSeizeEscrow(uint escrowId) external whenNotPaused {
        require(msg.sender == ownerOf(escrowId), "escrow: not escrow owner"); // will revert for burned

        Escrow memory escrow = getEscrow(escrowId);
        require(!escrow.released, "escrow: already released");
        uint gracePeriodEnd = escrow.expiration + escrow.maxGracePeriod;
        require(block.timestamp > gracePeriodEnd, "escrow: grace period not elapsed");//@provider also expired at this point too. So this pair Taker/Provider already expired.

        // update storage
        escrows[escrowId].released = true;
        
        // burn token because this is a withdrawal and a direct last action by NFT owner
        _burn(escrowId);

        // @dev withdrawal is immediate, so escrow.withdrawable is not set here (no _releaseEscrow call).
        // release escrowed and full interest
        uint withdawal = escrow.escrowed + escrow.interestHeld;//@no late fee
        asset.safeTransfer(msg.sender, withdawal);//@send to NFT owner

        emit EscrowSeizedLastResort(escrowId, msg.sender, withdawal);
    }

    // ----- admin ----- //

    /// @notice Sets whether a Loans contract is allowed to interact with this contract
    function setLoansCanOpen(address loans, bool allowed) external onlyOwner {
        // @dev no checks for Loans interface since calls are only from Loans to this contract
        loansCanOpen[loans] = allowed;// LoansNFT WETH/USDC can open Escrow WETH
        emit LoansCanOpenSet(loans, allowed);//@audit-ok this was checked on acceptance later.L no check that loans have same asset underlying
    }

    // ----- INTERNAL MUTATIVE ----- //

    function _startEscrow(uint offerId, uint escrowed, uint fee, uint loanId)
        internal//@escrowed is 1 WETH or borrower collateral. fee is any input
        returns (uint escrowId)//@ fee must higher than APR based on edcrowed amount and EscrowOfferId
    {
        require(loansCanOpen[msg.sender], "escrow: unauthorized loans contract"); //@only LoansNFT
        // @dev loans is not checked since is directly authed in this contract via setLoansAllowed
        require(configHub.canOpenSingle(asset, address(this)), "escrow: unsupported escrow");//@redundency check

        Offer memory offer = getOffer(offerId);//@similar to ProviderNFT
        require(offer.supplier != address(0), "escrow: invalid offer"); // revert here for clarity

        // check params are supported
        require(configHub.isValidCollarDuration(offer.duration), "escrow: unsupported duration");//@live config check
        
        // we don't check equality to avoid revert due to minor inaccuracies to the upside,
        // even though exact value should be used from the view.
        require(fee >= interestFee(offerId, escrowed), "escrow: insufficient fee");//@fee = amount * APR * duration / 365 days

        // check amount
        require(escrowed >= offer.minEscrow, "escrow: amount too low");
        // @dev fee is not taken from offer, because it is transferred in from loans
        uint prevOfferAmount = offer.available;
        require(escrowed <= prevOfferAmount, "escrow: amount too high");

        // storage updates
        offers[offerId].available -= escrowed;
        escrowId = nextTokenId++;
        escrows[escrowId] = EscrowStored({
            offerId: SafeCast.toUint64(offerId),//EscrowId
            loanId: SafeCast.toUint64(loanId),//LoanId use TakerId. Taker mint new NFT Pair when connect with ProviderId
            expiration: SafeCast.toUint32(block.timestamp + offer.duration),//@note it is not possible to grief Supplier with duration as they was fixed. Even when duration really small
            released: false, // unset until release
            loans: msg.sender,
            escrowed: escrowed,
            interestHeld: fee,
            withdrawable: 0 // unset until release
         });

        // emit before token transfer event in mint for easier indexing
        emit EscrowCreated(escrowId, escrowed, offer.duration, fee, offer.maxGracePeriod, offerId);
        // mint the NFT to the supplier
        // @dev does not use _safeMint to avoid reentrancy
        _mint(offer.supplier, escrowId);//NFT hold fee send to EscrowSupplier who create Escrow Offer. 
        //after: Offer lost escrowed amount (1WETH), gain NFT (escrowId). This contract gain fee(0.001 WETH) amount. LoansNFT lose fee Amount
        emit OfferUpdated(offerId, offer.supplier, prevOfferAmount, prevOfferAmount - escrowed);
    }

    function _endEscrow(uint escrowId, Escrow memory escrow, uint fromLoans)//@fromLoans = 0 | repaid
        internal
        returns (uint toLoans)
    {
        // @dev only allow the same loans contract to release. Also ensures this is previously allowed Loans.
        require(msg.sender == escrow.loans, "escrow: loans address mismatch");//@only LoansNFT
        require(!escrow.released, "escrow: already released");//@ lastResortSeizeEscrow() supercede this

        uint withdrawable;//@withdrawal = escrowed + interestHeld + lateFee - interestRefund || escrow.escrowed + escrow.interestHeld + fromLoans
        (withdrawable, toLoans,) = _releaseCalculations(escrow, fromLoans);//@toLoans could be zero.

        // storage updates
        escrows[escrowId].released = true;
        escrows[escrowId].withdrawable = withdrawable;

        emit EscrowReleased(escrowId, fromLoans, withdrawable, toLoans);
    }

    // ----- INTERNAL VIEWS ----- //

    function _releaseCalculations(Escrow memory escrow, uint fromLoans)//@fromLoans= 0 | repiad. 
        internal//@maximum fromLoans is just whatever swapped by router output.
        view
        returns (uint withdrawal, uint toLoans, uint interestRefund)
    {//@fromLoans = repaid = Math.min(fromSwap, totalOwed) = Math.min(escrow.escrowed + lateFee , fromSwap)
        // handle under-payment (slippage, default) or over-payment (excessive late fees):
        // any shortfall is for the borrower (e.g., slippage) - taken out of the escrow funds held
        //@audit-ok assuming the worst. fromSwap is really small compare to original loans amount.
        // lateFee is non-zero after MIN_GRACE_PERIOD is over (late close loan / seized escrow)// @ok late fee seem correct. Range from 0->100%
        uint lateFee = _lateFee(escrow);//@ max late fee is 98% of original after 30 days.
        // refund due to early release. If late fee is not 0, this is likely 0 (because is after expiry).
        interestRefund = _interestFeeRefund(escrow);//0->95% of original deposit fee when created Escrow. pre-Fee must > APR rate when created.

        // everything owed: original escrow + (interest held - interest refund) + late fee
        uint targetWithdrawal = escrow.escrowed + escrow.interestHeld + lateFee - interestRefund;//@LoansNFT at best can prevent escrow receive full lateFee and reduce swap output. they still have to swap and lose full locked value
        // what we have is what we held (escrow + full interest) and whatever loans just sent us
        // @dev note that withdrawal of at least escrow + interest fee is always guaranteed
        uint available = escrow.escrowed + escrow.interestHeld + fromLoans;//@audit-ok Escrower still receive their original escrow + interest. but no late fee. Review. LoansNFT must repaid escrow in full. So it have enough availale to repaid escrowed fee

        // use as much as possible from available up to target
        withdrawal = Math.min(available, targetWithdrawal);
        // refund the rest if anything is left, this accounts both for interestRefund and any overpayment
        toLoans = available - withdrawal;

        // @dev note 1: interest refund "theoretically" covers some of the late fee shortfall, but
        // "in practice" this will never happen because either late fees are 0 or interest refund is 0.

        // @dev note 2: for (swtichEscrow, fromLoans is 0, and lateFee is 0, so toLoans is just
        // the interest refund

        /* @dev note 3: late fees are calculated, but cannot be "enforced" here, and instead Loans is
        trusted to use the views on this contract to correctly calculate the late fees and grace period
        to ensure they are not underpaid. This contract needs to trust Loans to do so for these reasons:
        1. Loans needs to swap from cash, and has the information needed to calculate the funds available
        for late fees (withdrawal amount, oracle rate, etc).
        2. Loans needs swap parameters, and has a keeper authorisation system for access control.

        So while a seizeEscrow() method in this contract *could* call to Loans, the keeper access control +
        the swap parameters + the reduced-grace-period time (by withdrawal), all make it more sensible to
        be done via Loans directly. The result is that "principal" is always guaranteed by this contract due
        to always remaining in it, but correct late fees payment depends on Loans implementation.
        */
    }

    function _lateFee(Escrow memory escrow) internal view returns (uint) {
        if (block.timestamp < escrow.expiration + MIN_GRACE_PERIOD) {
            // grace period cliff
            return 0;
        }
        uint overdue = block.timestamp - escrow.expiration; // counts from expiration despite the cliff //@1-30 days max
        // cap at specified grace period
        overdue = Math.min(overdue, escrow.maxGracePeriod);
        // @dev rounds up to prevent avoiding fee using many small positions //@feeAPR 1200% max
        return Math.ceilDiv(escrow.escrowed * escrow.lateFeeAPR * overdue, BIPS_BASE * YEAR);//@max late fee is 98.6% of escrowed amount
    }

    function _interestFeeRefund(Escrow memory escrow) internal view returns (uint) {
        uint duration = escrow.duration;
        // elapsed = now - startTime; startTime = expiration - duration
        uint elapsed = block.timestamp + duration - escrow.expiration;//@expiration = block.timestamp + offer.duration. So elapsed always >=0
        // cap to duration
        elapsed = Math.min(elapsed, duration);
        // refund is for time remaining. round down against user.
        // no div-zero due to range checks in ConfigHub.Duration max is 31_536_000 . so 31USDC can be rounded down. But escrow hold WETH not USDC.
        uint refund = escrow.interestHeld * (duration - elapsed) / duration;//@overdue no refund. Also interestHeld is rounded down so bad for user
        //@audit-ok Info. This rounded down does not harm user much due to few seconds . Also user cannot get more than refund amount. so this is harmless
        /* @dev there is no APR calculation here (APR calc used only on open) because:
         1. simpler
         2. avoidance of mismatch due to rounding issues
         3. actual fee held may be higher (it's checked to be >= APR calculated fee)
        */

        // ensure refund is not full, to prevent fee cancellation (griefing, DoS)
        uint maxRefund = escrow.interestHeld * MAX_FEE_REFUND_BIPS / BIPS_BASE;
        return Math.min(refund, maxRefund);//@note user can only receive back 95% refund as maximum. To prevent early Loans Escrow cancel? Then who is holding these money
    }
}
