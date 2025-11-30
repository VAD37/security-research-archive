// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {console2} from "forge-std/Test.sol";
import { ConfigHub, BaseNFT, CollarProviderNFT, Math, IERC20, SafeERC20 } from "./CollarProviderNFT.sol";
import { ITakerOracle } from "./interfaces/ITakerOracle.sol";
import { ICollarTakerNFT } from "./interfaces/ICollarTakerNFT.sol";
import { ICollarProviderNFT } from "./interfaces/ICollarProviderNFT.sol";

/**
 * @title CollarTakerNFT
 * @custom:security-contact security@collarprotocol.xyz
 *
 * Main Functionality:
 * 1. Manages the taker side of collar positions - handling position creation and settlement.
 * 2. Mints NFTs representing taker positions, allowing cancellations, rolls,
 *    and a secondary market for unexpired positions.
 * 3. Settles positions at expiry by calculating final payouts using oracle prices.
 * 4. Handles cancellation and withdrawal of settled positions.
 *
 * Role in the Protocol:
 * This contract acts as the core engine for the Collar Protocol, working in tandem with
 * CollarProviderNFT to create zero-sum paired positions. It holds and calculates the taker's side of
 * collars, which is typically wrapped by LoansNFT to create loan positions.
 *
 * Key Assumptions and Prerequisites:
 * 1. Takers must be able to receive ERC-721 tokens to withdraw earnings.
 * 2. The allowed provider contracts are trusted and properly implemented.
 * 3. The ConfigHub contract correctly manages protocol parameters and authorization.
 * 4. Asset (ERC-20) contracts are simple, non rebasing, do not allow reentrancy, balance changes
 *    correspond to transfer arguments.
 *
 * Post-Deployment Configuration:
 * - Oracle: If using Uniswap ensure adequate observation cardinality, if using Chainlink ensure correct config.
 * - ConfigHub: Set setCanOpenPair() to authorize this contract for its asset pair
 * - ConfigHub: Set setCanOpenPair() to authorize the provider contract
 * - CollarProviderNFT: Ensure properly configured
 */
contract CollarTakerNFT is ICollarTakerNFT, BaseNFT { //@Only hold CASH.
    using SafeERC20 for IERC20;
    using SafeCast for uint;

    uint internal constant BIPS_BASE = 10_000;

    string public constant VERSION = "0.2.0";

    // ----- IMMUTABLES ----- //
    IERC20 public immutable cashAsset;
    IERC20 public immutable underlying; // not used as ERC20 here

    // ----- STATE VARIABLES ----- //
    ITakerOracle public oracle;

    mapping(uint positionId => TakerPositionStored) internal positions;

    constructor(//@audit-ok I constructor use inverted USDC/WETH parameters
        address initialOwner,
        ConfigHub _configHub,
        IERC20 _cashAsset,//USDC
        IERC20 _underlying,//WETH
        ITakerOracle _oracle,// combinedOracle WETH/USDC . WETH/USD + USDC/USD
        string memory _name,//Taker WETH/USDC
        string memory _symbol//T WETH/USDC
    ) BaseNFT(initialOwner, _name, _symbol) {
        cashAsset = _cashAsset;
        underlying = _underlying;
        _setConfigHub(_configHub);//@fancy check
        _setOracle(_oracle);//@fancy check
        emit CollarTakerNFTCreated(address(_cashAsset), address(_underlying), address(_oracle));
    }

    // ----- VIEW FUNCTIONS ----- //

    /// @notice Returns the ID of the next taker position to be minted
    function nextPositionId() external view returns (uint) {
        return nextTokenId;
    }

    /// @notice Retrieves the details of a specific position (corresponds to the NFT token ID)
    function getPosition(uint takerId) public view returns (TakerPosition memory) {
        TakerPositionStored memory stored = positions[takerId];
        // do not try to call non-existent provider
        require(address(stored.providerNFT) != address(0), "taker: position does not exist");
        // @dev the provider position fields that are used are assumed to be immutable (set once)
        ICollarProviderNFT.ProviderPosition memory providerPos =
            stored.providerNFT.getPosition(stored.providerId);
        return TakerPosition({
            providerNFT: stored.providerNFT,
            providerId: stored.providerId,
            duration: providerPos.duration, // comes from the offer, implicitly checked with expiration
            expiration: providerPos.expiration, // checked to match on creation
            startPrice: stored.startPrice,
            putStrikePercent: providerPos.putStrikePercent,
            callStrikePercent: providerPos.callStrikePercent,
            takerLocked: stored.takerLocked,
            providerLocked: providerPos.providerLocked, // assumed immutable
            settled: stored.settled,
            withdrawable: stored.withdrawable
        });
    }

    /// @notice Expiration time and settled state of a specific position (corresponds to the NFT token ID)
    /// @dev This is more gas efficient than SLOADing everything in getPosition if just expiration / settled
    /// is needed
    function expirationAndSettled(uint takerId) external view returns (uint expiration, bool settled) {
        TakerPositionStored storage stored = positions[takerId];
        return (stored.providerNFT.expiration(stored.providerId), stored.settled);
    }

    /**
     * @notice Calculates the amount of cash asset that will be locked on provider side
     * for a given amount of taker locked asset and strike percentages.
     * @param takerLocked The amount of cash asset locked by the taker
     * @param putStrikePercent The put strike percentage in basis points
     * @param callStrikePercent The call strike percentage in basis points
     * @return The amount of cash asset the provider will lock
     */
    function calculateProviderLocked(uint takerLocked, uint putStrikePercent, uint callStrikePercent)
        public//@note Taker earn linear based on price speed. So this is really fair for both side. Provider with higher Strike call just waiting for longer period of time.
        pure//@audit-ok We have Rolls system allow bet to end early if Taker accept. H it doesnt really make sense to not End trading bet right at strike price instead of waiting until the end of duration
        returns (uint)//@if provider locked more than intended but gain little. why would they put money in?
    {//@Rolls suppose to be the only one call Taker. Lots of provider will open position with higher callStrike price. This result in unfair trade practice. Taker gain more than Provider risk. It suppose to have no provider risk as it was only used on Rolls only.
        // cannot be 0 due to range checks in providerNFT and configHub
        uint putRange = BIPS_BASE - putStrikePercent;// 10_000 - 9_000 = 1_000 = 10%. minimum 0.01% = 1, max 10000 = 100%
        uint callRange = callStrikePercent - BIPS_BASE;// 10%, maximum 0.01%, max 90000 = 900%
        // proportionally scaled according to ranges. Will div-zero panic for 0 putRange.
        // rounds down against of taker to prevent taker abuse by opening small positions
        return takerLocked * callRange / putRange;
    }

    /// @notice Returns the price used for opening and settling positions, which is current price from
    /// the oracle.
    /// @return Amount of cashAsset for a unit of underlying (i.e. 10**underlying.decimals())
    function currentOraclePrice() public view returns (uint) {
        return oracle.currentPrice();
    }

    /**
     * @notice Calculates the settlement results at a given price
     * @dev no validation, so may revert with division by zero for bad values
     * @param position The TakerPosition to calculate settlement for
     * @param endPrice The settlement price, as returned from the this contract's price views
     * @return takerBalance The amount the taker will be able to withdraw after settlement
     * @return providerDelta The amount transferred to/from provider position (positive or negative)
     */
    function previewSettlement(TakerPosition memory position, uint endPrice)
        external
        pure
        returns (uint takerBalance, int providerDelta)
    {
        return _settlementCalculations(position, endPrice);
    }

    // ----- STATE CHANGING FUNCTIONS ----- //

    /**
     * @notice Opens a new paired taker and provider position: minting taker NFT position to the caller,
     * and calling provider NFT mint provider position to the provider.
     * @dev The caller must have approved this contract to transfer the takerLocked amount
     * @param takerLocked The amount to pull from sender, to be locked on the taker side
     * @param providerNFT The CollarProviderNFT contract of the provider
     * @param offerId The offer ID on the provider side. Implies specific provider,
     * put & call percents, duration.
     * @return takerId The ID of the newly minted taker NFT
     * @return providerId The ID of the newly minted provider NFT
     */ //@take fee on provider side. Only provider pay fee.
    function openPairedPosition(uint takerLocked, CollarProviderNFT providerNFT, uint offerId)//@called from LoansNFT.openLoans and then swapandmintCollar()
        external //@called by any
        whenNotPaused//@providerNFT only called by single Taker. too many whitelist redundancy check
        returns (uint takerId, uint providerId)//@lock 360 USDC as cash asset, LoansNFT approve 360 USDC or loanAmount * putStrikePercent / 10000
    {//@ takerLocked = 360 USDC
        // check asset & self allowed
        require(configHub.canOpenPair(underlying, cashAsset, address(this)), "taker: unsupported taker");
        // check assets & provider allowed
        require(
            configHub.canOpenPair(underlying, cashAsset, address(providerNFT)), "taker: unsupported provider"
        );//@check whitelist by admin
        // check assets match
        require(providerNFT.underlying() == underlying, "taker: underlying mismatch");//@ check admin config is correct
        require(providerNFT.cashAsset() == cashAsset, "taker: cashAsset mismatch");
        console2.log("--- Taker OpenPair: takerLocked: %e, offerId: %s",takerLocked,offerId);
        CollarProviderNFT.LiquidityOffer memory offer = providerNFT.getOffer(offerId);
        require(offer.duration != 0, "taker: invalid offer");
        uint providerLocked = // providerLocker = takerLocked * (call - 100%) / (100% - put)
            calculateProviderLocked(takerLocked, offer.putStrikePercent, offer.callStrikePercent);// putStrike 90%, callStrike 110% //@Provider can lock whole lots more
        console2.log("oracle: %e",currentOraclePrice());
        // prices
        uint startPrice = currentOraclePrice();// WETH/USDC combined oracle price = 3600e6
        (uint putStrikePrice, uint callStrikePrice) = //@ put = 3240, call = 3960
            _strikePrices(offer.putStrikePercent, offer.callStrikePercent, startPrice);
        // avoid boolean edge cases and division by zero when settling
        require(
            putStrikePrice < startPrice && callStrikePrice > startPrice, "taker: strike prices not different"
        );//@prevent zero division yeah
        console2.log("price: %e ,putStrike: %e, callStrike: %e",startPrice, putStrikePrice, callStrikePrice);
        // open the provider position for providerLocked amount (reverts if can't).
        // sends the provider NFT to the provider
        providerId = providerNFT.mintFromOffer(offerId, providerLocked, nextTokenId);//@ProviderNFT Position is created with takerID,providerLocked amount
        console2.log("DONE create providerId NFT: %s",providerId);
        // check expiration matches expected
        uint expiration = block.timestamp + offer.duration; //@redundancy check . result would be safeCast time though.
        require(expiration == providerNFT.expiration(providerId), "taker: expiration mismatch");//@Info this is positionId not providerID

        // increment ID
        takerId = nextTokenId++;
        // store position data
        positions[takerId] = TakerPositionStored({ //@note position do not include strike price. it already been calculated into position
            providerNFT: providerNFT,
            providerId: SafeCast.toUint64(providerId),
            settled: false, // unset until settlement / cancellation
            startPrice: startPrice,// 3600e6 //@note Taker position start Price use Chainlink Oracle not uniswap oracle. all settlements using chainlink
            takerLocked: takerLocked, // 360 USDC
            withdrawable: 0 // unset until settlement
         });
        // mint the NFT to the sender, @dev does not use _safeMint to avoid reentrancy
        _mint(msg.sender, takerId);//@ new NFT to loansNFT. Taker Position send to user/Loans
        console2.log("-- Mint Taker NFT: %s, startPrice: &e",takerId, startPrice);
        emit PairedPositionOpened(takerId, address(providerNFT), providerId, offerId, takerLocked, startPrice);
        console2.log("-- Take CASH %e from %s",takerLocked,msg.sender);
        // pull the user side of the locked cash
        cashAsset.safeTransferFrom(msg.sender, address(this), takerLocked);//@taker get 360$ from sender. Which is loansNFT/user
    }//@taker tell Provider open position with 40$ to their name. 1% APR fee taken from provider and send to protocol

    /**
     * @notice Settles a paired position after expiry. Uses current oracle price at time of call.
     * @param takerId The ID of the taker position to settle
     *
     * @dev this should be called as soon after expiry as possible to minimize the difference between
     * price at expiry time and price at call time (which is used for payouts).
     * Both taker and provider are incentivised to call this method, however it's possible that
     * one side is not (e.g., due to being at max loss). For this reason a keeper should be run to
     * prevent users with gains from not settling their positions on time.
     */
    function settlePairedPosition(uint takerId) external whenNotPaused {
        // @dev this checks position exists
        TakerPosition memory position = getPosition(takerId);//@get both TakerPosition on this contract and linked ProviderPosition on external contract

        require(block.timestamp >= position.expiration, "taker: not expired");//@provider.expiration < block.timestamp
        require(!position.settled, "taker: already settled");//@stored.settled != true

        // settlement price
        uint endPrice = currentOraclePrice();// 1WETH = 3600e6 USDC
        // settlement amounts
        (uint takerBalance, int providerDelta) = _settlementCalculations(position, endPrice);//@ok

        // store changes
        positions[takerId].settled = true;
        positions[takerId].withdrawable = takerBalance;//@cache new taker balance

        (CollarProviderNFT providerNFT, uint providerId) = (position.providerNFT, position.providerId);//@target contract and ID
        // settle paired and make the transfers
        if (providerDelta > 0) cashAsset.forceApprove(address(providerNFT), uint(providerDelta));//@money from this contract/Taker send to provider
        providerNFT.settlePosition(providerId, providerDelta);//@only taker contract. take providerDelta Cash from this contract. Taker lose that same amount, provider gain that same amount
//if provider gain. Taker contract get some cash from CollarProvider. user can withdraw new amount
        emit PairedPositionSettled(
            takerId, address(providerNFT), providerId, endPrice, takerBalance, providerDelta
        );
    }//@ok

    /// @notice Withdraws funds from a settled position. Burns the NFT.
    /// @param takerId The ID of the settled position to withdraw from (NFT token ID).
    /// @return withdrawal The amount of cash asset withdrawn
    function withdrawFromSettled(uint takerId) external whenNotPaused returns (uint withdrawal) {
        require(msg.sender == ownerOf(takerId), "taker: not position owner");

        TakerPosition memory position = getPosition(takerId);
        require(position.settled, "taker: not settled");

        withdrawal = position.withdrawable;//@takerBalance. could be zero
        // store zeroed out withdrawable
        positions[takerId].withdrawable = 0;
        // burn token
        _burn(takerId);//@note can burn position with zero withdrawal due to failed bet.
        // transfer tokens
        cashAsset.safeTransfer(msg.sender, withdrawal);

        emit WithdrawalFromSettled(takerId, withdrawal);
    }

    /**
     * @notice Cancels a paired position and withdraws funds
     * @dev Can only be called by the owner of BOTH taker and provider NFTs
     * @param takerId The ID of the taker position to cancel
     * @return withdrawal The amount of funds withdrawn from both positions together
     */ //@ called by Rolls to settle different between short/long position early
    function cancelPairedPosition(uint takerId) external whenNotPaused returns (uint withdrawal) {//@audit-ok For Rolls mechanic. No self-abuse possible so far.what is the point of hedge position and cancel its own position? Is this for LoanNFT
        TakerPosition memory position = getPosition(takerId);
        (CollarProviderNFT providerNFT, uint providerId) = (position.providerNFT, position.providerId);

        // must be taker NFT owner
        require(msg.sender == ownerOf(takerId), "taker: not owner of ID");
        // must be provider NFT owner as well
        require(msg.sender == providerNFT.ownerOf(providerId), "taker: not owner of provider ID"); //@rolls control both

        // must not be settled yet
        require(!position.settled, "taker: already settled"); //@audit-ok Rolls is optional. Require Provider permission to position too.M can cancel position at exactly expiration date. use Rolls.executeRoll() to prevent full loss settlement.

        // storage changes. withdrawable is 0 before settlement, so needs no update
        positions[takerId].settled = true;
        // burn token
        _burn(takerId);

        // cancel and withdraw.@@ special condition below //@audit-ok Rolls give approval before cancel. rolls can only cancel position if `Rolls.sol` owner of ProviderPosition approve Taker contract to cancel position
        uint providerWithdrawal = providerNFT.cancelAndWithdraw(providerId);//@unique function only called by Taker contract. It transfer provider locked money to here.
//@normal user. must also give approval to TakerNFT to cancel ProviderNFT.
        // transfer the tokens locked in this contract and the withdrawal from provider
        withdrawal = position.takerLocked + providerWithdrawal;
        cashAsset.safeTransfer(msg.sender, withdrawal);//@info missing event?

        emit PairedPositionCanceled(
            takerId, address(providerNFT), providerId, withdrawal, position.expiration
        );
    }

    // ----- Owner Mutative ----- //

    /// @notice Sets the price oracle used by the contract
    /// @param _oracle The new price oracle to use
    function setOracle(ITakerOracle _oracle) external onlyOwner {
        _setOracle(_oracle);
    }

    // ----- INTERNAL MUTATIVE ----- //

    // internal owner

    function _setOracle(ITakerOracle _oracle) internal {
        // assets match
        require(_oracle.baseToken() == address(underlying), "taker: oracle underlying mismatch");//WETH
        require(_oracle.quoteToken() == address(cashAsset), "taker: oracle cashAsset mismatch");//USDC

        // Ensure price calls don't revert and return a non-zero price at least right now.
        // Only a sanity check, and the protocol should work even if the oracle is temporarily unavailable
        // in the future. For example, if a TWAP oracle is used, the observations buffer can be filled such that
        // the required time window is not available. If Chainlink oracle is used, the prices can be stale.
        uint price = _oracle.currentPrice();
        require(price != 0, "taker: invalid current price");

        // check these views don't revert (part of the interface used in Loans)
        // note: .convertToBaseAmount(price, price) should equal .baseUnitAmount(), but checking this
        // may be too strict for more complex oracles, and .baseUnitAmount() is not used internally now
        require(_oracle.convertToBaseAmount(price, price) != 0, "taker: invalid convertToBaseAmount");//@same as price *e18 /price

        emit OracleSet(oracle, _oracle); // emit before for the prev value
        oracle = _oracle;
    }

    // ----- INTERNAL VIEWS ----- //

    // calculations

    function _strikePrices(uint putStrikePercent, uint callStrikePercent, uint startPrice)
        internal
        pure
        returns (uint putStrikePrice, uint callStrikePrice)
    {
        putStrikePrice = startPrice * putStrikePercent / BIPS_BASE;
        callStrikePrice = startPrice * callStrikePercent / BIPS_BASE;
    }
//@note Taker and Provider and short,long position follow linear payments based on original price. There is  no leverage based on put,strike price. There is no gain as provider or taker setting more higher percentage price. It just an end price where they cut their lost.
    function _settlementCalculations(TakerPosition memory position, uint endPrice)//@ the leverage depend on locked position.So we only need to check if locked position is comparable with put,strike price
        internal //@ not necessary same linear on both side, not continuous,
        pure //@ either provider gain all  taker locked token or taker gain all provider locked token
        returns (uint takerBalance, int providerDelta) //@ok not possible to go out of range. this is remap function with absolute on two side.
    {
        uint startPrice = position.startPrice; // 3617.66 with 110% call strike and 90% put strike
        (uint putStrikePrice, uint callStrikePrice) = // put = 3255.89, call = 3979.432
            _strikePrices(position.putStrikePercent, position.callStrikePercent, startPrice);//@put = startPrice * putStrikePercent / BIPS_BASE

        // restrict endPrice to put-call range. put < endPrice< call
        endPrice = Math.max(Math.min(endPrice, callStrikePrice), putStrikePrice); //@endPrice = chainlink oracle 1e18 WETH = x USDC
        
        // start with locked (corresponds to endPrice == startPrice)
        takerBalance = position.takerLocked; // locked ~= 10% of collateral
        // endPrice == startPrice is no-op in both branches
        if (endPrice < startPrice) {//@ endPrice = 3600e6, start 3618e6
            // takerLocked: divided between taker and provider
            // providerLocked: all goes to provider
            uint providerGainRange = startPrice - endPrice;// 1e1 -> 1000e6
            uint putRange = startPrice - putStrikePrice;//with 3600e6. 36_000-> 100e6
            uint providerGain = position.takerLocked * providerGainRange / putRange; //1e1 * 1e1 / 36_000
            takerBalance -= providerGain;//@provider only gain as much as Taker put in.
            providerDelta = providerGain.toInt256();//@price drop to 3100, gain 1793 USDC same amount as taker locked. Taker balance become zero.
        } else {
            // takerLocked: all goes to taker
            // providerLocked: divided between taker and provider
            uint takerGainRange = endPrice - startPrice;// 10_000_000
            uint callRange = callStrikePrice - startPrice;//36_000
            uint takerGain = position.providerLocked * takerGainRange / callRange; // no div-zero ensured on open

            takerBalance += takerGain;
            providerDelta = -takerGain.toInt256();//@audit-ok L Taker can gain more than its position locked. But the cap price prevent this. can this be bypassed? NOPE
        }//@ 3600e6 *9999/ 10000 = 3599.964000 = 
        // console2.log("providerLocked: %e",position.providerLocked);//takerGainRange = 36_000
        // console2.log("takerLocked: %e",position.takerLocked);// callRange = 
        // console2.log("startPrice: %e",startPrice);
        // console2.log("putStrikePrice: %e",putStrikePrice);
        // console2.log("callStrikePrice: %e",callStrikePrice);
        // console2.log("endPrice: %e",endPrice);
        // console2.log("takerBalance: %e",takerBalance);
        // console2.log("providerDelta: %e",providerDelta);
    }
}