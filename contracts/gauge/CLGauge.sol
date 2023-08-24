// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {ICLGauge} from "contracts/gauge/interfaces/ICLGauge.sol";
import {IVoter} from "contracts/core/interfaces/IVoter.sol";
import {IUniswapV3Pool} from "contracts/core/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {SafeCast} from "contracts/gauge/libraries/SafeCast.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {FixedPoint128} from "contracts/core/libraries/FixedPoint128.sol";
import {VelodromeTimeLibrary} from "contracts/libraries/VelodromeTimeLibrary.sol";

contract CLGauge is ICLGauge, ERC721Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using SafeCast for uint128;

    /// @inheritdoc ICLGauge
    INonfungiblePositionManager public override nft;
    /// @inheritdoc ICLGauge
    IVoter public override voter;
    /// @inheritdoc ICLGauge
    IUniswapV3Pool public override pool;

    /// @inheritdoc ICLGauge
    address public override forwarder;
    /// @inheritdoc ICLGauge
    address public override feesVotingReward;
    /// @inheritdoc ICLGauge
    address public override rewardToken;
    /// @inheritdoc ICLGauge
    bool public override isPool;

    /// @inheritdoc ICLGauge
    uint256 public override periodFinish;
    /// @inheritdoc ICLGauge
    uint256 public override rewardRate;
    /// @inheritdoc ICLGauge
    uint256 public override lastUpdateTime; // TODO might be removed once we implement getReward

    mapping(uint256 => uint256) public override rewardRateByEpoch; // epochStart => rewardRate
    /// @dev The set of all staked nfts for a given address
    mapping(address => EnumerableSet.UintSet) internal _stakes;
    /// @inheritdoc ICLGauge
    mapping(uint256 => uint256) public override rewardGrowthInside;

    /// @inheritdoc ICLGauge
    function initialize(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _nft,
        bool _isPool
    ) external override {
        require(address(pool) == address(0), "AI");
        forwarder = _forwarder;
        pool = IUniswapV3Pool(_pool);
        feesVotingReward = _feesVotingReward;
        rewardToken = _rewardToken;
        voter = IVoter(_voter);
        nft = INonfungiblePositionManager(_nft);
        isPool = _isPool;
    }

    /// @inheritdoc ICLGauge
    function earned(address account, uint256 tokenId) external view override returns (uint256) {
        require(_stakes[account].contains(tokenId), "NA");

        return _earned(tokenId);
    }

    function _earned(uint256 tokenId) internal view returns (uint256) {
        uint256 timeDelta = block.timestamp - pool.lastUpdated();

        uint256 rewardGrowthGlobalX128 = pool.rewardGrowthGlobalX128();
        uint256 rewardReserve = pool.rewardReserve();

        if (timeDelta != 0 && pool.stakedLiquidity() > 0 && rewardRate > 0 && rewardReserve > 0) {
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
    function getReward(uint256 tokenId) external override nonReentrant {
        require(_stakes[msg.sender].contains(tokenId), "NA");

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = nft.positions(tokenId);
        _getReward(tickLower, tickUpper, liquidity, tokenId, msg.sender);
    }

    function _getReward(int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 tokenId, address owner) internal {
        pool.updateRewardsGrowthGlobal();
        uint256 rewardPerTokenInsideInitialX128 = rewardGrowthInside[tokenId];
        uint256 rewardPerTokenInsideX128 = pool.getRewardGrowthInside(tickLower, tickUpper, 0);
        uint256 reward =
            FullMath.mulDiv(rewardPerTokenInsideX128 - rewardPerTokenInsideInitialX128, liquidity, FixedPoint128.Q128);
        if (reward > 0) {
            IERC20(rewardToken).safeTransfer(owner, reward);
            emit ClaimRewards(owner, reward);
        }
        rewardGrowthInside[tokenId] = rewardPerTokenInsideX128;
    }

    /// @inheritdoc ICLGauge
    function deposit(uint256 tokenId) external override nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "NA");
        require(voter.isAlive(address(this)), "GK");

        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        _stakes[msg.sender].add(tokenId);

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidityToStake,,,,) = nft.positions(tokenId);
        uint256 rewardGrowth = pool.getRewardGrowthInside(tickLower, tickUpper, 0);
        rewardGrowthInside[tokenId] = rewardGrowth;

        pool.stake(liquidityToStake.toInt128(), tickLower, tickUpper);

        emit Deposit(msg.sender, tokenId, liquidityToStake);
    }

    /// @inheritdoc ICLGauge
    function withdraw(uint256 tokenId) external override nonReentrant {
        require(_stakes[msg.sender].contains(tokenId), "NA");

        _stakes[msg.sender].remove(tokenId);
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidityToStake,,,,) = nft.positions(tokenId);
        _getReward(tickLower, tickUpper, liquidityToStake, tokenId, msg.sender);

        pool.stake(-liquidityToStake.toInt128(), tickLower, tickUpper);

        emit Withdraw(msg.sender, tokenId, liquidityToStake);
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

    function notifyRewardAmount(uint256 _amount) external override nonReentrant {
        address sender = msg.sender;
        require(sender == address(voter), "NV");
        require(_amount != 0, "ZR");
        //_claimFees(); // TODO add this as well when due

        uint256 timestamp = block.timestamp;
        uint256 timeUntilNext = VelodromeTimeLibrary.epochNext(timestamp) - timestamp;

        if (timestamp >= periodFinish) {
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = _amount / timeUntilNext;
            pool.syncReward(rewardRate, _amount);
        } else {
            uint256 _remaining = periodFinish - timestamp;
            uint256 _leftover = _remaining * rewardRate;
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = (_amount + _leftover) / timeUntilNext;
            pool.syncReward(rewardRate, _amount + _leftover);
        }
        rewardRateByEpoch[VelodromeTimeLibrary.epochStart(timestamp)] = rewardRate;
        require(rewardRate != 0, "ZRR");

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        require(rewardRate <= balance / timeUntilNext, "RRH");

        lastUpdateTime = timestamp;
        periodFinish = timestamp + timeUntilNext;
        emit NotifyReward(sender, _amount);
    }
}
