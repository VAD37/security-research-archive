// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

import "forge-std/Test.sol";
import "src/WildcatArchController.sol";
import "src/WildcatMarketControllerFactory.sol";
import { MinimumDelinquencyGracePeriod, MaximumDelinquencyGracePeriod, MinimumReserveRatioBips, MaximumReserveRatioBips, MinimumDelinquencyFeeBips, MaximumDelinquencyFeeBips, MinimumWithdrawalBatchDuration, MaximumWithdrawalBatchDuration, MinimumAnnualInterestBips, MaximumAnnualInterestBips } from "./shared/TestConstants.sol";

contract WildcatMarketControllerFactoryTest is Test {
	WildcatArchController internal archController;
	WildcatMarketControllerFactory internal controllerFactory;
	MarketParameterConstraints internal constraints;

	function setUp() external {
		archController = new WildcatArchController();
		_resetConstraints();
		controllerFactory = new WildcatMarketControllerFactory(address(archController), address(0), constraints);
		archController.registerControllerFactory(address(controllerFactory));
		archController.registerBorrower(address(this));
	}

	function _resetConstraints() internal {
		constraints = MarketParameterConstraints({
			minimumDelinquencyGracePeriod: MinimumDelinquencyGracePeriod,
			maximumDelinquencyGracePeriod: MaximumDelinquencyGracePeriod,
			minimumReserveRatioBips: MinimumReserveRatioBips,
			maximumReserveRatioBips: MaximumReserveRatioBips,
			minimumDelinquencyFeeBips: MinimumDelinquencyFeeBips,
			maximumDelinquencyFeeBips: MaximumDelinquencyFeeBips,
			minimumWithdrawalBatchDuration: MinimumWithdrawalBatchDuration,
			maximumWithdrawalBatchDuration: MaximumWithdrawalBatchDuration,
			minimumAnnualInterestBips: MinimumAnnualInterestBips,
			maximumAnnualInterestBips: MaximumAnnualInterestBips
		});
	}

	function getMarketControllerParameters()
		external
		view
		virtual
		returns (MarketControllerParameters memory parameters)
	{
		parameters.archController = address(archController);
		parameters.borrower = address(this);
		parameters.sentinel = address(0);
		parameters.marketInitCodeStorage = controllerFactory.marketInitCodeStorage();
		parameters.marketInitCodeHash = controllerFactory.marketInitCodeHash();
		parameters.minimumDelinquencyGracePeriod = MinimumDelinquencyGracePeriod;
		parameters.maximumDelinquencyGracePeriod = MaximumDelinquencyGracePeriod;
		parameters.minimumReserveRatioBips = MinimumReserveRatioBips;
		parameters.maximumReserveRatioBips = MaximumReserveRatioBips;
		parameters.minimumDelinquencyFeeBips = MinimumDelinquencyFeeBips;
		parameters.maximumDelinquencyFeeBips = MaximumDelinquencyFeeBips;
		parameters.minimumWithdrawalBatchDuration = MinimumWithdrawalBatchDuration;
		parameters.maximumWithdrawalBatchDuration = MaximumWithdrawalBatchDuration;
		parameters.minimumAnnualInterestBips = MinimumAnnualInterestBips;
		parameters.maximumAnnualInterestBips = MaximumAnnualInterestBips;
	}

	function test_comparisionPrefixNotEmpty() public {
		assertNotEq(controllerFactory.ownCreate2Prefix(), 0);
	}

	// function test_comparisionDeployController() public {
	// 	// compare between openzeppelin Create2 address vs LibInitCode
	// 	address supposeController = LibStoredInitCode.calculateCreate2Address(
	// 		controllerFactory.ownCreate2Prefix(),
	// 		bytes32(uint256(uint160(address(this)))),
	// 		controllerFactory.controllerInitCodeHash()
	// 	);
	// 	address controller = controllerFactory.deployController();
	// 	console.log("create2 controller:", controller);
	// 	assertEq(controller, supposeController);
	// 	// make sure code at controller is the same as manually deploy through new WildcatMarketController()
	// 	WildcatMarketController _controller = new WildcatMarketController();
	// 	console.log("code length controller:", controller.code.length);
	// 	console.log("code length _controller:", address(_controller).code.length);

	// 	// print out code
	// 	console.log("create2 controller code:");
	// 	console.logBytes32(controller.codehash);
	// 	console.log("new WildcatMarketController code:");
	// 	console.logBytes32(address(_controller).codehash);
	// 	console.log("create2 controller code:");
	// 	console.logBytes(controller.code);
	// 	console.log("new WildcatMarketController code:");
	// 	console.logBytes(address(_controller).code);

	// 	assertEq(controller.codehash, address(_controller).codehash);
	// 	assertEq(controller.code.length, address(_controller).code.length);
	// }

	function test_MarketFactoryControllerPostInitParameters() external {
		// MarketControllerParameters memory parameters = controllerFactory.getMarketControllerParameters();
		// WildcatMarketController marketController =  WildcatMarketController( controllerFactory.controllerInitCodeStorage());
		WildcatMarketController marketController = WildcatMarketController(controllerFactory.deployController());
		console.log("controller address", address(marketController));
		console.logBytes32(address(marketController).codehash);
		console.log("codelength:", address(marketController).code.length);
		console.log("borrower", marketController.borrower());
		console.log("sentinel", marketController.sentinel());
		console.log("archController", address(marketController.archController()));
		console.log("controllerFactory", address(marketController.controllerFactory()));
		console.log("marketInitCodeStorage", marketController.marketInitCodeStorage());
		console.log("marketInitCodeHash", marketController.marketInitCodeHash());

		MarketParameterConstraints memory parameters = marketController.getParameterConstraints();
		console.log("get parameters");

		assertEq(
			parameters.minimumDelinquencyGracePeriod,
			MinimumDelinquencyGracePeriod,
			"minimumDelinquencyGracePeriod"
		);
		assertEq(
			parameters.maximumDelinquencyGracePeriod,
			MaximumDelinquencyGracePeriod,
			"maximumDelinquencyGracePeriod"
		);
		assertEq(parameters.minimumReserveRatioBips, MinimumReserveRatioBips, "minimumReserveRatioBips");
		assertEq(parameters.maximumReserveRatioBips, MaximumReserveRatioBips, "maximumReserveRatioBips");
		assertEq(parameters.minimumDelinquencyFeeBips, MinimumDelinquencyFeeBips, "minimumDelinquencyFeeBips");
		assertEq(parameters.maximumDelinquencyFeeBips, MaximumDelinquencyFeeBips, "maximumDelinquencyFeeBips");
		assertEq(
			parameters.minimumWithdrawalBatchDuration,
			MinimumWithdrawalBatchDuration,
			"minimumWithdrawalBatchDuration"
		);
		assertEq(
			parameters.maximumWithdrawalBatchDuration,
			MaximumWithdrawalBatchDuration,
			"maximumWithdrawalBatchDuration"
		);
		assertEq(parameters.minimumAnnualInterestBips, MinimumAnnualInterestBips, "minimumAnnualInterestBips");
		assertEq(parameters.maximumAnnualInterestBips, MaximumAnnualInterestBips, "maximumAnnualInterestBips");
	}

	function test_getMarketControllerParameters2() external {
		address _controller = controllerFactory.deployController();
		MarketParameterConstraints memory parameters = WildcatMarketController(_controller).getParameterConstraints();
		console.log("minimumDelinquencyGracePeriod:", parameters.minimumDelinquencyGracePeriod);
		console.log("maximumDelinquencyGracePeriod:", parameters.maximumDelinquencyGracePeriod);
		console.log("minimumReserveRatioBips:", parameters.minimumReserveRatioBips);
		console.log("maximumReserveRatioBips:", parameters.maximumReserveRatioBips);
		console.log("minimumDelinquencyFeeBips:", parameters.minimumDelinquencyFeeBips);
		console.log("maximumDelinquencyFeeBips:", parameters.maximumDelinquencyFeeBips);
		assertEq(
			parameters.minimumDelinquencyGracePeriod,
			MinimumDelinquencyGracePeriod,
			"minimumDelinquencyGracePeriod"
		);
		assertEq(
			parameters.maximumDelinquencyGracePeriod,
			MaximumDelinquencyGracePeriod,
			"maximumDelinquencyGracePeriod"
		);
		assertEq(parameters.minimumReserveRatioBips, MinimumReserveRatioBips, "minimumReserveRatioBips");
		assertEq(parameters.maximumReserveRatioBips, MaximumReserveRatioBips, "maximumReserveRatioBips");
		assertEq(parameters.minimumDelinquencyFeeBips, MinimumDelinquencyFeeBips, "minimumDelinquencyFeeBips");
		assertEq(parameters.maximumDelinquencyFeeBips, MaximumDelinquencyFeeBips, "maximumDelinquencyFeeBips");
		assertEq(
			parameters.minimumWithdrawalBatchDuration,
			MinimumWithdrawalBatchDuration,
			"minimumWithdrawalBatchDuration"
		);
		assertEq(
			parameters.maximumWithdrawalBatchDuration,
			MaximumWithdrawalBatchDuration,
			"maximumWithdrawalBatchDuration"
		);
		assertEq(parameters.minimumAnnualInterestBips, MinimumAnnualInterestBips, "minimumAnnualInterestBips");
		assertEq(parameters.maximumAnnualInterestBips, MaximumAnnualInterestBips, "maximumAnnualInterestBips");
	}
}
