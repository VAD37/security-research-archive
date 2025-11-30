pragma solidity >=0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "solady/utils/FixedPointMathLib.sol";
import "solady/utils/LibString.sol";

contract LogTest is Test {
    using FixedPointMathLib for int256;

    function doLog(uint256 n, bool isLast) internal pure returns (string memory output) {
        output =
            string.concat('{"n": ', LibString.toString(n), 'n, "result": ', LibString.toString(int256(n).lnWad()), "n}");
        if (isLast) {
            output = string.concat(output, ",");
        }
    }

    function testLog() external {
        string memory output = "\n[\n";
        for (uint256 i = 10; i < 100; i += 15) {
            uint256 n = (i * 1e18) / 100;
            output = string.concat(output, doLog(n, false), "\n");
        }
        for (uint256 i = 0; i <= 100; i += 20) {
            uint256 n = (i ** 3) + 1;
            n *= 1e18;
            output = string.concat(output, doLog(n, i == 100), "\n");
        }
        output = string.concat(output, "]\n");
        console2.log(output);
    }

    function normal(address[] calldata target1) external {
        emit log_named_bytes("call normal:", msg.data);
        
    }

    function test_debug() external {
      address[] memory target1 = new address[](6);
      target1[0] = address(0x123456);
      target1[1] = address(0x2);
      target1[2] = address(0x3);
      target1[3] = address(0x4);
        _callWith(address(this), abi.encodeWithSelector(LogTest.normal.selector, target1));
    }

    function _callWith(address target, bytes memory data) internal {
        assembly {
            if iszero(call(gas(), target, 0, add(data, 0x20), mload(data), 0, 0)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
