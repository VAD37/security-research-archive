// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "script/utils/ConsoleFactory.s.sol";

import {GnosisSafeProxyFactory,GnosisSafeProxy} from "safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "safe-contracts/GnosisSafe.sol";
import "src/core/SafeDeployer.sol";

contract MockSafeDeployer is SafeDeployer {
    constructor(address provider) SafeDeployer(provider) {}

    function getSetupSubAccount(
        address[] memory _owners,
        uint256 _threshold,
        address _consoleAccount
    ) public view returns (bytes memory) {
        return _setupSubAccount(_owners, _threshold, _consoleAccount);
    }

    function genNonce(
        bytes32 _ownersHash,
        bytes32 _salt
    ) public returns (uint256) {
        return _genNonce(_ownersHash, _salt);
    }
}

contract GnosisTest is Test, ConsoleFactory("offchain/addressManager.ts") {
    address attacker = address(0xbeeeeeeeeef);
    address owner1 = makeAddr("owner1");
    MockSafeDeployer mockDeployer;

    function setUp() public {
        vm.createSelectFork(
            "https://eth-mainnet.alchemyapi.io/v2/kIP2_euA9T6Z-e5MjHzTzRUmgqCLsHUA",
            18311111
        );
        ConstantSetup.setUpConstants();
        ConsoleFactory.deployConsole(address(this), false);
        mockDeployer = new MockSafeDeployer(address(addressProvider));
    }

    function testSaltCreate2() public {
        vm.startPrank(attacker);
        console.log("manual create subaccount");

        address[] memory owners = new address[](1);
        owners[0] = attacker;
        bytes memory initializer = mockDeployer.getSetupSubAccount(
            owners,
            1,
            address(this)
        );
        bytes32 ownersHash = keccak256(abi.encode(owners));
        uint nonce = mockDeployer.genNonce(ownersHash, bytes32(0));
        // manually create subaccount proxy. This include initializer
        GnosisSafeProxy _proxy = GnosisSafeProxyFactory(proxyDeployer).createProxyWithNonce(
            singleton,
            initializer,
            nonce
        );
        //@ this proxy subaccount still must have a guard SafeModerator, a module which is ConsoleAccount
        GnosisSafe safe = GnosisSafe(payable(_proxy));
        console.log("created safe",address(_proxy));
        console.log("subaccount owner0:",safe.getOwners()[0]);

    }
}
