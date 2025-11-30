// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;
import {console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IstETH.sol";
import "./interfaces/IwstETH.sol";
import "./interfaces/IsDAI.sol";
import "./interfaces/IeETHLiquidityPool.sol";
import "./interfaces/IweETH.sol";
import "../proxies/Upgradeable2Step.sol";
import "./SophonFarmingState.sol";

/**
 * @title Sophon Farming Contract
 * @author Sophon
 */
contract SophonFarming is Upgradeable2Step, SophonFarmingState {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a new pool is added
    event Add(address indexed lpToken, uint256 indexed pid, uint256 allocPoint);

    /// @notice Emitted when a pool is updated
    event Set(address indexed lpToken, uint256 indexed pid, uint256 allocPoint);

    /// @notice Emitted when a user deposits to a pool
    event Deposit(address indexed user, uint256 indexed pid, uint256 depositAmount, uint256 boostAmount);

    /// @notice Emitted when a user withdraws from a pool
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);

    /// @notice Emitted when a user increases the boost of an existing deposit
    event IncreaseBoost(address indexed user, uint256 indexed pid, uint256 boostAmount);

    /// @notice Emitted when all pool funds are bridged to Sophon blockchain
    event Bridge(address indexed user, uint256 indexed pid, uint256 amount);

    /// @notice Emitted when the admin withdraws booster proceeds
    event WithdrawProceeds(uint256 indexed pid, uint256 proceeds);

    error PoolExists();
    error PoolDoesNotExist();
    error AlreadyInitialized();
    error NotFound(address lpToken);
    error FarmingIsStarted();
    error FarmingIsEnded();
    error InvalidStartBlock();
    error InvalidEndBlock();
    error InvalidDeposit();
    error InvalidBooster();
    error WithdrawNotAllowed();
    error WithdrawTooHigh(uint256 maxAllowed);
    error WithdrawIsZero();
    error NothingInPool();
    error NoEthSent();
    error BoostTooHigh(uint256 maxAllowed);
    error BoostIsZero();
    error BridgeInvalid();

    address public immutable dai;
    address public immutable sDAI;
    address public immutable weth;
    address public immutable stETH;
    address public immutable wstETH;
    address public immutable eETH;
    address public immutable eETHLiquidityPool;
    address public immutable weETH;

    /**
     * @notice Construct SophonFarming
     * @param tokens_ Immutable token addresses
     * @dev 0:dai, 1:sDAI, 2:weth, 3:stETH, 4:wstETH, 5:eETH, 6:eETHLiquidityPool, 7:weETH
     */
    constructor(address[8] memory tokens_) {
        dai = tokens_[0];//0x6B175474E89094C44Da98b954EedeAC495271d0F // unique dai function move and transfer
        sDAI = tokens_[1];//0x83F20F44975D03b1b09e64809B757c47f942BEeA //New contract SavingDAI
        weth = tokens_[2];//0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        stETH = tokens_[3];//0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84 //lido staking old v0.4
        wstETH = tokens_[4];//0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 // lido v0.6.12
        eETH = tokens_[5];//0x35fA164735182de50811E8e2E824cFb9B6118ac2
        eETHLiquidityPool = tokens_[6];//@deposit and exit //0x308861A430be4cce5502d0A12724771Fc6DaF216
        weETH = tokens_[7];//0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee //ether.fi warp eETH
    }

    /**
     * @notice Allows direct deposits of ETH for deposit to the wstETH pool
     */
    receive() external payable {
        console.log("receive");
        if (msg.sender == weth) {//@audit-ok ignore L why accept free ether from WETH. And not from stETH or weETH`
            return;
        }

        depositEth(0, PredefinedPool.wstETH);
    }

    /**
     * @notice Initialize the farm
     * @param ethAllocPoint_ eth alloc points //20000
     * @param sDAIAllocPoint_ sdai alloc points //20000
     * @param _pointsPerBlock points per block //25e18
     * @param _startBlock start block // block.number
     * @param _boosterMultiplier booster multiplier //2e18 . //@audit-ok nothing bad happen. what happen when booster 1e18
     */
    function initialize(uint256 ethAllocPoint_, uint256 sDAIAllocPoint_, uint256 _pointsPerBlock, uint256 _startBlock, uint256 _boosterMultiplier) public virtual onlyOwner {
        if (_initialized) {
            revert AlreadyInitialized();
        }

        pointsPerBlock = _pointsPerBlock;//25e18

        if (_startBlock == 0) {
            revert InvalidStartBlock();
        }
        startBlock = _startBlock;

        if (_boosterMultiplier < 1e18) {
            revert InvalidBooster();
        }
        boosterMultiplier = _boosterMultiplier;//2e18

        poolExists[dai] = true;
        poolExists[weth] = true;
        poolExists[stETH] = true;
        poolExists[eETH] = true;

        // sDAI
        typeToId[PredefinedPool.sDAI] = add(sDAIAllocPoint_, sDAI, "sDAI", false);//@audit-ok H sDAI have weirdly more purchase power than other pool due to price different.
        IERC20(dai).approve(sDAI, 2**256-1);//@audit-ok same as type.max L not using uint max

        // wstETH
        typeToId[PredefinedPool.wstETH] = add(ethAllocPoint_, wstETH, "wstETH", false);
        IERC20(stETH).approve(wstETH, 2**256-1);//@note approve here used only for unique converting code, predefined function 

        // weETH
        typeToId[PredefinedPool.weETH] = add(ethAllocPoint_, weETH, "weETH", false);
        IERC20(eETH).approve(weETH, 2**256-1);

        _initialized = true;
    }

    /**
     * @notice Adds a new pool to the farm. Can only be called by the owner.
     * @param _allocPoint alloc point for new pool
     * @param _lpToken lpToken address
     * @param _description description of new pool
     * @param _withUpdate True will update accounting for all pools
     * @return uint256 The pid of the newly created asset
     */
    function add(uint256 _allocPoint, address _lpToken, string memory _description, bool _withUpdate) public onlyOwner returns (uint256) {
        if (poolExists[_lpToken]) {//pool WETH exist but no approve
            revert PoolExists();//@audit-ok L can add zero zddress pool
        }
        if (isFarmingEnded()) {// if end date then revert. admin can set this to zero and reset to new end date
            revert FarmingIsEnded();
        }
        if (_withUpdate) {
            massUpdatePools();//@audit-ok L why not update after add new pool?
        }//@edit accPointsPerShare if have deposit, and lastRewardBlock
        uint256 lastRewardBlock =
            getBlockNumber() > startBlock ? getBlockNumber() : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolExists[_lpToken] = true;//@audit-ok approve only for some special pool need convert to wrap token.add Pool but does not approve new token. this was approved in init

        uint256 pid = poolInfo.length;

        poolInfo.push(
            PoolInfo({
                lpToken: IERC20(_lpToken),
                l2Farm: address(0),
                amount: 0,
                boostAmount: 0,
                depositAmount: 0,
                allocPoint: _allocPoint,//20000 suppose to spread evenly between pool
                lastRewardBlock: lastRewardBlock,//min (block.number, startBlock)
                accPointsPerShare: 0,
                description: _description
            })
        );

        emit Add(_lpToken, pid, _allocPoint);

        return pid;
    }

    /**
     * @notice Updates the given pool's allocation point. Can only be called by the owner.
     * @param _pid The pid to update
     * @param _allocPoint The new alloc point to set for the pool
     * @param _withUpdate True will update accounting for all pools
     */
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_withUpdate) {
            massUpdatePools();
        }

        PoolInfo storage pool = poolInfo[_pid];
        address lpToken = address(pool.lpToken);
        if (lpToken == address(0) || !poolExists[lpToken]) {
            revert PoolDoesNotExist();
        }
        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;
        //lastRewardBlock = min(block.number, startBlock)
        if (getBlockNumber() < pool.lastRewardBlock) {//@audit-ok wtf.is this suppose to reset it to smaller value?
            pool.lastRewardBlock = startBlock;
        }

        emit Set(lpToken, _pid, _allocPoint);
    }

    /**
     * @notice Returns the number of pools in the farm
     * @return uint256 number of pools
     */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @notice Checks if farming is ended
     * @return bool True if farming is ended
     */
    function isFarmingEnded() public view returns (bool) {
        uint256 _endBlock = endBlock;
        if (_endBlock != 0 && getBlockNumber() > _endBlock) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Checks if the withdrawal period is ended
     * @return bool True if withdrawal period is ended
     */
    function isWithdrawPeriodEnded() public view returns (bool) {
        uint256 _endBlockForWithdrawals = endBlockForWithdrawals;
        if (_endBlockForWithdrawals != 0 && getBlockNumber() > _endBlockForWithdrawals) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice Updates the bridge contract
     */
    function setBridge(BridgeLike _bridge) public onlyOwner {
        bridge = _bridge;
    }

    /**
     * @notice Updates the L2 Farm for the pool
     * @param _pid the pid
     * @param _l2Farm the l2Farm address
     */
    function setL2FarmForPool(uint256 _pid, address _l2Farm) public onlyOwner {
        poolInfo[_pid].l2Farm = _l2Farm;
    }

    /**
     * @notice Set the start block of the farm
     * @param _startBlock the start block
     */
    function setStartBlock(uint256 _startBlock) public onlyOwner {
        if (_startBlock == 0 || (endBlock != 0 && _startBlock >= endBlock)) {
            revert InvalidStartBlock();
        }
        if (getBlockNumber() > startBlock) {//@note cannot reset startblock once started.
            revert FarmingIsStarted();
        }
        startBlock = _startBlock;//@audit-ok not possible can set startBlock bigger than endBlock if endBlock = 0. Endblock also have check prevent smaller than start block
    }

    /**
     * @notice Set the end block of the farm
     * @param _endBlock the end block
     * @param _withdrawalBlocks the last block that withdrawals are allowed
     */
    function setEndBlock(uint256 _endBlock, uint256 _withdrawalBlocks) public onlyOwner {
        uint256 _endBlockForWithdrawals;
        if (_endBlock != 0) {
            if (_endBlock <= startBlock || getBlockNumber() > _endBlock) {//@note can still set endblock same as current block
                revert InvalidEndBlock();
            }
            if (isFarmingEnded()) {//@skip if endblock ==0
                revert FarmingIsEnded();
            }
            _endBlockForWithdrawals = _endBlock + _withdrawalBlocks;
        } else {
            // withdrawal blocks needs an endBlock
            _endBlockForWithdrawals = 0;
        }
        massUpdatePools();
        endBlock = _endBlock;//@audit-ok M owner can set end block to 0 allowing emergency withdrawal of everyone and reset to new endblock. bypass isFarmingEnded
        endBlockForWithdrawals = _endBlockForWithdrawals;//@note withdrawal block can be same as endBlock.
    }

    /**
     * @notice Set points per block
     * @param _pointsPerBlock points per block to set
     */
    function setPointsPerBlock(uint256 _pointsPerBlock) public onlyOwner {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        massUpdatePools();
        pointsPerBlock = _pointsPerBlock;////25e18
    }

    /**
     * @notice Set booster multiplier
     * @param _boosterMultiplier booster multiplier to set
     */
    function setBoosterMultiplier(uint256 _boosterMultiplier) public onlyOwner {
        if (_boosterMultiplier < 1e18) {
            revert InvalidBooster();
        }
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        massUpdatePools();
        boosterMultiplier = _boosterMultiplier;//2e18
    }

    /**
     * @notice Returns the block multiplier
     * @param _from from block
     * @param _to to block
     * @return uint256 The block multiplier
     */
    function _getBlockMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        uint256 _endBlock = endBlock;
        if (_endBlock != 0) {
            _to = Math.min(_to, _endBlock);
        }
        if (_to > _from) {
            return (_to - _from) * 1e18;//@note _getBlockMultiplier is just block delta, block passed * 1e18
        } else {
            return 0;
        }
    }

    /**
     * @notice Returns pending points for user in a pool
     * @param _pid pid of the pool
     * @param _user user in the pool
     * @return uint256 pendings points
     */
    function _pendingPoints(uint256 _pid, address _user) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
//@audit-ok precision rounding M accPointsPerShare already 1e18 why *1e18 again for?
        uint256 accPointsPerShare = pool.accPointsPerShare * 1e18;//start from 0 , updated from massUpdatePools
        //pool.accPointsPerShare = pointReward / pool.amount + pool.accPointsPerShare;
        uint256 lpSupply = pool.amount;
        if (getBlockNumber() > pool.lastRewardBlock && lpSupply != 0) {//@audit-ok H pendingPoint does not use endBlock. this result in pendingPoints change depend on when refunding rewards happen
            uint256 blockMultiplier = _getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());

            uint256 pointReward =
                blockMultiplier *
                pointsPerBlock *
                pool.allocPoint /
                totalAllocPoint;

            accPointsPerShare = pointReward *
                1e18 /
                lpSupply +
                accPointsPerShare;
        }

        return user.amount *
            accPointsPerShare /
            1e36 +
            user.rewardSettled -
            user.rewardDebt;
    }

    /**
     * @notice Returns pending points for user in a pool
     * @param _pid pid of the pool
     * @param _user user in the pool
     * @return uint256 pendings points
     */
    function pendingPoints(uint256 _pid, address _user) external view returns (uint256) {
        return _pendingPoints(_pid, _user);
    }

    /**
     * @notice Update accounting of all pools
     */
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for(uint256 pid = 0; pid < length;) {
            updatePool(pid);
            unchecked { ++pid; }
        }
    }

    /**
     * @notice Updating accounting of a single pool
     * @param _pid pid to update
     */
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];//@audit-ok not affecting offchain view period.reward accrued point still update after farming ended. This affect offchain view operation
        if (getBlockNumber() <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.amount;//deposit + boostAmount
        uint256 _pointsPerBlock = pointsPerBlock;//25e18
        uint256 _allocPoint = pool.allocPoint;//20000 could also be > 1e18
        if (lpSupply == 0 || _pointsPerBlock == 0 || _allocPoint == 0) {
            pool.lastRewardBlock = getBlockNumber();//@note no update to pool share if no deposit or allocPoint. Admin can disable pool by setting alloc point to zero
            return;
        }
        uint256 blockMultiplier = _getBlockMultiplier(pool.lastRewardBlock, getBlockNumber());//block passed * 1e18
        uint256 pointReward =
            blockMultiplier *//blockDelta * 1e18
            _pointsPerBlock *// * 25e18
            _allocPoint /    // * 20000
            totalAllocPoint; // 80000
        //@spread points evenly between pools
        pool.accPointsPerShare = pointReward /
            lpSupply +//@audit-ok why earned points divided by deposited amount? Some pool with bigger allocation will get smaller share of points if they have larger deposit?
            pool.accPointsPerShare;//@audit-ok H if pool have low deposit like 1e1 token. accPoint earn will be inflated like ERC4626
//accPointsPerShare+= 1-1000e18 *25e18 * 20000/80000 / 0-1000e18
        pool.lastRewardBlock = getBlockNumber();//@note accPointsPerShare is accrued block point split between pool * 1e18. under condition pool token > 1e18
    }

    /**
     * @notice Deposit assets to SophonFarming
     * @param _pid pid of the pool
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function deposit(uint256 _pid, uint256 _amount, uint256 _boostAmount) external {
        poolInfo[_pid].lpToken.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );//@there is only 3 pools early on. sDAI, wstETH,weETH

        _deposit(_pid, _amount, _boostAmount);
    }

    /**
     * @notice Deposit DAI to SophonFarming
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function depositDai(uint256 _amount, uint256 _boostAmount) external {
        IERC20(dai).safeTransferFrom(
            msg.sender,
            address(this),
            _amount//@note hard code function . depositing DAI=sDAI, stETH =wstETH, eETH=weETH. ether=wstETH|weETH, weth=wstETH|weETH
        );

        _depositPredefinedAsset(_amount, _amount, _boostAmount, PredefinedPool.sDAI);
    }

    /**
     * @notice Deposit stETH to SophonFarming
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function depositStEth(uint256 _amount, uint256 _boostAmount) external {
        IERC20(stETH).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _depositPredefinedAsset(_amount, _amount, _boostAmount, PredefinedPool.wstETH);
    }

    /**
     * @notice Deposit eETH to SophonFarming
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function depositeEth(uint256 _amount, uint256 _boostAmount) external {
        IERC20(eETH).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        _depositPredefinedAsset(_amount, _amount, _boostAmount, PredefinedPool.weETH);
    }

    /**
     * @notice Deposit ETH to SophonFarming when specifying a pool
     * @param _boostAmount amount to boost
     * @param _predefinedPool specific pool type to deposit to
     */
    function depositEth(uint256 _boostAmount, PredefinedPool _predefinedPool) public payable {
        if (msg.value == 0) {
            revert NoEthSent();
        }

        uint256 _finalAmount = msg.value;
        if (_predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _ethTOstEth(_finalAmount);
        } else if (_predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _ethTOeEth(_finalAmount);
        }

        _depositPredefinedAsset(_finalAmount, msg.value, _boostAmount, _predefinedPool);
    }

    /**
     * @notice Deposit WETH to SophonFarming when specifying a pool
     * @param _amount amount of the deposit
     * @param _boostAmount amount to boost
     * @param _predefinedPool specific pool type to deposit to
     */
    function depositWeth(uint256 _amount, uint256 _boostAmount, PredefinedPool _predefinedPool) external {
        IERC20(weth).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        uint256 _finalAmount = _wethTOEth(_amount);
        if (_predefinedPool == PredefinedPool.wstETH) {
            _finalAmount = _ethTOstEth(_finalAmount);
        } else if (_predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _ethTOeEth(_finalAmount);
        }//@audit-ok M deposit ETH does not revert when PredefinedPool = sDAI. allowing deposit of WETH to sDAI pool

        _depositPredefinedAsset(_finalAmount, _amount, _boostAmount, _predefinedPool);
    }

    /**
     * @notice Deposit a predefined asset to SophonFarming
     * @param _amount amount of the deposit
     * @param _initalAmount amount of the deposit prior to conversions
     * @param _boostAmount amount to boost
     * @param _predefinedPool specific pool type to deposit to
     */
    function _depositPredefinedAsset(uint256 _amount, uint256 _initalAmount, uint256 _boostAmount, PredefinedPool _predefinedPool) internal {

        uint256 _finalAmount;

        if (_predefinedPool == PredefinedPool.sDAI) {//@ sDAI is rounded down due to huge deposit. share = asset * 1e27 / 1.08395e27
            _finalAmount = _daiTOsDai(_amount);//deposit DAI to sDAI.DAI already approved. sDAI is ERC4626. not possible for any external attack.
        } else if (_predefinedPool == PredefinedPool.wstETH) {//@also ERC4626. no possible attack
            _finalAmount = _stEthTOwstEth(_amount);//1 stETH = 0.856 wstETH //@audit-ok wstETH is undervalued on mainnet. Does this project support cross withdraw?
        } else if (_predefinedPool == PredefinedPool.weETH) {
            _finalAmount = _eethTOweEth(_amount);//1 eETH = 1.03897 weETH
        } else {
            revert InvalidDeposit();
        }

        // adjust boostAmount for the new asset
        _boostAmount = _boostAmount * _finalAmount / _initalAmount;//@note no check for maximum boostAmount at all for all functions.

        _deposit(typeToId[_predefinedPool], _finalAmount, _boostAmount);//@audit-ok some token pool give higher booster than other due to wrap conversion
    }

    /**
     * @notice Deposit an asset to SophonFarming
     * @param _pid pid of the deposit
     * @param _depositAmount amount of the deposit
     * @param _boostAmount amount to boost
     */
    function _deposit(uint256 _pid, uint256 _depositAmount, uint256 _boostAmount) internal {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }
        if (_depositAmount == 0) {
            revert InvalidDeposit();
        }
        if (_boostAmount > _depositAmount) {//@audit-ok notworking. booster input same as original deposit does not affect price conversion. M mainnet price conversion always changing to higher value. boostAmount here might fail due to conversion after receive new token
            revert BoostTooHigh(_depositAmount);//@boost here should rounded to maximum value if exceed to simplify user experience
        }//@note new boost cannot higher than new LPPool token deposit

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);//@also called from massUpdatePool
        //refresh accPointsPerShare and updateTimestamp
        uint256 userAmount = user.amount;//@previous deposit + boost
        user.rewardSettled =//@audit-ok cache pending is correct M accrued rewards not send directly to user like in docs UserInfo struct docs.
            userAmount *//0 first deposit
            pool.accPointsPerShare / //@ depend on pool.amount. so it still 0 until first deposit
            1e18 +
            user.rewardSettled -
            user.rewardDebt;//@audit-ok M first user call deposit will have no rewardSettled. It need to refresh 2nd times. due to accPoint will also be 0 on first deposit.
        //@ rewardSettled = userAmount * accPointsPerShare / 1e18 + rewardSettled - rewardDebt
        // booster purchase proceeds //@note rewardSettled is newReward - oldReward
        heldProceeds[_pid] = heldProceeds[_pid] + _boostAmount;

        // deposit amount is reduced by amount of the deposit to boost
        _depositAmount = _depositAmount - _boostAmount;//@note if use boost, it reduce future rewards? by subtracting from deposit amount

        // set deposit amount
        user.depositAmount = user.depositAmount + _depositAmount;
        pool.depositAmount = pool.depositAmount + _depositAmount;//@note pool.deposit = sum (user.deposit)

        // apply the boost multiplier
        _boostAmount = _boostAmount * boosterMultiplier / 1e18;//@note boost is just a portion of deposit multiplied to give extra rewards
        //@audit-ok yep it is M boosterMultiplier config changed later by admin will affect previous and future deposit.
        user.boostAmount = user.boostAmount + _boostAmount;
        pool.boostAmount = pool.boostAmount + _boostAmount;//@note pool.boost = sum (user.boost)

        // userAmount is increased by remaining deposit amount + full boosted amount
        userAmount = userAmount + _depositAmount + _boostAmount;

        user.amount = userAmount;//@note user.amount used for rewards include user booost or deposit multiplied one time by admin config.
        pool.amount = pool.amount + _depositAmount + _boostAmount;
        //@ accrue rewards here?? @audit-ok why not refresh rewardDebt first before use it? to prevent overflow during deposit?
        user.rewardDebt = userAmount *
            pool.accPointsPerShare /
            1e18;

        emit Deposit(msg.sender, _pid, _depositAmount, _boostAmount);
    }

    /**
     * @notice Increase boost from existing deposits
     * @param _pid pid to pool
     * @param _boostAmount amount to boost
     */
    function increaseBoost(uint256 _pid, uint256 _boostAmount) external {
        if (isFarmingEnded()) {
            revert FarmingIsEnded();
        }

        if (_boostAmount == 0) {
            revert BoostIsZero();
        }

        uint256 maxAdditionalBoost = getMaxAdditionalBoost(msg.sender, _pid);// userInfo[_pid][_user].depositAmount @deposit already reduced by boosted amount
        if (_boostAmount > maxAdditionalBoost) {
            revert BoostTooHigh(maxAdditionalBoost);
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 userAmount = user.amount;
        user.rewardSettled =//@ userAmount * accPointsPerShare /1e18 == new rewardDebt
            userAmount *
            pool.accPointsPerShare /
            1e18 +
            user.rewardSettled - //@ newRewardDebt + previousRewardSettled - oldRewardDebt = deltaRewardDebt + previousRewardSettled
            user.rewardDebt;//@audit-ok L the way handled rewardSettled can be fixed to make it simpler using algebra

        // booster purchase proceeds
        heldProceeds[_pid] = heldProceeds[_pid] + _boostAmount;//@note booster is transfered to owner account. It just gone. user convert all deposit into booster will have double purchase power

        // user's remaining deposit is reduced by amount of the deposit to boost
        user.depositAmount = user.depositAmount - _boostAmount;
        pool.depositAmount = pool.depositAmount - _boostAmount;

        // apply the multiplier
        uint256 finalBoostAmount = _boostAmount * boosterMultiplier / 1e18;//@audit-ok M boosterAmount cache on calculation is not the best way to do it. Admin can update booster later

        user.boostAmount = user.boostAmount + finalBoostAmount;
        pool.boostAmount = pool.boostAmount + finalBoostAmount;

        // user amount is increased by the full boosted amount - deposit amount used to boost
        userAmount = userAmount + finalBoostAmount - _boostAmount;

        user.amount = userAmount;
        pool.amount = pool.amount + finalBoostAmount - _boostAmount;//@audit-ok M other user increase booster also drop other accrued point if not call accrued yet.

        user.rewardDebt = userAmount * //@cache user starting point. this is subtracted later in rewardSettled
            pool.accPointsPerShare /
            1e18;

        emit IncreaseBoost(msg.sender, _pid, finalBoostAmount);
    }

    /**
     * @notice Returns max additional boost amount allowed to boost current deposits
     * @dev total allowed boost is 100% of total deposit
     * @param _user user in pool
     * @param _pid pid of pool
     * @return uint256 max additional boost
     */
    function getMaxAdditionalBoost(address _user, uint256 _pid) public view returns (uint256) {
        return userInfo[_pid][_user].depositAmount;
    }

    /**
     * @notice Withdraw an asset to SophonFarming
     * @param _pid pid of the withdraw
     * @param _withdrawAmount amount of the withdraw
     */
    function withdraw(uint256 _pid, uint256 _withdrawAmount) external {
        if (isWithdrawPeriodEnded()) {//@audit-ok if withdrawal period ended. user not boosting 100% will have stuck token. owner take all to bridge. M withdrawal period end have stuck token if user forget to withdraw out
            revert WithdrawNotAllowed();
        }
        if (_withdrawAmount == 0) {
            revert WithdrawIsZero();
        }

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);//@audit-ok Review not unfair cause it depend on pool.amount change. M unfair distribution due to single pool update. All pools spread point evently so it need to called all at once.

        uint256 userDepositAmount = user.depositAmount;

        if (_withdrawAmount == type(uint256).max) {
            _withdrawAmount = userDepositAmount;//@note user cannot withdraw booster. as it belong to owner.
        } else if (_withdrawAmount > userDepositAmount) {
            revert WithdrawTooHigh(userDepositAmount);
        }//@audit-ok nope it will just increasing H accept withdraw 0 token twice. This will break user rewards. RewardDebt is updated to new value higher.rewardSettled reset to 0.

        uint256 userAmount = user.amount;//deposit + boostedMul
        user.rewardSettled =//refresh reward shouuld be claimed with new accrued point. 
            userAmount *
            pool.accPointsPerShare /
            1e18 +
            user.rewardSettled -
            user.rewardDebt;

        user.depositAmount = userDepositAmount - _withdrawAmount;//@audit-ok pendign rewards handled this H when user get back rewards. it should be massUpdated too. Currently there is no callback reward from owner themself.
        pool.depositAmount = pool.depositAmount - _withdrawAmount;

        userAmount = userAmount - _withdrawAmount;

        user.amount = userAmount;
        pool.amount = pool.amount - _withdrawAmount;

        pool.lpToken.safeTransfer(msg.sender, _withdrawAmount);
        //reward got reduced here to significant number to zero.
        user.rewardDebt = userAmount * //@note user.rewardDebt is just starting point of accrued reward based on user last deposit. It is not the reward itself.
            pool.accPointsPerShare /   //later this accrued point is recalculated using new accrued point and subtract to old value to get current user gain reward based on time passed.
            1e18;                      // deltaAccrued reward added to previous reward.
        //@note when withdraw everything. rewardDebt reset to 0. cached rewardSettled still there
        emit Withdraw(msg.sender, _pid, _withdrawAmount);
    }

    /**
     * @notice Permissionless function to allow anyone to bridge during the correct period
     * @param _pid pid to bridge
     */
    function bridgePool(uint256 _pid) external {
        if (!isFarmingEnded() || !isWithdrawPeriodEnded() || isBridged[_pid]) {
            revert Unauthorized();//revert when farming is not ended or withdraw period is not ended or already bridged
        }

        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];

        uint256 depositAmount = pool.depositAmount;
        if (depositAmount == 0 || address(bridge) == address(0) || pool.l2Farm == address(0)) {
            revert BridgeInvalid();
        }

        IERC20 lpToken = pool.lpToken;
        lpToken.approve(address(bridge), depositAmount);

        // TODO: change _refundRecipient, verify l2Farm, _l2TxGasLimit and _l2TxGasPerPubdataByte
        // These are pending the launch of Sophon testnet
        bridge.deposit(
            pool.l2Farm,            // _l2Receiver
            address(lpToken),       // _l1Token
            depositAmount,          // _amount
            200000,                 // _l2TxGasLimit
            0,                      // _l2TxGasPerPubdataByte
            owner()                 // _refundRecipient
        );

        isBridged[_pid] = true;//@audit-ok owner can reset ML user can still deposit after bridge if ending time reset to zero

        emit Bridge(msg.sender, _pid, depositAmount);
    }

    // TODO: does this function need to call claimFailedDeposit on the bridge?
    // This is pending the launch of Sophon testnet
    /**
     * @notice Called by an admin if a bridge process to Sophon fails
     * @param _pid pid of the failed bridge to revert
     */
    function revertFailedBridge(uint256 _pid) external onlyOwner {
        isBridged[_pid] = false;
    }

    /**
     * @notice Converts WETH to ETH
     * @dev WETH withdrawl
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _wethTOEth(uint256 _amount) internal returns (uint256) {
        // unwrap weth to eth
        IWeth(weth).withdraw(_amount);//@eth transfer does not trigger receive/deposit
        return _amount;
    }

    /**
     * @notice Converts ETH to stETH
     * @dev Lido
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _ethTOstEth(uint256 _amount) internal returns (uint256) {
        // submit function does not return exact amount of stETH so we need to check balances
        uint256 balanceBefore = IERC20(stETH).balanceOf(address(this));
        IstETH(stETH).submit{value: _amount}(address(this));
        return (IERC20(stETH).balanceOf(address(this)) - balanceBefore);
    }

    /**
     * @notice Converts stETH to wstETH
     * @dev Lido
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _stEthTOwstEth(uint256 _amount) internal returns (uint256) {
        // wrap returns exact amount of wstETH
        return IwstETH(wstETH).wrap(_amount);
    }

    /**
     * @notice Converts ETH to eETH
     * @dev ether.fi
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _ethTOeEth(uint256 _amount) internal returns (uint256) {
        // deposit returns exact amount of eETH
        return IeETHLiquidityPool(eETHLiquidityPool).deposit{value: _amount}(address(this));
    }

    /**
     * @notice Converts eETH to weETH
     * @dev ether.fi
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _eethTOweEth(uint256 _amount) internal returns (uint256) {
        // wrap returns exact amount of weETH
        return IweETH(weETH).wrap(_amount);
    }

    /**
     * @notice Converts DAI to sDAI
     * @dev MakerDao
     * @param _amount in amount
     * @return uint256 out amount
     */
    function _daiTOsDai(uint256 _amount) internal returns (uint256) {
        // deposit DAI to sDAI
        return IsDAI(sDAI).deposit(_amount, address(this));
    }

    /**
     * @notice Allows an admin to withdraw booster proceeds
     * @param _pid pid to withdraw proceeds from
     */
    function withdrawProceeds(uint256 _pid) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 _proceeds = heldProceeds[_pid];
        heldProceeds[_pid] = 0;
        pool.lpToken.safeTransfer(msg.sender, _proceeds);
        emit WithdrawProceeds(_pid, _proceeds);
    }

    /**
     * @notice Returns the current block number
     * @dev Included to help with testing since it can be overridden for custom functionality
     * @return uint256 current block number
     */
    function getBlockNumber() virtual public view returns (uint256) {
        return block.number;
    }

    /**
     * @notice Returns info about each pool
     * @return poolInfos all pool info
     */
    function getPoolInfo() external view returns (PoolInfo[] memory poolInfos) {
        uint256 length = poolInfo.length;
        poolInfos = new PoolInfo[](length);
        for(uint256 pid = 0; pid < length;) {
            poolInfos[pid] = poolInfo[pid];
            unchecked { ++pid; }
        }
    }

    /**
     * @notice Returns user info for a list of users
     * @param _users list of users
     * @return userInfos optimized user info
     */
    function getOptimizedUserInfo(address[] memory _users) external view returns (uint256[4][][] memory userInfos) {
        userInfos = new uint256[4][][](_users.length);
        uint256 len = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            userInfos[i] = new uint256[4][](len);
            for(uint256 pid = 0; pid < len;) {
                UserInfo memory uinfo = userInfo[pid][_user];
                userInfos[i][pid][0] = uinfo.amount;
                userInfos[i][pid][1] = uinfo.boostAmount;
                userInfos[i][pid][2] = uinfo.depositAmount;
                userInfos[i][pid][3] = _pendingPoints(pid, _user);
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }

    /**
     * @notice Returns accrued points for a list of users
     * @param _users list of users
     * @return pendings accured points for user
     */
    function getPendingPoints(address[] memory _users) external view returns (uint256[][] memory pendings) {
        pendings = new uint256[][](_users.length);
        uint256 len = poolInfo.length;
        for(uint256 i = 0; i < _users.length;) {
            address _user = _users[i];
            pendings[i] = new uint256[](len);
            for(uint256 pid = 0; pid < len;) {
                pendings[i][pid] = _pendingPoints(pid, _user);
                unchecked { ++pid; }
            }
            unchecked { i++; }
        }
    }
}