// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// import {BondingCurve} from "./BondingCurve.sol";
import {LaunchToken} from "./LaunchToken.sol";
import {IUniswapV2RouterMinimal} from "./interfaces/IUniswapV2RouterMinimal.sol";
import {IUniswapV2FactoryMinimal} from "./interfaces/IUniswapV2FactoryMinimal.sol";
import {ILaunchpad, IBondingCurveMinimal} from "./interfaces/ILaunchpad.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {ERC165Checker} from "@openzeppelin/utils/introspection/ERC165Checker.sol";

import {LaunchpadLPVault} from "./LaunchpadLPVault.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {ReentrancyGuard} from "@solady/utils/ReentrancyGuard.sol";

import {ICLOBManager} from "contracts/clob/ICLOBManager.sol";
import {IUniV2Factory} from "./interfaces/IUniV2Factory.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {IDistributor} from "./interfaces/IDistributor.sol";
import {IGTELaunchpadV2Pair} from "./uniswap/interfaces/IGTELaunchpadV2Pair.sol";

import {SpotOperatorRoles} from "contracts/utils/OperatorPanel.sol";
import {OperatorHelperLib} from "contracts/utils/types/OperatorHelperLib.sol";
import {IOperatorPanel} from "contracts/utils/interfaces/IOperatorPanel.sol";
import {EventNonceLib as LaunchpadEventNonce} from "contracts/utils/types/EventNonce.sol";

contract Launchpad is ILaunchpad, Initializable, Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                EVENTS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @dev sig: 0xedb9fe87bd33aab1b87917d7ac18478fc6e849256def39db1a60ca615a1a35f9
    event LaunchpadDeployed(address indexed quoteAsset, address bondingCurve, address router, uint256 eventNonce);
    /// @dev sig: 0xb32a6b288aadfa675cb030ee2f51c6dc12675a9e5531231a996b8edb611f1956
    event BondingLocked(address indexed token, IUniswapV2Pair indexed pairAddress, uint256 eventNonce);
    /// @dev sig: 0xca2a6f300abd801d3ade4ca6344f9caba868f5165eb754544d4fe6195fe07212
    event BondingCurveUpdated(address indexed oldCurve, address indexed newCurve, uint256 eventNonce);
    /// @dev sig: 0x8d4aad4953d0ca700d468f3753aa14432d1b35b43ec6409f051fb6aa43a89607
    event TokenLaunched(
        address indexed dev,
        address indexed token,
        address indexed quoteAsset,
        IBondingCurveMinimal bondingCurve,
        uint256 timestamp,
        uint256 eventNonce
    );
    /// @dev sig: 0x221ca85ebf95f18d1618caabee27ca0867de44313b2989c305e6e6f96f582e40
    event QuoteAssetUpdated(
        address indexed oldQuoteToken, address indexed newQuoteToken, uint256 newQuoteTokenDecimals, uint256 eventNonce
    );
    /// @dev sig: 0xe8f92b6d8befe44289e67ee6740a1b61cfea7bd8ebe8c2050c4ec7ef555d5fc5
    event Swap(
        address indexed buyer,
        address indexed token,
        int256 baseDelta,
        int256 quoteDelta,
        uint256 nextAmountSold,
        uint256 newPrice,
        uint256 eventNonce
    );

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                ERRORS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @dev sig: 0xa2c1d73f
    error BadLaunchFee();
    /// @dev sig: 0x2fe7552a
    error InvalidCurve();
    /// @dev sig: 0xfe717103
    error BondingCurveSetupFailed(bytes returnData);
    /// @dev sig: 0xc7022a01
    error MissingCredits();
    /// @dev sig: 0x5e2acf84
    error OnlyLaunchAsset();
    /// @dev sig: 0x9efab874
    error BondingInactive();
    /// @dev sig: 0x9c8d2cd2
    error InvalidRecipient();
    /// @dev sig: 0x4233ebcb
    error DustAttackInvalid();
    /// @dev sig: 0x1d33d88c
    error InvalidQuoteAsset();
    /// @dev sig: 0x6f156a5e
    error UninitializedCurve();
    /// @dev sig: 0xa3265e40
    error UninitializedQuote();
    /// @dev sig: 0x9b480a76
    error InvalidQuoteScaling();
    /// @dev sig: 0xad73b7b2
    error UnsupportedRewardToken();
    /// @dev sig: 0x6728a9f6
    error SlippageToleranceExceeded();
    /// @dev sig: 0xb12d13eb
    error ETHTransferFailed();
    /// @dev sig: 0xa1d718af
    error InsufficientBaseSold();

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                STATE
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @dev The abi version of this impl so the indexer can handle event-changing upgrades
    uint256 public constant ABI_VERSION = 1;
    uint256 public constant TOTAL_SUPPLY = 1 ether * 1e9;//1_000_000_000
    uint256 public constant BONDING_SUPPLY = 800_000_000 ether;

    address public immutable gteRouter;
    IOperatorPanel public immutable operator;
    IDistributor public immutable distributor;
    IUniswapV2RouterMinimal public immutable uniV2Router;
    IUniswapV2FactoryMinimal internal immutable uniV2Factory;

    // @todo make proxy addr immutable with deterministic addr
    LaunchpadLPVault public launchpadLPVault;

    /// @dev This is just the quote ERC20 cast as LaunchToken so we dont have to import ERC20
    LaunchToken public currentQuoteAsset;
    IBondingCurveMinimal public currentBondingCurve;

    mapping(address token => LaunchData) internal _launches;

    uint256 public launchFee;
    bytes public uniV2InitCodeHash;

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                MODIFIERS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    modifier onlyLaunchAsset() {
        if (_launches[msg.sender].quote == address(0)) revert OnlyLaunchAsset();
        _;
    }

    modifier onlyBondingActive(address token) {
        if (!_launches[token].active) revert BondingInactive();
        _;
    }

    modifier onlySenderOrOperator(address account, SpotOperatorRoles requiredRole) {
        if (msg.sender != gteRouter) OperatorHelperLib.onlySenderOrOperator(operator, account, requiredRole);
        _;
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                CONSTRUCTOR
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    // slither-disable-next-line missing-zero-check
    constructor(
        address uniV2Router_,//uniV2Router MockUniV2Router
        address gteRouter_,//none 0x
        address clobFactory_,// EOA
        address operator_,//contract IOperatorPanel. @note there is two operators panel exist in parallel. perp and account. Unclear launchpad use whom.
        address distributor_//Distributor.sol
    ) {
        uniV2Router = IUniswapV2RouterMinimal(uniV2Router_);
        gteRouter = gteRouter_;
        operator = IOperatorPanel(operator_);
        uniV2Factory = IUniswapV2FactoryMinimal(uniV2Router.factory());
        distributor = IDistributor(distributor_);

        _disableInitializers();
    }

    /// @dev bondingCurveSetupData should contain an ABI-encoded call destined for the bonding curve contract
    function initialize(
        address owner_,//owner in salt contract
        address quoteAsset_,// QUOTE token
        address bondingCurve_,//SimpleBondingCurve.sol
        address launchpadLPVault_,//LaunchpadLPVault.sol
        bytes memory bondingCurveInitData//abi.encode(200_000_000 ether, 10 ether)
    ) external initializer {
        _initializeOwner(owner_);

        if (quoteAsset_ == address(0)) revert InvalidQuoteAsset();
        if (!ERC165Checker.supportsInterface(bondingCurve_, type(IBondingCurveMinimal).interfaceId)) {
            revert InvalidCurve();
        }

        // Sanity check that the new quote asset at the very least implements an ERC20 approval
        LaunchToken(quoteAsset_).approve(address(this), 0);//@note launch pad ignore USDT

        currentBondingCurve = IBondingCurveMinimal(bondingCurve_);
        currentQuoteAsset = LaunchToken(quoteAsset_);
        launchpadLPVault = LaunchpadLPVault(launchpadLPVault_);

        // e.g. bondingCurve.setVirtualReserves({virtualBase: virtualBase_, virtualQuote: virtualQuote_});
        currentBondingCurve.init(bondingCurveInitData);

        emit LaunchpadDeployed(quoteAsset_, bondingCurve_, address(uniV2Router), LaunchpadEventNonce.inc());
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                PUBLIC VIEWS
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    function launches(address launchToken) public view returns (LaunchData memory) {
        return _launches[launchToken];
    }

    function baseSoldFromCurve(address token) public view returns (uint256) {
        return _launches[token].curve.baseSoldFromCurve(token);
    }

    function quoteBoughtByCurve(address token) public view returns (uint256) {
        return _launches[token].curve.quoteBoughtByCurve(token);
    }

    function quoteBaseForQuote(address token, uint256 quoteAmount, bool isBuy)
        public
        view
        returns (uint256 baseAmount)
    {
        return _launches[token].curve.quoteBaseForQuote(token, quoteAmount, isBuy);
    }

    function quoteQuoteForBase(address token, uint256 baseAmount, bool isBuy)
        public
        view
        returns (uint256 quoteAmount)
    {
        return _launches[token].curve.quoteQuoteForBase(token, baseAmount, isBuy);
    }

    function eventNonce() external view returns (uint256) {
        return LaunchpadEventNonce.getCurrentNonce();
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                            PUBLIC WRITES
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @notice Launches a new token
    function launch(string memory name, string memory symbol, string memory mediaURI)
        external
        payable
        nonReentrant
        returns (address token)
    {
        if (msg.value != launchFee) revert BadLaunchFee();

        address quote = address(currentQuoteAsset);
        IBondingCurveMinimal curve = currentBondingCurve;

        if (quote == address(0)) revert UninitializedQuote();//@note all quote token must be ERC20 set by admin
        if (address(curve) == address(0)) revert UninitializedCurve();

        token = address(new LaunchToken(name, symbol, mediaURI, gteRouter));//@audit-ok L team say nope.launch token address is predictable. This could be abused to instantly inflate value of a token before anyone can buy it.

        curve.initializeCurve(token, TOTAL_SUPPLY, BONDING_SUPPLY);// 1B supply and 800M bonding for sale
        distributor.createRewardsPair(token, quote);

        _launches[token] = LaunchData({active: true, curve: curve, quote: quote});

        emit TokenLaunched({
            dev: msg.sender,
            token: token,
            quoteAsset: quote,
            bondingCurve: curve,
            timestamp: block.timestamp,
            eventNonce: LaunchpadEventNonce.inc()
        });

        LaunchToken(token).mint(TOTAL_SUPPLY);//@audit no protection for dev creator to buy their asset first. Someone can simply snap up new token and sell it before dev get a chance to quickbuy their own
    }

    /// @notice Buys an `amountOutBase` of a bonding `token` so long as it costs less than `maxAmountInQuote`
    function buy(BuyData calldata buyData)
        external
        nonReentrant
        onlyBondingActive(buyData.token)//@allow non exist token
        onlySenderOrOperator(buyData.account, SpotOperatorRoles.LAUNCHPAD_FILL)//@this is broken one. out of scope
        returns (uint256 amountOutBaseActual, uint256 amountInQuote)
    {
        IUniswapV2Pair pair = _assertValidRecipient(buyData.recipient, buyData.token);//@still accept token non contract with quote address 0x0
        LaunchData memory data = _launches[buyData.token];
        //@active when all 800M baseToken from bonding is sold to user.
        (amountOutBaseActual, data.active) = _checkGraduation(buyData.token, data, buyData.amountOutBase);//@external call likely fail due to no result return
        //@cap max buy before graduation to 800M.
        amountInQuote = data.curve.buy(buyData.token, amountOutBaseActual);//just normal uniswap curve. price is not affected by user moving along the curve

        if (data.active && amountInQuote == 0) revert DustAttackInvalid();
        if (amountInQuote > buyData.maxAmountInQuote) revert SlippageToleranceExceeded();
//_increaseFeeShares() called from LaunchToken custom logic
        buyData.token.safeTransfer(buyData.recipient, amountOutBaseActual);//can buy whole 1B from this. but need lots of ETH. there always some dust token left after launch market
        address(data.quote).safeTransferFrom(buyData.account, address(this), amountInQuote);

        _emitSwapEvent({
            account: buyData.account,
            token: buyData.token,
            baseAmount: amountOutBaseActual,
            quoteAmount: amountInQuote,
            isBuy: true,
            curve: data.curve
        });

        // If graduated, handle AMM setup and remaining swap
        if (!data.active) {//@audit-ok buy disabled what happen post launch though. do buy still work? if active became false
            (amountOutBaseActual, amountInQuote) = _graduate(buyData, pair, data, amountOutBaseActual, amountInQuote);//@do graduate affect price with left over token?
        }
    }

    function _graduate(
        BuyData calldata buyData,
        IUniswapV2Pair pair,
        LaunchData memory data,
        uint256 amountOutBaseActual,
        uint256 amountInQuote
    ) internal returns (uint256 finalAmountOutBaseActual, uint256 finalAmountInQuote) {
        LaunchToken(buyData.token).unlock();
        _launches[buyData.token].active = false;
        emit BondingLocked(buyData.token, pair, LaunchpadEventNonce.inc());

        uint256 additionalQuote = _createPairAndSwapRemaining({
            token: buyData.token,
            pair: pair,
            data: data,
            remainingBase: buyData.amountOutBase - amountOutBaseActual,
            remainingQuote: buyData.maxAmountInQuote - amountInQuote,
            recipient: buyData.recipient
        });

        finalAmountInQuote = amountInQuote + additionalQuote;
        finalAmountOutBaseActual = additionalQuote > 0 ? buyData.amountOutBase : amountOutBaseActual;
    }

    /// @notice Sells an `amountInBase` of a bonding `token` as long as the proceeds are at least `minAmountOutQuote`
    function sell(address account, address token, address recipient, uint256 amountInBase, uint256 minAmountOutQuote)
        external
        nonReentrant
        onlyBondingActive(token)
        onlySenderOrOperator(account, SpotOperatorRoles.LAUNCHPAD_FILL)
        returns (uint256 amountInBaseActual, uint256 amountOutQuoteActual)
    {
        LaunchData memory data = _launches[token];

        uint256 currentBaseSold = data.curve.baseSoldFromCurve(token);
        if (currentBaseSold < amountInBase) revert InsufficientBaseSold();

        // slither-disable-next-line reentrancy-no-eth
        uint256 amountOutQuote = data.curve.sell(token, amountInBase);

        if (amountOutQuote == 0) revert DustAttackInvalid();
        if (amountOutQuote < minAmountOutQuote) revert SlippageToleranceExceeded();

        _emitSwapEvent({
            account: account,
            token: token,
            baseAmount: amountInBase,
            quoteAmount: amountOutQuote,
            isBuy: false,
            curve: data.curve
        });

        token.safeTransferFrom(account, address(this), amountInBase);
        data.quote.safeTransfer(recipient, amountOutQuote);

        return (amountInBase, amountOutQuote);
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                               OWNER-ONLY
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    /// @notice Updates the bonding curve, live launches are not affected
    function updateBondingCurve(address newBondingCurve) external onlyOwner {
        if (!ERC165Checker.supportsInterface(newBondingCurve, type(IBondingCurveMinimal).interfaceId)) {
            revert InvalidCurve();
        }

        emit BondingCurveUpdated(address(currentBondingCurve), newBondingCurve, LaunchpadEventNonce.inc());

        currentBondingCurve = IBondingCurveMinimal(newBondingCurve);//@audit L new bonding curve didnt get init() the same as constructor
    }//@audit L when update new bonding Curve. Its virtual Reserve + bonding must >= totalSUpply 1B minted here. There is no check here

    /// @notice Updates the quote asset.
    /// @dev The quote asset cannot have been an existing LaunchToken
    function updateQuoteAsset(address newQuoteAsset) external onlyOwner {
        if (newQuoteAsset == address(0) || _launches[newQuoteAsset].quote != address(0)) revert InvalidQuoteAsset();

        // Check new quote at least implements approve in lieu of ERC165
        LaunchToken(newQuoteAsset).approve(address(this), 0);

        emit QuoteAssetUpdated(
            address(currentQuoteAsset), newQuoteAsset, LaunchToken(newQuoteAsset).decimals(), LaunchpadEventNonce.inc()
        );

        currentQuoteAsset = LaunchToken(newQuoteAsset);
    }

    // @todo event
    function updateInitCodeHash(bytes memory newHash) external onlyOwner {
        uniV2InitCodeHash = newHash;
    }

    /// @notice Pulls the fees earned from launching tokens
    function pullFees() external onlyOwner {
        // slither-disable-next-line low-level-calls
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");

        if (!success) revert ETHTransferFailed();
    }

    // @todo event
    function updateLaunchFee(uint256 newLaunchFee) external onlyOwner {
        launchFee = newLaunchFee;
    }

    // @todo event
    function updateLaunchpadLPVault(address newLaunchpadLPVault) external onlyOwner {
        launchpadLPVault = LaunchpadLPVault(newLaunchpadLPVault);
    }

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                                FEE-SHARING
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    function increaseStake(address account, uint96 shares) external onlyLaunchAsset {
        distributor.increaseStake(msg.sender, account, shares);
    }//@only called by LaunchToken. During transfer and bonding phase. LaunchPad give share to early user?

    function decreaseStake(address account, uint96 shares) external onlyLaunchAsset {
        distributor.decreaseStake(msg.sender, account, shares);
    }//remove share from first user after they sell/transfer their token away

    // @todo this call needs to be simplified. the token can know the pair address and call it directly
    // launchpadLp in the pair is going to be a different address than this, so we cant call it directly here
    // pair just knows the distributor address which is why we pass the call to distributor, or we have to add the launchpad address as well
    function endRewards() external onlyLaunchAsset {
        address quote = _launches[msg.sender].quote;
        // @todo stick with one pair interface
        IGTELaunchpadV2Pair pair = IGTELaunchpadV2Pair(address(pairFor(address(uniV2Factory), msg.sender, quote)));

        distributor.endRewards(pair);
    }//@only when all user remove their share by transfer token away. This can be prevented some user never sell or simply give rewards to launch pad

    /*▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀
                            INTERNAL LOGIC
    ▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀▄▀*/

    function _checkGraduation(address token, LaunchData memory data, uint256 amountOutBase)
        internal
        view
        returns (uint256 amountOutBaseActual, bool stillActive)
    {
        uint256 maxBaseForSale = data.curve.bondingSupply(token);//max 800M

        uint256 baseSold = data.curve.baseSoldFromCurve(token);//800M + virtual_base(200M) - baseReserve; baseReserve is 1B, reduced after buy. aka sell reserve to user
        uint256 nextAmountSold = baseSold + amountOutBase;

        // No graduation, can buy full amount of base requested from curve
        if (nextAmountSold < maxBaseForSale) return (amountOutBase, true);//if buy all 800M in bonding phase

        amountOutBaseActual = maxBaseForSale - baseSold;//800M - 0 for first call, then 800M - 800M as maximum value

        return (amountOutBaseActual, false);
    }

    /// @dev Internal struct to help with stack depth
    struct SwapRemainingData {
        address token;
        address quote;
        address recipient;
        uint256 baseAmount;
        uint256 quoteAmount;
    }

    function _createPairAndSwapRemaining(
        address token,
        IUniswapV2Pair pair,
        LaunchData memory data,
        uint256 remainingBase,
        uint256 remainingQuote,
        address recipient
    ) internal returns (uint256 additionalQuoteUsed) {
        /// @todo sr wardens, please flag in your QA report your thoughts on the comments below

        // Create or get the pair
        try uniV2Factory.createPair(token, data.quote) returns (address p) {
            pair = IUniswapV2Pair(p);//@create contract with launch as creator
        } catch {
            // Do nothing, pair exists
            // @todo its more gas but lets check pair exists and create if it doest.
            // try catch in solidity is horrible and should be avoided
        }

        pair.skim(owner());//reset LP. make sure price is not affect by malicious user sending token to pair before creation

        // Add initial liquidity
        uint256 tokensToLock = data.curve.totalSupply(token) - data.curve.bondingSupply(token);//tokenToLock always = 200M= 1B - 800M. left over that is not bought by user.the buying always capped
        uint256 quoteToLock = data.curve.quoteBoughtByCurve(token);// USDC receive from user. ~40ETH

        token.safeApprove(address(uniV2Router), tokensToLock);//always 2e26
        data.quote.safeApprove(address(uniV2Router), quoteToLock);//4e19 - 1 =  3.999e19. There is rounding issue

        uniV2Router.addLiquidity({//@token already launched. to token transfer does not increase share from elsewhere
            tokenA: token,
            tokenB: address(data.quote),
            amountADesired: tokensToLock,// 200M. left over token
            amountBDesired: quoteToLock,//~40 ETH. actual one not virtual reserve
            amountAMin: 0,
            amountBMin: 0,
            to: address(launchpadLPVault),
            deadline: block.timestamp
        });

        // Handle remaining swap if needed

        // @todo clean up control flow here and confirm this is the right trigger
        if (remainingBase > 0 && remainingQuote > 0) {//@note not all last 200M token can be bought. It just fill whatever and launch token with half fill
            uint256 quoteNeeded =
                uniV2Router.getAmountIn({amountOut: remainingBase, reserveIn: quoteToLock, reserveOut: tokensToLock});

            if (remainingQuote >= quoteNeeded) {
                SwapRemainingData memory d = SwapRemainingData({
                    token: token,
                    quote: data.quote,
                    recipient: recipient,
                    baseAmount: remainingBase,
                    quoteAmount: quoteNeeded
                });

                (, uint256 quoteUsed) = _swapRemaining(d);
                return quoteUsed;
            }
        }

        return 0;
    }

    /// @dev Tries to perform an exact out swap of the remaining quote tokens from a partially filled buy
    function _swapRemaining(SwapRemainingData memory data) internal returns (uint256, uint256) {
        // Transfer the remaining quote from the user
        data.quote.safeTransferFrom(msg.sender, address(this), data.quoteAmount);

        // Prepare swap path
        address[] memory path = new address[](2);
        path[0] = data.quote;
        path[1] = data.token;

        // Approve router to spend remaining quote
        data.quote.safeApprove(address(uniV2Router), data.quoteAmount);

        try uniV2Router.swapTokensForExactTokens(
            data.baseAmount, data.quoteAmount, path, data.recipient, block.timestamp + 1
        ) {
            // Return the tokens received and quote used
            return (data.baseAmount, data.quoteAmount);
        } catch {
            // If swap fails, return the additional quote tokens to the user and remove approval
            data.quote.safeApprove(address(uniV2Router), 0);
            data.quote.safeTransfer(msg.sender, data.quoteAmount);
            return (0, 0);
        }
    }

    /// @dev Since the launchpad is the only address able to send or receive launch tokens during bonding,
    /// and an arbitrary `recipient` can be specified for
    function _assertValidRecipient(address recipient, address baseToken) internal view returns (IUniswapV2Pair pair) {
        pair = pairFor(address(uniV2Factory), baseToken, _launches[baseToken].quote);
        if (address(pair) == recipient) revert InvalidRecipient();
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (IUniswapV2Pair pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = IUniswapV2Pair(
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                hex"ff",
                                factory,
                                keccak256(abi.encodePacked(token0, token1)),
                                uniV2InitCodeHash // init code hash
                            )
                        )
                    )
                )
            )
        );
    }

    function _emitSwapEvent(
        address account,
        address token,
        uint256 baseAmount,
        uint256 quoteAmount,
        bool isBuy,
        IBondingCurveMinimal curve
    ) internal {
        int256 baseDelta = isBuy ? int256(baseAmount) : -int256(baseAmount);
        int256 quoteDelta = isBuy ? -int256(quoteAmount) : int256(quoteAmount);

        emit Swap({
            buyer: account,
            token: token,
            baseDelta: baseDelta,
            quoteDelta: quoteDelta,
            nextAmountSold: curve.baseSoldFromCurve(token), // Current state after trade. //(supply[token].bondingSupply + VIRTUAL_BASE) - reserves[token].baseReserve;
            newPrice: curve.quoteBoughtByCurve(token),
            eventNonce: LaunchpadEventNonce.inc()
        });
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert("UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert("UniswapV2Library: ZERO_ADDRESS");
    }
}
