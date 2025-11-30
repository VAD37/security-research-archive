// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface ERC20Like {
    function balanceOf(address) external view returns (uint);
}

contract Setup {
    // This is contract created through GSNMultisigFactory.
    // Proxy is created along with init data  https://etherscan.io/address/0x16154f7e9de01e6b39dac3159805e9b1531ee3cf#code#L269
    ERC20Like public immutable DREAMERS = ERC20Like(0x1C4d5CA50419f94fc952a20DdDCDC4182Ef77cdF);

    function isSolved() external view returns (bool) {
        return DREAMERS.balanceOf(address(this)) > 16 ether;
    }
}
// constructor(address _logic, address _admin, bytes memory _data)
// 00000000000000000000000058ccd381c5162c6d40f40de03d5d2eb779f87bb6 // logic
// 00000000000000000000000098123654f8805ff2db5cd93a5517ff0dbda40f76 //admin
// 0000000000000000000000000000000000000000000000000000000000000060 // start index location
// 00000000000000000000000000000000000000000000000000000000000000c4 // bytes length 196
// 4cd88b76 //initialize(string,string) func selector
// 0000000000000000000000000000000000000000000000000000000000000040 //string 1 start index
// 0000000000000000000000000000000000000000000000000000000000000080 //string 2 start index
// 0000000000000000000000000000000000000000000000000000000000000014 //string 1 length ~ 20
// 43727970746f447265616d65727320546f6b656e000000000000000000000000 // string 1 "CryptoDreamers Token"
// 0000000000000000000000000000000000000000000000000000000000000005 // string 2 length ~5
// 4352445254000000000000000000000000000000000000000000000000000000 //string 2 "CRDRT"
// 00000000000000000000000000000000000000000000000000000000
