pragma solidity ^0.7.6;
pragma abicoder v2;

import "../UniswapV3Pool.t.sol";

abstract contract UniswapV3PoolSwapTests is UniswapV3PoolTest {
    using stdJson for string;

    string jsonConstants;

    PoolSetup public poolSetup;

    Position[] public stakedPositions;
    Position[] public unstakedPositions;

    CLGauge public gauge;

    struct Position {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
    }

    struct FailedSwap {
        uint256 poolBalance0;
        uint256 poolBalance1;
        uint160 poolPriceBeforeX96;
        string swapError;
        int24 tickBefore;
    }

    struct SuccessfulSwap {
        uint256 amount0Before;
        int256 amount0Delta;
        uint256 amount1Before;
        int256 amount1Delta;
        string executionPrice;
        uint256 feeGrowthGlobal0X128Delta;
        uint256 feeGrowthGlobal1X128Delta;
        uint256 gaugeFeesToken0;
        uint256 gaugeFeesToken1;
        uint160 poolPriceAfterX96;
        uint160 poolPriceBeforeX96;
        int24 tickAfter;
        int24 tickBefore;
    }

    struct PoolSetup {
        string poolName;
        address pool;
        address gauge;
        uint256 poolBalance0;
        uint256 poolBalance1;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label({account: address(uniswapV3Callee), newLabel: "Test UniswapV3 Callee"});
        vm.label({account: address(this), newLabel: "Swap Test"});
    }

    struct AssertSwapData {
        uint256 amount0Before;
        uint256 amount1Before;
        int256 amount0Delta;
        int256 amount1Delta;
        uint256 feeGrowthGlobal0X128Delta;
        uint256 feeGrowthGlobal1X128Delta;
        int24 tickBefore;
        uint160 poolPriceBefore;
        int24 tickAfter;
        uint160 poolPriceAfter;
        uint256 gaugeFeesToken0;
        uint256 gaugeFeesToken1;
    }

    /// @dev overriden in each swap test base
    function assertSwapData(AssertSwapData memory asd, SuccessfulSwap memory ss) internal virtual {}

    /// @dev overriden in each swap test base
    function burnPosition() internal virtual {}

    // swap exactly 1.0000 token0 for token1
    function test_swap_exactly_1_token0_for_token1() public {
        bool zeroForOne = true;
        string memory swapName = "swap_exactly_1_token0_for_token1";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1e18;
        uint160 sqrtPriceLimitX96 = MIN_SQRT_RATIO + 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapExact0For1(poolSetup.pool, amount0, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap exactly 1.0000 token1 for token0
    function test_swap_exactly_1_token1_for_token0() public {
        bool zeroForOne = false;
        string memory swapName = "swap_exactly_1_token1_for_token0";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1e18;
        uint160 sqrtPriceLimitX96 = MAX_SQRT_RATIO - 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapExact1For0(poolSetup.pool, amount1, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token0 for exactly 1.0000 token1
    function test_swap_token0_for_exactly_1_token1() public {
        bool zeroForOne = true;
        string memory swapName = "swap_token0_for_exactly_1_token1";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1e18;
        uint160 sqrtPriceLimitX96 = MIN_SQRT_RATIO + 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swap0ForExact1(poolSetup.pool, amount1, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token1 for exactly 1.0000 token0
    function test_swap_token1_for_exactly_1_token0() public {
        bool zeroForOne = false;
        string memory swapName = "swap_token1_for_exactly_1_token0";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1e18;
        uint160 sqrtPriceLimitX96 = MAX_SQRT_RATIO - 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swap1ForExact0(poolSetup.pool, amount0, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap exactly 1.0000 token0 for token1 to price 0.5
    function test_swap_exactly_1_token0_for_token1_to_price_0point5() public {
        bool zeroForOne = true;
        string memory swapName = "swap_exactly_1_token0_for_token1_to_price_0point5";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1e18;
        uint160 sqrtPriceLimitX96 = encodePriceSqrt(50, 100);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapExact0For1(poolSetup.pool, amount0, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap exactly 1.0000 token1 for token0 to price 2
    function test_swap_exactly_1_token1_for_token0_to_price_2() public {
        bool zeroForOne = false;
        string memory swapName = "swap_exactly_1_token1_for_token0_to_price_2";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1e18;
        uint160 sqrtPriceLimitX96 = encodePriceSqrt(200, 100);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapExact1For0(poolSetup.pool, amount1, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token0 for exactly 1.0000 token1 to price 0.5
    function test_swap_token0_for_exactly_1_token1_to_price_0point5() public {
        bool zeroForOne = true;
        string memory swapName = "swap_token0_for_exactly_1_token1_to_price_0point5";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1e18;
        uint160 sqrtPriceLimitX96 = encodePriceSqrt(50, 100);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swap0ForExact1(poolSetup.pool, amount1, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token1 for exactly 1.0000 token0 to price 2
    function test_swap_token1_for_exactly_1_token0_to_price_2() public {
        bool zeroForOne = false;
        string memory swapName = "swap_token1_for_exactly_1_token0_to_price_2";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1e18;
        uint160 sqrtPriceLimitX96 = encodePriceSqrt(200, 100);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swap1ForExact0(poolSetup.pool, amount0, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap exactly 0point0000000000000010000 token0 for token1
    function test_swap_exactly_0point0000000000000010000_token0_for_token1() public {
        bool zeroForOne = true;
        string memory swapName = "swap_exactly_0point0000000000000010000_token0_for_token1";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1_000;
        uint160 sqrtPriceLimitX96 = MIN_SQRT_RATIO + 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapExact0For1(poolSetup.pool, amount0, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap exactly 0point0000000000000010000 token1 for token0
    function test_swap_exactly_0point0000000000000010000_token1_for_token0() public {
        bool zeroForOne = false;
        string memory swapName = "swap_exactly_0point0000000000000010000_token1_for_token0";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1_000;
        uint160 sqrtPriceLimitX96 = MAX_SQRT_RATIO - 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapExact1For0(poolSetup.pool, amount1, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token0 for exactly 0point0000000000000010000 token1
    function test_swap_token0_for_exactly_0point0000000000000010000_token1() public {
        bool zeroForOne = true;
        string memory swapName = "swap_token0_for_exactly_0point0000000000000010000_token1";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1_000;
        uint160 sqrtPriceLimitX96 = MIN_SQRT_RATIO + 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swap0ForExact1(poolSetup.pool, amount1, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token1 for exactly 0point0000000000000010000 token0
    function test_swap_token1_for_exactly_0point0000000000000010000_token0() public {
        bool zeroForOne = false;
        string memory swapName = "swap_token1_for_exactly_0point0000000000000010000_token0";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1_000;
        uint160 sqrtPriceLimitX96 = MAX_SQRT_RATIO - 1;

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swap1ForExact0(poolSetup.pool, amount0, users.alice, sqrtPriceLimitX96) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token1 for token0 to price 2.5000
    function test_swap_token1_for_token0_to_price_2point5() public {
        bool zeroForOne = false;
        string memory swapName = "swap_token1_for_token0_to_price_2point5";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint160 sqrtPriceLimitX96 = encodePriceSqrt(5, 2);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapToHigherSqrtPrice(poolSetup.pool, sqrtPriceLimitX96, users.alice) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token0 for token1 to price 0.4
    function test_swap_token0_for_token1_to_price_0point4() public {
        bool zeroForOne = true;
        string memory swapName = "swap_token0_for_token1_to_price_0point4";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint160 sqrtPriceLimitX96 = encodePriceSqrt(2, 5);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapToLowerSqrtPrice(poolSetup.pool, sqrtPriceLimitX96, users.alice) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token0 for token1 to price 2.5000
    function test_swap_token0_for_token1_to_price_2point5() public {
        bool zeroForOne = true;
        string memory swapName = "swap_token0_for_token1_to_price_2point5";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint160 sqrtPriceLimitX96 = encodePriceSqrt(5, 2);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapToLowerSqrtPrice(poolSetup.pool, sqrtPriceLimitX96, users.alice) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    // swap token1 for token0 to price 0.4
    function test_swap_token1_for_token0_to_price_0point4() public {
        bool zeroForOne = false;
        string memory swapName = "swap_token1_for_token0_to_price_0point4";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint160 sqrtPriceLimitX96 = encodePriceSqrt(2, 5);

        vm.recordLogs();

        bool swapFailed = false;
        string memory swapErrorMessage;

        try uniswapV3Callee.swapToHigherSqrtPrice(poolSetup.pool, sqrtPriceLimitX96, users.alice) {}
        catch Error(string memory reason) {
            swapFailed = true;
            swapErrorMessage = reason;
        }

        runAsserts(zeroForOne, swapFailed, assertKey, swapErrorMessage);
        burnPosition();
    }

    function runAsserts(bool zeroForOne, bool swapFailed, string memory assertKey, string memory swapErrorMessage)
        internal
    {
        if (swapFailed) {
            FailedSwap memory failedSwap = abi.decode(jsonConstants.parseRaw(assertKey), (FailedSwap));

            assertEq(swapErrorMessage, "SPL"); // only SPL happens
            assertApproxEqAbs(poolSetup.poolBalance0, failedSwap.poolBalance0, 1);
            assertApproxEqAbs(poolSetup.poolBalance1, failedSwap.poolBalance1, 1);
            assertEq(int256(poolSetup.sqrtPriceX96), int256(failedSwap.poolPriceBeforeX96));
            assertEq(poolSetup.tick, failedSwap.tickBefore);
            return;
        } else {
            SuccessfulSwap memory successfulSwap = abi.decode(jsonConstants.parseRaw(assertKey), (SuccessfulSwap));

            Vm.Log[] memory entries = vm.getRecordedLogs();

            SwapData memory sd = getAssertDataAfterSwap();

            assertSwapEvents(
                AssertSwapEvent({
                    entries: entries,
                    pool: poolSetup.pool,
                    poolBalance0Delta: sd.poolBalance0Delta,
                    poolBalance1Delta: sd.poolBalance1Delta,
                    zeroForOne: zeroForOne,
                    sqrtPriceX96After: sd.sqrtPriceX96After,
                    tickAfter: sd.tickAfter,
                    liquidityAfter: sd.liquidityAfter
                })
            );

            assertSwapData(
                AssertSwapData({
                    amount0Before: poolSetup.poolBalance0,
                    amount1Before: poolSetup.poolBalance1,
                    amount0Delta: sd.poolBalance0Delta,
                    amount1Delta: sd.poolBalance1Delta,
                    feeGrowthGlobal0X128Delta: sd.feeGrowthGlobal0X128,
                    feeGrowthGlobal1X128Delta: sd.feeGrowthGlobal1X128,
                    tickBefore: poolSetup.tick,
                    poolPriceBefore: poolSetup.sqrtPriceX96,
                    tickAfter: sd.tickAfter,
                    poolPriceAfter: sd.sqrtPriceX96After,
                    gaugeFeesToken0: sd.gaugeFeesToken0,
                    gaugeFeesToken1: sd.gaugeFeesToken1
                }),
                successfulSwap
            );
        }
    }

    struct AssertSwapEvent {
        Vm.Log[] entries;
        address pool;
        int256 poolBalance0Delta;
        int256 poolBalance1Delta;
        bool zeroForOne;
        uint160 sqrtPriceX96After;
        int24 tickAfter;
        uint256 liquidityAfter;
    }

    function assertSwapEvents(AssertSwapEvent memory ase) internal {
        // 3 type of event orders in case of swaps:
        // first case: 5 events: Transfer, SwapCallback, Transfer, Approve, Swap
        // second case: 4 events: SwapCallback, Transfer, Approve, Swap
        // third case: 2 events: SwapCallback, Swap
        uint256 eventsLength = ase.entries.length;
        uint8 transferEventIndex = 0;
        // if the first event is not a transfer, only second and third cases are possible,
        // so we have to increment the transferEventIndex
        if (ase.entries[0].topics[0] != keccak256("Transfer(address,address,uint256)")) {
            transferEventIndex = 1;
        }

        uint8 swapEventIndex = 1;

        // First Transfer (pool => sender)
        if (eventsLength == 5) {
            assertEq(ase.entries[transferEventIndex].topics[0], keccak256("Transfer(address,address,uint256)"));
            assertEq(ase.entries[transferEventIndex].topics[1], bytes32(uint256(uint160(ase.pool))));
            assertEq(ase.entries[transferEventIndex].topics[2], bytes32(uint256(uint160(users.alice))));
            assertEq(
                abi.decode(ase.entries[transferEventIndex].data, (int256)),
                ase.zeroForOne
                    ? int256(ase.poolBalance1Delta < 0 ? ase.poolBalance1Delta * -1 : ase.poolBalance1Delta)
                    : int256(ase.poolBalance0Delta < 0 ? ase.poolBalance0Delta * -1 : ase.poolBalance0Delta)
            );
            assertEq(ase.entries[transferEventIndex].emitter, ase.zeroForOne ? address(token1) : address(token0));
            swapEventIndex++;
            transferEventIndex += 2;
        }

        if (eventsLength > 2) {
            // Second Transfer (sender => pool)
            assertEq(ase.entries[transferEventIndex].topics[0], keccak256("Transfer(address,address,uint256)"));
            assertEq(ase.entries[transferEventIndex].topics[1], bytes32(uint256(uint160(users.alice))));
            assertEq(ase.entries[transferEventIndex].topics[2], bytes32(uint256(uint160(ase.pool))));
            assertEq(
                abi.decode(ase.entries[transferEventIndex].data, (int256)),
                ase.zeroForOne
                    ? int256(ase.poolBalance0Delta < 0 ? ase.poolBalance0Delta * -1 : ase.poolBalance0Delta)
                    : int256(ase.poolBalance1Delta < 0 ? ase.poolBalance1Delta * -1 : ase.poolBalance1Delta)
            );
            assertEq(ase.entries[transferEventIndex].emitter, ase.zeroForOne ? address(token0) : address(token1));
            swapEventIndex += 2;
        }
        // Swap Event
        assertEq(
            ase.entries[swapEventIndex].topics[0],
            keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)")
        );
        assertEq(ase.entries[swapEventIndex].topics[1], bytes32(uint256(uint160(address(uniswapV3Callee)))));
        assertEq(ase.entries[swapEventIndex].topics[2], bytes32(uint256(uint160(users.alice))));
        (int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick) =
            abi.decode(ase.entries[swapEventIndex].data, (int256, int256, uint160, uint128, int24));
        assertEq(amount0, ase.poolBalance0Delta);
        assertEq(amount1, ase.poolBalance1Delta);
        assertEq(uint256(sqrtPriceX96), uint256(ase.sqrtPriceX96After));
        assertEq(liquidity, ase.liquidityAfter);
        assertEq(tick, ase.tickAfter);
        assertEq(ase.entries[swapEventIndex].emitter, ase.pool);
    }

    struct SwapData {
        int256 poolBalance0Delta;
        int256 poolBalance1Delta;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint160 sqrtPriceX96After;
        int24 tickAfter;
        uint256 liquidityAfter;
        uint128 gaugeFeesToken0;
        uint128 gaugeFeesToken1;
    }

    function getAssertDataAfterSwap() internal view returns (SwapData memory sd) {
        (sd.sqrtPriceX96After, sd.tickAfter,,,,) = UniswapV3Pool(poolSetup.pool).slot0();
        sd.liquidityAfter = UniswapV3Pool(poolSetup.pool).liquidity();
        uint256 poolBalance0After = token0.balanceOf(poolSetup.pool);
        uint256 poolBalance1After = token1.balanceOf(poolSetup.pool);

        sd.poolBalance0Delta = int256(poolBalance0After) - int256(poolSetup.poolBalance0);
        sd.poolBalance1Delta = int256(poolBalance1After) - int256(poolSetup.poolBalance1);

        sd.feeGrowthGlobal0X128 = UniswapV3Pool(poolSetup.pool).feeGrowthGlobal0X128();
        sd.feeGrowthGlobal1X128 = UniswapV3Pool(poolSetup.pool).feeGrowthGlobal1X128();

        (sd.gaugeFeesToken0, sd.gaugeFeesToken1) = UniswapV3Pool(poolSetup.pool).gaugeFees();
    }
}
