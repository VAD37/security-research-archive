pragma solidity ^0.8.4;

interface IPermitToReenter {
    struct Sig {
        uint256 _index;
        bytes32 hashed;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function pot() external view returns (address);

    function amounts(address owner) external view returns (uint256);

    function solve() external;

    function withdraw() external payable;

    function deposit() external payable;

    function multisig(Sig[] calldata _sigs) external;
}
