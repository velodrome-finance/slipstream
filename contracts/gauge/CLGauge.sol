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
    function deposit(uint256 tokenId) external override nonReentrant {
        require(nft.ownerOf(tokenId) == msg.sender, "NA");
        require(voter.isAlive(address(this)), "GK");

        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        _stakes[msg.sender].add(tokenId);

        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidityToStake,,,,) = nft.positions(tokenId);
        uint256 rewardGrowth = pool.getRewardGrowthInside(tickLower, tickUpper);
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
        // TODO: claim rewards, update rewardGrowthInside

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
}
