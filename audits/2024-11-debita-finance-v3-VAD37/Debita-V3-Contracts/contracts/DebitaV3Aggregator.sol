pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "@contracts/DebitaProxyContract.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {console2} from "forge-std/Test.sol";
interface DLOFactory {
    function isLendOrderLegit(address _lendOrder) external view returns (bool);
}
interface IOwnerships {
    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function burn(uint256 tokenId) external;

    function mint(address to) external returns (uint256);
}

interface DLOImplementation {
    struct LendInfo {
        address lendOrderAddress;
        bool perpetual;
        bool lonelyLender;
        bool[] oraclesPerPairActivated;
        uint[] maxLTVs;
        uint apr;
        uint maxDuration;
        uint minDuration;
        address owner;
        address principle;
        address[] acceptedCollaterals;
        address[] oracle_Collaterals;
        uint[] maxRatio;
        address oracle_Principle;
        uint startedLendingAmount;
        uint availableAmount;
    }

    function getLendInfo() external view returns (LendInfo memory);
    function acceptLendingOffer(uint amount) external;
}

interface DebitaV3Loan {
    struct infoOfOffers {
        address principle;
        address lendOffer;
        uint principleAmount;
        uint lenderID;
        uint apr;
        uint ratio;
        uint collateralUsed;
        uint maxDeadline;
        bool paid;
        bool collateralClaimed;
        bool debtClaimed;
        uint interestToClaim;
        uint interestPaid;
    }

    struct LoanData {
        address collateral;
        address[] principles;
        address valuableCollateralAsset;
        bool isCollateralNFT;
        bool auctionInitialized;
        bool extended;
        uint startedAt;
        uint initialDuration;
        uint borrowerID;
        uint NftID;
        uint collateralAmount;
        uint collateralValuableAmount;
        uint valuableCollateralUsed;
        uint totalCountPaid;
        uint[] principlesAmount;
        infoOfOffers[] _acceptedOffers;
    }

    function getLoanData() external view returns (LoanData memory);
    function initialize(
        address _collateral,
        address[] memory _principles,
        bool _isCollateralNFT,
        uint _NftID,
        uint _collateralAmount,
        uint _valuableCollateralAmount,
        uint valuableCollateralUsed,
        address valuableAsset,
        uint _initialDuration,
        uint[] memory _principlesAmount,
        uint _borrowerID,
        infoOfOffers[] memory _acceptedOffers,
        address m_OwnershipContract,
        uint feeInterestLender,
        address _feeAddress
    ) external;
}

interface DebitaIncentives {
    function updateFunds(
        DebitaV3Loan.infoOfOffers[] memory informationOffers,
        address collateral,
        address[] memory lenders,
        address borrower
    ) external;
}

interface DBOFactory {
    function isBorrowOrderLegit(
        address _borrowOrder
    ) external view returns (bool);
}

interface IReceipt {
    struct receiptInstance {
        uint receiptID;
        uint attachedNFT;
        uint lockedAmount;
        uint lockedDate;
        uint decimals;
        address vault;
        address underlying;
    }

    function getDataByReceipt(
        uint receiptID
    ) external view returns (receiptInstance memory);
}

interface DBOImplementation {
    struct BorrowInfo {
        address borrowOrderAddress;
        bool[] oraclesPerPairActivated;
        uint[] LTVs;
        uint maxApr;
        uint duration;
        address owner;
        address[] acceptedPrinciples;
        address collateral;
        address valuableAsset;
        bool isNFT;
        uint receiptID;
        address[] oracles_Principles;
        uint[] ratio;
        address oracle_Collateral;
        uint valuableAssetAmount; // only used for auction sold NFTs
        uint availableAmount;
        uint startAmount;
    }

    function getBorrowInfo()
        external
        view
        returns (DBOImplementation.BorrowInfo memory);
    function acceptBorrowOffer(uint amount) external;
}

interface IOracle {
    function getThePrice(address _token) external view returns (uint);
}

contract DebitaV3Aggregator is ReentrancyGuard {
    event LoanCreated(
        address indexed loan,
        DebitaV3Loan.infoOfOffers[] offers,
        uint totalCountPaid,
        address collateral,
        bool auctionInit
    );
    event LoanDeleted(
        address indexed loan,
        DebitaV3Loan.infoOfOffers[] offers,
        uint totalCountPaid,
        address collateral,
        bool auctionInit
    );
    event LoanUpdated(
        address indexed loan,
        DebitaV3Loan.infoOfOffers[] offers,
        uint totalCountPaid,
        address collateral,
        bool auctionInit
    );

    address s_DLOFactory; // DLOFactory.sol // DLOFactory (DLOImplementation) DebitaLendOffer-Implementation
    address s_DBOFactory; // DBOFactory.sol // DBOFactory(DBOImplementation) DebitaBorrowOffer-Implementation
    address s_Incentives; // DebitaIncentives.sol
    address s_OwnershipContract; //Ownerships  DebitaLoanOwnerships
    address s_LoanImplementation; // DebitaV3Loan.sol
    address public s_AuctionFactory; //AuctionFactory.sol

    address public feeAddress; // address where the fees are sent
    address public owner;
    uint deployedTime; // time when the contract was deployed
    uint public feePerDay = 4; // fee per day (0.04%)
    uint public maxFEE = 80; // max fee 0.8%
    uint public minFEE = 20; // min fee 0.2%
    uint public feeCONNECTOR = 1500; // 15% of the fee goes to the connector
    uint public feeInterestLender = 1500; // 15% of the paid interest
    uint public loanID;//@ DebitaV3Loan ID 
    bool public isPaused; // aggregator is paused

    mapping(address => bool) public isSenderALoan; // if the address is a loan
    mapping(address => bool) public isCollateralAValidReceipt; // if address is a whitelisted NFT
    // id ownership => loan id
    mapping(uint => uint) public getLoanIdByOwnershipID;
    // loan id ==> loan address
    mapping(uint => address) public getAddressById;
    //
    mapping(address => bool) public oracleEnabled; // collateral address => is enabled?

    constructor(
        address _DLOFactory,
        address _DBOFactory,
        address _Incentives,
        address _OwnershipContract,
        address _auctionFactory,
        address loanImplementation
    ) {
        s_DLOFactory = _DLOFactory;// DLOFactory (DLOImplementation) DebitaLendOffer-Implementation
        s_DBOFactory = _DBOFactory;//DBOFactory(DBOImplementation) DebitaBorrowOffer-Implementation
        s_Incentives = _Incentives;// DebitaIncentives
        s_OwnershipContract = _OwnershipContract; //Ownerships  DebitaLoanOwnerships
        feeAddress = msg.sender;
        owner = msg.sender;
        s_AuctionFactory = _auctionFactory; // auctionFactoryDebita  AuctionFactory.sol
        s_LoanImplementation = loanImplementation;// DebitaV3Loan.sol
        deployedTime = block.timestamp;
    }

    struct BorrowInfo {
        address borrowOrderAddress;
        bool[] oraclesPerPairActivated;
        uint[] LTVs;
        uint maxApr;
        uint duration;
        address owner;
        address[] acceptedPrinciples;
        address collateral;
        address valuableAsset;
        bool isNFT;
        uint receiptID;
        address[] oracles_Principles;
        uint[] ratio;
        address oracle_Collateral;
        uint valuableAssetAmount; // only used for auction sold NFTs
        uint availableAmount;
    }

    modifier onlyLoan() {
        require(isSenderALoan[msg.sender], "Sender is not a loan");
        _;
    }

    // lenders have multiple accepted collaterals
    // borrowers have multiple accepted principles
    /**
     * @notice Calculate ratio for each lend order and the borrower individually and then check if the ratios are within the limits
     * @dev Match offers from lenders with a borrower -- It can be called by anyone and the msg.sender will get a reward for calling this function
     * @param lendOrders array of lend orders you want to get liquidity from
     * @param lendAmountPerOrder array of amounts you want to get from each lend order
     * @param porcentageOfRatioPerLendOrder array of percentages of the ratio you want to get from each lend order (10000 = 100% of the maxRatio)
     * @param borrowOrder address of the borrow order
     * @param principles array of principles you want to borrow
     * @param indexForPrinciple_BorrowOrder array of indexes for the principles on the borrow order (in which index is the principle on acceptedPrinciples)
     * @param indexForCollateral_LendOrder array of indexes for the collateral on each lend order (in which index is the collateral on acceptedCollaterals)
     * @param indexPrinciple_LendOrder array of indexes for the principle on each lend order (in which index is the principle of the lend order on principles param)
     */
    function matchOffersV3(
        address[] memory lendOrders, //DLOImplementation address created from factory
        uint[] memory lendAmountPerOrder,
        uint[] memory porcentageOfRatioPerLendOrder,
        address borrowOrder, // DBOImplementation address from factory
        address[] memory principles,
        uint[] memory indexForPrinciple_BorrowOrder,
        uint[] memory indexForCollateral_LendOrder,
        uint[] memory indexPrinciple_LendOrder
    ) external nonReentrant returns (address) {
        // Add count
        loanID++;//start from 1
        DBOImplementation.BorrowInfo memory borrowInfo = DBOImplementation(
            borrowOrder
        ).getBorrowInfo();
        // check lendOrder length is less than 100
        require(lendOrders.length <= 100, "Too many lend orders");//@audit M offers length is <30 not <=100. must follow limit by s_LoanImplementation
        // check borrow order is legit
        require(
            DBOFactory(s_DBOFactory).isBorrowOrderLegit(borrowOrder),
            "Invalid borrow order"
        );
        // check if the aggregator is paused
        require(!isPaused, "New loans are paused");
        // check if valid collateral
        require(//@accept any collateral, if NFT, must be receipt NFT
            isCollateralAValidReceipt[borrowInfo.collateral] || 
                !borrowInfo.isNFT,
            "Invalid collateral"
        );//@audit-ok price feeds will be empty and revert.it still possible to sneak in NFT as ERC20 though. this allow bypass oracle, between NFT oracle and ERC20 oracle
        //@ what happen if there is no oracle though. how that ERC20 is offer? how to game bribe system
        // get price of collateral using borrow order oracle
        uint priceCollateral_BorrowOrder;//@oracle might not be used???

        if (borrowInfo.oracle_Collateral != address(0)) {
            priceCollateral_BorrowOrder = getPriceFrom(//@oracle whitelist, this is ERC20 collateral or NFT underlying asset.
                borrowInfo.oracle_Collateral,
                borrowInfo.valuableAsset
            );//@audit L should have use oracle from lender not from borrower. universal oracle is the best
        }
        uint[] memory ratiosForBorrower = new uint[](principles.length);//@principles is subset list of accepted principle inside borrow order

        // calculate ratio from the borrower for each principle used on this loan --  same collateral different principles
        for (uint i = 0; i < principles.length; i++) {
            // check if principle is accepted by borow order
            require(//@safety check, still it can be used to game non exist token?
                borrowInfo.acceptedPrinciples[//borrowInfo come from user input. Other user borrow Order.
                    indexForPrinciple_BorrowOrder[i] // user input
                ] == principles[i],
                "Invalid principle on borrow order"
            );
            // if the oracle is activated on this pair, get the price and calculate the ratio. If not use fixed ratio of the offer
            if (
                borrowInfo.oraclesPerPairActivated[
                    indexForPrinciple_BorrowOrder[i]
                ]
            ) {
                // if oracle is activated check price is not 0
                require(priceCollateral_BorrowOrder != 0, "Invalid price");
                // get principle price
                uint pricePrinciple = getPriceFrom( //@already check oracle whitelist, no token decimals check or offset here
                    borrowInfo.oracles_Principles[
                        indexForPrinciple_BorrowOrder[i]
                    ],
                    principles[i] //@note price feeds is not token pair. all feeds are Token/USD
                ); //@price e8 decimals //@audit-ok ignore this issue. M not all chainlink token have e8 decimals. Like BTC/USD, USD/ETH 
                /* 
               
                pricePrinciple / priceCollateral_BorrowOrder = 100% ltv (multiply by 10^8 to get extra 8 decimals to avoid floating)

                Example:
                collateral / principle
                1.45 / 2000 = 0.000725 nominal tokens of principle per collateral for 100% LTV                                        
                */ //@audit H a shock AERO price drop below 0.0001 will cause precision loss. e8 decimals is not enough to remedy this. this allow freely exchange collateral and principle at zero cost
                uint principleDecimals = ERC20(principles[i]).decimals(); //@AERO e18 , USDC e6
                //@priceCollateral_BorrowOrder = USDC =3370e8 ,  AERO = 1.32e8
                uint ValuePrincipleFullLTVPerCollateral = (priceCollateral_BorrowOrder *
                        10 ** 8) / pricePrinciple; //@pricePrinciple = AERO ,USDC
                //@ ValuePrincipleFullLTVPerCollateral = price Ratio = collateral / principle
                // take 100% of the LTV and multiply by the LTV of the principle //@LTV is input from borrowOrder original user. //@audit-ok M LTV have no safety check for user to prevent over 100% collateral 
                uint value = (ValuePrincipleFullLTVPerCollateral * 
                    borrowInfo.LTVs[indexForPrinciple_BorrowOrder[i]]) / 10000;
                /**
                 get the ratio for the amount of principle the borrower wants to borrow
                 fix the 8 decimals and get it on the principle decimals
                 */
                uint ratio = (value * (10 ** principleDecimals)) / (10 ** 8);
                ratiosForBorrower[i] = ratio;//@audit M ratio decimals is not consistent. its decimals depend on principles decimals. which can be both e6,e18
                console2.log("--borrow index1: %s, ratio: %e", i,ratio);
                console2.log("pricePrinciple: %e", pricePrinciple);
                console2.log("priceCollateral_BorrowOrder: %e", pricePrinciple);
                console2.log("ValuePrincipleFullLTVPerCollateral: %e", ValuePrincipleFullLTVPerCollateral);
                console2.log("borrowInfo.LTV: %e", borrowInfo.LTVs[indexForPrinciple_BorrowOrder[i]]);
                console2.log("value: %e", value);
            } else {//@?? do not use oracle, just use input ratio from caller
                ratiosForBorrower[i] = borrowInfo.ratio[
                    indexForPrinciple_BorrowOrder[i] //@ isnt this suppose tobe from borrow order contract? not from msg.sender
                ];
                console2.log("--borrow index2: %s, ratio: %e", i,ratiosForBorrower[i]);
            }
        }
        // calculate ratio per lenderOrder, same collateral different (for loop)
        uint amountOfCollateral;
        uint decimalsCollateral = ERC20(borrowInfo.valuableAsset).decimals();
        // weighted ratio for each principle
        uint[] memory weightedAverageRatio = new uint[](principles.length);

        // amount of collateral used per principle
        uint[] memory amountCollateralPerPrinciple = new uint[](
            principles.length
        );//@audit-ok R what happen if principles dupliate in list. 
        // amount of principle per principle to be lent
        uint[] memory amountPerPrinciple = new uint[](principles.length);

        // weighted APR for each principle
        uint[] memory weightedAverageAPR = new uint[](principles.length);

        // Info of each accepted offer
        address[] memory lenders = new address[](lendOrders.length);
        DebitaV3Loan.infoOfOffers[]
            memory offers = new DebitaV3Loan.infoOfOffers[](lendOrders.length);

        // percentage
        uint percentage = ((borrowInfo.duration * feePerDay) / 86400);//0.04% per day always smaller than 0.1% 
        uint[] memory feePerPrinciple = new uint[](principles.length);

        // init DLOFACTORY
        DLOFactory dloFactory = DLOFactory(s_DLOFactory);
        for (uint i = 0; i < lendOrders.length; i++) {//@single borrow order can have max 30 lend order to match with it
            // check lend order is legit
            require(
                dloFactory.isLendOrderLegit(lendOrders[i]), //@audit-ok L also accept lend/borrow order no longer active.
                "Invalid lend order"
            );
            // check incentives here
            DLOImplementation.LendInfo memory lendInfo = DLOImplementation(
                lendOrders[i]
            ).getLendInfo();
            uint principleIndex = indexPrinciple_LendOrder[i]; //@audit-ok L length check for  indexPrinciple_LendOrder == lendOrders
            // check if is lonely lender, if true, only one lender is allowed
            if (lendInfo.lonelyLender) {
                require(lendOrders.length == 1, " Only one lender is allowed");
            }//@lend order by user can force itself to be sole provider of lending?? What is this purpose?
            console2.log("-- lendloop: %s, principle_index: %s ,principle: %s", i, principleIndex,principles[principleIndex]);
            console2.log("porcentageOfRatioPerLendOrder: %e", porcentageOfRatioPerLendOrder[i]);
            // check porcentage of ratio is between 100% and 0%
            require( //@matchOffer input . @ok from caller input
                porcentageOfRatioPerLendOrder[i] <= 10000 &&
                    porcentageOfRatioPerLendOrder[i] > 0,
                "Invalid percentage"
            );

            // check that the collateral is accepted by the lend order
            require(
                lendInfo.acceptedCollaterals[indexForCollateral_LendOrder[i]] ==
                    borrowInfo.collateral,
                "Invalid collateral Lend Offer"
            );//@ borrowInfo current collateral is the same as lendOrder accepted collateral

            // check that the principle is provided by the lend order
            require(
                lendInfo.principle == principles[principleIndex],
                "Invalid principle on lend order"
            );//@ lender Order must have same principle? same colalteral as borrower order
            // check that the duration is between the min and max duration from the lend order
            require(
                borrowInfo.duration >= lendInfo.minDuration &&
                    borrowInfo.duration <= lendInfo.maxDuration,
                "Invalid duration"
            );
            uint collateralIndex = indexForCollateral_LendOrder[i];//@ collateral[i] == acceptedCollaterals[i] == borrower.collateral
            uint maxRatio;
            // check if the lend order has an oracle activated for the pair
            if (lendInfo.oraclesPerPairActivated[collateralIndex]) {//@ there is no check if lendOrder oracle by user is poiting to the same collateral token
                // calculate the price for collateral and principles with each oracles provided by the lender
                uint priceCollateral_LendOrder = getPriceFrom( //@oracle contract is whitelist, tokenPrice ask for 
                    lendInfo.oracle_Collaterals[collateralIndex],
                    borrowInfo.valuableAsset // ERC721: underlying, ERC20: Same as collateral
                );//AERO/USD = 1.32e8
                uint pricePrinciple = getPriceFrom(
                    lendInfo.oracle_Principle,
                    principles[principleIndex]
                );//USDC/USD = 1e8 or WETH/USD 3370e8
                console2.log("priceCollateral_LendOrder: %e", priceCollateral_LendOrder);
                console2.log("pricePrinciple: %e", pricePrinciple);
                uint fullRatioPerLending = (priceCollateral_LendOrder *
                    10 ** 8) / pricePrinciple; // AERO/USD / WETH/USD = AERO / WETH = 1.32e8 / 3370e8 = 0.0003916914e8
                console2.log("fullRatioPerLending: %e", fullRatioPerLending);
                uint maxValue = (fullRatioPerLending * //@LTV from user: any value. default 5000 - 7000
                    lendInfo.maxLTVs[collateralIndex]) / 10000;
                console2.log("lendInfo.maxLTV: %e", lendInfo.maxLTVs[collateralIndex]);
                console2.log("maxValue: %e", maxValue);
                uint principleDecimals = ERC20(principles[principleIndex])
                    .decimals();
                maxRatio = (maxValue * (10 ** principleDecimals)) / (10 ** 8);// AERO/WETH = 0.0003916914e18 , USDC/AERO = 0.77e6
                console2.log("maxRatio1: %e", maxRatio); // 0.35737e17 AERO/USDC
            } else {
                maxRatio = lendInfo.maxRatio[collateralIndex];//@this ratio is calculated with raw price not price ratio.
                console2.log("maxRatio2: %e", maxRatio);
            }
            // calculate ratio based on porcentage of the lend order . @ratio reduced by user input. user input percentage < 100%. but ratio can be any value.
            uint ratio = (maxRatio * porcentageOfRatioPerLendOrder[i]) / 10000;//@ lendInfo variable * user input variable??
            uint m_amountCollateralPerPrinciple = amountCollateralPerPrinciple[ //@this shit is from previous loop. total of previous used principle during this loop
                principleIndex
            ];//@ 0 on first lend order loop
            console2.log("ratio: %e", ratio); //0.377e18
            console2.log("m_amountCollateralPerPrinciple: %e", m_amountCollateralPerPrinciple);
            console2.log("lendAmountPerOrder: %e", lendAmountPerOrder[i]);
            // calculate the amount of collateral used by the lender
            uint userUsedCollateral = (lendAmountPerOrder[i] * //@ how much lending get from this lend Orders , AERO, userUsedCollateral = 25e17 * 1e18 / 5e17
                (10 ** decimalsCollateral)) / ratio; //@borrow collateral/NFT underlying. AERO e18
            console2.log("userUsedCollateral: %e",userUsedCollateral); //@userUsedCollateral= 2.5e18 * 1e6 / 0.377e18 = 6.6e6 USDC
            // get updated weight average from the last weight average
            uint updatedLastWeightAverage = (weightedAverageRatio[
                principleIndex
            ] * m_amountCollateralPerPrinciple) /
                (m_amountCollateralPerPrinciple + userUsedCollateral);//@ weight = 0 on first loop
            console2.log("updatedLastWeightAverage: %e", updatedLastWeightAverage);
            // same with apr
            uint updatedLastApr = (weightedAverageAPR[principleIndex] *
                amountPerPrinciple[principleIndex]) /
                (amountPerPrinciple[principleIndex] + lendAmountPerOrder[i]);//apr = 0 on first loop
            console2.log("updatedLastApr: %e", updatedLastApr);
            // add the amounts to the total amounts
            amountPerPrinciple[principleIndex] += lendAmountPerOrder[i];
            amountOfCollateral += userUsedCollateral;
            amountCollateralPerPrinciple[principleIndex] += userUsedCollateral; //@ cache total to next loop . lender ready to lend ~6.9e6 USDC to borrower in exchange for what?
            console2.log("amountCollateralPerPrinciple: %e", amountCollateralPerPrinciple[principleIndex]);
            console2.log("amountOfCollateral: %e", amountOfCollateral);
            console2.log("amountPerPrinciple: %e", amountPerPrinciple[principleIndex]);
            // calculate new weights . //@ ratio should be % and < 1e18
            uint newWeightedAverage = (ratio * userUsedCollateral) /
                (m_amountCollateralPerPrinciple + userUsedCollateral);//@ weightAverage = lendAmountPerOrder[i] * e18 / (userUsedCollateral + last collateral) = 
            console2.log("newWeightedAverage: %e", newWeightedAverage);
            uint newWeightedAPR = (lendInfo.apr * lendAmountPerOrder[i]) /
                amountPerPrinciple[principleIndex];
            console2.log("newWeightedAPR: %e", newWeightedAPR);
            // calculate the weight of the new amounts, add them to the weighted and accept offers
            weightedAverageRatio[principleIndex] =
                newWeightedAverage +
                updatedLastWeightAverage;
            weightedAverageAPR[principleIndex] =
                newWeightedAPR +
                updatedLastApr;
            console2.log("weightedAverageRatio: %e", weightedAverageRatio[principleIndex]);
            console2.log("weightedAverageAPR: %e", weightedAverageAPR[principleIndex]);
            // mint ownership for the lender
            uint lendID = IOwnerships(s_OwnershipContract).mint(lendInfo.owner);//@audit-ok it is APR calculate later. H APR is not clamp to yearly but based on borrower duration.
            offers[i] = DebitaV3Loan.infoOfOffers({
                principle: lendInfo.principle,
                lendOffer: lendOrders[i],
                principleAmount: lendAmountPerOrder[i],
                lenderID: lendID,
                apr: lendInfo.apr,
                ratio: ratio,
                collateralUsed: userUsedCollateral,
                maxDeadline: lendInfo.maxDuration + block.timestamp,
                paid: false,
                collateralClaimed: false,
                debtClaimed: false,
                interestToClaim: 0,
                interestPaid: 0
            });
            getLoanIdByOwnershipID[lendID] = loanID;
            lenders[i] = lendInfo.owner;
            DLOImplementation(lendOrders[i]).acceptLendingOffer(
                lendAmountPerOrder[i]
            );
        }
        console2.log("-percentage: %e", percentage);
        // fix the percentage of the fees
        if (percentage > maxFEE) {
            percentage = maxFEE;
        }//@ok fee over longer period capped to 0.5%-1% max

        if (percentage < minFEE) { //0.2%
            percentage = minFEE; //@percentage = time/1day * 0.04%
        }

        // check ratio for each principle and check if the ratios are within the limits of the borrower
        for (uint i = 0; i < principles.length; i++) {
            require(
                weightedAverageRatio[i] >=
                    ((ratiosForBorrower[i] * 9800) / 10000) &&
                    weightedAverageRatio[i] <=
                    (ratiosForBorrower[i] * 10200) / 10000,
                "Invalid ratio" //@so requirements is 2% margin of error based on how much borrower want to borrow? //@audit H someone can make fake borrow order with 100% collateral rate. then ask for lender with 100% lending
            );//AERO borrower ratio: 3.5737548e17 = 50% AERO . WETH borrower ratio: 2.0422e14 = 1 / ETH price * 70%

            // calculate fees --> msg.sender keeps 15% of the fee for connecting the offers
            uint feeToPay = (amountPerPrinciple[i] * percentage) / 10000;
            uint feeToConnector = (feeToPay * feeCONNECTOR) / 10000;
            feePerPrinciple[i] = feeToPay;
            // transfer fee to feeAddress
            SafeERC20.safeTransfer(
                IERC20(principles[i]),
                feeAddress,
                feeToPay - feeToConnector
            );
            // transfer fee to connector
            SafeERC20.safeTransfer(
                IERC20(principles[i]),
                msg.sender,
                feeToConnector
            );
            // check if the apr is within the limits of the borrower
            require(weightedAverageAPR[i] <= borrowInfo.maxApr, "Invalid APR");
        }
        // if collateral is an NFT, check if the amount of collateral is within the limits
        // it has a 2% margin to make easier the matching, amountOfCollateral is the amount of collateral "consumed" and the valuableAssetAmount is the underlying amount of the NFT
        if (borrowInfo.isNFT) {
            require(
                amountOfCollateral <=
                    (borrowInfo.valuableAssetAmount * 10200) / 10000 &&
                    amountOfCollateral >=
                    (borrowInfo.valuableAssetAmount * 9800) / 10000,
                "Invalid collateral amount"
            );
        }
        DBOImplementation(borrowOrder).acceptBorrowOffer(
            borrowInfo.isNFT ? 1 : amountOfCollateral
        );

        uint borrowID = IOwnerships(s_OwnershipContract).mint(borrowInfo.owner);

        // finish the loan & change the inputs

        // falta pagar incentivos y pagar fee
        DebitaProxyContract _loanProxy = new DebitaProxyContract(
            s_LoanImplementation
        );
        DebitaV3Loan deployedLoan = DebitaV3Loan(address(_loanProxy));
        // init loan
        deployedLoan.initialize(
            borrowInfo.collateral,
            principles,
            borrowInfo.isNFT,
            borrowInfo.receiptID,
            borrowInfo.isNFT ? 1 : amountOfCollateral,
            borrowInfo.valuableAssetAmount,
            amountOfCollateral,
            borrowInfo.valuableAsset,
            borrowInfo.duration,
            amountPerPrinciple,
            borrowID, //borrowInfo.id,
            offers,
            s_OwnershipContract,
            feeInterestLender,
            feeAddress
        );
        // save loan
        getAddressById[loanID] = address(deployedLoan);
        isSenderALoan[address(deployedLoan)] = true;

        // transfer the principles to the borrower
        for (uint i; i < principles.length; i++) {
            SafeERC20.safeTransfer(
                IERC20(principles[i]),
                borrowInfo.owner,
                amountPerPrinciple[i] - feePerPrinciple[i]
            );
        }
        // transfer the collateral to the loan
        if (borrowInfo.isNFT) {
            IERC721(borrowInfo.collateral).transferFrom(
                address(this),
                address(deployedLoan),
                borrowInfo.receiptID
            );
        } else {
            SafeERC20.safeTransfer(
                IERC20(borrowInfo.collateral),
                address(deployedLoan),
                amountOfCollateral
            );
        }
        // update incentives
        DebitaIncentives(s_Incentives).updateFunds(
            offers,
            borrowInfo.collateral,
            lenders,
            borrowInfo.owner
        );

        // emit
        emit LoanCreated(
            address(deployedLoan),
            offers,
            0,
            borrowInfo.collateral,
            false
        );
        return address(deployedLoan);
    }

    function statusCreateNewOffers(bool _newStatus) public {
        require(msg.sender == owner, "Invalid address");
        isPaused = _newStatus;
    }

    function setValidNFTCollateral(address _collateral, bool status) external {
        require(msg.sender == owner, "Invalid address");
        isCollateralAValidReceipt[_collateral] = status;
    }
    function setNewFee(uint _fee) external {
        require(msg.sender == owner, "Invalid address");
        require(_fee >= 1 && _fee <= 10, "Invalid fee");
        feePerDay = _fee;
    }

    function setNewMaxFee(uint _fee) external {
        require(msg.sender == owner, "Invalid address");
        require(_fee >= 50 && _fee <= 100, "Invalid fee");
        maxFEE = _fee;
    }

    function setNewMinFee(uint _fee) external {
        require(msg.sender == owner, "Invalid address");
        require(_fee >= 10 && _fee <= 50, "Invalid fee");
        minFEE = _fee;
    }

    function setNewFeeConnector(uint _fee) external {
        require(msg.sender == owner, "Invalid address");
        require(_fee >= 500 && _fee <= 2000, "Invalid fee");
        feeCONNECTOR = _fee;
    }

    function changeOwner(address owner) public {
        require(msg.sender == owner, "Only owner");
        require(deployedTime + 6 hours > block.timestamp, "6 hours passed");
        owner = owner;
    }

    function setOracleEnabled(address _oracle, bool status) external {
        require(msg.sender == owner, "Invalid address");
        oracleEnabled[_oracle] = status;
    }

    function getAllLoans(
        uint offset,
        uint limit
    ) external view returns (DebitaV3Loan.LoanData[] memory) {
        // return LoanData
        uint _limit = loanID;
        if (limit > _limit) {
            limit = _limit;
        }

        DebitaV3Loan.LoanData[] memory loans = new DebitaV3Loan.LoanData[](
            limit - offset
        );

        for (uint i = 0; i < limit - offset; i++) {
            if ((i + offset + 1) >= loanID) {
                break;
            }
            address loanAddress = getAddressById[i + offset + 1];

            DebitaV3Loan loan = DebitaV3Loan(loanAddress);
            loans[i] = loan.getLoanData();

            // loanIDs start at 1
        }
        return loans;
    }

    function getPriceFrom(
        address _oracle,
        address _token
    ) internal view returns (uint) {
        require(oracleEnabled[_oracle], "Oracle not enabled");
        return IOracle(_oracle).getThePrice(_token);
    }

    function emitLoanUpdated(address loan) public onlyLoan {
        DebitaV3Loan loanInstance = DebitaV3Loan(loan);
        DebitaV3Loan.LoanData memory loanData = loanInstance.getLoanData();
        emit LoanUpdated(
            loan,
            loanData._acceptedOffers,
            loanData.totalCountPaid,
            loanData.collateral,
            loanData.auctionInitialized
        );
    }
}
//Match offer V3
//@note b1.borrower whitelsit NFT receipt or collateral ERC20 token
// collateral ERC20 can be any token as long as lender accept weird token
//b2. borrowOrder legit 
//b3 verify whitelist oracle from borrowOrder both collateral and principles
// price from oracle non zero . oracle exist but collateral ERC20 token might not exist. it still revert
// calculate list ratiosForBorrower (unknown purpose)
// 
// l0: lender collateral calculation
// l1 lenders length <30 or == 1 if lonely lender
// l2: lendOrder legit
// l3 length check for other index list lend order input > lend Orders length
// l4 ratioPerLender < 100% and > 0%
// l5 lend order collateral must be same as borrower collateral
// l6 lend order principle == borrower accepted principle and same as caller input
// l7 lend order duration is between min and max duration of borrow order
// l8 get lend order collateral.

