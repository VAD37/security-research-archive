// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./ITrading.sol";
import {CloseInfo} from "./ITradingClose.sol";
import "./ITradingChecker.sol";

struct PartnerInfo {
    string name;
    string url;
    address protocolAddress;
    address callbackReceiver;
    uint256 gasCost;
}

interface IHookManager {

    event UpdatePartnerName(address indexed protocolAddress, string name);
    event UpdatePartnerUrl(address indexed protocolAddress, string url);
    event UpdatePartnerCallbackReceiver(address indexed protocolAddress, address callbackReceiver);

    function addPartner(
        string calldata name, string calldata url, address protocolAddress, address callbackReceiver
    ) external;

    function updatePartnerName(address protocolAddress, string calldata name) external;

    function updatePartnerUrl(address protocolAddress, string calldata url) external;

    function updatePartnerCallbackReceiver(address protocolAddress, address callbackReceiver) external;

    function getPartnerByAddress(address protocolAddress) external view returns (uint256 blockNumber, PartnerInfo memory);

    function partners(uint start, uint8 length) external view returns (uint256 blockNumber, PartnerInfo[] memory);

    function afterMarketExecuted(bytes32 tradeHash, ITrading.OpenTrade memory ot) external;

    function afterMarketRefund(bytes32 tradeHash, address user, ITradingChecker.Refund refund) external;

    function afterClose(bytes32 tradeHash, address user, CloseInfo memory info) external;
}
