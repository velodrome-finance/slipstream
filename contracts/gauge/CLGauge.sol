// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ICLGauge} from "contracts/gauge/interfaces/ICLGauge.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";
import {IVotingEscrow} from "contracts/core/interfaces/IVotingEscrow.sol";
import {ICLPool} from "contracts/core/interfaces/ICLPool.sol";
import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "contracts/libraries/EnumerableSet.sol";
import {SafeCast} from "contracts/gauge/libraries/SafeCast.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {FixedPoint128} from "contracts/core/libraries/FixedPoint128.sol";
import {VelodromeTimeLibrary} from "contracts/libraries/VelodromeTimeLibrary.sol";
import {IReward} from "contracts/gauge/interfaces/IReward.sol";

contract CLGauge is ICLGauge, ERC721Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using SafeCast for uint128;

    /// @inheritdoc ICLGauge
    INonfungiblePositionManager public override nft;
    /// @inheritdoc ICLGauge
    IVoter public override voter;
    /// @inheritdoc ICLGauge
    ICLPool public override pool;

    /// @inheritdoc ICLGauge
    address public override feesVotingReward;
    /// @inheritdoc ICLGauge
    address public override rewardToken;

    /// @inheritdoc ICLGauge
    uint256 public override periodFinish;
    /// @inheritdoc ICLGauge
    uint256 public override rewardRate;

    mapping(uint256 => uint256) public override rewardRateByEpoch; // epochStart => rewardRate
    /// @dev The set of all staked nfts for a given address
    mapping(address => EnumerableSet.UintSet) internal _stakes;
    /// @inheritdoc ICLGauge
    mapping(uint256 => uint256) public override rewardGrowthInside;

    /// @inheritdoc ICLGauge
    mapping(uint256 => uint256) public override rewards;
    /// @inheritdoc ICLGauge
    mapping(uint256 => uint256) public override lastUpdateTime;

    /// @inheritdoc ICLGauge
    uint256 public override fees0;
    /// @inheritdoc ICLGauge
    uint256 public override fees1;
    /// @inheritdoc ICLGauge
    address public override token0;
    /// @inheritdoc ICLGauge
    address public override token1;
    /// @inheritdoc ICLGauge
    int24 public override tickSpacing;

    /// @inheritdoc ICLGauge
    bool public override isPool;

    /// @inheritdoc ICLGauge
    function initialize(
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _nft,
        address _token0,
        address _token1,
        int24 _tickSpacing,
        bool _isPool
    ) external override {
        require(address(pool) == address(0), "AI");
        pool = ICLPool(_pool);
        feesVotingReward = _feesVotingReward;
        rewardToken = _rewardToken;
        voter = IVoter(_voter);
        nft = INonfungiblePositionManager(_nft);
        token0 = _token0;
        token1 = _token1;
        tickSpacing = _tickSpacing;
        isPool = _isPool;
    }

    // updates the claimable rewards and lastUpdateTime for tokenId
    function _updateRewards(uint256 tokenId, int24 tickLower, int24 tickUpper) internal {
        if (lastUpdateTime[tokenId] == block.timestamp) return;
        pool.updateRewardsGrowthGlobal();
        lastUpdateTime[tokenId] = block.timestamp;
        rewards[tokenId] += _earned(tokenId);
        rewardGrowthInside[tokenId] = pool.getRewardGrowthInside(tickLower, tickUpper, 0);
    }

    /// @inheritdoc ICLGauge
    function earned(address account, uint256 tokenId) external view override returns (uint256) {
        require(_stakes[account].contains(tokenId), "NA");

        return _earned(tokenId);
    }

    function _earned(uint256 tokenId) internal view returns (uint256) {
        uint256 lastUpdated = pool.lastUpdated();

        uint256 timeDelta = block.timestamp - lastUpdated;

        uint256 rewardGrowthGlobalX128 = pool.rewardGrowthGlobalX128();
        uint256 rewardReserve = pool.rewardReserve();

        if (timeDelta != 0 && rewardReserve > 0 && pool.stakedLiquidity() > 0) {
            uint256 reward = rewardRate * timeDelta;
            if (reward > rewardReserve) reward = rewardReserve;

            rewardGrowthGlobalX128 += FullMath.mulDiv(reward, FixedPoint128.Q128, pool.stakedLiquidity());
        }

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = nft.positions(tokenId);

        uint256 rewardPerTokenInsideInitialX128 = rewardGrowthInside[tokenId];
        uint256 rewardPerTokenInsideX128 = pool.getRewardGrowthInside(tickLower, tickUpper, rewardGrowthGlobalX128);

        uint256 claimable =
            FullMath.mulDiv(rewardPerTokenInsideX128 - rewardPerTokenInsideInitialX128, liquidity, FixedPoint128.Q128);
        return claimable;
    }

    /// @inheritdoc ICLGauge
    function getReward(address account) external override nonReentrant {
        require(msg.sender == address(voter), "NV");

        uint256[] memory tokenIds = _stakes[account].values();
        uint256 length = tokenIds.length;
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
        for (uint256 i = 0; i < length; i++) {
            tokenId = tokenIds[i];
            (,,,,, tickLower, tickUpper,,,,,) = nft.positions(tokenId);
            _getReward(tickLower, tickUpper, tokenId, account);
        }
    }

    /// @inheritdoc ICLGauge
    function getReward(uint256 tokenId) external override nonReentrant {
        require(_stakes[msg.sender].contains(tokenId), "NA");

        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nft.positions(tokenId);
        _getReward(tickLower, tickUpper, tokenId, msg.sender);
    }

    function _getReward(int24 tickLower, int24 tickUpper, uint256 tokenId, address owner) internal {
        _updateRewards(tokenId, tickLower, tickUpper);

        uint256 reward = rewards[tokenId];

        if (reward > 0) {
            delete rewards[tokenId];
            IERC20(rewardToken).safeTransfer(owner, reward);
            emit ClaimRewards(owner, reward);
        }
    }

    /// @inheritdoc ICLGauge
    function deposit(uint256 tokenId) external override nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "NA");
        require(voter.isAlive(address(this)), "GK");
        (,, address _token0, address _token1, int24 _tickSpacing, int24 tickLower, int24 tickUpper,,,,,) =
            nft.positions(tokenId);
        require(token0 == _token0 && token1 == _token1 && tickSpacing == _tickSpacing, "PM");

        // trigger update on staked position so NFT will be in sync with the pool
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        _stakes[msg.sender].add(tokenId);

        (,,,,,,, uint128 liquidityToStake,,,,) = nft.positions(tokenId);
        pool.stake(liquidityToStake.toInt128(), tickLower, tickUpper, true);

        uint256 rewardGrowth = pool.getRewardGrowthInside(tickLower, tickUpper, 0);
        rewardGrowthInside[tokenId] = rewardGrowth;
        lastUpdateTime[tokenId] = block.timestamp;

        emit Deposit(msg.sender, tokenId, liquidityToStake);
    }

    /// @inheritdoc ICLGauge
    function withdraw(uint256 tokenId) external override nonReentrant {
        require(_stakes[msg.sender].contains(tokenId), "NA");

        // trigger update on staked position so NFT will be in sync with the pool
        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidityToStake,,,,) = nft.positions(tokenId);
        _getReward(tickLower, tickUpper, tokenId, msg.sender);

        // update virtual liquidity in pool only if token has existing liquidity
        // i.e. not all removed already via decreaseStakedLiquidity
        if (liquidityToStake != 0) {
            pool.stake(-liquidityToStake.toInt128(), tickLower, tickUpper, true);
        }

        _stakes[msg.sender].remove(tokenId);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Withdraw(msg.sender, tokenId, liquidityToStake);
    }

    /// @inheritdoc ICLGauge
    function increaseStakedLiquidity(
        uint256 tokenId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external override nonReentrant returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        require(_stakes[msg.sender].contains(tokenId), "NA");
        require(voter.isAlive(address(this)), "GK");

        // NFT manager will send these tokens to the pool
        IERC20(token0).safeIncreaseAllowance(address(nft), amount0Desired);
        IERC20(token1).safeIncreaseAllowance(address(nft), amount1Desired);

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1Desired);

        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nft.positions(tokenId);
        _updateRewards(tokenId, tickLower, tickUpper);

        (liquidity, amount0, amount1) = nft.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            })
        );

        pool.stake(liquidity.toInt128(), tickLower, tickUpper, false);

        uint256 amount0Surplus = amount0Desired - amount0;
        uint256 amount1Surplus = amount1Desired - amount1;

        if (amount0Surplus > 0) {
            IERC20(token0).safeTransfer(msg.sender, amount0Surplus);
        }
        if (amount1Surplus > 0) {
            IERC20(token1).safeTransfer(msg.sender, amount1Surplus);
        }
    }

    /// @inheritdoc ICLGauge
    function decreaseStakedLiquidity(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external override nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(_stakes[msg.sender].contains(tokenId), "NA");

        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nft.positions(tokenId);
        _updateRewards(tokenId, tickLower, tickUpper);

        (amount0, amount1) = nft.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            })
        );

        pool.stake(-liquidity.toInt128(), tickLower, tickUpper, false);

        nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: uint128(amount0),
                amount1Max: uint128(amount1)
            })
        );
    }

    /// @inheritdoc ICLGauge
    function stakedContains(address depositor, uint256 tokenId) external view override returns (bool) {
        return _stakes[depositor].contains(tokenId);
    }

    /// @inheritdoc ICLGauge
    function stakedLength(address depositor) external view override returns (uint256) {
        return _stakes[depositor].length();
    }

    function left() external view override returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    /// @inheritdoc ICLGauge
    function notifyRewardAmount(uint256 _amount) external override nonReentrant {
        address sender = msg.sender;
        require(sender == address(voter), "NV");
        require(_amount != 0, "ZR");
        _claimFees();
        _notifyRewardAmount(sender, _amount);
    }

    /// @inheritdoc ICLGauge
    function notifyRewardWithoutClaim(uint256 _amount) external override nonReentrant {
        address sender = msg.sender;
        require(sender == IVotingEscrow(voter.ve()).team(), "NT");
        require(_amount != 0, "ZR");
        _notifyRewardAmount(sender, _amount);
    }

    function _notifyRewardAmount(address _sender, uint256 _amount) internal {
        uint256 timestamp = block.timestamp;
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(timestamp) - timestamp;
        pool.updateRewardsGrowthGlobal();
        uint256 nextPeriodFinish = timestamp + timeUntilNext;

        IERC20(rewardToken).safeTransferFrom(_sender, address(this), _amount);
        // rolling over stuck rewards from previous epoch (if any)
        _amount += pool.rollover();

        if (timestamp >= periodFinish) {
            rewardRate = _amount / timeUntilNext;
            pool.syncReward({rewardRate: rewardRate, rewardReserve: _amount, periodFinish: nextPeriodFinish});
        } else {
            uint256 _leftover = timeUntilNext * rewardRate;
            rewardRate = (_amount + _leftover) / timeUntilNext;
            pool.syncReward({rewardRate: rewardRate, rewardReserve: _amount + _leftover, periodFinish: nextPeriodFinish});
        }
        rewardRateByEpoch[VelodromeTimeLibrary.epochStart(timestamp)] = rewardRate;
        require(rewardRate != 0, "ZRR");

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        require(rewardRate <= balance / timeUntilNext, "RRH");

        periodFinish = nextPeriodFinish;
        emit NotifyReward(_sender, _amount);
    }

    function _claimFees() internal {
        if (!isPool) return;

        (uint256 claimed0, uint256 claimed1) = pool.collectFees();
        if (claimed0 > 0 || claimed1 > 0) {
            uint256 _fees0 = fees0 + claimed0;
            uint256 _fees1 = fees1 + claimed1;
            address _token0 = token0;
            address _token1 = token1;
            if (_fees0 > VelodromeTimeLibrary.WEEK) {
                fees0 = 0;
                IERC20(_token0).safeIncreaseAllowance(feesVotingReward, _fees0);
                IReward(feesVotingReward).notifyRewardAmount(_token0, _fees0);
            } else {
                fees0 = _fees0;
            }
            if (_fees1 > VelodromeTimeLibrary.WEEK) {
                fees1 = 0;
                IERC20(_token1).safeIncreaseAllowance(feesVotingReward, _fees1);
                IReward(feesVotingReward).notifyRewardAmount(_token1, _fees1);
            } else {
                fees1 = _fees1;
            }

            emit ClaimFees(msg.sender, claimed0, claimed1);
        }
    }
}
