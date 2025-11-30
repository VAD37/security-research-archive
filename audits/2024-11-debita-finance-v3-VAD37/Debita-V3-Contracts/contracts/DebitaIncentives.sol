pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DebitaIncentives {
    event Incentivized(
        address indexed principle,
        address indexed incentivizeToken,
        uint amount,
        bool lendIncentivize,
        uint epoch
    );

    event ClaimedIncentives(
        address indexed user,
        address indexed principle,
        address indexed incentivizeToken,
        uint amount,
        uint epoch
    );

    event UpdatedFunds(
        address indexed lenders,
        address indexed principle,
        address indexed collateral,
        address borrower,
        uint epoch
    );

    event WhitelistedPair(
        address indexed principle,
        address indexed collateral,
        bool whitelisted
    );

    uint public blockDeployedContract; // timestamp of deployment
    uint public epochDuration = 14 days; // duration of an epoch
    address owner;
    address aggregatorContract;

    struct infoOfOffers {
        address principle; // address of the principle
        address lendOffer; // address of the lend offer
        uint principleAmount; // amount of principle
        uint lenderID; // ID of the lender
        uint apr; // APR of the offer
        uint ratio; // ratio of the offer
        uint collateralUsed; // collateral used
        uint maxDeadline; // max deadline
        bool paid; // has been paid
        bool collateralClaimed; // has collateral been claimed
        bool debtClaimed; // total debt claimed
        uint interestToClaim; // available interest to claim
        uint interestPaid; // interest already paid
    }

    struct InfoOfBribePerPrinciple {
        address principle; // address of the principle
        address[] bribeToken; // address of the bribe tokens
        uint[] amountPerLent;
        uint[] amountPerBorrow;
        uint epoch;
    }
    /* 
    -------
    Lend Incentives
    -------
    */
    // principle => (keccack256(bribe token, epoch)) => total incentives amount
    mapping(address => mapping(bytes32 => uint))
        public lentIncentivesPerTokenPerEpoch;

    // wallet address => keccack256(principle + epoch) => amount lent
    mapping(address => mapping(bytes32 => uint))
        public lentAmountPerUserPerEpoch;

    /* 
    --------
    Borrow Incentives
    --------
    */
    // principle => keccack(bribe token, epoch) => amount per Token
    mapping(address => mapping(bytes32 => uint))
        public borrowedIncentivesPerTokenPerEpoch;

    // wallet address => keccack256(principle + epoch) => amount
    mapping(address => mapping(bytes32 => uint)) public borrowAmountPerEpoch;

    // principle => epoch => total lent amount

    mapping(address => mapping(uint => uint)) public totalUsedTokenPerEpoch;

    // wallet => keccack256(principle + epoch + bribe token)  => amount claimed
    mapping(address => mapping(bytes32 => bool)) public claimedIncentives;

    /* 
    Security check
    */

    // principle => collateral => is whitelisted
    mapping(address => mapping(address => bool)) public isPairWhitelisted;
    mapping(address => bool) public isPrincipleWhitelisted;

    /* MAPPINGS FOR READ FUNCTIONS */

    // epoch uint => index  => principle address
    mapping(uint => mapping(uint => address)) public epochIndexToPrinciple;
    // epoch uint => amount of principles incentivized
    mapping(uint => uint) public principlesIncentivizedPerEpoch;

    // epoch uint => principle address => has been indexed
    mapping(uint => mapping(address => bool)) public hasBeenIndexed;

    // epoch => keccak(principle address, index) => bribeToken
    mapping(uint => mapping(bytes32 => address))
        public SpecificBribePerPrincipleOnEpoch;

    // epoch => principle => amount of bribe Tokens
    mapping(uint => mapping(address => uint))
        public bribeCountPerPrincipleOnEpoch;

    // epoch => incentive token => bool has been indexed
    mapping(uint => mapping(address => bool)) public hasBeenIndexedBribe;

    modifier onlyAggregator() {
        require(msg.sender == aggregatorContract, "Only aggregator");
        _;
    }

    constructor() {
        owner = msg.sender;
        blockDeployedContract = block.timestamp;
    }

    /**
     * @dev Claim the incentives for the user
     * @param principles array of principles used during the epoch
     * @param tokensIncentives array of tokens to claim per principle
     * @param epoch epoch to claim
     */

    function claimIncentives( //@audit-ok missing how much bribes token user can claim per epoch. Due to missing view function.
        address[] memory principles,
        address[][] memory tokensIncentives, //@audit-ok L no array length check?
        uint epoch
    ) public {
        // get information
        require(epoch < currentEpoch(), "Epoch not finished");
        //@can use non exist principles. mapping point to nothing though
        for (uint i; i < principles.length; i++) {
            address principle = principles[i];
            uint lentAmount = lentAmountPerUserPerEpoch[msg.sender][ //@ from aggregator updateFunds and infoOffers[].principleAmount
                hashVariables(principle, epoch)
            ];//msg.sender must also be lender
            // get the total lent amount for the epoch and principle
            uint totalLentAmount = totalUsedTokenPerEpoch[principle][epoch];//@ from aggregator updateFunds 

            uint porcentageLent;

            if (lentAmount > 0) {
                porcentageLent = (lentAmount * 10000) / totalLentAmount;
            }

            uint borrowAmount = borrowAmountPerEpoch[msg.sender][ //@ from aggregator updateFunds. 
                hashVariables(principle, epoch)
            ];
            uint totalBorrowAmount = totalUsedTokenPerEpoch[principle][epoch];//@same as totalLentAmount
            uint porcentageBorrow;

            require(
                borrowAmount > 0 || lentAmount > 0,
                "No borrowed or lent amount"
            );

            porcentageBorrow = (borrowAmount * 10000) / totalBorrowAmount; //@audit-ok H precision lost cause some user always have zero percentage. 1e6 USDC over 1,000,000 USDC will lost some rewards
            //@for each principle, loop through list of bribe tokens from input. User input maybe depend on getTotalBribesPerEpoch
            for (uint j = 0; j < tokensIncentives[i].length; j++) { //@audit-ok L no check if incentive token exist
                address token = tokensIncentives[i][j]; //@token is incentive token. 
                uint lentIncentive = lentIncentivesPerTokenPerEpoch[principle][ //@from incentivizePair()
                    hashVariables(token, epoch)
                ];
                uint borrowIncentive = borrowedIncentivesPerTokenPerEpoch[ //@from incentivizePair(). total rewards token already transfer before epoch begin
                    principle
                ][hashVariables(token, epoch)];
                require(
                    !claimedIncentives[msg.sender][
                        hashVariablesT(principle, epoch, token)
                    ],
                    "Already claimed"
                );
                require(//@audit-ok Without rewards before hand, there is no reason to claim incentives
                    (lentIncentive > 0 && lentAmount > 0) ||
                        (borrowIncentive > 0 && borrowAmount > 0),
                    "No incentives to claim"
                );
                claimedIncentives[msg.sender][
                    hashVariablesT(principle, epoch, token)
                ] = true;//@did claim for both lending,borrowing bribe token.
                //@amount = totalReward * (user_lend_amount,user_borrow_amount) / total_used_token
                uint amountToClaim = (lentIncentive * porcentageLent) / 10000;
                amountToClaim += (borrowIncentive * porcentageBorrow) / 10000; //@audit-ok other precision issue. M precision lost may cause last user cannot withdraw

                IERC20(token).transfer(msg.sender, amountToClaim);//@audit-ok ignore problems. MR not using safe transfer for USDT

                emit ClaimedIncentives(
                    msg.sender,
                    principle,
                    token,
                    amountToClaim,
                    epoch
                );
            }
        }
    }

    /**
     * @dev Incentivize the pair --> anyone can incentivze the pair but it's mainly thought for chain incentives or points system
        * @param principles array of principles to incentivize
        * @param incentiveToken array of tokens you want to give as incentives
        * @param lendIncentivize array of bools to know if you want to incentivize the lend or the borrow
        * @param amounts array of amounts to incentivize
        * @param epochs array of epochs to incentivize

     */
    function incentivizePair(
        address[] memory principles,//AERO
        address[] memory incentiveToken,//USDC
        bool[] memory lendIncentivize,//true means lender, false means borrower
        uint[] memory amounts,//1e18
        uint[] memory epochs//2
    ) public {
        require(
            principles.length == incentiveToken.length &&
                incentiveToken.length == lendIncentivize.length &&
                lendIncentivize.length == amounts.length &&
                amounts.length == epochs.length,
            "Invalid input"
        );

        for (uint i; i < principles.length; i++) {
            uint epoch = epochs[i];
            address principle = principles[i];
            address incentivizeToken = incentiveToken[i];
            uint amount = amounts[i];
            require(epoch > currentEpoch(), "Epoch already started");
            require(isPrincipleWhitelisted[principle], "Not whitelisted");//@audit-ok loop have limit, unlimitied token is fine.did not check incentiveToken is whitelisted. this allow infinite token bribes per epoch. run out of gas query as possible attack

            // if principles has been indexed into array of the epoch
            if (!hasBeenIndexed[epochs[i]][principles[i]]) {
                uint lastAmount = principlesIncentivizedPerEpoch[epochs[i]];
                epochIndexToPrinciple[epochs[i]][lastAmount] = principles[i];//@?? lastAmount is index
                principlesIncentivizedPerEpoch[epochs[i]]++;//epoch have new principle token
                hasBeenIndexed[epochs[i]][principles[i]] = true;//@view only. tell this epoch have principle money.
            }

            // if bribe token has been indexed into array of the epoch
            if (!hasBeenIndexedBribe[epoch][incentivizeToken]) { //@audit-ok M this if check ignore principle token. If incentivize same token but different principle. It will not be cached.
                uint lastAmount = bribeCountPerPrincipleOnEpoch[epoch][ //@did author already cache it above?
                    principle
                ];//@lastAmount is index.
                SpecificBribePerPrincipleOnEpoch[epoch][
                    hashVariables(principle, lastAmount)
                ] = incentivizeToken;//@cache epoch have principle token and reward token
                bribeCountPerPrincipleOnEpoch[epoch][incentivizeToken]++;//@audit-ok M09 this increase wrong index. principle should be increased not incentivizeToken
                hasBeenIndexedBribe[epoch][incentivizeToken] = true;
            }

            // transfer the tokens
            IERC20(incentivizeToken).transferFrom(
                msg.sender,
                address(this),
                amount
            );
            require(amount > 0, "Amount must be greater than 0");

            // add the amount to the total amount of incentives
            if (lendIncentivize[i]) {
                lentIncentivesPerTokenPerEpoch[principle][
                    hashVariables(incentivizeToken, epoch)
                ] += amount;
            } else {
                borrowedIncentivesPerTokenPerEpoch[principle][
                    hashVariables(incentivizeToken, epoch)
                ] += amount;
            }
            emit Incentivized(
                principles[i],
                incentiveToken[i],
                amounts[i],
                lendIncentivize[i],
                epochs[i]
            );
        }
    }

    // Update the funds of the user and the total amount of the principle
    // -- only aggregator whenever a loan is matched

    /**
     * @dev Update the funds of the user and the total amount of the principle
     * @param informationOffers array of information of the offers
     * @param collateral address of the collateral
     * @param lenders array of lenders
     * @param borrower address of the borrower
     */
    function updateFunds(
        infoOfOffers[] memory informationOffers,
        address collateral,
        address[] memory lenders,
        address borrower
    ) public onlyAggregator {
        for (uint i = 0; i < lenders.length; i++) {
            bool validPair = isPairWhitelisted[informationOffers[i].principle][
                collateral
            ];//@audit-ok not important. M incentive can still update funds despite principle no longer active.
            if (!validPair) {
                return;
            }
            address principle = informationOffers[i].principle;

            uint _currentEpoch = currentEpoch();

            lentAmountPerUserPerEpoch[lenders[i]][
                hashVariables(principle, _currentEpoch)
            ] += informationOffers[i].principleAmount;
            totalUsedTokenPerEpoch[principle][
                _currentEpoch
            ] += informationOffers[i].principleAmount;//@audit-ok Seperate track of rewards lent/total and borrow/total ratio is the same.R this should be added twice? Since this variable used by both borrow and lend
            borrowAmountPerEpoch[borrower][
                hashVariables(principle, _currentEpoch)
            ] += informationOffers[i].principleAmount;

            emit UpdatedFunds(
                lenders[i],
                principle,
                collateral,
                borrower,
                _currentEpoch
            );
        }
    }

    // Get the amount of principles incentivized and the amount of bribes per principle
    function getBribesPerEpoch(
        uint epoch,
        uint offset,
        uint limit
    ) public view returns (InfoOfBribePerPrinciple[] memory) {
        // get the amount of principles incentivized
        uint totalPrinciples = principlesIncentivizedPerEpoch[epoch];//@ok
        if (totalPrinciples == 0) {
            return new InfoOfBribePerPrinciple[](0);
        }
        if (offset > totalPrinciples) {
            return new InfoOfBribePerPrinciple[](0);//@ok
        }
        if (limit > totalPrinciples) {
            limit = totalPrinciples;//@limit is end of index again.
        }
        uint length = limit - offset;
        InfoOfBribePerPrinciple[] memory bribes = new InfoOfBribePerPrinciple[](
            length
        );//@ok

        for (uint i = 0; i < length; i++) {//@i: range offset -> limit.  length = 3,offset 2, limit =totalPrinciples = 5
            address principle = epochIndexToPrinciple[epoch][i + offset];//@index: range offset -> limit.
            uint totalBribes = bribeCountPerPrincipleOnEpoch[epoch][principle];//@audit-ok M09  this is wrong due to bribe cache wrong token
            address[] memory bribeToken = new address[](totalBribes);//@assume 3 bribes token with 5 principles.
            uint[] memory amountPerLent = new uint[](totalBribes);
            uint[] memory amountPerBorrow = new uint[](totalBribes);

            for (uint j = 0; j < totalBribes; j++) {
                address token = SpecificBribePerPrincipleOnEpoch[epoch][
                    hashVariables(principle, j)
                ];//@token = incentivizeToken
                uint lentIncentive = lentIncentivesPerTokenPerEpoch[principle][
                    hashVariables(token, epoch)
                ];//ok
                uint borrowIncentive = borrowedIncentivesPerTokenPerEpoch[
                    principle
                ][hashVariables(token, epoch)];//ok

                bribeToken[j] = token;
                amountPerLent[j] = lentIncentive;
                amountPerBorrow[j] = borrowIncentive;
            }

            bribes[i] = InfoOfBribePerPrinciple(//@ p: AERO, reward: USDC , 100e18 ... hasBeenIndexedBribe[epoch][USDC] = true. edit SpecificBribePerPrincipleOnEpoch,bribeCountPerPrincipleOnEpoch
                principle,//                        p: USDC, reward: USDC, 100e18 ... skip bribeCountPerPrincipleOnEpoch[principal] = 0
                bribeToken,//totalBribes for USDC = 0. because it skip above.
                amountPerLent,
                amountPerBorrow,
                epoch
            );//@ok length is total principles
        }
        return bribes;
    }

    function setAggregatorContract(address _aggregatorContract) public {
        require(msg.sender == owner, "Only owner");
        require(aggregatorContract == address(0), "Already set");
        aggregatorContract = _aggregatorContract;
    }

    function whitelListCollateral(
        address _principle,//AERO, AERO
        address _collateral,//AERO,USDC
        bool whitelist
    ) public {
        require(msg.sender == owner, "Only owner");
        if (isPrincipleWhitelisted[_principle] == false && whitelist) {
            isPrincipleWhitelisted[_principle] = whitelist;
        }
        isPairWhitelisted[_principle][_collateral] = whitelist;//@there are 2 whitelist property? One for principle, one for pair
        emit WhitelistedPair(_principle, _collateral, whitelist);
    }

    function deprecatePrinciple(address _principle) public {
        require(msg.sender == owner, "Only owner");
        isPrincipleWhitelisted[_principle] = false;
    }

    function hashVariables(
        address _principle,
        uint _epoch
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_principle, _epoch));
    }
    function hashVariablesT(
        address _principle,
        uint _epoch,
        address _tokenToClaim
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_principle, _epoch, _tokenToClaim));
    }
    function currentEpoch() public view returns (uint) {
        return ((block.timestamp - blockDeployedContract) / epochDuration) + 1;
    }
}
