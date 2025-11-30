pragma solidity ^0.8.0;

import "@contracts/auctions/Auction.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {console2} from "forge-std/Test.sol";
interface IAggregator {
    function isSenderALoan(address) external view returns (bool);
}

contract auctionFactoryDebita {
    event createdAuction(
        address indexed auctionAddress,
        address indexed creator
    );
    event auctionEdited(
        address indexed auctionAddress,
        address indexed creator
    );
    event auctionEnded(address indexed auctionAddress, address indexed creator);

    // auction address ==> is auction
    mapping(address => bool) public isAuction; // if a contract is an auction

    // auction address ==> index
    mapping(address => uint) public AuctionOrderIndex; // index of an auction inside the active Orders

    // index ==> auction address
    mapping(uint => address) public allActiveAuctionOrders; // all active orders

    uint public activeOrdersCount; // count of active orders

    // 15%
    uint public FloorPricePercentage = 1500; // floor price for liquidations
    uint public auctionFee = 200; // fee for liquidations 2%
    uint public publicAuctionFee = 50; // fee for public auctions 0.5%
    uint deployedTime;
    address owner; // owner of the contract
    address aggregator;

    address public feeAddress; // address to send fees
    address[] public historicalAuctions; // all historical auctions

    constructor() {
        owner = msg.sender;
        feeAddress = msg.sender;
        deployedTime = block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }

    modifier onlyAuctions() {
        require(isAuction[msg.sender], "Only auctions");
        _;
    }
    /**
     * @dev create auction 
        * @param _veNFTID veNFT ID for the auction
        * @param _veNFTAddress veNFT address that you want to sell
        * @param liquidationToken the token address of the token you want to sell your veNFT for
        * @param _initAmount initial amount
        * @param _floorAmount floor amount of sell
        * @param _duration duration of the auction

     */
    function createAuction(
        uint _veNFTID, //voting escrow NFT. lock VE token for NFT
        address _veNFTAddress, //@veNFT 0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4 . Lock 100e18 token
        address liquidationToken,//AERO 1.33$
        uint _initAmount, //100e18
        uint _floorAmount,// 10e18
        uint _duration // 1 day
    ) public returns (address) {
        // check if aggregator is set
        require(aggregator != address(0), "Aggregator not set");

        // initAmount should be more than floorAmount
        require(_initAmount >= _floorAmount, "Invalid amount");
        DutchAuction_veNFT _createdAuction = new DutchAuction_veNFT(
            _veNFTID,
            _veNFTAddress,
            liquidationToken,
            msg.sender,
            _initAmount,
            _floorAmount,
            _duration,
            IAggregator(aggregator).isSenderALoan(msg.sender) // if the sender is a loan --> isLiquidation = true
        );

        // Transfer veNFT @ERC721.safeTransfer do nothing special
        IERC721(_veNFTAddress).safeTransferFrom(
            msg.sender, //@audit-ok H03 can use any NFT address to auction. reentrancy attack to delete wrong index first before it is init
            address(_createdAuction),
            _veNFTID,
            ""
        );

        // LOGIC INDEX
        AuctionOrderIndex[address(_createdAuction)] = activeOrdersCount;//cache
        allActiveAuctionOrders[activeOrdersCount] = address(_createdAuction);//cache search dictionary
        activeOrdersCount++;
        historicalAuctions.push(address(_createdAuction));//@array infinity list
        isAuction[address(_createdAuction)] = true; //activate auction

        // emit event
        emit createdAuction(address(_createdAuction), msg.sender);
        return address(_createdAuction);
    }

    /**
     * @dev get active auction orders
     * @param offset offset
     * @param limit limit
     */
    function getActiveAuctionOrders(
        uint offset,
        uint limit
    ) external view returns (DutchAuction_veNFT.dutchAuction_INFO[] memory) {
        uint length = limit;
        if (limit > activeOrdersCount) {
            length = activeOrdersCount;
        }
        // chequear esto
        DutchAuction_veNFT.dutchAuction_INFO[]
            memory result = new DutchAuction_veNFT.dutchAuction_INFO[](
                length - offset
            );
        for (uint i = 0; (i + offset) < length; i++) {
            address order = allActiveAuctionOrders[offset + i];
            DutchAuction_veNFT.dutchAuction_INFO
                memory AuctionInfo = DutchAuction_veNFT(order).getAuctionData();
            result[i] = AuctionInfo;
        }
        return result;
    }

    function getLiquidationFloorPrice(
        uint initAmount
    ) public view returns (uint) {
        return (initAmount * FloorPricePercentage) / 10000;
    }

    function _deleteAuctionOrder(address _AuctionOrder) external onlyAuctions {
        // get index of the Auction order
        uint index = AuctionOrderIndex[_AuctionOrder]; //get auction Index. index = activeOrdersCount . // count 4, index 2
        AuctionOrderIndex[_AuctionOrder] = 0;//reset cache index. this is unique mapping // mapping(address,uimt) -> 0

        // get last Auction order
        allActiveAuctionOrders[index] = allActiveAuctionOrders[ //replace current disable auction with latest auction. index 2 = index 3
            activeOrdersCount - 1
        ];// active index 3 = active index 3
        // take out last Auction order
        allActiveAuctionOrders[activeOrdersCount - 1] = address(0);// delete last auction that was replaced
        // switch index of the last Auction order to the deleted Auction order
        AuctionOrderIndex[allActiveAuctionOrders[index]] = index;//@ index reset to zero above. mapping(address 0x,uint) -> 3 
        activeOrdersCount--; // remove last array of active auction.
    }//@audit-ok M remove latest auction always replace AuctionOrderIndex(0x0) latest auction index.

    /**
     * @dev get historical auctions
     * @param offset offset
     * @param limit limit
     */
    function getHistoricalAuctions(
        uint offset,
        uint limit
    ) public view returns (DutchAuction_veNFT.dutchAuction_INFO[] memory) {
        uint length = limit;
        if (limit > historicalAuctions.length) {
            length = historicalAuctions.length;
        }
        DutchAuction_veNFT.dutchAuction_INFO[]
            memory result = new DutchAuction_veNFT.dutchAuction_INFO[](
                length - offset
            );//@audit-ok M?? limit view of historical auctions does not work. offset 300, limit 100. will always revert. for offchain operation this still revert if view function was too costly.
        for (uint i = 0; (i + offset) < length; i++) {
            address order = historicalAuctions[offset + i];
            DutchAuction_veNFT.dutchAuction_INFO
                memory AuctionInfo = DutchAuction_veNFT(order).getAuctionData();
            result[i] = AuctionInfo;
        }
        return result;
    }

    function getHistoricalAmount() public view returns (uint) {
        return historicalAuctions.length;
    }

    function setFloorPriceForLiquidations(uint _ratio) public onlyOwner {
        // Less than 30% and more than 5%
        require(_ratio <= 3000 && _ratio >= 500, "Invalid ratio");
        FloorPricePercentage = _ratio;
    }

    function changeAuctionFee(uint _fee) public onlyOwner {
        // between 0.5% and 4%
        require(_fee <= 400 && _fee >= 50, "Invalid fee");
        auctionFee = _fee;
    }
    function changePublicAuctionFee(uint _fee) public onlyOwner {
        // between 0% and 1%
        require(_fee <= 100 && _fee >= 0, "Invalid fee");
        publicAuctionFee = _fee;
    }

    function setAggregator(address _aggregator) public onlyOwner {
        require(aggregator == address(0), "Already set");
        aggregator = _aggregator;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function changeOwner(address owner) public {
        require(msg.sender == owner, "Only owner");
        require(deployedTime + 6 hours > block.timestamp, "6 hours passed");//@audit-ok H01 cannot change owner after 6 hours. Is this intended?
        owner = owner;
    }//@audit-ok H anyone change Factory owner due to shadow variable.

    function emitAuctionDeleted(
        address _auctionAddress,
        address creator
    ) public onlyAuctions {
        emit auctionEnded(_auctionAddress, creator);
    }

    function emitAuctionEdited(
        address _auctionAddress,
        address creator
    ) public onlyAuctions {
        emit auctionEdited(_auctionAddress, creator);
    }

    // Events mints
}
