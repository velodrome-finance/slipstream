pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseFixture.sol";
import {Position} from "contracts/core/libraries/Position.sol";

contract CLGaugeTest is BaseFixture {
    CLPool public pool;
    CLGauge public gauge;

    function setUp() public virtual override {
        super.setUp();

        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );
        gauge = CLGauge(voter.createGauge({_poolFactory: address(poolFactory), _pool: address(pool)}));
    }

    function test_InitialState() external {
        assertEq(address(gauge.pool()), address(pool));
        assertEq(address(gauge.gaugeFactory()), address(gaugeFactory));
        assertEq(gauge.minter(), address(minter));
        assertEq(address(gauge.voter()), address(voter));
        assertEq(address(gauge.nft()), address(nft));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertEq(gauge.token0(), address(token0));
        assertEq(gauge.token1(), address(token1));
        assertEq(gauge.tickSpacing(), TICK_SPACING_60);
        assertNotEq(gauge.feesVotingReward(), address(0));
        assertTrue(gauge.isPool());

        assertEq(gauge.periodFinish(), 0);
        assertEq(gauge.rewardRate(), 0);
        assertEq(gauge.fees0(), 0);
        assertEq(gauge.fees1(), 0);

        assertEq(gaugeFactory.penaltyRate(), 0);
        assertEq(gaugeFactory.defaultMinStakeTime(), 0);
    }
}
