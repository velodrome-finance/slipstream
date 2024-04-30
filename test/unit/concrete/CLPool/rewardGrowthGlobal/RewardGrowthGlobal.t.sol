pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLPoolTest} from "../CLPool.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "contracts/core/libraries/FullMath.sol";

contract RewardGrowthGlobalTest is CLPoolTest {
    CLPool public pool;
    CLGauge public gauge;

    int24 tickSpacing = TICK_SPACING_60;

    function setUp() public override {
        super.setUp();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: tickSpacing,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(payable(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)})));

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
        vm.label({account: address(clCallee), newLabel: "Test CL Callee"});
        vm.label({account: address(pool), newLabel: "Pool"});
        vm.label({account: address(gauge), newLabel: "Gauge"});
    }

    //@dev This function asserts the values of the Rewards to be Rolled Over
    function assertRollover(uint256 reward, uint256 timeNoStakedLiq, uint256 timeElapsed) internal {
        uint256 rewardRate = reward / WEEK;
        uint256 rollover = rewardRate * timeNoStakedLiq;

        uint256 accumulatedReward = rewardRate * (timeElapsed - timeNoStakedLiq);
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, pool.stakedLiquidity());

        assertApproxEqAbs(rewardToken.balanceOf(users.alice), accumulatedReward, 1e5);
        assertApproxEqAbs(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128, 1e4);

        assertEqUint(pool.rewardRate(), rewardRate);
        assertEqUint(pool.rollover(), rollover);
        assertApproxEqAbs(pool.rewardReserve(), rewardRate * (WEEK - timeElapsed), 1e5);
    }

    //@dev This function skips to next Epoch and asserts the values of claimed and rolled over Reward Balances
    function assertRolloverRewardsAfterEpochFlip(
        uint256 tokenId,
        uint256 reward1,
        uint256 reward2,
        uint256 timeNoStakedLiq
    ) internal {
        uint256 rewardRate = reward1 / WEEK;
        uint256 rollover = rewardRate * timeNoStakedLiq;

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        // alice rewards should be `WEEK - timeNoStakedLiq` worth of rewards
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, rewardRate * (WEEK - timeNoStakedLiq), 1e5);

        // at the start of the new epoch reserves should be dust
        assertApproxEqAbs(pool.rewardReserve(), reward1 - reward1 / WEEK * WEEK, 1e5);

        // assert that emissions got stuck in the gauge for the current epoch,
        // `timeNoStakedLiq` worth of rewards will be rolled over to next epoch
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, rollover, 1e5);

        addRewardToGauge(address(voter), address(gauge), reward2);

        // rewardRate and rewardReserve should account for stuck rewards from previous epoch
        assertEqUint(pool.rewardRate(), (reward2 + rollover) / WEEK);
        assertApproxEqAbs(pool.rewardReserve(), reward2 + rollover, 1e5);
        assertEqUint(pool.rollover(), 0);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        // we assert that the stuck rewards get rolled over to the next epoch correctly
        aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward1 + reward2, 1e6);

        gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertLe(gaugeRewardTokenBalance, 1e6);
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
        clCallee.mint(address(pool), users.alice, -tickSpacing, tickSpacing, liquidity);

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
        clCallee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

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
        clCallee.swapExact1For0(address(pool), 86e16, users.alice, MAX_SQRT_RATIO - 1);

        assertEqUint(pool.liquidity(), liquidity + stakedLiquidity);

        accumulatedReward = rewardRate * 2 hours;
        rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(rewardRate, reward / WEEK);
        assertEqUint(pool.rewardReserve(), 1e18 - accumulatedReward);
    }

    function test_RewardsRolledOverToNextEpochIfThereIsNoStakedLiquidityAtRewardDistribution() public {
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
        uint256 rollover = reward / WEEK * (WEEK / 2);
        assertEqUint(pool.rewardReserve(), reward - rollover);
        assertEqUint(pool.rollover(), rollover);

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
        rollover = reward / WEEK * (WEEK / 2);
        assertApproxEqAbs(pool.rewardReserve(), reward / 2 - rollover, 1e5);
        assertEqUint(pool.rollover(), rollover);
        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward / 2, 1e5);

        // assert that emissions got stuck in the gauge
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward / 2, 1e5);

        addRewardToGauge(address(voter), address(gauge), reward);

        rewardRate = pool.rewardRate();

        // rewardRate and rewardReserve should account for stuck rewards from previous epoch
        assertEqUint(rewardRate, (reward + reward / 2) / WEEK);
        assertApproxEqAbs(pool.rewardReserve(), reward + reward / 2, 1e5);
        assertEqUint(pool.rollover(), 0);

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
        assertLe(gaugeRewardTokenBalance, 1e6);
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

        assertRollover({
            reward: reward,
            timeNoStakedLiq: 1 days,
            timeElapsed: 4 days // 3 days with active staked liq, 1 day without
        });

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward,
            timeNoStakedLiq: 1 days
        });
    }

    function test_RewardsRolledOverIfThereAreMultipleHolesInStakedLiquidityWithDepositAndWithdraw() public {
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

        uint256 oldAliceBal;
        uint256 reward = TOKEN_1;
        uint256 timeNoStakedLiquidity;
        uint256 rewardRate = reward / WEEK;
        addRewardToGauge(address(voter), address(gauge), reward);
        assertEqUint(pool.rewardRate(), rewardRate);
        // for every 5 hours during the epoch, we will simulate 2 hours with no stakedLiquidity
        for (uint256 i = 0; i < (WEEK / 5 hours); i++) {
            uint256 timeDelta = 3 hours; // 3 hours with staked liq, followed by 2 hours without

            // skip 3 hours and withdraw to remove stakedLiquidity
            skip(timeDelta);
            vm.startPrank(users.alice);
            gauge.withdraw(tokenId);

            uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
            assertApproxEqAbs(aliceRewardBalance, oldAliceBal + (timeDelta * rewardRate), 1e5); // Accrued rewards during timeDelta

            assertEqUint(pool.stakedLiquidity(), 0);

            timeDelta = 2 hours;

            // skipping 2 hours, won't generate rewards which is desirable but rewards get stuck in gauge
            skip(timeDelta);

            nft.approve(address(gauge), tokenId);
            gauge.deposit(tokenId);

            timeNoStakedLiquidity += timeDelta;
            assertRollover({
                reward: reward,
                timeNoStakedLiq: timeNoStakedLiquidity,
                timeElapsed: 5 hours * (i + 1) // 3 hours with active staked liq, 2 hours without
            });
            oldAliceBal = aliceRewardBalance;
        }

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward,
            timeNoStakedLiq: timeNoStakedLiquidity
        });
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
        clCallee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        assertEqUint(pool.stakedLiquidity(), 0);

        // 1 day worth of rewards not accumulating
        skip(1 days);

        // swapping 86e16 puts back the price into the range where both positions are active
        clCallee.swapExact1For0(address(pool), 86e16, users.alice, MAX_SQRT_RATIO - 1);

        assertEqUint(pool.stakedLiquidity(), stakedLiquidity);

        skip(1 days);

        // collect rewards to trigger update on accumulator
        gauge.getReward(tokenId);

        assertRollover({
            reward: reward,
            timeNoStakedLiq: 1 days,
            timeElapsed: 5 days // 4 days with active staked liq, 1 day without
        });

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward,
            timeNoStakedLiq: 1 days
        });
    }

    function test_RewardsRolledOverIfThereAreMultipleHolesInStakedLiquidityWithSwap() public {
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
        uint256 timeNoStakedLiquidity;
        uint256 rewardRate = reward / WEEK;

        // store ticks to be used when crossing stakedLiqudity range
        int24 inactiveLiqTick = -1847;
        (, int24 activeLiqTick,,,,) = CLPool(pool).slot0();

        addRewardToGauge(address(voter), address(gauge), reward);
        assertEq(pool.rewardRate(), rewardRate);
        for (uint256 i = 0; i < (WEEK / 5 hours); i++) {
            // we will have 3 hours with staked liq, followed by 1 hour without and another with
            uint256 timeDelta = 3 hours;

            // move 3 hours and swap to move out from stakedLiquidity range
            skip(timeDelta);
            vm.startPrank(users.alice);

            // simulate progressively smaller swaps until out of stakedLiquidity range
            uint256 swaps = 0;
            while (pool.stakedLiquidity() != 0) {
                (, int24 tick,,,,) = CLPool(pool).slot0();
                if (tick > inactiveLiqTick) {
                    clCallee.swapExact0For1(address(pool), 1e18 / ++swaps, users.alice, MIN_SQRT_RATIO + 1);
                } else {
                    clCallee.swapExact1For0(address(pool), 1e18 / ++swaps, users.alice, MAX_SQRT_RATIO - 1);
                }
            }
            assertEqUint(pool.stakedLiquidity(), 0);

            // 1 hour worth of rewards not accumulating
            timeDelta = 1 hours;
            skip(timeDelta);
            timeNoStakedLiquidity += timeDelta;

            // simulate progressively smaller swaps until back in stakedLiquidity range
            swaps = 0;
            while (pool.stakedLiquidity() == 0) {
                (, int24 tick,,,,) = CLPool(pool).slot0();
                // swapping 86e16 puts back the price into the range where both positions are active in the first swap
                if (tick < activeLiqTick) {
                    clCallee.swapExact1For0(address(pool), 86e16 / ++swaps, users.alice, MAX_SQRT_RATIO - 1);
                } else {
                    clCallee.swapExact0For1(address(pool), 86e16 / ++swaps, users.alice, MIN_SQRT_RATIO + 1);
                }
            }
            assertApproxEqAbs(uint256(pool.stakedLiquidity()), stakedLiquidity, 1e2);

            // 1 more hour of rewards accumulating
            skip(timeDelta);

            // collect rewards to trigger update on accumulator
            gauge.getReward(tokenId);

            assertRollover({
                reward: reward,
                timeNoStakedLiq: timeNoStakedLiquidity,
                timeElapsed: 5 hours * (i + 1) // 4 hours with active staked liq, 1 hour without
            });
        }

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward,
            timeNoStakedLiq: timeNoStakedLiquidity
        });
    }

    function test_RewardsRolledOverIfHolesAcrossAdjacentEpochs() public {
        uint256 reward = TOKEN_1;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward);

        // 2 day gap
        skip(2 days);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(1 days);

        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), (reward * 2 / 7 + reward * 2) / (6 days));
        assertApproxEqAbs(pool.rewardReserve(), reward * 2 / 7 + reward * 2, 1e6);
    }

    function test_RewardsRolledOverIfHolesAcrossNonAdjacentEpochs() public {
        uint256 reward = TOKEN_1;

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / WEEK);
        assertEqUint(pool.rewardReserve(), reward);

        // 2 day gap
        skip(2 days);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);
        skipToNextEpoch(1 days);

        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), (reward * 2 / 7 + reward * 2) / (6 days));
        assertApproxEqAbs(pool.rewardReserve(), reward * 2 / 7 + reward * 2, 1e6);
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

        // all rewardReserves should be accounted in the accumulator
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(reward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEq(pool.rewardRate(), reward / WEEK);
        assertLe(pool.rewardReserve(), 1e5);
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

        // all rewardReserves should be accounted in the accumulator
        // possible to rollover full amount if sufficient time passes
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(reward, Q128, stakedLiquidity);

        assertEqUint(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128);
        assertEq(pool.rewardRate(), reward / (WEEK - 1));
        assertEqUint(pool.rewardReserve(), reward);

        // sanity checks
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, reward * 2, 1e6);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward, 1);
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

        assertEq(pool.rollover(), reward);

        addRewardToGauge(address(voter), address(gauge), reward);

        assertEqUint(pool.rollover(), 0);

        assertEqUint(pool.rewardGrowthGlobalX128(), 0);
        assertEq(pool.rewardRate(), (reward * 2) / (WEEK - 60));
        assertApproxEqAbs(pool.rewardReserve(), reward * 2, 1e6);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertLe(aliceRewardBalance, 1e6);

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
        assertApproxEqAbs(pool.rewardReserve(), reward - reward / WEEK * (WEEK - 60), 1e6);
        assertEqUint(pool.rollover(), reward / WEEK * 60);

        skipToNextEpoch(200);

        addRewardToGauge(address(voter), address(gauge), reward * 2);
        assertEqUint(pool.rollover(), 0);
        assertEq(pool.rewardRate(), (reward * 2 + reward - (reward / WEEK * (WEEK - 120))) / (WEEK - 200));
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

        uint256 rewardRate = reward / WEEK;
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertEq(pool.rewardRate(), rewardRate);
        assertEq(pool.rollover(), rewardRate * 1 days);
        assertApproxEqAbs(aliceRewardBalance, (reward / 7 * 6), 1e6);
        assertApproxEqAbs(pool.rewardReserve(), reward - reward / WEEK * WEEK, 1e6);
    }

    function test_RewardGrowthGlobalUpdatesCorrectlyWithMultipleCallsToUpdateRewardsGrowthGlobalAfterEpochFlip()
        public
    {
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        skip(1 days);
        addRewardToGauge(address(voter), address(gauge), reward);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward * 2, 1e6);
        assertLe(pool.rewardReserve(), 1e6);
    }
}
