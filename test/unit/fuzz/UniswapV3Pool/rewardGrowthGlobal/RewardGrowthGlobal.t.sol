pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3PoolTest} from "../UniswapV3Pool.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "contracts/core/libraries/FullMath.sol";

contract RewardGrowthGlobalFuzzTest is UniswapV3PoolTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    int24 tickSpacing = TICK_SPACING_60;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({tokenA: address(token0), tokenB: address(token1), tickSpacing: tickSpacing})
        );
        gauge = CLGauge(voter.gauges(address(pool)));

        deal({token: address(token0), to: users.alice, give: TOKEN_1 * 100});
        deal({token: address(token1), to: users.alice, give: TOKEN_1 * 100});

        vm.startPrank(users.alice);
        token0.approve(address(uniswapV3Callee), type(uint256).max);
        token1.approve(address(uniswapV3Callee), type(uint256).max);
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);

        skipToNextEpoch(0);
    }

    function _mintNewCustomRangePositionForUser(
        uint128 amount0,
        uint128 amount1,
        int24 tickLower,
        int24 tickUpper,
        address user
    ) internal returns (uint256) {
        vm.startPrank(user);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: tickSpacing,
            tickLower: tickLower,
            tickUpper: tickUpper,
            recipient: user,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp + 1
        });
        (uint256 tokenId,,,) = nft.mint(params);
        return tokenId;
    }

    function _mintNewFullRangePositionForUser(uint128 amount0, uint128 amount1, address user)
        internal
        returns (uint256)
    {
        return
            _mintNewCustomRangePositionForUser(amount0, amount1, getMinTick(tickSpacing), getMaxTick(tickSpacing), user);
    }

    function _mintNewFullRangePositionAndDepositIntoGauge(uint128 _amount0, uint128 _amount1, address _user)
        internal
        returns (uint256)
    {
        uint256 tokenId = _mintNewFullRangePositionForUser(_amount0, _amount1, _user);
        vm.startPrank(_user);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        return tokenId;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label({account: address(uniswapV3Callee), newLabel: "Test UniswapV3 Callee"});
        vm.label({account: address(pool), newLabel: "Pool"});
        vm.label({account: address(gauge), newLabel: "Gauge"});
    }

    function testFuzz_RewardGrowthGlobalUpdatesCorrectlyWithDelayedRewardDistribute(uint256 reward, uint256 delay)
        public
    {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});
        reward = bound(reward, WEEK, type(uint128).max);
        delay = bound(delay, 1, WEEK - 1 hours);

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), reward);

        // move one hour and mint new position and stake it as well to trigger update
        skip(1 hours);
        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 hours;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), reward - accumulatedReward);
    }

    function testFuzz_RewardGrowthGlobalUpdatesCorrectlyWithdrawPosition(uint256 reward) public {
        reward = bound(reward, WEEK, type(uint128).max);

        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId = _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        addRewardToGauge(address(voter), address(gauge), reward);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward);

        // still 0 since no action triggered update on the accumulator
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        skip(1 days);

        // withdraw to update
        vm.prank(users.alice);
        gauge.withdraw(tokenId);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 days;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward - accumulatedReward);
    }

    function testFuzz_notifyRewardAmountUpdatesPoolStateCorrectlyOnAdditionalRewardInSameEpoch(uint256 reward) public {
        reward = bound(reward, WEEK, type(uint128).max);

        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});
        skip(1 days);

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(pool.rewardRate(), reward / 6 days + reward / 5 days);
        assertEqUint(pool.rewardReserve(), reward + reward / 6 days * 5 days);
        assertEqUint(pool.lastUpdated(), block.timestamp);
    }
}
