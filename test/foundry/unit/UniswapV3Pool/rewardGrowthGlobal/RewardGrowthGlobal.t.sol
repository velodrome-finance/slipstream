pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseFixture.sol";
import {TestUniswapV3Callee} from "contracts/core/test/TestUniswapV3Callee.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3PoolTest} from "../UniswapV3Pool.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "contracts/core/libraries/FullMath.sol";
import "forge-std/console.sol";

contract RewardGrowthGlobalTest is UniswapV3PoolTest {
    UniswapV3Pool public pool;
    TestUniswapV3Callee public uniswapV3Callee;
    CLGauge public gauge;

    int24 tickSpacing = TICK_SPACING_60;

    function setUp() public override {
        super.setUp();

        uniswapV3Callee = new TestUniswapV3Callee();

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
            deadline: block.timestamp
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

    function test_RewardGrowthGlobalUpdatesCorrectlyWhenRewardDistributedAtTheStartOfTheEpoch() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 liquidity = 10e18;
        uint128 stakedLiquidity = 10e18;

        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        // sanity checks
        assertEqUint(pool.liquidity(), liquidity);
        assertEqUint(pool.stakedLiquidity(), stakedLiquidity);
        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // still 0 since no action triggered update on the accumulator
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18);

        // move one hour and mint new position and stake it as well to trigger update
        skip(1 hours);
        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 hours;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWithDelayedRewardDistribute() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 delay = 1 hours;
        skip(delay);
        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), 1e18);

        // move one hour and mint new position and stake it as well to trigger update
        skip(1 hours);
        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 hours;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);
    }

    // fuzzing the previous test
    function test_RewardGrowthGlobalUpdatesCorrectlyWithFuzzDelayAndFuzzRewardDistribute(uint256 reward, uint256 delay)
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

    function test_DelayedDistributeUpdatesAccumulatorAtTheEndOfTheEpochCorrectlyComparedToOnTimeDistribute() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 reward = TOKEN_1 * 10;

        // SNAPSHOT STATE //
        uint256 snapshot = vm.snapshot();
        addRewardToGauge(address(voter), address(gauge), reward);

        // move one week and trigger update by minting new position
        skip(WEEK);
        // mint new position and stake it as well to trigger update
        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 rewardReserveNoDelay = pool.rewardReserve();
        uint256 rewardsForNoDelay = FullMath.mulDiv(pool.rewardGrowthGlobalX128(), stakedLiquidity, Q128);

        // REVERT STATE //
        vm.revertTo(snapshot);

        // sanity check to for successfull revert
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        // we move the reward distribution by 1 hour as oppose to the previous where we distribute at epoch start
        skip(1 hours);
        addRewardToGauge(address(voter), address(gauge), reward);

        // move one week minus the delay and trigger update by minting new position
        // moves time to epoch flip boundary
        skip(WEEK - 1 hours);
        // mint new position and stake it as well to trigger update
        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 rewardReserveDelayed = pool.rewardReserve();
        uint256 rewardsForDelayed = FullMath.mulDiv(pool.rewardGrowthGlobalX128(), stakedLiquidity, Q128);

        // at the end of the epoch (not flipped) for the same period
        // the whole reward amount should be accounted in the accumulator,
        // hence rewards should be correct (not counting dust)
        assertApproxEqAbs(rewardReserveNoDelay, rewardReserveDelayed, 1e6);
        assertApproxEqAbs(rewardsForNoDelay, rewardsForDelayed, 1e6);

        assertApproxEqAbs(rewardReserveNoDelay + rewardsForNoDelay, reward, 1);
        assertApproxEqAbs(rewardsForNoDelay + rewardReserveNoDelay, reward, 1);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWithdrawPosition() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId = _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18);

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
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);
    }

    // fuzzing the previous test
    function test_RewardGrowthGlobalUpdatesCorrectlyWithdrawPositionWithFuzzReward(uint256 reward) public {
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
        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 days;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward - accumulatedReward);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyCrossingInitializedTicks() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 liquidity = 10e18;
        uint128 stakedLiquidity = 10e18;

        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        // this takes 29953549559107810 tokens (0.0299...) from each
        uniswapV3Callee.mint(address(pool), users.alice, -tickSpacing, tickSpacing, liquidity);

        // sanity checks
        assertEqUint(pool.liquidity(), liquidity + stakedLiquidity);
        assertEqUint(pool.stakedLiquidity(), stakedLiquidity);
        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // still 0 since no action triggered update on the accumulator
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18);

        // move one hour and swap to trigger update
        skip(1 hours);

        //swap here for update
        vm.prank(users.alice);
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        // we moved out from the tighter liquidity range to the full range liq
        assertEqUint(pool.liquidity(), liquidity);
        // TODO put this back once stakedLiquidity on swaps are updated
        // assertEqUint(pool.stakedLiquidity(), 0);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 hours;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);

        skip(1 hours);

        vm.prank(users.alice);
        // swapping 86e16 puts back the price into the range where both positions are active
        uniswapV3Callee.swapExact1For0(address(pool), 86e16, users.alice, MAX_SQRT_RATIO - 1);

        assertEqUint(pool.liquidity(), liquidity + stakedLiquidity);

        accumulatedReward = rewardRate * 2 hours;
        rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);
    }

    function test_RewardsGetStuckIfThereIsNoStakedLiquidityAtRewardDistribution() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 liquidity = 10e18;
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId = _mintNewFullRangePositionForUser(amount0, amount1, users.alice);

        // sanity checks
        assertEqUint(pool.liquidity(), liquidity);
        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // still 0 since no action triggered update on the accumulator
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18);

        // move half a week and deposit to trigger update
        skip(WEEK / 2);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * WEEK / 2;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), 0);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward);

        skip(WEEK / 2);
        // mint new position and stake it as well to trigger update
        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        accumulatedReward = rewardRate * WEEK;
        // stakedLiquidity will not contain the newly staked liq at this point
        rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        // we are validating an undesirabled state, probably will change
        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128 / 2);
        assertApproxEqAbs(pool.rewardReserve(), reward / 2, 1e5);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2, 1e5);

        // assert that emissions gots stuck in the gauge
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 2, 1e5);
    }

    function test_RewardsGetStuckIfThereAreHolesInStakedLiquidityWithDepositAndWithdraw() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        // adding 29953549559107810 as amount0 and amount1 will be equal to ~10 liquidity
        uint256 tokenId = _mintNewCustomRangePositionForUser(
            29953549559107810, 29953549559107810, -tickSpacing, tickSpacing, users.alice
        );

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint128 stakedLiquidity = pool.stakedLiquidity();
        assertApproxEqAbs(uint256(stakedLiquidity), 10e18, 1e3);

        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // move 3 days and withdraw to remove stakedLiquidity
        skip(3 days);
        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 3, 1e5);

        assertEqUint(pool.stakedLiquidity(), 0);

        // skipping 1 day, won't generate rewards which is desirable but rewards get stuck in gauge
        skip(1 days);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        // alice rewards should be 6 days worth of reward
        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 6, 1e5);

        // at the start of the new epoch reserves should be 1 day worth of reward
        assertApproxEqAbs(pool.rewardReserve(), reward / 7, 1e5);

        // assert that emissions got stuck in the gauge, 1 day worth of reward
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 7 * 1, 1e5);
    }

    // TODO finnish once stakedLiq is updated in swap
    function _test_RewardsGetStuckIfThereAreHolesInStakedLiquidityWithSwap() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 liquidity = 10e18;

        _mintNewFullRangePositionForUser(amount0, amount1, users.alice);

        // adding 29953549559107810 as amount0 and amount1 will be equal to ~10 liquidity
        uint256 tokenId = _mintNewCustomRangePositionForUser(
            29953549559107810, 29953549559107810, -tickSpacing, tickSpacing, users.alice
        );
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint128 stakedLiquidity = pool.stakedLiquidity();
        assertApproxEqAbs(uint256(stakedLiquidity), 10e18, 1e3);

        // sanity checks
        assertEqUint(pool.liquidity(), liquidity + stakedLiquidity);
        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // still 0 since no action triggered update on the accumulator
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18);

        // move half a week and swap to move out from stakedLiquidity range
        skip(WEEK / 2);
        vm.startPrank(users.alice);
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        assertEqUint(pool.stakedLiquidity(), 0);

        skip(1 days);

        // swapping 86e16 puts back the price into the range where both positions are active
        uniswapV3Callee.swapExact1For0(address(pool), 86e16, users.alice, MAX_SQRT_RATIO - 1);

        skip(1 days);
        // add new stakedLiquidty to trigger an update on the accumulator
        _mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * (WEEK / 2 + 1 days);
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        // we are validating an undesirabled state, probably will change
        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertApproxEqAbs(pool.rewardReserve(), reward / 2, 1e6);

        // TODO finnish this

        // vm.prank(users.alice);
        // gauge.getReward(tokenId);

        // //assert that emissions gots stuck in the gauge
        // uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        // assertApproxEqAbs(gaugeRewardTokenBalance, reward / 2, 1e6);
    }

    function test_notifyRewardAmountUpdatesPoolStateCorrectlyOnAdditionalRewardInSameEpoch() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});
        skip(1 days);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(pool.rewardRate(), reward / 6 days + reward / 5 days);
        assertEqUint(pool.rewardReserve(), reward + reward / 6 days * 5 days);
        assertEqUint(pool.lastUpdated(), block.timestamp);
    }

    // fuzzing the previous test
    function test_notifyRewardAmountUpdatesPoolStateCorrectlyOnAdditionalFuzzRewardInSameEpoch(uint256 reward) public {
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
