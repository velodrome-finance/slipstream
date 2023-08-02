pragma solidity ^0.7.6;
pragma abicoder v2;

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

    function test_CreatePoolWithTickSpacingLow() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_LOW
        });
        assertEqUint(poolFactory.getFee(pool), 500);
    }

    function test_CreatePoolWithTickSpacingMedium() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_MEDIUM
        });
        assertEqUint(poolFactory.getFee(pool), 3_000);
    }

    function test_CreatePoolWithTickSpacingHigh() public {
        address pool = createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: TICK_SPACING_HIGH
        });
        assertEqUint(poolFactory.getFee(pool), 10_000);
    }
}
