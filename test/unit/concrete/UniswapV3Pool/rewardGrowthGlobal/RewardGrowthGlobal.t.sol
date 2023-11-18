pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3PoolTest} from "../UniswapV3Pool.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "contracts/core/libraries/FullMath.sol";

contract RewardGrowthGlobalTest is UniswapV3PoolTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    int24 tickSpacing = TICK_SPACING_60;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: tickSpacing,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(voter.gauges(address(pool)));

        vm.startPrank(users.alice);

        skipToNextEpoch(0);
    }

    function mintNewFullRangePositionAndDepositIntoGauge(uint256 _amount0, uint256 _amount1, address _user)
        internal
        returns (uint256)
    {
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(_amount0, _amount1, _user);
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
        uint128 liquidity = 10e18;
        uint128 stakedLiquidity = 10e18;

        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

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
        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 hours;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWithDelayedRewardDistribute() public {
        uint128 stakedLiquidity = 10e18;

        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

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
        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 1 hours;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);
    }

    function test_DelayedDistributeUpdatesAccumulatorAtTheEndOfTheEpochCorrectlyComparedToOnTimeDistribute() public {
        uint128 stakedLiquidity = 10e18;

        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1 * 10;

        // SNAPSHOT STATE //
        uint256 snapshot = vm.snapshot();
        addRewardToGauge(address(voter), address(gauge), reward);

        // move one week and trigger update by minting new position
        skip(WEEK);
        // mint new position and stake it as well to trigger update
        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

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
        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

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
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId = mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

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

    function test_RewardGrowthGlobalUpdatesCorrectlyCrossingInitializedTicks() public {
        uint128 liquidity = 10e18;
        uint128 stakedLiquidity = 10e18;

        mintNewFullRangePositionAndDepositIntoGauge(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

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
        assertEqUint(pool.stakedLiquidity(), stakedLiquidity);

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

    function test_StuckRewardsRolledOverToNextEpochIfThereIsNoStakedLiquidityAtRewardDistribution() public {
        uint128 liquidity = 10e18;
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

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
        assertEqUint(pool.timeNoStakedLiquidity(), WEEK / 2);

        skipToNextEpoch(0);

        // mint new position and stake it as well to trigger update
        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId2);
        gauge.deposit(tokenId2);

        accumulatedReward = rewardRate * WEEK / 2;
        // stakedLiquidity will not contain the newly staked liq at this point
        rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        // we are validating an undesirabled state, this should roll over to the next epoch
        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertApproxEqAbs(pool.rewardReserve(), reward / 2, 1e5);

        assertEqUint(pool.timeNoStakedLiquidity(), WEEK / 2);
        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2, 1e5);

        // assert that emissions gots stuck in the gauge
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 2, 1e5);

        addRewardToGauge(address(voter), address(gauge), reward);

        rewardRate = pool.rewardRate();

        // rewardRate and rewardReserve should account for stuck rewards from previous epoch
        assertEqUint(rewardRate, (reward + reward / 2) / WEEK);
        assertApproxEqAbs(pool.rewardReserve(), reward + reward / 2, 1e5);
        assertEqUint(pool.timeNoStakedLiquidity(), 0);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        // we assert that the stuck rewards get rolled over to the next epoch correctly
        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2 + (reward + reward / 2) / 2, 1e6);

        gauge.getReward(tokenId2);
        uint256 aliceRewardBalanceTokenId2 = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalanceTokenId2, aliceRewardBalance + (reward + reward / 2) / 2, 1e6);

        gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, 0, 1e6);
    }

    function test_RewardsRolledOverIfThereAreHolesInStakedLiquidityWithDepositAndWithdraw() public {
        // adding 29953549559107810 as amount0 and amount1 will be equal to ~10 liquidity
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
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

        assertEqUint(pool.timeNoStakedLiquidity(), 1 days);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        // alice rewards should be 6 days worth of reward
        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 7 * 6, 1e5);

        // at the start of the new epoch reserves should be 1 day worth of reward
        assertApproxEqAbs(pool.rewardReserve(), reward / 7, 1e5);

        // assert that emissions got stuck in the gauge for the current epoch, 1 day worth of reward
        // will be rolled over to next epoch
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 7, 1e5);

        addRewardToGauge(address(voter), address(gauge), reward);

        uint256 rewardRate = pool.rewardRate();

        // rewardRate and rewardReserve should account for stuck rewards from previous epoch
        assertEqUint(rewardRate, (reward + reward / 7) / WEEK);
        assertApproxEqAbs(pool.rewardReserve(), reward + reward / 7, 1e5);
        assertEqUint(pool.timeNoStakedLiquidity(), 0);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        // we assert that the stuck rewards get rolled over to the next epoch correctly
        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward * 2, 1e6);

        gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, 0, 1e6);
    }

    function test_RewardsRolledOverIfThereAreHolesInStakedLiquidityWithSwap() public {
        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // adding 29953549559107810 as amount0 and amount1 will be equal to ~10 liquidity
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            29953549559107810, 29953549559107810, -tickSpacing, tickSpacing, users.alice
        );
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint128 stakedLiquidity = pool.stakedLiquidity();
        assertApproxEqAbs(uint256(stakedLiquidity), 10e18, 1e3);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // move 3 days and swap to move out from stakedLiquidity range
        skip(3 days);
        vm.startPrank(users.alice);
        uniswapV3Callee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        assertEqUint(pool.stakedLiquidity(), 0);

        // 1 day worth of rewards not accumulating
        skip(1 days);

        // swapping 86e16 puts back the price into the range where both positions are active
        uniswapV3Callee.swapExact1For0(address(pool), 86e16, users.alice, MAX_SQRT_RATIO - 1);

        assertEqUint(pool.stakedLiquidity(), stakedLiquidity);

        skip(1 days);

        // collect rewards to trigger update on accumulator
        gauge.getReward(tokenId);

        uint256 rewardRate = pool.rewardRate();
        uint256 accumulatedReward = rewardRate * 4 days;
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        // we are validating an undesirabled state, probably will change
        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertApproxEqAbs(pool.rewardReserve(), reward / 7 * 3, 1e6);
        assertEqUint(pool.timeNoStakedLiquidity(), 1 days);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        //assert that emissions gots stuck in the gauge
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 7, 1e6);

        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        // we assert that the stuck rewards get rolled over to the next epoch correctly
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward * 2, 1e6);

        gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, 0, 1e6);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWhenRewardReserveIsZeroAndRewardRateGreaterThanZeroUpdateTriggeredByWithdraw(
    ) public {
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(1);

        // withdraw to update RewardGrowthGlobal
        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        // calculate the rewardRate by hand because we lose some precision during the division
        uint256 rewardRate = reward / WEEK;
        uint256 accumulatedReward = rewardRate * WEEK;
        // all rewardReserves should be accounted in the accumulator
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEq(pool.rewardRate(), reward / WEEK);
        assertApproxEqAbs(pool.rewardReserve(), 0, 1e5);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWhenRewardReserveIsZeroAndRewardRateGreaterThanZeroUpdateTriggeredByNextNotify(
    ) public {
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(1);

        // add new rewards to update RewardGrowthGlobal
        addRewardToGauge(address(voter), address(gauge), reward);

        // calculate the rewardRate by hand because we lose some precision during the division
        uint256 previousRewardRate = reward / WEEK;
        uint256 accumulatedReward = previousRewardRate * WEEK;

        // all rewardReserves should be accounted in the accumulator
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEq(pool.rewardRate(), reward / (WEEK - 1));
        assertEqUint(pool.rewardReserve(), reward);

        // sanity checks
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward * 2, 1e6);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, accumulatedReward, 1);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWhenNoStakeLiquidityPresentForMoreThanOneEpoch() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(60);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertEq(pool.timeNoStakedLiquidity(), WEEK + 60);

        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.timeNoStakedLiquidity(), 0);

        assertEqUint(pool.rewardGrowthGlobalX128(), 0);
        assertEq(pool.rewardRate(), (reward * 2) / (WEEK - 60));
        assertApproxEqAbs(pool.rewardReserve(), reward * 2, 1e6);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, 0, 1e6);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward * 2, 1e6);
    }

    function test_RewardGrowthNoRollover() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / WEEK);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // roll half a week, then withdraw
        skip(WEEK / 2);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(0);
        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEq(gauge.rewardRate(), (reward * 2 + reward / 2) / (7 days));

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, TOKEN_1 * 3, 1e6);
    }

    function test_RewardGrowthDelayedRollover() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / WEEK);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // roll half a week, then withdraw
        skip(WEEK / 2);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(1 days);
        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEq(gauge.rewardRate(), (reward * 2 + reward / 2) / (6 days));

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, TOKEN_1 * 3, 1e6);
    }

    function test_RewardGrowthEpochSkipped() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / WEEK);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // roll half a week, then withdraw
        skip(WEEK / 2);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(0);
        // one epoch skipped entirely
        skipToNextEpoch(1 days);
        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEq(gauge.rewardRate(), (reward * 2 + reward / 2) / (6 days));

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, TOKEN_1 * 3, 1e6);
    }

    function test_RewardGrowthEpochSkippedNoDelay() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / WEEK);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // roll half a week, then withdraw
        skip(WEEK / 2);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(0);
        // one epoch skipped entirely
        skipToNextEpoch(0);
        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEq(gauge.rewardRate(), (reward * 2 + reward / 2) / (7 days));

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, TOKEN_1 * 3, 1e6);
    }

    function test_RewardGrowthMultipleEpochSkippedDelayed() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / WEEK);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // roll half a week, then withdraw
        skip(WEEK / 2);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(0);
        // skip multiple epoch
        skipToNextEpoch(0);
        // delay
        skipToNextEpoch(1 days);
        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEq(gauge.rewardRate(), (reward * 2 + reward / 2) / (6 days));

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, TOKEN_1 * 3, 1e6);
    }

    function test_RewardGrowthMultipleEpochSkippedNoDelay() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        assertEq(gauge.rewardRate(), reward / WEEK);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // roll half a week, then withdraw
        skip(WEEK / 2);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(0);
        // skip multiple epoch
        skipToNextEpoch(0);
        skipToNextEpoch(0);
        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEq(gauge.rewardRate(), (reward * 2 + reward / 2) / (7 days));

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, TOKEN_1 * 3, 1e6);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWithUnstakedLiquidityBothAtTheStartAndEndOfTheEpoch() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(60);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skip(WEEK - 120);

        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / WEEK * (WEEK - 120), 1e6);
        assertApproxEqAbs(pool.rewardReserve(), reward / WEEK * 120, 1e6);
        assertEqUint(pool.timeNoStakedLiquidity(), 60); // only 60 recorded so far

        skipToNextEpoch(200);

        addRewardToGauge(address(voter), address(gauge), reward * 2);
        assertEqUint(pool.timeNoStakedLiquidity(), 0);
        assertEq(pool.rewardRate(), (reward * 2 + reward / WEEK * 120) / (WEEK - 200));
        assertApproxEqAbs(pool.rewardReserve(), (reward * 2 + reward / WEEK * 120), 1e6);
    }

    function test_RewardGrowthOnlyAccountRewardsTillTheEndOfTheEpochInCaseOfLateNotify() public {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(60);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, (reward / 7 * 6), 1e6);
        assertApproxEqAbs(pool.rewardReserve(), (reward / 7), 1e6);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWithMultipleCallsToUpdateRewardsGrowthGlobalAfterEpochFlip()
        public
    {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // tnsl
        skip(1 days);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        // the delay being accounted as well in case of tnsl
        skip(1 days);
        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward * 2, 1e6);
        assertApproxEqAbs(pool.rewardReserve(), 0, 1e6);
    }
}
