pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3FactoryTest} from "./UniswapV3Factory.t.sol";

contract CreatePoolTest is UniswapV3FactoryTest {
    function test_RevertIf_SameTokens() public {
        vm.expectRevert();
        poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_0, tickSpacing: TICK_SPACING_LOW});
    }

    function test_RevertIf_ZeroAddress() public {
        vm.expectRevert();
        poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: address(0), tickSpacing: TICK_SPACING_LOW});

        vm.expectRevert();
        poolFactory.createPool({tokenA: address(0), tokenB: TEST_TOKEN_0, tickSpacing: TICK_SPACING_LOW});

        vm.expectRevert();
        poolFactory.createPool({tokenA: address(0), tokenB: address(0), tickSpacing: TICK_SPACING_LOW});
    }

    function test_RevertIf_TickSpacingNotEnabled() public {
        vm.expectRevert();
        poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: 250});
    }

    function test_CreatePoolWithReversedTokens() public {
        createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_1,
            token1: TEST_TOKEN_0,
            tickSpacing: TICK_SPACING_LOW
        });
    }

    function test_CreatePoolWithTickSpacingStable() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_STABLE
        });
        assertEqUint(poolFactory.getSwapFee(pool), 100);

        CLGauge gauge = CLGauge(voter.gauges(pool));
        address feesVotingReward = voter.gaugeToFees(address(gauge));
        assertEq(UniswapV3Pool(pool).gauge(), address(gauge));
        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.forwarder(), forwarder);
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertTrue(gauge.isPool());
    }

    function test_CreatePoolWithTickSpacingLow() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW
        });
        assertEqUint(poolFactory.getSwapFee(pool), 500);

        CLGauge gauge = CLGauge(voter.gauges(pool));
        address feesVotingReward = voter.gaugeToFees(address(gauge));
        assertEq(UniswapV3Pool(pool).gauge(), address(gauge));
        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.forwarder(), forwarder);
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertTrue(gauge.isPool());
    }

    function test_CreatePoolWithTickSpacingMedium() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_MEDIUM
        });
        assertEqUint(poolFactory.getSwapFee(pool), 500);

        CLGauge gauge = CLGauge(voter.gauges(pool));
        address feesVotingReward = voter.gaugeToFees(address(gauge));
        assertEq(UniswapV3Pool(pool).gauge(), address(gauge));
        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.forwarder(), forwarder);
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertTrue(gauge.isPool());
    }

    function test_CreatePoolWithTickSpacingHigh() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_HIGH
        });
        assertEqUint(poolFactory.getSwapFee(pool), 3_000);

        CLGauge gauge = CLGauge(voter.gauges(pool));
        address feesVotingReward = voter.gaugeToFees(address(gauge));
        assertEq(UniswapV3Pool(pool).gauge(), address(gauge));
        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.forwarder(), forwarder);
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertTrue(gauge.isPool());
    }

    function test_CreatePoolWithTickSpacingVolatile() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_VOLATILE
        });
        assertEqUint(poolFactory.getSwapFee(pool), 10_000);

        CLGauge gauge = CLGauge(voter.gauges(pool));
        address feesVotingReward = voter.gaugeToFees(address(gauge));
        assertEq(UniswapV3Pool(pool).gauge(), address(gauge));
        assertEq(address(gauge.pool()), address(pool));
        assertEq(gauge.forwarder(), forwarder);
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertTrue(gauge.isPool());
    }
}
