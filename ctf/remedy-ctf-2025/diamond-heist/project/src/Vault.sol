// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./openzeppelin-contracts/interfaces/IERC20.sol";
import "./openzeppelin-contracts/interfaces/IERC3156FlashBorrower.sol";
import "./openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Diamond.sol";
import "./Burner.sol";
import "./HexensCoin.sol";
import {Test, console} from "forge-std/Test.sol";

contract Vault is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public constant AUTHORITY_THRESHOLD = 100_000 ether;

    Diamond diamond;
    HexensCoin hexensCoin;

    function initialize(address diamond_, address hexensCoin_) public initializer {
        __Ownable_init(); //owner to msg.sender which is Challenge.sol
        diamond = Diamond(diamond_);
        hexensCoin = HexensCoin(hexensCoin_);
    }

    function governanceCall(bytes calldata data) external {
        require(msg.sender == owner() || hexensCoin.getCurrentVotes(msg.sender) >= AUTHORITY_THRESHOLD); //we only get 10_000 ether
        (bool success,) = address(this).call(data);
        require(success);
    }

    function burn(address token, uint256 amount) external {
        require(msg.sender == owner() || msg.sender == address(this));
        Burner burner = new Burner();
        IERC20(token).transfer(address(burner), amount);
        burner.destruct();
        console.log("burned %e", amount,address(burner));
    }

    function _authorizeUpgrade(address) internal view override {
        require(msg.sender == owner() || msg.sender == address(this)); //governanceCall
        require(IERC20(diamond).balanceOf(address(this)) == 0, "diamond balance must be 0");
    }
}
