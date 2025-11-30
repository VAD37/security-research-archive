// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IPot} from "src/IPot.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVaultLib {
    function calcAssetAllocation(uint256 value) external view returns (uint256);
    function calcAssetForWithdrawals(uint256 value) external view returns (uint256);
    function verify(address user) external view;
}

contract ChallengeHard1 is ERC20, Ownable, ReentrancyGuard {
    IVaultLib public immutable vaultLib;

    bytes32 private constant _METADATA_HASH = 0xc7c0c772add21d1639bb77ae5849a656557b13b677f5a86173b67b5c45961338;
    bytes32 private _configBits;

    uint256 public constant FLOOR_LIMIT = 1e15;
    uint256 public constant SCALAR_UNIT = 1e18;

    uint256 public liquidityMetric;
    uint256 public conversionParam;
    bool public maintenanceState = false;

    uint256 public ingressTariff = 50;
    uint256 public egressTariff = 100;
    uint256 public constant BASIS_VALUE = 10000;

    bytes32 private _potSlot;

    mapping(address => uint256) public userLiquidityMetric;

    // Events with cryptic names
    event DataFlowIn(address indexed entity, uint256 deltaA, uint256 deltaB);
    event DataFlowOut(address indexed entity, uint256 deltaB, uint256 deltaA);
    event ParamUpdate(uint256 newConfig);

    constructor(string memory tokenName, string memory tokenSymbol, address _potAddress, address _vaultLib)
        ERC20(tokenName, tokenSymbol)
        Ownable(msg.sender)
    {
        _potSlot = bytes32(uint256(uint160(_potAddress)));

        conversionParam = SCALAR_UNIT - 1;

        _configBits = bytes32(
            (uint256(block.timestamp) << 192) | (uint256(block.number) << 128) | (uint256(BASIS_VALUE) << 64)
                | uint256(42)
        );

        vaultLib = IVaultLib(_vaultLib);
    }

    function getPotInstance() public view returns (IPot) {
        return IPot(address(uint160(uint256(_potSlot))));
    }

    function ingressLiquidity() external payable nonReentrant {
        require(!maintenanceState, "System maintenance in progress");
        require(msg.value >= FLOOR_LIMIT, "Insufficient transaction value");

        liquidityMetric += msg.value;
        userLiquidityMetric[msg.sender] += msg.value;

        uint256 assetAllocation = vaultLib.calcAssetAllocation(msg.value);

        _mint(msg.sender, assetAllocation);

        emit DataFlowIn(msg.sender, msg.value, assetAllocation);
    }

    function egressLiquidity(uint256 liquidityAmount) external nonReentrant {
        require(!maintenanceState, "System maintenance in progress");
        require(liquidityAmount > 0, "Non-positive retrieval amount");
        require(liquidityAmount <= address(this).balance, "Insufficient system capacity");

        uint256 assetRequirement = vaultLib.calcAssetForWithdrawals(liquidityAmount);
        require(balanceOf(msg.sender) >= assetRequirement, "Insufficient asset holdings");

        userLiquidityMetric[msg.sender] -= liquidityAmount;
        liquidityMetric -= liquidityAmount;
        _burn(msg.sender, assetRequirement);

        (bool txSuccess,) = msg.sender.call{value: liquidityAmount}("");
        require(txSuccess, "Transaction execution failed");

        emit DataFlowOut(msg.sender, assetRequirement, liquidityAmount);
    }

    function reconfigureConversionParameter(uint256 newValue) external onlyOwner {
        require(newValue > 0, "Invalid parameter configuration");
        conversionParam = newValue;
        emit ParamUpdate(newValue);
    }

    function toggleSystemState(bool newState) external onlyOwner {
        maintenanceState = newState;
    }

    function verifySystemCompletion() external returns (string memory) {
        try vaultLib.verify(msg.sender) {
            getPotInstance().addPoints(msg.sender);
        } catch (bytes memory reason) {
            // Decode the error reason
            if (reason.length >= 4) {
                // Check if it's a standard Error(string) message
                bytes4 selector;
                assembly {
                    selector := mload(add(reason, 0x20))
                }

                if (selector == 0x08c379a0) {
                    // Error(string) selector
                    // Decode the error message
                    assembly {
                        // Skip the selector and length to get to the string data
                        reason := add(reason, 0x04)
                    }
                    return abi.decode(reason, (string));
                }
            }

            // If not a standard error, return raw hex
            return string(reason);
        }
    }

    function getConversionParameter() external view returns (uint256) {
        return conversionParam;
    }

    function calculateRequiredAssets(uint256 liquidityValue) public view returns (uint256) {
        return (liquidityValue * conversionParam) / SCALAR_UNIT;
    }

    function calculateAvailableLiquidity(uint256 assetValue) public view returns (uint256) {
        return (assetValue * SCALAR_UNIT) / conversionParam;
    }

    function updateIngressTariff(uint256 newRate) external onlyOwner {
        require(newRate <= 500, "Excessive rate configuration");
        ingressTariff = newRate;
    }

    function updateEgressTariff(uint256 newRate) external onlyOwner {
        require(newRate <= 500, "Excessive rate configuration");
        egressTariff = newRate;
    }

    function executeSecurityProtocol(uint256 amount) external onlyOwner {
        require(maintenanceState, "Security protocol inactive");
        require(amount <= address(this).balance, "Insufficient system resources");

        (bool txSuccess,) = msg.sender.call{value: amount}("");
        require(txSuccess, "Protocol execution failed");
    }

    function getSystemCapacity() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        assembly {
            mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
            mstore(4, 0x0000002000000000000000000000000000000000000000000000000000000000)
            mstore(36, 0x0000001a53797374656d2072656a6563746564207472616e73616374696f6e00)
            revert(0, 100)
        }
    }

    fallback() external payable {
        assembly {
            mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
            mstore(4, 0x0000002000000000000000000000000000000000000000000000000000000000)
            mstore(36, 0x0000001a53797374656d2072656a6563746564207472616e73616374696f6e00)
            revert(0, 100)
        }
    }

    function _calculateComplexMetrics(uint256 a, uint256 b) private pure returns (uint256) {
        return (a * b) / (a + b) + ((a ^ b) % 100);
    }

    function getSystemMetadata() external pure returns (bytes32) {
        return _METADATA_HASH;
    }
}
