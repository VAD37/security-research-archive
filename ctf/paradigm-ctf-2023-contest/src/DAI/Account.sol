import "@clones-with-immutable-args/src/Clone.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./SystemConfiguration.sol";
import "./AccountManager.sol";

contract Account is Clone {
    event DebtIncreased(uint256 amount, string memo);
    event DebtDecreased(uint256 amount, string memo);
    event log_named_bytes        (string key, bytes val);
    uint256 public debt;
    //@constructor immutable: address config, address owner, uint arraylength, address[] array
    function deposit() external payable {
        emit log_named_bytes("deposit", msg.data);
    }

    function withdraw(uint256 amount) external {
        emit log_named_bytes("withdraw", msg.data);
        emit log_named_bytes("amount", abi.encodePacked(amount));
        emit log_named_bytes("00:", abi.encodePacked(_getArgAddress(0)));
        emit log_named_bytes("20:", abi.encodePacked(_getArgAddress(20)));
        emit log_named_bytes("40:", abi.encodePacked(_getArgUint256(40)));
        emit log_named_bytes("60:", abi.encodePacked(_getArgUint256(60)));
        emit log_named_bytes("80:", abi.encodePacked(_getArgUint256(80)));
        require(msg.sender == _getArgAddress(20), "ONLY_ACCOUNT_HOLDER");

        require(isHealthy(amount, 0), "NOT_HEALTHY");

        (bool ok,) = payable(msg.sender).call{value: amount}(hex"");
        require(ok, "TRANSFER_FAILED");
    }

    //@only called from AccountManager
    function increaseDebt(address operator, uint256 amount, string calldata memo) external {
        // emit log_named_bytes("increaseDebt", msg.data);
        emit log_named_bytes("offset", abi.encodePacked(_getImmutableArgsOffset()));    
        emit log_named_bytes("operator", abi.encodePacked(operator));
        emit log_named_bytes("amount", abi.encodePacked(amount));
        emit log_named_bytes("memo", abi.encodePacked(memo));
        emit log_named_bytes("00:", abi.encodePacked(_getArgAddress(0)));
        emit log_named_bytes("20:", abi.encodePacked(_getArgAddress(20)));
        emit log_named_bytes("40:", abi.encodePacked(_getArgUint256(40)));
        emit log_named_bytes("60:", abi.encodePacked(_getArgUint256(60)));
        emit log_named_bytes("80:", abi.encodePacked(_getArgUint256(80)));
        SystemConfiguration configuration = SystemConfiguration(_getArgAddress(0));
        require(configuration.isAuthorized(msg.sender), "NOT_AUTHORIZED");

        require(operator == _getArgAddress(20), "ONLY_ACCOUNT_HOLDER");//@only account creator and msg.sender call mintStable

        require(isHealthy(0, amount), "NOT_HEALTHY");

        debt += amount;

        emit DebtIncreased(amount, memo);
    }
    
    //@only called from AccountManager
    function decreaseDebt(uint256 amount, string calldata memo) external {
        emit log_named_bytes("decreaseDebt", msg.data);
        SystemConfiguration configuration = SystemConfiguration(_getArgAddress(0));
        require(configuration.isAuthorized(msg.sender), "NOT_AUTHORIZED");

        debt -= amount;//@debt no healthy check. collateral still there

        emit DebtDecreased(amount, memo);
    }

    function isHealthy(uint256 burnETH, uint256 mintDAI) public view returns (bool) {
        SystemConfiguration configuration = SystemConfiguration(_getArgAddress(0));

        uint256 totalBalance = address(this).balance - burnETH;
        uint256 totalDebt = debt + mintDAI;

        (, int256 ethPriceInt,,,) = AggregatorV3Interface(configuration.getEthUsdPriceFeed()).latestRoundData();
        if (ethPriceInt <= 0) return false;//@1787.55855000

        uint256 ethPrice = uint256(ethPriceInt);//@ 1 ETH == max debt 1200$
        //collateral * 1800 >= debt * 1.5
        return totalBalance * ethPrice / 1e8 >= totalDebt * configuration.getCollateralRatio() / 10000;
    }

    function recoverAccount(address newOwner, address[] memory newRecoveryAccounts, bytes[] memory signatures)
        external
        returns (Account)
    {
        require(isHealthy(0, 0), "UNHEALTHY_ACCOUNT");//@audit ignore debt on migration

        bytes32 signHash = keccak256(abi.encodePacked(block.chainid, _getArgAddress(20), newOwner, newRecoveryAccounts));

        uint256 numRecoveryAccounts = _getArgUint256(40);
        require(signatures.length == numRecoveryAccounts, "INCORRECT_LENGTH");

        for (uint256 i = 0; i < numRecoveryAccounts; i++) {
            require(
                SignatureChecker.isValidSignatureNow(_getArgAddress(72 + 32 * i), signHash, signatures[i]),
                "INVALID_SIGNATURE"
            );
        }

        SystemConfiguration configuration = SystemConfiguration(_getArgAddress(0));

        uint256 currentDebt = debt;//@reset debt on recover? This seem like focus point
        debt = 0;

        return AccountManager(configuration.getAccountManager()).migrateAccount{value: address(this).balance}(
            newOwner, newRecoveryAccounts, currentDebt
        );
    }

    function debugViewOffset() external view returns (uint256) {
        return _getImmutableArgsOffset();
    }
    function debugViewSystem() external view returns (address) {
        return _getArgAddress(0);
    }
}
