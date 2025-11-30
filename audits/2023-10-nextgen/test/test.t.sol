// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../smart-contracts/ERC721Enumerable.sol";

contract NFTEnum is ERC721Enumerable {
    constructor() ERC721("NFTEnum", "NFTEnum") {}

    function mint() public returns (uint256) {
        uint index = totalSupply();
        _mint(msg.sender, index);
        return index;
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function burnTwice(uint256 tokenId) public {
        _burn(tokenId);
        _burn(tokenId);
    }
}

// 🚀 TEST
contract TestFoundry is Test {
    NFTEnum nft;

    function setUp() public {
        nft = new NFTEnum();
    }

    // function testDoubleBurn() public {
    //     uint token1 = _mintTokenForUser(address(0x1));
    //     uint token2 = _mintTokenForUser(address(0x2));
    //     uint token3 = _mintTokenForUser(address(0x3));
    //     console.log("token1 owner: %s ", nft.ownerOf(token1));
    //     console.log("token1 balance: %s ", nft.balanceOf(address(0x1)));
    //     console.log("token2 owner: %s ", nft.ownerOf(token2));
    //     console.log("token2 balance: %s ", nft.balanceOf(address(0x2)));
    //     console.log("token3 owner: %s ", nft.ownerOf(token3));
    //     console.log("token3 balance: %s ", nft.balanceOf(address(0x3)));

    //     console.log("burning token` twice");
    //     nft.burnTwice(1);

    //     console.log("token1 owner: %s ", nft.ownerOf(token1));
    //     console.log("token1 balance: %s ", nft.balanceOf(address(0x1)));
    //     console.log("token2 owner: %s ", nft.ownerOf(token2));
    //     console.log("token2 balance: %s ", nft.balanceOf(address(0x2)));
    //     console.log("token3 owner: %s ", nft.ownerOf(token3));
    //     console.log("token3 balance: %s ", nft.balanceOf(address(0x3)));
    // }

    function _mintTokenForUser(address _user) internal returns (uint256) {
        vm.prank(_user);
        return nft.mint();
    }
}
