pragma solidity ^0.8.0;

import "./flatten_ERC20.sol";
contract ERC20MultiVotesTest {

    MockERC20MultiVotes token;
    address constant delegate1 = address(0xDEAD);
    address constant delegate2 = address(0xBEEF);
    address constant delegate3 = address(0xA22FF);

    constructor() {
        token = new MockERC20MultiVotes(address(this));
    }
    //Need to test 2 new changes undelegate and _decrementVotesUntilFree
    // test that undelegate transfer randomly does not inflate vote count.
    // but how to test that user got their correct vote count?
}