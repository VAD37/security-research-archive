pragma solidity ^0.7.0;

contract OFAC{
    address immutable OFAC;

    mapping(address=>bool) public whitelist;

    modifier onlyOFAC(){
        require(msg.sender == OFAC, "only regulator can call this");
        _;
    }
    constructor(address _ofac){
        OFAC = _ofac;

        whitelist[msg.sender] = true;
    }

    function sanction(address target) onlyOFAC public {
        delete whitelist[target];
    }

    function unsanction(address target) onlyOFAC public {
        whitelist[target] = true;
    }
}