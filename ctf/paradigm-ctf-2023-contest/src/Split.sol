import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@clones-with-immutable-args/src/ClonesWithImmutableArgs.sol";
import {console} from "forge-std/Test.sol";
import "./SplitWallet.sol";

contract Split is ERC721("Split", "SPLIT") {
    using ClonesWithImmutableArgs for address;

    struct SplitData {
        bytes32 hash;
        SplitWallet wallet;
    }

    SplitWallet private immutable IMPLEMENTATION = new SplitWallet();
    uint256 private immutable SCALE = 1e6;

    uint256 public nextId;

    mapping(uint256 => SplitData) private _splitsById;

    mapping(address => mapping(address => uint256)) public balances;

    modifier onlySplitOwner(uint256 splitId) {
        _onlySplitOwner(splitId);
        _;
    }

    function _onlySplitOwner(uint256 splitId) private view {
        require(msg.sender == ownerOf(splitId), "NOT_SPLIT_OWNER");
    }

    modifier validSplit(address[] memory accounts, uint32[] memory percents, uint32 relayerFee) {
        _validSplit(accounts, percents, relayerFee);
        _;
    }

    function _validSplit(address[] memory accounts, uint32[] memory percents, uint32 relayerFee) private pure {
        require(accounts.length == percents.length, "MISMATCH_LENGTH");

        uint256 sum;
        for (uint256 i = 0; i < accounts.length; i++) {
            sum += percents[i];
        }

        require(sum == SCALE, "INVALID_PERCENTAGES");//1e6 == 1000000

        require(relayerFee < SCALE / 10, "INVALID_RELAYER_FEE");//<10000  <10%
    }

    function createSplit(address[] memory accounts, uint32[] memory percents, uint32 relayerFee)//@ [dead beed], 5e5
        external
        returns (uint256)
    {
        return _createSplit(accounts, percents, relayerFee, msg.sender);
    }

    function createSplitFor(address[] memory accounts, uint32[] memory percents, uint32 relayerFee, address owner)
        external//@audit can create wallet for someone else. and transfer that wallet away?
        returns (uint256)
    {
        return _createSplit(accounts, percents, relayerFee, owner);
    }

    function _createSplit(address[] memory accounts, uint32[] memory percents, uint32 relayerFee, address owner)
        private
        validSplit(accounts, percents, relayerFee)
        returns (uint256)
    {
        uint256 tokenId = nextId++;

        address wallet = address(IMPLEMENTATION).clone(abi.encodePacked(address(this)));//@create address
        //@ first ID is 0
        _splitsById[tokenId] =
            SplitData({hash: _hashSplit(accounts, percents, relayerFee), wallet: SplitWallet(payable(wallet))});

        _mint(owner, tokenId);

        return tokenId;
    }

    function updateSplit(uint256 splitId, address[] memory accounts, uint32[] memory percents, uint32 relayerFee)
        external
    {
        _updateSplit(splitId, accounts, percents, relayerFee);
    }

    function updateSplitAndDistribute(
        uint256 splitId,
        address[] memory accounts,
        uint32[] memory percents,
        uint32 relayerFee,
        IERC20 token
    ) external {
        _updateSplit(splitId, accounts, percents, relayerFee);
        _distribute(splitId, accounts, percents, relayerFee, token);
    }

    function distribute(
        uint256 splitId,
        address[] memory accounts,
        uint32[] memory percents,
        uint32 relayerFee,
        IERC20 token
    ) external {
        _distribute(splitId, accounts, percents, relayerFee, token);
    }

    function withdraw(IERC20[] calldata tokens, uint256[] calldata amounts) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];

            balances[msg.sender][address(token)] -= amount;

            if (address(token) == address(0x00)) {
                payable(msg.sender).transfer(amount);
            } else {
                token.transfer(msg.sender, amount);
            }
        }
    }

    function _updateSplit(uint256 splitId, address[] memory accounts, uint32[] memory percents, uint32 relayerFee)
        private
        onlySplitOwner(splitId)
        validSplit(accounts, percents, relayerFee)
    {
        _splitsById[splitId].hash = _hashSplit(accounts, percents, relayerFee);
    }

    function _distribute(
        uint256 splitId,//@user
        address[] memory accounts, //@user [2]
        uint32[] memory percents, //@user [2] 50%-50%
        uint32 relayerFee,//@user
        IERC20 token//@user
    ) private {
        require(_splitsById[splitId].hash == _hashSplit(accounts, percents, relayerFee));//can keccak return 0?
        SplitWallet wallet = _splitsById[splitId].wallet;
        uint256 storedWalletBalance = balances[address(wallet)][address(token)];
        uint256 externalWalletBalance = wallet.balanceOf(token);
        console.log("storedWalletBalance: %e", storedWalletBalance);
        console.log("externalWalletBalance: %e", externalWalletBalance);
        uint256 totalBalance = storedWalletBalance + externalWalletBalance;

        if (msg.sender != ownerOf(splitId)) {
            uint256 relayerAmount = totalBalance * relayerFee / SCALE;
            balances[msg.sender][address(token)] += relayerAmount;
            console.log("relayerAmount: %e", relayerAmount);
            totalBalance -= relayerAmount;
        }

        for (uint256 i = 0; i < accounts.length; i++) {//@audit can give token to other wallet
            balances[accounts[i]][address(token)] += totalBalance * percents[i] / SCALE;
            console.log("give balance to: %s", accounts[i]);
            console.log("give balance: %e", totalBalance * percents[i] / SCALE);
        }

        if (storedWalletBalance > 0) {
            console.log("reset wallet %s balance", address(wallet));
            balances[address(wallet)][address(token)] = 0;
        }

        if (externalWalletBalance > 0) {
            console.log("pull %e ", externalWalletBalance);
            wallet.pullToken(token, externalWalletBalance);//@ we can pull 100 ETH from wallet. it distribute stuff
            console.log("wallet leftover: %e", wallet.balanceOf(token));
        }
    }

    function _hashSplit(address[] memory accounts, uint32[] memory percents, uint32 relayerFee)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(accounts, percents, relayerFee));//@length here not encoded.
    }

    function splitsById(uint256 id) external view returns (SplitData memory) {
        return _splitsById[id];
    }

    receive() external payable {}
}
