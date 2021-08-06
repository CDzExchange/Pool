// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IBEP20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/SignedSafeMath.sol";
import "./libraries/SafeBEP20.sol";
import "./CDzToken.sol";
import "./CDzBar.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

// import "@nomiclabs/buidler/console.sol";
interface IMigratorChef {
    // Perform LP token migration from legacy CDzExchange to NewCDzExchange
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to CDzExchange LP tokens.
    // NewCDzExchange must mint EXACTLY the same amount of NewCDzExchange LP tokens or
    // else something bad will happen. Traditional CDzExchange does not
    // do that so be careful!
    function migrate(IBEP20 token) external returns (IBEP20);
}

// LaunchPool is a CDZ pool. He can launch CDZ and he is a fair guy.
// Have fun reading it. Hopefully it's bug-free. God bless.
contract LaunchPool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeBEP20 for IBEP20;

    // @notice Info of each user.
    // `amount` LP Token amount the user has provided .
    // `rewardDebt` The amount of CDZ entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    // @notice Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. CDZs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that CDZs distribution occurs.
        uint256 accCDZPerShare; // Accumulated CDZs per share, times 1e12. See below.
    }

    // The CDZ TOKEN!
    CDzToken public cdz;

    // The reward bar
    CDzBar public bar;

    // @notice CDZ tokens created per block.
    uint256 public cdzPerBlock;
    // @notice Bonus multiplier for early cdz makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // @notice The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // @notice Info of each pool.
    PoolInfo[] public poolInfo;
    // @dev Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // @notice Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // @notice The total of CDZ Token by LaunchPool rewarded.
    uint256 public cdzTotalRewarded = 0;

    // @notice The block number when CDZ reward starts.
    uint256 public startBlock;
    // @notice The block number when CDZ reward end.
    uint256 public endBlock;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, BEP20 lpToken);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, bool overwrite);
    event LogUpdatePool(uint256 indexed pid, uint256 lastRewardBlock, uint256 lpSupply, uint256 accCDZPerShare);

    constructor(
        CDzToken _cdz,
        uint256 _cdzPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) {
        cdz = _cdz;
        cdzPerBlock = _cdzPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
        bar = new CDzBar(_cdz);
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accCDZPerShare: 0
        }));
    }

    //@notice Update the given pool's CDZ allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // @notice set the end block. Can only be called by the owner
    function setEndBlock(uint256 _endBlock) public onlyOwner {
        endBlock = _endBlock;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IBEP20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IBEP20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending CDZs on frontend.
    function pendingCDZ(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCDZPerShare = pool.accCDZPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 number = block.number;
        if (number > endBlock) {
            number = endBlock;
        }
        if (number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, number);
            uint256 cdzReward = multiplier.mul(cdzPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accCDZPerShare = accCDZPerShare.add(cdzReward.mul(1e12).div(lpSupply));
        }
        return int256(user.amount.mul(accCDZPerShare).div(1e12)).sub(user.rewardDebt).toUInt256();
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // @notice Update reward variables of the given pool to be up-to-date.
    // @param `_pid` The index of the pool.
    // @return `pool` Returns the pool that was updated
    function updatePool(uint256 _pid) public returns (PoolInfo memory pool){
        pool = poolInfo[_pid];
        uint256 number = block.number;
        if (number > endBlock) {
            number = endBlock;
        }
        if (number > pool.lastRewardBlock) {
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 multiplier = getMultiplier(pool.lastRewardBlock, number);
                uint256 cdzReward = multiplier.mul(cdzPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
                cdzReward = safeCDZReward(cdzReward);
                pool.accCDZPerShare = pool.accCDZPerShare.add(cdzReward.mul(1e12).div(lpSupply));
            }
            pool.lastRewardBlock = number;
            poolInfo[_pid] = pool;
            emit LogUpdatePool(_pid, pool.lastRewardBlock, lpSupply, pool.accCDZPerShare);
        }
    }

    // @notice Deposit LP tokens to LaunchPool for CDZ allocation.
    // @param `_pid` The index of the pool
    // @param `_amount` LP Token amount to deposit
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (_amount > 0) {
            user.rewardDebt = user.rewardDebt.add(int256(_amount.mul(pool.accCDZPerShare).div(1e12)));
            user.amount = user.amount.add(_amount);
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        }
        emit Deposit(msg.sender, _pid, _amount);
    }

    // @notice Withdraw LP tokens from LaunchPool.
    // @param `_pid` The index of pool.
    // @param `_amount` LP Token amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];
        // Effects
        if (_amount > 0) {
            // if not reach the harvest block number will loss the _amount of share reward
            if (block.number < endBlock) {
                int256 accumulatedCDZ = int256(user.amount.mul(pool.accCDZPerShare).div(1e12));
                uint256 _pendingCDZ = accumulatedCDZ.sub(user.rewardDebt).toUInt256();
                uint256 saveReward = _pendingCDZ.sub(_pendingCDZ.mul(_amount).div(user.amount));
                user.amount = user.amount.sub(_amount);
                user.rewardDebt = int256(user.amount.mul(pool.accCDZPerShare).div(1e12).sub(saveReward));
            } else {
                user.amount = user.amount.sub(_amount);
                user.rewardDebt = user.rewardDebt.sub(int256(_amount.mul(pool.accCDZPerShare).div(1e12)));
            }
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // @notice Harvest reward from pool.
    // @param `_pid` The index of pool
    function harvest(uint256 _pid) external nonReentrant {
        require(block.number >= endBlock, "harvest: not reach the end block number");
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];
        int256 accumulatedCDZ = int256(user.amount.mul(pool.accCDZPerShare).div(1e12));
        uint256 _pendingCDZ = accumulatedCDZ.sub(user.rewardDebt).toUInt256();

        // Effects
        user.rewardDebt = accumulatedCDZ;

        if (_pendingCDZ != 0) {
            safeCDZTransfer(address(msg.sender), _pendingCDZ);
        }

        emit Harvest(msg.sender, _pid, _pendingCDZ);
    }

    // @notice Withdraw LP Tokens from LaunchPool and harvest the reward.
    // @param `_pid` The index of pool.
    // @param `_amount` LP Token amount to withdraw.
    function withdrawAndHarvest(uint256 _pid, uint256 _amount) external nonReentrant {
        require(block.number >= endBlock, "harvest: not reach the end block number");
        PoolInfo memory pool = updatePool(_pid);
        UserInfo storage user = userInfo[_pid][msg.sender];
        int256 accumulatedCDZ = int256(user.amount.mul(pool.accCDZPerShare).div(1e12));
        uint256 _pendingCDZ = accumulatedCDZ.sub(user.rewardDebt).toUInt256();
        // Effects
        user.rewardDebt = accumulatedCDZ.sub(int256(_amount.mul(pool.accCDZPerShare).div(1e12)));
        user.amount = user.amount.sub(_amount);
        safeCDZTransfer(address(msg.sender), _pendingCDZ);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
        emit Harvest(msg.sender, _pid, _pendingCDZ);
    }

    // @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    // @param `_pid` The index of pool.
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // @notice Retrieve the balance when the pool has end.
    function retrieveBalance(address _to, bool _withUpdate) external onlyOwner nonReentrant {
        require(block.number > endBlock, "retrieveReward: not reach the end block");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 balance = cdz.balanceOf(address(this));
        cdz.transfer(_to, balance);
    }

    // @dev Safe cdz transfer function, just in case if rounding error causes pool to not have enough CDZs.
    function safeCDZTransfer(address _to, uint256 _amount) internal {
        bar.safeCDzTransfer(_to, _amount);
    }

    // @dev Safe cdz reward
    function safeCDZReward(uint256 _amount) internal returns(uint256 reward) {
        uint256 cdzBal = cdz.balanceOf(address(this));
        if (_amount > cdzBal ) {
            reward = cdzBal;
        } else {
            reward = _amount;
        }
        cdz.transfer(address(bar), reward);
        cdzTotalRewarded = cdzTotalRewarded.add(reward);
    }
}
