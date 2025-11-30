import "@clones-with-immutable-args/src/Clone.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SplitWallet is Clone {
    function deposit() external payable {}

    function pullToken(IERC20 token, uint256 amount) external {
        require(msg.sender == _getArgAddress(0));//@msg.sender is Split.sol

        if (address(token) == address(0x00)) {
            payable(msg.sender).transfer(amount);
        } else {
            token.transfer(msg.sender, amount);//@no token address check. this can be split too
        }//@audit the goal is steal all ETH and wallet balance too
    }

    function balanceOf(IERC20 token) external view returns (uint256) {
        if (address(token) == address(0x00)) {
            return address(this).balance;
        }

        return token.balanceOf(address(this));
    }
}
