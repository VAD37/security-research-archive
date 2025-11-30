// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import {ILpETH, IERC20} from "./interfaces/ILpETH.sol";
import {ILpETHVault} from "./interfaces/ILpETHVault.sol";
import {IWETH} from "./interfaces/IWETH.sol";

/**
 * @title   PrelaunchPoints
 * @author  Loop
 * @notice  Staking points contract for the prelaunch of Loop Protocol.
 */
contract PrelaunchPoints {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for ILpETH;
    address internal constant VM_ADDRESS = address(uint160(uint256(keccak256("hevm cheat code"))));
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    Vm internal constant vm = Vm(VM_ADDRESS);
    ILpETH public lpETH;
    ILpETHVault public lpETHVault;
    IWETH public immutable WETH;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable exchangeProxy;

    address public owner;

    uint256 public totalSupply;
    uint256 public totalLpETH;
    mapping(address => bool) public isTokenAllowed;

    enum Exchange {
        UniswapV3,
        TransformERC20
    }
//@uniswap iplm 0x0e992C001E375785846EEb9cd69411B53f30f24B
    bytes4 public constant UNI_SELECTOR = 0x803ba26d;//@ 	sellTokenForEthToUniswapV3(bytes,uint256,uint256,address)
    bytes4 public constant TRANSFORM_SELECTOR = 0x415565b0;//@ 	transformERC20(address,address,uint256,uint256,(uint32,bytes)[])
//@ transformERC20 0x44A6999Ec971cfCA458AFf25A808F272f6d492A2
    uint32 public loopActivation;//@fixed 120 days from  deployment
    uint32 public startClaimDate;//@ when owner convert all ETH to lpETH and lock all tokens
    uint32 public constant TIMELOCK = 7 days;
    bool public emergencyMode;

    mapping(address => mapping(address => uint256)) public balances; // User -> Token -> Balance

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Locked(address indexed user, uint256 amount, address token, bytes32 indexed referral);
    event StakedVault(address indexed user, uint256 amount);
    event Converted(uint256 amountETH, uint256 amountlpETH);
    event Withdrawn(address indexed user, address token, uint256 amount);
    event Claimed(address indexed user, address token, uint256 reward);
    event Recovered(address token, uint256 amount);
    event OwnerUpdated(address newOwner);
    event LoopAddressesUpdated(address loopAddress, address vaultAddress);
    event SwappedTokens(address sellToken, uint256 sellAmount, uint256 buyETHAmount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidToken();
    error NothingToClaim();
    error TokenNotAllowed();
    error CannotLockZero();
    error CannotWithdrawZero();
    error UseClaimInstead();
    error FailedToSendEther();
    error SwapCallFailed();
    error WrongSelector(bytes4 selector);
    error WrongDataTokens(address inputToken, address outputToken);
    error WrongDataAmount(uint256 inputTokenAmount);
    error WrongRecipient(address recipient);
    error WrongExchange();
    error LoopNotActivated();
    error NotValidToken();
    error NotAuthorized();
    error CurrentlyNotPossible();
    error NoLongerPossible();

    /*//////////////////////////////////////////////////////////////
                             INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    /**
     * @param _exchangeProxy address of the 0x protocol exchange proxy
     * @param _wethAddress   address of WETH
     * @param _allowedTokens list of token addresses to allow for locking
     */
    constructor(address _exchangeProxy, address _wethAddress, address[] memory _allowedTokens) {
        owner = msg.sender;
        exchangeProxy = _exchangeProxy;//0xDef1C0ded9bec7F1a1670819833240f027b25EfF
        WETH = IWETH(_wethAddress);

        loopActivation = uint32(block.timestamp + 120 days);
        startClaimDate = 4294967295; // Max uint32 ~ year 2107

        // Allow intital list of tokens
        uint256 length = _allowedTokens.length;
        for (uint256 i = 0; i < length;) {
            isTokenAllowed[_allowedTokens[i]] = true;
            unchecked {
                i++;
            }
        }
        isTokenAllowed[_wethAddress] = true;
    }

    /*//////////////////////////////////////////////////////////////
                            STAKE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Locks ETH
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lockETH(bytes32 _referral) external payable {
        _processLock(ETH, msg.value, msg.sender, _referral);
    }

    /**
     * @notice Locks ETH for a given address
     * @param _for       address for which ETH is locked
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lockETHFor(address _for, bytes32 _referral) external payable {
        _processLock(ETH, msg.value, _for, _referral);
    }

    /**
     * @notice Locks a valid token
     * @param _token     address of token to lock
     * @param _amount    amount of token to lock
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lock(address _token, uint256 _amount, bytes32 _referral) external {
        if (_token == ETH) {
            revert InvalidToken();
        }
        _processLock(_token, _amount, msg.sender, _referral);
    }

    /**
     * @notice Locks a valid token for a given address
     * @param _token     address of token to lock
     * @param _amount    amount of token to lock
     * @param _for       address for which ETH is locked
     * @param _referral  info of the referral. This value will be processed in the backend.
     */
    function lockFor(address _token, uint256 _amount, address _for, bytes32 _referral) external {
        if (_token == ETH) {
            revert InvalidToken();
        }
        _processLock(_token, _amount, _for, _referral);
    }

    /**
     * @dev Generic internal locking function that updates rewards based on
     *      previous balances, then update balances.
     * @param _token       Address of the token to lock
     * @param _amount      Units of ETH or token to add to the users balance
     * @param _receiver    Address of user who will receive the stake
     * @param _referral    Address of the referral user
     */
    function _processLock(address _token, uint256 _amount, address _receiver, bytes32 _referral)
        internal
        onlyBeforeDate(loopActivation)
    {
        if (_amount == 0) {
            revert CannotLockZero();
        }
        if (_token == ETH) {
            totalSupply = totalSupply + _amount;
            balances[_receiver][ETH] += _amount;
        } else {
            if (!isTokenAllowed[_token]) {
                revert TokenNotAllowed();
            }
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);//@audit L there is token reentrancy but token must be whitelisted so this is not possible.

            if (_token == address(WETH)) {
                WETH.withdraw(_amount);
                totalSupply = totalSupply + _amount;
                balances[_receiver][ETH] += _amount;
            } else {
                balances[_receiver][_token] += _amount;
            }
        }

        emit Locked(_receiver, _amount, _token, _referral);
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM AND WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Called by a user to get their vested lpETH
     * @param _token      Address of the token to convert to lpETH
     * @param _percentage Proportion in % of tokens to withdraw. NOT useful for ETH
     * @param _exchange   Exchange identifier where the swap takes place
     * @param _data       Swap data obtained from 0x API
     */
    function claim(address _token, uint8 _percentage, Exchange _exchange, bytes calldata _data)
        external
        onlyAfterDate(startClaimDate)
    {
        _claim(_token, msg.sender, _percentage, _exchange, _data);
    }

    /**
     * @dev Called by a user to get their vested lpETH and stake them in a
     *      Loop vault for extra rewards
     * @param _token      Address of the token to convert to lpETH
     * @param _percentage Proportion in % of tokens to withdraw. NOT useful for ETH
     * @param _exchange   Exchange identifier where the swap takes place
     * @param _data       Swap data obtained from 0x API
     */
    function claimAndStake(address _token, uint8 _percentage, Exchange _exchange, bytes calldata _data)
        external
        onlyAfterDate(startClaimDate)
    {
        uint256 claimedAmount = _claim(_token, address(this), _percentage, _exchange, _data);
        lpETH.approve(address(lpETHVault), claimedAmount);
        lpETHVault.stake(claimedAmount, msg.sender);

        emit StakedVault(msg.sender, claimedAmount);
    }

    /**
     * @dev Claim logic. If necessary converts token to ETH before depositing into lpETH contract.
     */
    function _claim(address _token, address _receiver, uint8 _percentage, Exchange _exchange, bytes calldata _data)
        internal
        returns (uint256 claimedAmount)
    {
        uint256 userStake = balances[msg.sender][_token];
        if (userStake == 0) {
            revert NothingToClaim();
        }
        if (_token == ETH) {//@totalLpETH might higher than totalSupply if someone deposit lpETH before admin call convertAllETH enable claimDate.
            claimedAmount = userStake.mulDiv(totalLpETH, totalSupply);//@totalSupply == totalLPETH. decimal might differ
            balances[msg.sender][_token] = 0;//@audit-ok mulDiv already round down during internal math M sending 1wei will prevent last person claim 100% of ETH. but can only call 99% then 99% again
            lpETH.safeTransfer(_receiver, claimedAmount);//@audit-ok M cannot self transfer  ERC20 by OpenZeppelin did accept this.if claimAndStake transfer to this contract.
        } else {//@LRT token
            uint256 userClaim = userStake * _percentage / 100;
            _validateData(_token, userClaim, _exchange, _data);
            balances[msg.sender][_token] = userStake - userClaim;//@note if user claim more than 100%. it will reverse when removed from balance later.
            //@note all swap data must have this contract as recipient. then this contract deposit all ETH into lpETH for user
            // At this point there should not be any ETH in the contract
            // Swap token to ETH
            _fillQuote(IERC20(_token), userClaim, _data);//@sell tokens to WETH then it get withdraw into ETH. all token transfer to this address as result of swap
        
            // Convert swapped ETH to lpETH (1 to 1 conversion)
            claimedAmount = address(this).balance;
            lpETH.deposit{value: claimedAmount}(_receiver);
        }
        emit Claimed(msg.sender, _token, claimedAmount);
    }

    /**
     * @dev Called by a staker to withdraw all their ETH or LRT
     * Note Can only be called after the loop address is set and before claiming lpETH,
     * i.e. for at least TIMELOCK. In emergency mode can be called at any time.
     * @param _token      Address of the token to withdraw
     */
    function withdraw(address _token) external {
        if (!emergencyMode) {
            if (block.timestamp <= loopActivation) {//@user can still withdrwa token if owner does not swap all ETH to lpETH. so they can still withdraw after 120 days
                revert CurrentlyNotPossible();
            }
            if (block.timestamp >= startClaimDate) {//@no user can withdraw if project activated
                revert NoLongerPossible();
            }
        }

        uint256 lockedAmount = balances[msg.sender][_token];
        balances[msg.sender][_token] = 0;

        if (lockedAmount == 0) {//@withdraw 0 WETH  as WETH balance always 0
            revert CannotWithdrawZero();
        }//@emergency mode after deployment.
        if (_token == ETH) {
            if (block.timestamp >= startClaimDate){//@ if emergency user must call claim for ETH to get their locked ETH now lpETH
                revert UseClaimInstead();
            }
            totalSupply = totalSupply - lockedAmount;//@audit-ok  cannot withdraw after claiming start .during emergency Mode after claiming. totalSupply can reduce this inturn increase claiming power of other user

            (bool sent,) = msg.sender.call{value: lockedAmount}("");

            if (!sent) {
                revert FailedToSendEther();
            }
        } else {//@ if emergency after claiming. user can still withdraw Token and
            IERC20(_token).safeTransfer(msg.sender, lockedAmount);
        }

        emit Withdrawn(msg.sender, _token, lockedAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Called by a owner to convert all the locked ETH to get lpETH
     */
    function convertAllETH() external onlyAuthorized onlyBeforeDate(startClaimDate) {
        if (block.timestamp - loopActivation <= TIMELOCK) {
            revert LoopNotActivated();
        }

        // deposits all the ETH to lpETH contract. Receives lpETH back
        uint256 totalBalance = address(this).balance;
        lpETH.deposit{value: totalBalance}(address(this));

        totalLpETH = lpETH.balanceOf(address(this));

        // Claims of lpETH can start immediately after conversion.
        startClaimDate = uint32(block.timestamp);//@note startClaimDate always 7 days  after  loopActivation

        emit Converted(totalBalance, totalLpETH);
    }

    /**
     * @notice Sets a new owner
     * @param _owner address of the new owner
     */
    function setOwner(address _owner) external onlyAuthorized {
        owner = _owner;

        emit OwnerUpdated(_owner);
    }

    /**
     * @notice Sets the lpETH contract address
     * @param _loopAddress address of the lpETH contract
     * @dev Can only be set once before 120 days have passed from deployment.
     *      After that users can only withdraw ETH.
     */
    function setLoopAddresses(address _loopAddress, address _vaultAddress)
        external
        onlyAuthorized
        onlyBeforeDate(loopActivation)
    {
        lpETH = ILpETH(_loopAddress);
        lpETHVault = ILpETHVault(_vaultAddress);
        loopActivation = uint32(block.timestamp);

        emit LoopAddressesUpdated(_loopAddress, _vaultAddress);
    }

    /**
     * @param _token address of a wrapped LRT token
     * @dev ONLY add wrapped LRT tokens. Contract not compatible with rebase tokens.
     */
    function allowToken(address _token) external onlyAuthorized {
        isTokenAllowed[_token] = true;
    }

    /**
     * @param _mode boolean to activate/deactivate the emergency mode
     * @dev On emergency mode all withdrawals are accepted at
     */
    function setEmergencyMode(bool _mode) external onlyAuthorized {
        emergencyMode = _mode;
    }

    /**
     * @dev Allows the owner to recover other ERC20s mistakingly sent to this contract
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAuthorized {
        if (tokenAddress == address(lpETH) || isTokenAllowed[tokenAddress]) {
            revert NotValidToken();
        }
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);

        emit Recovered(tokenAddress, tokenAmount);
    }

    /**
     * Enable receive ETH
     * @dev ETH sent to this contract directly will be locked forever.
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates the data sent from 0x API to match desired behaviour
     * @param _token     address of the token to sell
     * @param _amount    amount of token to sell
     * @param _exchange  exchange identifier where the swap takes place
     * @param _data      swap data from 0x API
     */
    function _validateData(address _token, uint256 _amount, Exchange _exchange, bytes calldata _data) internal view {
        address inputToken;//@LRT token //@ this can be faked for Uniswap
        address outputToken;//@ this can be faked for Uniswap
        uint256 inputTokenAmount;//@userClaim = userStake * _percentage / 100; //percentage is user input percentage > 100%
        address recipient;
        bytes4 selector;
        if (_exchange == Exchange.UniswapV3) {
            (inputToken, outputToken, inputTokenAmount, recipient, selector) = _decodeUniswapV3Data(_data);
            if (selector != UNI_SELECTOR) {//@note only accept swapTokenForETH. so last token must always be WETH
                revert WrongSelector(selector);
            }
            // UniswapV3Feature.sellTokenForEthToUniswapV3(encodedPath, sellAmount, minBuyAmount, recipient) requires `encodedPath` to be a Uniswap-encoded path, where the last token is WETH, and sends the NATIVE token to `recipient`
            if (outputToken != address(WETH)) {//@audit both input and output can be WETH token
                revert WrongDataTokens(inputToken, outputToken);
            }
        } else if (_exchange == Exchange.TransformERC20) {
            (inputToken, outputToken, inputTokenAmount, selector) = _decodeTransformERC20Data(_data);//@audit-ok R does not validate transfromation[] path.
            if (selector != TRANSFORM_SELECTOR) {//@transformERC20(address,address,uint256,uint256,(uint32,bytes)[])
                revert WrongSelector(selector);//@ this does not check minimum output either
            }
            if (outputToken != ETH) {
                revert WrongDataTokens(inputToken, outputToken);
            }
        } else {
            revert WrongExchange();
        }

        if (inputToken != _token) {
            revert WrongDataTokens(inputToken, outputToken);
        }
        if (inputTokenAmount != _amount) {
            revert WrongDataAmount(inputTokenAmount);
        }
        if (recipient != address(this) && recipient != address(0)) {//@note accept recipient 0x0 address meaning sending to msg.sender and address(this) as target of swap token
            revert WrongRecipient(recipient);
        }
    }
//real//803ba26d00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000e3a26401a8d86920000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bcd5fe23c85820f7b72d0926fc9b05b43e359b7ee0001f4c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000cd2e894fbd5c23e551a905b85e26948a
//user//803ba26d0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000c96d4f72f69d6eb6000000000000000000000000000000000000000000000000001183062edd8e710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b99d8a9c45b2eca8864373a26d1459e3dff1e17f3002710c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000869584cd00000000000000000000000008a3c2a819e3de7aca384c798269b3ce1cd0e437000000000000000000000000000000002038022d7f26996da7c5918108798368
//803ba26d
//0000000000000000000000000000000000000000000000000000000000000080 //location to start reading bytes
//000000000000000000000000000000000000000000000000c96d4f72f69d6eb6// uint256, 14.514344529267355318
//000000000000000000000000000000000000000000000000001183062edd8e71 //uint256,  0.004929137183395441
//0000000000000000000000000000000000000000000000000000000000000000//address
//000000000000000000000000000000000000000000000000000000000000002b// bytes length 43 = 86hex start of reading bytes length and data
//99d8a9c45b2eca8864373a26d1459e3dff1e17f3 002710 c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2 000000000000000000000000000000000000000000
//869584cd              ///unknown function call
//00000000000000000000000008a3c2a819e3de7aca384c798269b3ce1cd0e437 //EOA address receiver?
//000000000000000000000000000000002038022d7f26996da7c5918108798368 // 42826108658633038698.667964812257493864

//real
//803ba26d
//0000000000000000000000000000000000000000000000000000000000000080 >@ p start here, next line
//0000000000000000000000000000000000000000000000000de0b6b3a7640000 //1000000000000000000 input
//0000000000000000000000000000000000000000000000000e3a26401a8d8692 //1025173921945454226  guaranteedPrice
//0000000000000000000000000000000000000000000000000000000000000000//address
//000000000000000000000000000000000000000000000000000000000000002b// bytes length 43
//cd5fe23c85820f7b72d0926fc9b05b43e359b7ee (shr96) 0001f4 c02aaa39b223fe8d0a //address[] path packed
//0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000
//869584cd //anything beyond this just tracking data
//0000000000000000000000001000000000000000000000000000000000000011 //address 40 length? 
//00000000000000000000000000000000cd2e894fbd5c23e551a905b85e26948a //decodedUniqueId
    /**
     * @notice Decodes the data sent from 0x API when UniswapV3 is used
     * @param _data      swap data from 0x API
     */
    function _decodeUniswapV3Data(bytes calldata _data)
        internal
        pure
        returns (address inputToken, address outputToken, uint256 inputTokenAmount, address recipient, bytes4 selector)
    {
        uint256 encodedPathLength;
        assembly {//@audit H it is very easy to bypass decodeUniswap validation check for path swap. input and output token. But there is no reason for user to do this
            let p := _data.offset//@ 0xa4 +0xa4 164 + 164 = 328  //@audit-ok H which calldataload stack does this view get from? internal call or from directly root function call. because offset is fuck up
            selector := calldataload(p)//@EVM this was called last in assembly stack so selector only take 4bytes out 32bytes calldata. The whole thing was shifted first
            p := add(p, 36) // Data: selector 4 + lenght data 32 //skip 1st 32 bytes is bytes location not bytes length
            inputTokenAmount := calldataload(p)//@ user input token //sellAmount , p 32 is minBuyAmount
            recipient := calldataload(add(p, 64))//@skip 32 of inputAmount ,skip 32 of guaranteedPrice, recipient addres is empty mean return this address
            encodedPathLength := calldataload(add(p, 96)) // Get length of encodedPath (obtained through abi.encodePacked) //@next 32 bytes is bytes length. this normally encodedPATH
            inputToken := shr(96, calldataload(add(p, 128))) // Shift to the Right with 24 zeroes (12 bytes = 96 bits) to get address
            outputToken := shr(96, calldataload(add(p, add(encodedPathLength, 108)))) // Get last address of the hop 108 = 128 - 20. target = 108+ byteslength //   p+151 = skip 23 bytes. skip 20 first address and 3 bytes of next path data
        }//@audit-ok this reading support multiple path M 0xExChange sometime return path more convoluted than 2 path swapping. This could cause issue when swapping.
    }//@audit-ok last check output token to correct. M bypass hop path by swapping WETH into some other token. path[3] is wstETH->WETH->anotherToken
//@audit can bypass uniswap swap by faking input and outputToken. But this doing nothing special as user balances already been removed beforehand. No swap = no lpETH for user. Lost for exploiter
    /**
     * @notice Decodes the data sent from 0x API when other exchanges are used via 0x TransformERC20 function
     * @param _data      swap data from 0x API
     */
    function _decodeTransformERC20Data(bytes calldata _data)
        internal
        pure
        returns (address inputToken, address outputToken, uint256 inputTokenAmount, bytes4 selector)
    {
        assembly {
            let p := _data.offset
            selector := calldataload(p)
            inputToken := calldataload(add(p, 4)) // Read slot, selector 4 bytes
            outputToken := calldataload(add(p, 36)) // Read slot
            inputTokenAmount := calldataload(add(p, 68)) // Read slot
        }
    }

    /**
     *
     * @param _sellToken     The `sellTokenAddress` field from the API response.
     * @param _amount       The `sellAmount` field from the API response.
     * @param _swapCallData  The `data` field from the API response.
     */

    function _fillQuote(IERC20 _sellToken, uint256 _amount, bytes calldata _swapCallData) internal {
        // Track our balance of the buyToken to determine how much we've bought.
        uint256 boughtETHAmount = address(this).balance;

        require(_sellToken.approve(exchangeProxy, _amount));//@audit what to do with approval but not swap the whole thing?

        (bool success,) = payable(exchangeProxy).call{value: 0}(_swapCallData);
        if (!success) {
            revert SwapCallFailed();
        }

        // Use our current buyToken balance to determine how much we've bought.
        boughtETHAmount = address(this).balance - boughtETHAmount;
        emit SwappedTokens(address(_sellToken), _amount, boughtETHAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorized() {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyAfterDate(uint256 limitDate) {
        if (block.timestamp <= limitDate) {
            revert CurrentlyNotPossible();
        }
        _;
    }

    modifier onlyBeforeDate(uint256 limitDate) {
        if (block.timestamp >= limitDate) {
            revert NoLongerPossible();
        }
        _;
    }
}
