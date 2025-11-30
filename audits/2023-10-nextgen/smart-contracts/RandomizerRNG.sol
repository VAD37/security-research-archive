// SPDX-License-Identifier: MIT

/**
 *
 *  @title: NextGen Randomizer Contract RNG
 *  @date: 18-October-2023
 *  @version: 1.7
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;

import "./ArrngConsumer.sol";
import "./Ownable.sol";
import "./INextGenCore.sol";
import "./INextGenAdmins.sol";
//The RandomizerRNG contract is responsible for generating a random hash for each token during the minting process using the ARRng.io service.
contract NextGenRandomizerRNG is ArrngConsumer, Ownable {

    mapping(uint256 => uint256) public requestToToken;
    address gencore;
    INextGenCore public gencoreContract;
    INextGenAdmins private adminsContract;
    event Withdraw(address indexed _add, bool status, uint256 indexed funds);
    uint256 ethRequired;
    mapping(uint256 => uint256) public tokenToRequest;
    mapping(uint256 => uint256) public tokenIdToCollection;

    constructor(address _gencore, address _adminsContract, address _arRNG) ArrngConsumer(_arRNG) {
        gencore = _gencore;
        gencoreContract = INextGenCore(_gencore);
        adminsContract = INextGenAdmins(_adminsContract);
    }

    modifier FunctionAdminRequired(bytes4 _selector) {
        require(adminsContract.retrieveFunctionAdmin(msg.sender, _selector) == true || adminsContract.retrieveGlobalAdmin(msg.sender) == true, "Not allowed");
        _;
    }

    function requestRandomWords(uint256 tokenid, uint256 _ethRequired) public payable {//@0.001eth
        require(msg.sender == gencore);
        uint256 requestId = arrngController.requestRandomWords{value: _ethRequired}(1, (address(this)));
        tokenToRequest[tokenid] = requestId;
        requestToToken[requestId] = tokenid;//@note RNG use tx.origin to refund gas. so it use address(this) to refund gas to this contract

    }
    //@call from receiveRandomness()
    function fulfillRandomWords(uint256 id, uint256[] memory numbers) internal override {
        gencoreContract.setTokenHash(tokenIdToCollection[requestToToken[id]], requestToToken[id], bytes32(abi.encodePacked(numbers,requestToToken[id])));
    }

    // function that calculates the random hash and returns it to the gencore contract
    function calculateTokenHash(uint256 _collectionID, uint256 _mintIndex, uint256 _saltfun_o) public {
        require(msg.sender == gencore);//@audit-ok use this contract ETH .RNG missing payable. how do you pay for RNG service without ETH
        tokenIdToCollection[_mintIndex] = _collectionID;//@audit-ok collection cannot be duplicate .H cache  key: tokenID, value: collectionID is inversed causing duplicate collection to override each other.
        requestRandomWords(_mintIndex, ethRequired);
    }

    // function to update contracts

    function updateAdminContract(address _newadminsContract) public FunctionAdminRequired(this.updateAdminContract.selector) {
        require(INextGenAdmins(_newadminsContract).isAdminContract() == true, "Contract is not Admin");
        adminsContract = INextGenAdmins(_newadminsContract);
    }

    function updateCoreContract(address _gencore) public FunctionAdminRequired(this.updateCoreContract.selector) { 
        gencore = _gencore;
        gencoreContract = INextGenCore(_gencore);
    }

    // function to update cost

    function updateRNGCost(uint256 _ethRequired) public FunctionAdminRequired(this.updateRNGCost.selector) {
        ethRequired = _ethRequired;
    }

    // function to withdraw any balance from the smart contract

    function emergencyWithdraw() public FunctionAdminRequired(this.emergencyWithdraw.selector) {
        uint balance = address(this).balance;
        address admin = adminsContract.owner();
        (bool success, ) = payable(admin).call{value: balance}("");
        emit Withdraw(msg.sender, success, balance);
    }

    receive() external payable {}

    // get randomizer contract status
    function isRandomizerContract() external view returns (bool) {
        return true;
    }
}
