pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../../BaseFixture.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLPoolTest} from "../CLPool.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "contracts/core/libraries/FullMath.sol";

contract RewardGrowthGlobalFuzzTest is CLPoolTest {
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

    function mintNewFullRangePositionAndDepositIntoGauge(uint128 _amount0, uint128 _amount1, address _user)
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
    function assertRollover(
        uint256 reward,
        uint256 timeNoStakedLiq,
        uint256 stakedLiquidity,
        uint256 timeElapsed,
        uint256 delay
    ) internal {
        uint256 rewardRate = reward / (WEEK - delay);
        uint256 rollover = rewardRate * timeNoStakedLiq;

        uint256 accumulatedReward = rewardRate * (timeElapsed - timeNoStakedLiq);
        uint256 rewardGrowthGlobalX128 = FullMath.mulDiv(accumulatedReward, Q128, stakedLiquidity);

        assertApproxEqAbs(rewardToken.balanceOf(users.alice), accumulatedReward, 1e5);
        assertApproxEqAbs(pool.rewardGrowthGlobalX128(), rewardGrowthGlobalX128, 1e4);

        assertEqUint(pool.rewardRate(), rewardRate);
        assertEqUint(pool.rollover(), rollover);
        assertApproxEqAbs(pool.rewardReserve(), rewardRate * (WEEK - (timeElapsed + delay)), 1e6);
    }

    //@dev This function skips an Epoch and asserts the values of the claimed and rolled over Reward Balances
    function assertRolloverRewardsAfterEpochFlip(
        uint256 tokenId,
        uint256 reward1,
        uint256 reward2,
        uint256 delay,
        uint256 timeNoStakedLiq
    ) internal {
        uint256 rewardRate = reward1 / (WEEK - delay);
        uint256 rollover = rewardRate * timeNoStakedLiq;

        // generating a pseudo-random number for delayed reward distribution
        uint256 getRewardSkip = uint256(keccak256(abi.encodePacked(block.timestamp)));
        getRewardSkip = bound(getRewardSkip, 0, WEEK - 1);

        skipToNextEpoch(getRewardSkip);

        gauge.getReward(tokenId);

        // alice rewards should be `WEEK - timeNoStakedLiq` worth of rewards
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, rewardRate * (WEEK - (timeNoStakedLiq + delay)), 1e6);

        // at the start of the new epoch reserves should be dust
        assertApproxEqAbs(pool.rewardReserve(), reward1 - reward1 / (WEEK - delay) * (WEEK - delay), 1e6);

        // assert that emissions got stuck in the gauge for the current epoch, `timeNoStakedLiq` worth of rewards
        // will be rolled over to next epoch
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, rollover, 1e6);

        // generating a pseudo-random number for delayed reward notification
        uint256 notifySkip = uint256(keccak256(abi.encodePacked(getRewardSkip)));
        notifySkip = bound(notifySkip, 0, WEEK - getRewardSkip - 1);
        skip(notifySkip);

        addRewardToGauge(address(voter), address(gauge), reward2);

        // rewardRate and rewardReserve should account for stuck rewards from previous epoch
        assertEqUint(pool.rewardRate(), (reward2 + rollover) / (WEEK - (getRewardSkip + notifySkip)));
        assertApproxEqAbs(pool.rewardReserve(), reward2 + rollover, 1e5);
        assertEqUint(pool.rollover(), 0);

        // any rewards accrued came from the dust leftover in rewardreserves
        assertLe(gauge.earned(address(users.alice), tokenId), reward1 - reward1 / (WEEK - delay) * (WEEK - delay));
    }

    function testFuzz_RewardGrowthGlobalUpdatesCorrectlyWithDelayedRewardDistribute(uint256 reward, uint256 delay)
        public
    {
        reward = bound(reward, WEEK, type(uint128).max);
        delay = bound(delay, 1, WEEK - 1 hours);

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), reward);

        // move one hour and mint new position and stake it as well to trigger update
        skip(1 hours);
        mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

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

        uint128 amount0 = 10e18;
        uint128 amount1 = 10e18;
        uint128 stakedLiquidity = 10e18;

        uint256 tokenId = mintNewFullRangePositionAndDepositIntoGauge(amount0, amount1, users.alice);

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

    function testFuzz_RewardsRolledOverToNextEpochIfThereIsNoStakedLiquidityAtRewardDistribution(
        uint256 reward,
        uint256 time,
        uint256 delay
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        time = bound(time, 1, WEEK - 2); // WEEK-2 to have at least 1 second with staked liq
        delay = bound(delay, 0, WEEK - time - 1);

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // sanity checks
        assertEqUint(pool.liquidity(), 10e18);
        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        // still 0 since no action triggered update on the accumulator
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        // reward states should be set
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), reward / (WEEK - delay));
        assertEqUint(pool.rewardReserve(), reward);

        // skip ahead in epoch and deposit to trigger update
        skip(time);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertEqUint(pool.lastUpdated(), block.timestamp);

        assertRollover({
            reward: reward,
            timeNoStakedLiq: time,
            stakedLiquidity: pool.stakedLiquidity(),
            timeElapsed: time, // time with and without liq
            delay: delay
        });

        skipToNextEpoch(0);

        // mint new position and stake it as well to trigger update
        uint256 tokenId2 =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);
        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        assertRollover({
            reward: reward,
            timeNoStakedLiq: time,
            stakedLiquidity: pool.stakedLiquidity(),
            timeElapsed: WEEK - delay, // time with and without liq
            delay: delay
        });

        nft.approve(address(gauge), tokenId2);
        gauge.deposit(tokenId2);

        uint256 rewardRate = pool.rewardRate();
        // assert that emissions got stuck in the gauge
        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertApproxEqAbs(gaugeRewardTokenBalance, rewardRate * time, 1e6);

        addRewardToGauge(address(voter), address(gauge), reward);

        uint256 newRewardRate = pool.rewardRate();

        // rewardRate and rewardReserve should account for stuck rewards from previous epoch
        assertEqUint(newRewardRate, (reward + rewardRate * time) / WEEK);
        assertApproxEqAbs(pool.rewardReserve(), reward + rewardRate * time, 1e5);
        assertEqUint(pool.rollover(), 0);

        skipToNextEpoch(0);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        // we assert that the stuck rewards get rolled over to the next epoch correctly
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(
            aliceRewardBalance, rewardRate * (WEEK - (time + delay)) + (reward + rewardRate * time) / 2, 1e6
        );

        gauge.getReward(tokenId2);
        assertApproxEqAbs(
            rewardToken.balanceOf(users.alice), aliceRewardBalance + (reward + rewardRate * time) / 2, 1e6
        );

        gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertLe(gaugeRewardTokenBalance, 1e7);
    }

    function testFuzz_RewardsRolledOverIfThereAreHolesInStakedLiquidityWithDepositAndWithdrawAndDelayedDistribution(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 3); // WEEK-3 to have at least 1 sec with and another without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = bound(time, 1, epochDistributionTime - 1);
        time2 = bound(time2, 1, epochDistributionTime - time); // time without stakedLiquidity

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

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        // withdraw after skip to remove stakedLiquidity
        skip(time);
        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        uint256 rewardRate = reward / epochDistributionTime;
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, rewardRate * time, 1e5);

        assertEqUint(pool.stakedLiquidity(), 0);

        // skip without generating rewards, rewards should be rolled over
        skip(time2);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertRollover({
            reward: reward,
            timeNoStakedLiq: time2,
            stakedLiquidity: pool.stakedLiquidity(),
            timeElapsed: time + time2, // time with and without liq
            delay: delay
        });

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward2,
            delay: delay,
            timeNoStakedLiq: time2
        });
    }

    function testFuzz_RewardsRolledOverIfThereAreMultipleHolesInStakedLiquidityWithDepositAndWithdraw(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 timeChunkSize,
        uint256 timeWithLiq
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 2 days); // WEEK-2 days to have at least four 12 hour timechunks

        uint256 epochDistributionTime = WEEK - delay;
        // smallest timechunk is 12 hours, otherwise test would take too long
        timeChunkSize = bound(timeChunkSize, 12 hours, epochDistributionTime / 2);
        timeWithLiq = bound(timeWithLiq, 1, timeChunkSize - 1);

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

        skip(delay);

        uint256 oldAliceBal;
        uint256 aliceRewardBalance;
        uint256 timeNoStakedLiquidity;
        addRewardToGauge(address(voter), address(gauge), reward);
        assertEq(pool.rewardRate(), reward / epochDistributionTime);
        // for this test an epoch is split into time chunks, each with `timeChunkSize` seconds of duration
        // each timeChunk will have a period of time with and without liquidity
        for (uint256 i = 0; i < (epochDistributionTime / timeChunkSize); i++) {
            // withdraw to remove stakedLiquidity
            skip(timeWithLiq);
            vm.startPrank(users.alice);
            gauge.withdraw(tokenId);

            aliceRewardBalance = rewardToken.balanceOf(users.alice);
            assertApproxEqAbs(aliceRewardBalance, oldAliceBal + (timeWithLiq * (reward / epochDistributionTime)), 1e5); // Accrued rewards during `timeWithLiq`

            assertEqUint(pool.stakedLiquidity(), 0);

            // this skip won't generate rewards which is desirable, but rewards get stuck in gauge
            skip(timeChunkSize - timeWithLiq);

            nft.approve(address(gauge), tokenId);
            gauge.deposit(tokenId);

            timeNoStakedLiquidity += timeChunkSize - timeWithLiq;
            assertRollover({
                reward: reward,
                timeNoStakedLiq: timeNoStakedLiquidity,
                stakedLiquidity: pool.stakedLiquidity(),
                timeElapsed: timeChunkSize * (i + 1),
                delay: delay
            });
            oldAliceBal = aliceRewardBalance;
        }

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward2,
            delay: delay,
            timeNoStakedLiq: timeNoStakedLiquidity
        });
    }

    function testFuzz_RewardsRolledOverIfThereAreHolesInStakedLiquidityWithIncreaseAndDecrease(
        uint128 amount,
        uint128 liquidityAmount,
        uint24 delay,
        uint24 time,
        uint24 time2
    ) public {
        amount = uint128(bound(uint256(amount), 1e4, 1_000_000 ether));
        liquidityAmount = uint128(bound(uint256(liquidityAmount), 1, 1_000_000 ether));
        delay = uint24(bound(delay, 0, WEEK - 3)); // WEEK-3 to have at least 1 sec with and another without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = uint24(bound(time, 1, epochDistributionTime - 1));
        time2 = uint24(bound(time2, 1, epochDistributionTime - time)); // time without stakedLiquidity

        deal({token: address(token0), to: users.alice, give: amount + liquidityAmount});
        deal({token: address(token1), to: users.alice, give: amount + liquidityAmount});

        // adding `amount` as amount0 and amount1 will be equal to ~10 liquidity
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            amount, amount, -tickSpacing, tickSpacing, users.alice
        );

        // deposit and decrease to the desired amount of liquidity
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        uint256 stakedLiquidity = pool.stakedLiquidity();

        // needs to be 0 since there are no rewards
        assertEqUint(pool.rewardGrowthGlobalX128(), 0);

        // delay before distributing rewards
        skip(delay);

        uint256 reward = TOKEN_1;
        addRewardToGauge(address(voter), address(gauge), reward);

        // decrease all stakedLiquidity
        skip(time);
        vm.startPrank(users.alice);
        gauge.decreaseStakedLiquidity(tokenId, pool.stakedLiquidity(), 0, 0, block.timestamp);
        assertEqUint(pool.stakedLiquidity(), 0);

        gauge.getReward(tokenId);

        // skip without generating rewards, rewards should be rolled over
        skip(time2);

        token0.approve(address(gauge), liquidityAmount);
        token1.approve(address(gauge), liquidityAmount);
        // increasing back liquidity to accumulate rewards
        gauge.increaseStakedLiquidity(tokenId, liquidityAmount, liquidityAmount, 0, 0, block.timestamp);

        assertRollover({
            reward: reward,
            timeNoStakedLiq: time2,
            stakedLiquidity: stakedLiquidity,
            timeElapsed: time + time2, // time with and without liq
            delay: delay
        });

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward * 2,
            delay: delay,
            timeNoStakedLiq: time2
        });
    }

    function testFuzz_RewardsRolledOverIfThereAreHolesInStakedLiquidityWithSwap(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 4); // WEEK-4 to save time for remaining skips

        uint256 epochDistributionTime = WEEK - delay;
        // remove dust, use distibutionTime-2 to have at least 1 second with and another without staked liq
        time = bound(time, 2, epochDistributionTime - 2) / 2 * 2;
        time2 = bound(time2, 1, epochDistributionTime - time); // time without stakedLiquidity

        nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        // adding 29953549559107810 as amount0 and amount1 will be equal to ~10 liquidity
        uint256 tokenId = nftCallee.mintNewCustomRangePositionForUserWith60TickSpacing(
            29953549559107810, 29953549559107810, -tickSpacing, tickSpacing, users.alice
        );
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        uint128 stakedLiquidity = pool.stakedLiquidity();
        assertApproxEqAbs(uint256(stakedLiquidity), 10e18, 1e3);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        // skip and swap to move out of active stakedLiquidity range
        skip(time / 2);
        vm.startPrank(users.alice);
        clCallee.swapExact0For1(address(pool), 1e18, users.alice, MIN_SQRT_RATIO + 1);

        assertEqUint(pool.stakedLiquidity(), 0);

        // skip without generating rewards, rewards should be rolled over
        skip(time2);

        // swapping 86e16 puts back the price into the range where both positions are active
        clCallee.swapExact1For0(address(pool), 86e16, users.alice, MAX_SQRT_RATIO - 1);

        assertEqUint(pool.stakedLiquidity(), stakedLiquidity);

        skip(time / 2);

        // collect rewards to trigger update on accumulator
        gauge.getReward(tokenId);

        assertRollover({
            reward: reward,
            timeNoStakedLiq: time2,
            stakedLiquidity: pool.stakedLiquidity(),
            timeElapsed: time + time2, // time with and without liq
            delay: delay
        });

        assertRolloverRewardsAfterEpochFlip({
            tokenId: tokenId,
            reward1: reward,
            reward2: reward2,
            delay: delay,
            timeNoStakedLiq: time2
        });
    }

    function testFuzz_RewardGrowthNoRollover(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        time = bound(time, 1, WEEK - 1);
        delay = bound(delay, 0, WEEK - time);
        time2 = bound(time2, 0, WEEK - 1); // lower bound is 0 to test with and without delayed distribution
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        uint256 rewardRate = reward / (WEEK - delay);
        assertEq(gauge.rewardRate(), rewardRate);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // skip some time, then withdraw
        skip(time);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(time2);
        addRewardToGauge(address(voter), address(gauge), reward2);

        uint256 rollover = rewardRate * (WEEK - (time + delay));
        assertApproxEqAbs(gauge.rewardRate(), (reward2 + rollover) / (WEEK - time2), 1e6);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward + reward2, 1e7);
    }

    function testFuzz_RewardGrowthGlobalUpdatesCorrectlyWithUnstakedLiquidityBothAtTheStartAndEndOfTheEpoch(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 3); // WEEK-3 to have at least 1 sec with and another without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = bound(time, 1, epochDistributionTime - 1);
        time2 = bound(time2, 1, epochDistributionTime - time);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(time);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skip(WEEK - (time + time2 + delay));

        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        uint256 rewardRate = reward / epochDistributionTime;
        assertEqUint(pool.rewardRate(), rewardRate);
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, rewardRate * (WEEK - (time + time2 + delay)), 1e6);
        assertApproxEqAbs(pool.rewardReserve(), reward - rewardRate * (WEEK - (time2 + delay)), 1e6);
        assertEqUint(pool.rollover(), rewardRate * time);

        skipToNextEpoch(200);

        addRewardToGauge(address(voter), address(gauge), reward2);
        assertEqUint(pool.rollover(), 0);
        assertApproxEqAbs(
            pool.rewardRate(), (reward2 + reward - (rewardRate * (WEEK - (time + time2 + delay)))) / (WEEK - 200), 1e4
        );
        assertApproxEqAbs(pool.rewardReserve(), (reward2 + rewardRate * (time + time2)), 1e6);
    }

    function testFuzz_RewardGrowthGlobalUpdatesCorrectlyWithLateNotifyAndUnstakedLiquidityCrossingEpochFlips(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 3); // WEEK-3 to have at least 1 sec with and another without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = bound(time, 1, epochDistributionTime - 1);
        time2 = bound(time2, 1, epochDistributionTime - time);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        // no staked liquidity after reward distribution
        skip(time2);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // skip to create a period with liquidity, then withdraw in same epoch
        skip(WEEK - (time + time2 + delay));
        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        uint256 prevRewardRate = reward / epochDistributionTime;
        assertEqUint(pool.rewardRate(), prevRewardRate);
        assertEqUint(pool.rollover(), prevRewardRate * time2);
        assertApproxEqAbs(pool.rewardReserve(), reward - prevRewardRate * (WEEK - (time + delay)), 1e6);

        uint256 accumulatedReward = prevRewardRate * (WEEK - (time + time2 + delay));
        assertApproxEqAbs(rewardToken.balanceOf(users.alice), accumulatedReward, 1e6);

        // skip to next epoch without staked liq and perform delayed reward distribution
        skipToNextEpoch(time);
        addRewardToGauge(address(voter), address(gauge), reward2);

        uint256 rollover = prevRewardRate * (time + time2);
        uint256 rewardReserve = reward2 + rollover; // rewards were rolled over
        assertApproxEqAbs(pool.rewardReserve(), rewardReserve, 1e6);

        // deposit back liquidity
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // skip and withdraw liquidity in same epoch
        skip(WEEK - (time + time2));
        vm.startPrank(users.alice);
        gauge.withdraw(tokenId);

        assertEqUint(pool.rollover(), 0);
        uint256 rewardRate = rewardReserve / (WEEK - time);
        assertApproxEqAbs(pool.rewardRate(), rewardRate, 1e6);
        assertApproxEqAbs(pool.rewardReserve(), rewardReserve - rewardRate * (WEEK - (time + time2)), 1e6);
        assertApproxEqAbs(
            rewardToken.balanceOf(users.alice) - accumulatedReward, rewardRate * (WEEK - (time + time2)), 1e7
        );

        // skip to next epoch without staked liquidity and deposit
        skipToNextEpoch(0);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        rollover = rewardRate * time2;
        assertApproxEqAbs(pool.rollover(), rollover, 1e7);
        rewardReserve = rewardReserve - rewardReserve / (WEEK - time) * (WEEK - time); // remaining reserves are dust
        assertApproxEqAbs(pool.rewardReserve(), rewardReserve, 1e6);

        // distribute rewards to reserves
        addRewardToGauge(address(voter), address(gauge), reward / 2);
        // rewards were rolled over and distributed correctly
        assertEqUint(pool.rollover(), 0);
        rewardReserve = reward / 2 + rollover + rewardReserve;
        assertApproxEqAbs(pool.rewardReserve(), rewardReserve, 1e6);
        assertApproxEqAbs(pool.rewardRate(), rewardReserve / WEEK, 1e7);

        accumulatedReward = rewardToken.balanceOf(users.alice);

        // skip to next epoch and claim all accrued rewards
        skipToNextEpoch(0);
        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        // remaining reserves will be dust
        assertApproxEqAbs(pool.rewardReserve(), rewardReserve - rewardReserve / WEEK * WEEK, 1e6);
        assertApproxEqAbs(rewardToken.balanceOf(users.alice) - accumulatedReward, rewardReserve, 1e7);
    }

    function testFuzz_notifyRewardAmountUpdatesPoolStateCorrectlyOnAdditionalRewardInSameEpoch(
        uint256 reward,
        uint256 reward2
    ) public {
        reward = bound(reward, WEEK, type(uint128).max);
        reward2 = bound(reward2, WEEK, type(uint128).max);

        skip(1 days);

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(1 days);

        addRewardToGauge(address(voter), address(gauge), reward2);

        assertApproxEqAbs(pool.rewardRate(), (reward + reward2) / 5 days, 2);
        assertEqUint(pool.rewardReserve(), reward2 + (reward / 6 days) * 6 days);
        assertEqUint(pool.lastUpdated(), block.timestamp);
    }

    function testFuzz_RewardsRolledOverIfHolesAcrossAdjacentEpochs(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 2); // WEEK-2 to have at least 1 sec without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = bound(time, 1, epochDistributionTime - 1);
        // bounding by WEEK - 1 results in large rounding errors in rewardRate when time2 -> WEEK - 1
        time2 = bound(time2, 1, WEEK * 4 / 5);

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        uint256 rewardRate = reward / epochDistributionTime;
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), rewardRate);
        assertEqUint(pool.rewardReserve(), reward);

        skip(time);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(time2);

        addRewardToGauge(address(voter), address(gauge), reward2);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertApproxEqAbs(pool.rewardRate(), (rewardRate * time + reward2) / (WEEK - time2), 5);
        assertApproxEqAbs(pool.rewardReserve(), rewardRate * time + reward2, 1e6);
    }

    function testFuzz_RewardsRolledOverIfHolesAcrossNonAdjacentEpochs(
        uint256 reward,
        uint256 reward2,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        reward2 = bound(reward2, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 2); // WEEK-2 to have at least 1 sec without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = bound(time, 1, epochDistributionTime - 1);
        // bounding by WEEK - 1 results in large rounding errors in rewardRate when time2 -> WEEK - 1
        time2 = bound(time2, 1, WEEK * 4 / 5);

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        uint256 rewardRate = reward / epochDistributionTime;
        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertEqUint(pool.rewardRate(), rewardRate);
        assertEqUint(pool.rewardReserve(), reward);

        skip(time);
        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);
        skipToNextEpoch(time2);

        addRewardToGauge(address(voter), address(gauge), reward2);

        assertEqUint(pool.lastUpdated(), block.timestamp);
        assertApproxEqAbs(pool.rewardRate(), (rewardRate * time + reward2) / (WEEK - time2), 5);
        assertApproxEqAbs(pool.rewardReserve(), rewardRate * time + reward2, 1e6);
    }

    function testFuzz_RewardGrowthEpochSkipped(uint256 reward, uint256 delay, uint256 time, uint256 time2) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 2); // WEEK-2 to have at least 1 sec without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = bound(time, 1, epochDistributionTime - 1);
        time2 = bound(time2, 0, WEEK - 1); // 0 lower bound covers case where distribution is not delayed
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        uint256 rewardRate = reward / epochDistributionTime;
        assertEq(gauge.rewardRate(), rewardRate);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        // roll some time, then withdraw
        skip(time);

        gauge.withdraw(tokenId);

        // no stake, nothing happens
        skipToNextEpoch(0);
        // one epoch skipped entirely
        skipToNextEpoch(time2);
        addRewardToGauge(address(voter), address(gauge), reward * 2);

        assertApproxEqAbs(gauge.rewardRate(), (reward * 2 + rewardRate * (WEEK - (time + delay))) / (WEEK - time2), 1e6);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(0);

        gauge.getReward(tokenId);

        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertApproxEqAbs(aliceRewardBalance, reward * 3, 1e6);
    }

    function testFuzz_RewardGrowthOnlyAccountRewardsTillTheEndOfTheEpochInCaseOfLateNotify(
        uint256 reward,
        uint256 delay,
        uint256 time,
        uint256 time2
    ) public {
        reward = bound(reward, 1 ether, 1_000_000 ether);
        delay = bound(delay, 0, WEEK - 2); // WEEK-2 to have at least 1 sec without staked liq

        uint256 epochDistributionTime = WEEK - delay;
        time = bound(time, 1, epochDistributionTime - 1);
        time2 = bound(time2, 1, WEEK - 1);

        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);

        skip(delay);

        addRewardToGauge(address(voter), address(gauge), reward);

        skip(time);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        skipToNextEpoch(time2);

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

        uint256 rewardRate = reward / epochDistributionTime;
        uint256 aliceRewardBalance = rewardToken.balanceOf(users.alice);
        assertEq(pool.rewardRate(), rewardRate);
        assertEq(pool.rollover(), rewardRate * time);
        assertApproxEqAbs(aliceRewardBalance, rewardRate * (WEEK - (time + delay)), 1e6);
        assertApproxEqAbs(pool.rewardReserve(), reward - reward / epochDistributionTime * epochDistributionTime, 1e6);
    }
}
