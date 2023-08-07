pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../../BaseFixture.sol";
import {TestUniswapV3Callee} from "contracts/core/test/TestUniswapV3Callee.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {UniswapV3PoolTest} from "../UniswapV3Pool.t.sol";
import "forge-std/StdJson.sol";

/// @dev The UniswapV3Pool swap snapshot was translated into swap_asserts.json
/// Changes of note: execution price was scaled by 10**39 as Solidity has no native support for decimals.
/// Execution price is a string field as it also contains "-Infinity" and "NaN" values
/// poolPriceAfter and poolPriceBefore are stored as X96 pool price values (not sqrtPrice)
contract UniswapV3PoolSwapTest is UniswapV3PoolTest {
    using stdJson for string;

    TestUniswapV3Callee public uniswapV3Callee;

    string jsonConstants;

    PoolSetup public poolSetup;

    Position[] public positions;

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
        uint160 poolPriceAfterX96;
        uint160 poolPriceBeforeX96;
        int24 tickAfter;
        int24 tickBefore;
    }

    struct PoolSetup {
        string poolName;
        address pool;
        uint256 poolBalance0;
        uint256 poolBalance1;
        uint160 sqrtPriceX96;
        int24 tick;
    }

    modifier isPoolInitialized() {
        if (poolSetup.pool == address(0)) return;
        _;
    }

    function setUp() public virtual override {
        super.setUp();

        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/test/foundry/unit/UniswapV3Pool/swap/swap_assert.json"));

        jsonConstants = vm.readFile(path);

        uniswapV3Callee = new TestUniswapV3Callee();

        deal(address(token0), users.alice, TOKEN_2_TO_255);
        deal(address(token1), users.alice, TOKEN_2_TO_255);

        vm.startPrank(users.alice);

        token0.approve(address(uniswapV3Callee), type(uint256).max);
        token1.approve(address(uniswapV3Callee), type(uint256).max);

        labelContracts();
    }

    function labelContracts() internal override {
        super.labelContracts();
        vm.label({account: address(uniswapV3Callee), newLabel: "Test UniswapV3 Callee"});
        vm.label({account: address(this), newLabel: "Swap Test"});
    }

    // swap exactly 1.0000 token0 for token1
    function test_swap_exactly_1_token0_for_token1() public isPoolInitialized {
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
    function test_swap_exactly_1_token1_for_token0() public isPoolInitialized {
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
    function test_swap_token0_for_exactly_1_token1() public isPoolInitialized {
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
    function test_swap_token1_for_exactly_1_token0() public isPoolInitialized {
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
    function test_swap_exactly_1_token0_for_token1_to_price_0point5() public isPoolInitialized {
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
    function test_swap_exactly_1_token1_for_token0_to_price_2() public isPoolInitialized {
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
    function test_swap_token0_for_exactly_1_token1_to_price_0point5() public isPoolInitialized {
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
    function test_swap_token1_for_exactly_1_token0_to_price_2() public isPoolInitialized {
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
    function test_swap_exactly_0point0000000000000010000_token0_for_token1() public isPoolInitialized {
        bool zeroForOne = true;
        string memory swapName = "swap_exactly_0point0000000000000010000_token0_for_token1";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1000;
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
    function test_swap_exactly_0point0000000000000010000_token1_for_token0() public isPoolInitialized {
        bool zeroForOne = false;
        string memory swapName = "swap_exactly_0point0000000000000010000_token1_for_token0";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1000;
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
    function test_swap_token0_for_exactly_0point0000000000000010000_token1() public isPoolInitialized {
        bool zeroForOne = true;
        string memory swapName = "swap_token0_for_exactly_0point0000000000000010000_token1";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount1 = 1000;
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
    function test_swap_token1_for_exactly_0point0000000000000010000_token0() public isPoolInitialized {
        bool zeroForOne = false;
        string memory swapName = "swap_token1_for_exactly_0point0000000000000010000_token0";
        string memory assertKey = string(abi.encodePacked(poolSetup.poolName, "_", swapName));

        uint256 amount0 = 1000;
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
    function test_swap_token1_for_token0_to_price_2point5() public isPoolInitialized {
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
    function test_swap_token0_for_token1_to_price_0point4() public isPoolInitialized {
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
    function test_swap_token0_for_token1_to_price_2point5() public isPoolInitialized {
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
    function test_swap_token1_for_token0_to_price_0point4() public isPoolInitialized {
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
            assertEq(poolSetup.poolBalance0, failedSwap.poolBalance0);
            assertEq(poolSetup.poolBalance1, failedSwap.poolBalance1);
            assertEq(int256(poolSetup.sqrtPriceX96), int256(failedSwap.poolPriceBeforeX96));
            assertEq(poolSetup.tick, failedSwap.tickBefore);
            return;
        } else {
            SuccessfulSwap memory successfulSwap = abi.decode(jsonConstants.parseRaw(assertKey), (SuccessfulSwap));

            Vm.Log[] memory entries = vm.getRecordedLogs();

            (
                int256 poolBalance0Delta,
                int256 poolBalance1Delta,
                uint256 feeGrowthGlobal0X128,
                uint256 feeGrowthGlobal1X128,
                uint160 sqrtPriceX96After,
                int24 tickAfter,
                uint256 liquidityAfter
            ) = getAssertDataAfterSwap();

            assertSwapEvents(
                AssertSwapEvent({
                    entries: entries,
                    pool: poolSetup.pool,
                    poolBalance0Delta: poolBalance0Delta,
                    poolBalance1Delta: poolBalance1Delta,
                    zeroForOne: zeroForOne,
                    sqrtPriceX96After: sqrtPriceX96After,
                    tickAfter: tickAfter,
                    liquidityAfter: liquidityAfter
                })
            );

            assertSwapData(
                AssertSwapData({
                    amount0Before: poolSetup.poolBalance0,
                    amount1Before: poolSetup.poolBalance1,
                    amount0Delta: poolBalance0Delta,
                    amount1Delta: poolBalance1Delta,
                    feeGrowthGlobal0X128Delta: feeGrowthGlobal0X128,
                    feeGrowthGlobal1X128Delta: feeGrowthGlobal1X128,
                    tickBefore: poolSetup.tick,
                    poolPriceBefore: poolSetup.sqrtPriceX96,
                    tickAfter: tickAfter,
                    poolPriceAfter: sqrtPriceX96After
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
    }

    function assertSwapData(AssertSwapData memory asd, SuccessfulSwap memory ss) internal {
        assertEq(asd.amount0Before, ss.amount0Before);
        assertEq(asd.amount1Before, ss.amount1Before);
        assertEq(asd.amount0Delta, ss.amount0Delta);
        assertEq(asd.amount1Delta, ss.amount1Delta);
        assertEq(asd.feeGrowthGlobal0X128Delta, ss.feeGrowthGlobal0X128Delta);
        assertEq(asd.feeGrowthGlobal1X128Delta, ss.feeGrowthGlobal1X128Delta);
        assertEq(asd.tickBefore, ss.tickBefore);
        assertEq(uint256(asd.poolPriceBefore), uint256(ss.poolPriceBeforeX96));
        assertEq(asd.tickAfter, ss.tickAfter);
        assertEq(uint256(asd.poolPriceAfter), uint256(ss.poolPriceAfterX96));
        if (asd.amount0Delta != 0) {
            int256 executionPrice = getScaledExecutionPrice(asd.amount1Delta, asd.amount0Delta);
            assertEq(executionPrice, int256(stringToUint(ss.executionPrice)));
        } else if (asd.amount1Delta == 0) {
            assertEq("NaN", ss.executionPrice);
        } else {
            assertEq("-Infinity", ss.executionPrice);
        }
    }

    function burnPosition() internal {
        uint256 positionsLength = positions.length;
        for (uint256 i = 0; i < positionsLength; i++) {
            Position memory position = positions[i];
            UniswapV3Pool(poolSetup.pool).burn(position.tickLower, position.tickUpper, position.liquidity);
            UniswapV3Pool(poolSetup.pool).collect(
                users.alice, position.tickLower, position.tickUpper, type(uint128).max, type(uint128).max
            );
        }
    }

    function getAssertDataAfterSwap()
        internal
        view
        returns (
            int256 poolBalance0Delta,
            int256 poolBalance1Delta,
            uint256 feeGrowthGlobal0X128,
            uint256 feeGrowthGlobal1X128,
            uint160 sqrtPriceX96After,
            int24 tickAfter,
            uint256 liquidityAfter
        )
    {
        (sqrtPriceX96After, tickAfter,,,,,) = UniswapV3Pool(poolSetup.pool).slot0();
        liquidityAfter = UniswapV3Pool(poolSetup.pool).liquidity();
        uint256 poolBalance0After = token0.balanceOf(poolSetup.pool);
        uint256 poolBalance1After = token1.balanceOf(poolSetup.pool);

        poolBalance0Delta = int256(poolBalance0After) - int256(poolSetup.poolBalance0);
        poolBalance1Delta = int256(poolBalance1After) - int256(poolSetup.poolBalance1);

        feeGrowthGlobal0X128 = UniswapV3Pool(poolSetup.pool).feeGrowthGlobal0X128();
        feeGrowthGlobal1X128 = UniswapV3Pool(poolSetup.pool).feeGrowthGlobal1X128();
    }
}
