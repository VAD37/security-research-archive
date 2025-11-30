// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.12;

import "openzeppelin/security/ReentrancyGuard.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface ChainlinkOracle {
    function latestRoundData() external view returns (
      uint80,  // roundId,
      int256,  // answer,
      uint256, // startedAt,
      uint256, // updatedAt,
      uint80   // answeredInRound
    );
}

interface SwapRouter {
    function swap(
        address token_in,
        address token_out,
        uint256 amount_in,
        uint256 min_amount_out
    ) external returns (uint256);
}

interface Weth {
    function deposit() external payable;
    function withdrawTo(address account, uint256 amount) external;
}
contract TestDeploy {
    address public admin;
    constructor() {
    }
}

interface IVault {
    function admin() view external returns (address);
}

contract Vault  {



    uint256 public constant PRECISION = 10**18;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant PERCENTAGE_BASE = 100_00; // == 100%
    uint256 public constant PERCENTAGE_BASE_HIGH_PRECISION = 100_00_000; // == 100%

    address public constant ARBITRUM_SEQUENCER_UPTIME_FEED = 0xFdB631F5EE196F0ed6FAa767959853A9F217697D;
    uint256 public constant ORACLE_FRESHNESS_THRESHOLD = 24*60*60; // 24h

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 public constant FULL_UTILIZATION = 100_00_000;
    uint256[4] public FALLBACK_INTEREST_CONFIGURATION = [ uint256(3_00_000),uint256(20_00_000), uint256(100_00_000), uint256(80_00_000)];

    address public swap_router;

    // whitelisted addresses allowed to interact with this vault
    mapping(address => bool) public is_whitelisted_dex;

    mapping(address => mapping(address => bool)) public is_whitelisted_token;
    // token_in -> token_out
    mapping(address => mapping(address => bool)) public is_enabled_market;
    // token_in -> token_out
    mapping(address => mapping(address => uint256)) public max_leverage;
    // token -> Chainlink oracle
    mapping(address => address) public to_usd_oracle;
    // token_in -> token_out -> slippage
    mapping(address => mapping(address => uint256)) public liquidate_slippage;

    // the fee charged to traders when opening a position
    uint256 public trade_open_fee; // 10 = 0.1%
    uint256 public liquidation_penalty;
    // share of trading fee going to LPs vs protocol
    uint256 public trading_fee_lp_share;
    address public protocol_fee_receiver;

    // trader margin balances
    mapping(address => mapping(address => uint256)) public margin;

    // Liquidity
    // cooldown to prevent flashloan deposit/withdraws
    uint256 public withdraw_liquidity_cooldown;
    mapping(address => uint256) public account_withdraw_liquidity_cooldown;

    // base LPs
    mapping(address => mapping(address => uint256)) public base_lp_shares;
    mapping(address => uint256) public base_lp_total_shares;
    mapping(address => uint256) public base_lp_total_amount;

    // Safety Module LPs
    mapping(address => mapping(address => uint256)) public safety_module_lp_shares;
    mapping(address => uint256) public safety_module_lp_total_shares;
    mapping(address => uint256) public safety_module_lp_total_amount;

    uint256 public safety_module_interest_share_percentage;

    // debt_token -> total_debt_shares
    mapping(address => uint256) public total_debt_shares;
    // debt_token -> Position uid -> debt_shares
    mapping(address => mapping(bytes32 => uint256)) public debt_shares;
    // debt_token -> total_debt
    mapping(address => uint256) public total_debt_amount;
    // debt_token -> timestamp
    mapping(address => uint256) public last_debt_update;

    // token -> bad_debt
    mapping(address => uint256) public bad_debt;

    // dynamic interest rates [min, mid, max, kink]
    mapping(address => uint256[4]) public interest_configuration;

    // Structs
    struct Position {
        bytes32 uid;
        address account;
        address debt_token;
        uint256 margin_amount;
        uint256 debt_shares;
        address position_token;
        uint256 position_amount;
    }

    
    // Rest of your variables go here
    address public admin;
    address public suggested_admin;
    bool public is_accepting_new_orders;
    

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }
event PositionOpened(address indexed _account, Position position);
event PositionClosed(address indexed account, bytes32 uid, Position position, uint256 amount_received);
event BadDebt(address indexed token, uint256 amount, bytes32 position_uid);
event PositionReduced(address indexed account, bytes32 uid, Position position, uint256 amount_received);
event PositionLiquidated(address indexed account, bytes32 uid, Position position);
event MarginAdded(bytes32 uid, uint256 amount);
event MarginRemoved(bytes32 uid, uint256 amount);
event AccountFunded(address indexed account, uint256 amount, address indexed token);
event WithdrawBalance(address indexed account, address indexed token, uint256 amount);
event ProvideLiquidity(address indexed account, address indexed token, uint256 amount);
event WithdrawLiquidity(address indexed account, address indexed token, uint256 amount);
event BaseLpInterestReceived(address token, uint256 amount);
event SafetyModuleInterestReceived(address token, uint256 amount);
event TradingFeeDistributed(address indexed receiver, address indexed token, uint256 amount);
event NewAdminSuggested(address indexed new_admin, address indexed suggested_by);
event AdminTransferred(address indexed new_admin, address indexed promoted_by);

function open_position(address _account, address _position_token, uint256 _min_position_amount_out, address _debt_token, uint256 _debt_amount, uint256 _margin_amount) external returns (bytes32, uint256){}
function close_position(bytes32 _position_uid, uint256 _min_amount_out) external returns(uint256){}
function reduce_position(bytes32 _position_uid, uint256 _reduce_by_amount, uint256 _min_amount_out) external returns(uint256){}
function liquidate(bytes32 _position_uid) external{}
function add_margin(bytes32 _position_uid, uint256 _amount) external{}
function remove_margin(bytes32 _position_uid, uint256 _amount) external{}
function effective_leverage(bytes32 _position_uid) external view returns(uint256){}
function is_liquidatable(bytes32 _position_uid) external view returns(bool){}
function to_usd_oracle_price(address _token) external view returns(uint256){}
function current_exchange_rate(bytes32 _position_uid) external view returns (uint256) {}
function fund_account(address _token, uint256 _amount) external {}
function withdraw_from_account(address _token, uint256 _amount) external {}
function provide_liquidity(address _token, uint256 _amount, bool _is_safety_module) external {}
function withdraw_liquidity(address _token, uint256 _amount, bool _is_safety_module) external {}
function lp_shares_to_amount(address _token, uint256 _shares, bool _is_safety_module) external view returns(uint256) {}
function available_liquidity(address _token) external view returns(uint256) {}
function debt(bytes32 _position_uid) external view returns(uint256) {}
function position_amount(bytes32 _position_uid) external view returns(uint256) {}
function current_interest_per_second(address _debt_token) external view returns (uint256) {}
function suggest_admin(address _new_admin) external {}
function accept_admin() external {}
function set_is_accepting_new_orders(bool _is_accepting_new_orders) external {}
function whitelist_token(address _token, address _token_to_usd_oracle) external returns (uint256) {}
function remove_token_from_whitelist(address _token) external {}
function enable_market(address _token1, address _token2, uint256 _max_leverage) external {}
function set_max_leverage_for_market(address _token1, address _token2, uint256 _max_leverage) external {}
function set_liquidate_slippage_for_market(address _token1, address _token2, uint256 _slippage) external {}
function set_trade_open_fee(uint256 _fee) external {}
function set_liquidation_penalty(uint256 _penalty) external {}
function set_safety_module_interest_share_percentage(uint256 _percentage) external {}
function set_trading_fee_lp_share(uint256 _percentage) external {}
function set_protocol_fee_receiver(address _receiver) external {}
function set_is_whitelisted_dex(address _dex, bool _whitelisted) external {}
function set_swap_router(address _swap_router) external {}
function set_withdraw_liquidity_cooldown(uint256 _seconds) external {}
function set_variable_interest_parameters(address _address, uint256 _min_interest_rate, uint256 _mid_interest_rate, uint256 _max_interest_rate, uint256 _rate_switch_utilization) external {}


}
