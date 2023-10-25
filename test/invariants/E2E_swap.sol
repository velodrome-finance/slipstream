pragma solidity =0.7.6;
pragma abicoder v2;

import "./Setup.sol";
import "./helpers/Hevm.sol";
import {CoreTestERC20} from "contracts/core/test/CoreTestERC20.sol";
import {UniswapV3Pool} from "contracts/core/UniswapV3Pool.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {
    INonfungiblePositionManager, NonfungiblePositionManager
} from "contracts/periphery/NonfungiblePositionManager.sol";
import {IVoter} from "contracts/test/MockVoter.sol";
import {VelodromeTimeLibrary} from "contracts/libraries/VelodromeTimeLibrary.sol";

contract E2E_swap {
    SetupTokens tokens;
    SetupUniswap uniswap;

    UniswapV3Pool pool;
    CLGauge gauge;
    NonfungiblePositionManager nft;
    IVoter voter;

    CoreTestERC20 token0;
    CoreTestERC20 token1;

    UniswapMinter minter;
    UniswapSwapper swapper;

    CoreTestERC20 rewardToken;

    uint256 EMISSION_REWARD = 100e18;
    uint128 POSITIONS_LIQUIDITY = uint128(1e8 ether);

    uint256 totalClaimed;
    uint256 totalDistributed;

    int24[] usedTicks;
    bool inited;

    uint256[] stakedPositions;
    uint256[] unstakedPositions;

    struct PoolParams {
        uint24 fee;
        int24 tickSpacing;
        int24 minTick;
        int24 maxTick;
        uint24 tickCount;
        uint160 startPrice;
        int24 startTick;
    }

    struct PoolPositions {
        int24[] tickLowers;
        int24[] tickUppers;
        uint128[] amounts;
    }

    PoolParams poolParams;
    PoolPositions poolPositions;

    constructor() {
        tokens = new SetupTokens();
        token0 = tokens.token0();
        token1 = tokens.token1();

        uniswap = new SetupUniswap(token0, token1);

        minter = new UniswapMinter(token0, token1);
        swapper = new UniswapSwapper(token0, token1);

        tokens.mintTo(0, address(swapper), 1e9 ether);
        tokens.mintTo(1, address(swapper), 1e9 ether);

        tokens.mintTo(0, address(minter), 1e10 ether);
        tokens.mintTo(1, address(minter), 1e10 ether);
    }

    //
    //
    // Helpers
    //
    //
    function removeFromArray(uint256 index, uint256[] storage array) internal {
        array[index] = array[array.length - 1];
        array.pop();
    }

    function skip_some_time(uint256 seed) internal {
        uint256 currentTime = block.timestamp;
        // 259200 seconds = 3 days
        uint256 timeToSkip = uint256(seed % 259200) + 1;
        hevm.warp(currentTime + timeToSkip);
        hevm.roll(block.number + timeToSkip / 2);

        uint256 newTime = block.timestamp;

        // if we arrive in a new epoch notify
        if (VelodromeTimeLibrary.epochStart(currentTime) != VelodromeTimeLibrary.epochStart(newTime)) {
            uint256 gaugeBalanceBefore = rewardToken.balanceOf(address(gauge));

            hevm.prank(address(voter));
            gauge.notifyRewardAmount(EMISSION_REWARD);

            uint256 gaugeBalanceAfter = rewardToken.balanceOf(address(gauge));

            totalDistributed += EMISSION_REWARD;

            check_gauge_balance_invariant(gaugeBalanceBefore, gaugeBalanceAfter);
        }
    }

    function get_random_zeroForOne_priceLimit(int256 _amountSpecified)
        internal
        view
        returns (uint160 sqrtPriceLimitX96)
    {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice,,,,,) = pool.slot0();
        uint160 minimumPrice = TickMath.MIN_SQRT_RATIO;
        sqrtPriceLimitX96 = minimumPrice
            + uint160(
                (uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (currentPrice - minimumPrice))
            );
    }

    function get_random_oneForZero_priceLimit(int256 _amountSpecified)
        internal
        view
        returns (uint160 sqrtPriceLimitX96)
    {
        // help echidna a bit by calculating a valid sqrtPriceLimitX96 using the amount as random seed
        (uint160 currentPrice,,,,,) = pool.slot0();
        uint160 maximumPrice = TickMath.MAX_SQRT_RATIO;
        sqrtPriceLimitX96 = currentPrice
            + uint160(
                (uint256(_amountSpecified > 0 ? _amountSpecified : -_amountSpecified) % (maximumPrice - currentPrice))
            );
    }

    //
    //
    // Invariants
    //
    //
    function check_liquidityNet_invariant() internal {
        int128 liquidityNet = 0;
        for (uint256 i = 0; i < usedTicks.length; i++) {
            (, int128 tickLiquidityNet,,,,,,,,) = pool.ticks(usedTicks[i]);
            int128 result = liquidityNet + tickLiquidityNet;
            assert((tickLiquidityNet >= 0 && result >= liquidityNet) || (tickLiquidityNet < 0 && result < liquidityNet));
            liquidityNet = result;
        }

        // prop #20
        assert(liquidityNet == 0);
    }

    function check_stakedLiquidityNet_invariant() internal {
        int128 stakedLiquidityNet = 0;
        for (uint256 i = 0; i < usedTicks.length; i++) {
            (,, int128 stakedTickLiquidityNet,,,,,,,) = pool.ticks(usedTicks[i]);
            int128 result = stakedLiquidityNet + stakedTickLiquidityNet;
            assert(
                (stakedTickLiquidityNet >= 0 && result >= stakedLiquidityNet)
                    || (stakedTickLiquidityNet < 0 && result < stakedLiquidityNet)
            );
            stakedLiquidityNet = result;
        }

        assert(stakedLiquidityNet == 0);
    }

    function check_liquidity_invariant() internal {
        (, int24 currentTick,,,,) = pool.slot0();
        int128 liquidity = 0;
        for (uint256 i = 0; i < usedTicks.length; i++) {
            int24 tick = usedTicks[i];
            if (tick <= currentTick) {
                (, int128 tickLiquidityNet,,,,,,,,) = pool.ticks(tick);
                int128 result = liquidity + tickLiquidityNet;
                assert((tickLiquidityNet >= 0 && result >= liquidity) || (tickLiquidityNet < 0 && result < liquidity));
                liquidity = result;
            }
        }

        // prop #21
        assert(uint128(liquidity) == pool.liquidity());
        assert(liquidity >= 0);
    }

    function check_tick_feegrowth_invariant() internal {
        (, int24 currentTick,,,,) = pool.slot0();

        if (currentTick == poolParams.maxTick || currentTick == poolParams.minTick) return;

        int24 tickBelow = currentTick - poolParams.tickSpacing;
        int24 tickAbove = currentTick + poolParams.tickSpacing;

        (,,, uint256 tB_feeGrowthOutside0X128, uint256 tB_feeGrowthOutside1X128,,,,,) = pool.ticks(tickBelow);
        (,,, uint256 tA_feeGrowthOutside0X128, uint256 tA_feeGrowthOutside1X128,,,,,) = pool.ticks(tickAbove);

        // prop #22
        assert(tB_feeGrowthOutside0X128 + tA_feeGrowthOutside0X128 <= pool.feeGrowthGlobal0X128());

        // prop #23
        assert(tB_feeGrowthOutside1X128 + tA_feeGrowthOutside1X128 <= pool.feeGrowthGlobal1X128());
    }

    function check_tick_rewardgrowth_invariant() internal {
        (, int24 currentTick,,,,) = pool.slot0();

        if (currentTick == poolParams.maxTick || currentTick == poolParams.minTick) return;

        int24 tickBelow = currentTick - poolParams.tickSpacing;
        int24 tickAbove = currentTick + poolParams.tickSpacing;

        (,,,,, uint256 tB_rewardGrowthOutsideX128,,,,) = pool.ticks(tickBelow);
        (,,,,, uint256 tA_rewardGrowthOutsideX128,,,,) = pool.ticks(tickAbove);

        assert(tB_rewardGrowthOutsideX128 + tA_rewardGrowthOutsideX128 <= pool.rewardGrowthGlobalX128());
    }

    struct GaugeFeesBeforeAndAfter {
        uint128 gaugeFees_sell_bfre;
        uint128 gaugeFees_sell_aftr;
        uint128 gaugeFees_buy_bfre;
        uint128 gaugeFees_buy_aftr;
    }

    function check_swap_invariants(
        int24 tick_bfre,
        int24 tick_aftr,
        uint128 liq_bfre,
        uint128 liq_aftr,
        uint256 bal_sell_bfre,
        uint256 bal_sell_aftr,
        uint256 bal_buy_bfre,
        uint256 bal_buy_aftr,
        uint256 feegrowth_sell_bfre,
        uint256 feegrowth_sell_aftr,
        uint256 feegrowth_buy_bfre,
        uint256 feegrowth_buy_aftr,
        GaugeFeesBeforeAndAfter memory gfba
    ) internal {
        // prop #17
        if (tick_bfre == tick_aftr) {
            assert(liq_bfre == liq_aftr);
        }

        // prop #13 + #15
        assert(feegrowth_sell_bfre <= feegrowth_sell_aftr);

        // prop #14 + #16
        assert(feegrowth_buy_bfre == feegrowth_buy_aftr);

        // prop #18 + #19
        if (bal_sell_bfre == bal_sell_aftr) {
            assert(bal_buy_bfre == bal_buy_aftr);
        }

        assert(gfba.gaugeFees_sell_bfre <= gfba.gaugeFees_sell_aftr);

        assert(gfba.gaugeFees_buy_bfre == gfba.gaugeFees_buy_aftr);
    }

    function check_pool_staked_liquidity_invariant() internal {
        (, int24 currentTick,,,,) = pool.slot0();

        uint256 stakedLiquidity;
        for (uint256 i = 0; i < stakedPositions.length; i++) {
            (,,,,, int24 tickLower, int24 tickUpper, uint128 liq,,,,) = nft.positions(stakedPositions[i]);
            // if position is active
            if (tickLower <= currentTick && tickUpper > currentTick) {
                stakedLiquidity += liq;
            }
        }

        assert(stakedLiquidity == pool.stakedLiquidity());
        assert(stakedLiquidity <= pool.liquidity());
    }

    function check_gauge_balance_invariant(uint256 gaugeBalanceBefore, uint256 gaugeBalanceAfter) internal {
        assert(gaugeBalanceAfter == gaugeBalanceBefore + EMISSION_REWARD);
    }

    function check_pool_reward_invariant(
        uint256 rewardGrowthBefore,
        uint256 rewardGrowthAfter,
        uint256 rewardReserveBefore,
        uint256 rewardReserveAfter
    ) internal {
        assert(rewardGrowthBefore <= rewardGrowthAfter);
        assert(rewardReserveBefore >= rewardReserveAfter);
    }

    function check_withdraw_invariant(UniswapMinter.StakingData memory sd) internal {
        assert(sd.collectedToken0 == 0);
        assert(sd.collectedToken1 == 0);
        assert(sd.feeGrowthInside0LastX128Before <= sd.feeGrowthInside0LastX128After);
        assert(sd.feeGrowthInside1LastX128Before <= sd.feeGrowthInside1LastX128After);
        assert(sd.collectedReward >= 0);
        assert(sd.tokensOwed0 == 0);
        assert(sd.tokensOwed1 == 0);
    }

    function check_nft_collect_invariant(uint256 amount0, uint256 amount1) internal {
        assert(amount0 == 0);
        assert(amount1 == 0);
    }

    function check_deposit_invariant(UniswapMinter.StakingData memory sd) internal {
        assert(sd.collectedToken0 >= 0);
        assert(sd.collectedToken1 >= 0);
        assert(sd.feeGrowthInside0LastX128Before <= sd.feeGrowthInside0LastX128After);
        assert(sd.feeGrowthInside1LastX128Before <= sd.feeGrowthInside1LastX128After);
        assert(sd.collectedReward == 0);
        assert(sd.tokensOwed0 == 0);
        assert(sd.tokensOwed1 == 0);
    }

    function check_increase_staked_liquidity_invariant(UniswapMinter.LiquidityManagementData memory lmd) internal {
        assert(lmd.collectedReward >= 0);
        assert(lmd.token0Change == lmd.actualToken0Change);
        assert(lmd.token1Change == lmd.actualToken1Change);
        assert(lmd.feeGrowthInside0LastX128Before <= lmd.feeGrowthInside0LastX128After);
        assert(lmd.feeGrowthInside1LastX128Before <= lmd.feeGrowthInside1LastX128After);
        assert(lmd.tokensOwed0 == 0);
        assert(lmd.tokensOwed1 == 0);
        assert(lmd.liquidityBefore < lmd.liquidityAfter);
    }

    function check_decrease_staked_liquidity_invariant(UniswapMinter.LiquidityManagementData memory lmd) internal {
        assert(lmd.collectedReward >= 0);
        assert(lmd.token0Change == lmd.actualToken0Change);
        assert(lmd.token1Change == lmd.actualToken1Change);
        assert(lmd.feeGrowthInside0LastX128Before <= lmd.feeGrowthInside0LastX128After);
        assert(lmd.feeGrowthInside1LastX128Before <= lmd.feeGrowthInside1LastX128After);
        assert(lmd.tokensOwed0 == 0);
        assert(lmd.tokensOwed1 == 0);
        assert(lmd.liquidityBefore > lmd.liquidityAfter);
    }

    function check_total_claimed_and_distributed_invariant() internal {
        assert(totalClaimed <= totalDistributed);
    }

    //
    //
    // Helper to reconstruct the "random" init setup of the pool
    //
    //
    function viewRandomInit(uint128 _seed)
        public
        view
        returns (PoolParams memory _poolParams, PoolPositions memory _poolPositions)
    {
        _poolParams = forgePoolParams(_seed);
        _poolPositions = forgePoolPositions(_seed, _poolParams.tickSpacing, _poolParams.tickCount, _poolParams.maxTick);
    }

    //
    //
    // Setup functions
    //
    //
    function forgePoolParams(uint128 _seed) internal view returns (PoolParams memory _poolParams) {
        //
        // decide on one of the three fees, and corresponding tickSpacing
        //
        if (_seed % 3 == 0) {
            _poolParams.fee = uint24(500);
            _poolParams.tickSpacing = int24(10);
        } else if (_seed % 3 == 1) {
            _poolParams.fee = uint24(3_000);
            _poolParams.tickSpacing = int24(60);
        } else if (_seed % 3 == 2) {
            _poolParams.fee = uint24(10_000);
            _poolParams.tickSpacing = int24(200);
        }

        _poolParams.maxTick = (int24(887272) / _poolParams.tickSpacing) * _poolParams.tickSpacing;
        _poolParams.minTick = -_poolParams.maxTick;
        _poolParams.tickCount = uint24(_poolParams.maxTick / _poolParams.tickSpacing);

        //
        // set the initial price
        //
        _poolParams.startTick = int24((_seed % uint128(_poolParams.tickCount)) * uint128(_poolParams.tickSpacing));
        if (_seed % 3 == 0) {
            // set below 0
            _poolParams.startPrice = TickMath.getSqrtRatioAtTick(-_poolParams.startTick);
        } else if (_seed % 3 == 1) {
            // set at 0
            _poolParams.startPrice = TickMath.getSqrtRatioAtTick(0);
            _poolParams.startTick = 0;
        } else if (_seed % 3 == 2) {
            // set above 0
            _poolParams.startPrice = TickMath.getSqrtRatioAtTick(_poolParams.startTick);
        }
    }

    function forgePoolPositions(uint128 _seed, int24 _poolTickSpacing, uint24 _poolTickCount, int24 _poolMaxTick)
        internal
        view
        returns (PoolPositions memory poolPositions_)
    {
        // between 1 and 10 (inclusive) positions
        uint8 positionsCount = uint8(_seed % 10) + 1;

        poolPositions_.tickLowers = new int24[](positionsCount);
        poolPositions_.tickUppers = new int24[](positionsCount);
        poolPositions_.amounts = new uint128[](positionsCount);

        for (uint8 i = 0; i < positionsCount; i++) {
            int24 tickLower;
            int24 tickUpper;
            uint128 amount;

            int24 randomTick1 = int24((_seed % uint128(_poolTickCount)) * uint128(_poolTickSpacing));

            if (_seed % 2 == 0) {
                // make tickLower positive
                tickLower = randomTick1;

                // tickUpper is somewhere above tickLower
                uint24 poolTickCountLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                int24 randomTick2 = int24((_seed % uint128(poolTickCountLeft)) * uint128(_poolTickSpacing));
                tickUpper = tickLower + randomTick2;
            } else {
                // make tickLower negative or zero
                tickLower = randomTick1 == 0 ? 0 : -randomTick1;

                uint24 poolTickCountNegativeLeft = uint24((_poolMaxTick - randomTick1) / _poolTickSpacing);
                uint24 poolTickCountTotalLeft = poolTickCountNegativeLeft + _poolTickCount;

                uint24 randomIncrement = uint24((_seed % uint128(poolTickCountTotalLeft)) * uint128(_poolTickSpacing));

                if (randomIncrement <= uint24(tickLower)) {
                    // tickUpper will also be negative
                    tickUpper = tickLower + int24(randomIncrement);
                } else {
                    // tickUpper is positive
                    randomIncrement -= uint24(-tickLower);
                    tickUpper = tickLower + int24(randomIncrement);
                }
            }

            amount = POSITIONS_LIQUIDITY;

            poolPositions_.tickLowers[i] = tickLower;
            poolPositions_.tickUppers[i] = tickUpper;
            poolPositions_.amounts[i] = amount;

            _seed += uint128(tickLower);
        }
    }

    function _init(uint128 _seed) internal {
        //
        // generate random pool params
        //
        poolParams = forgePoolParams(_seed);

        //
        // deploy the pool
        //
        uniswap.createPool(poolParams.tickSpacing, poolParams.startPrice);

        pool = uniswap.pool();
        gauge = uniswap.gauge();
        nft = uniswap.nft();
        voter = uniswap.voter();
        rewardToken = uniswap.rewardToken();
        //
        // set the pool inside the minter and swapper contracts
        //
        minter.setPool(pool);
        minter.setGauge(gauge);
        minter.setNft(nft);
        minter.setRewardToken(rewardToken);

        swapper.setPool(pool);
        swapper.setGauge(gauge);

        //
        // generate random positions
        //
        poolPositions = forgePoolPositions(_seed, poolParams.tickSpacing, poolParams.tickCount, poolParams.maxTick);

        //
        // create the positions
        //
        for (uint8 i = 0; i < poolPositions.tickLowers.length; i++) {
            int24 tickLower = poolPositions.tickLowers[i];
            int24 tickUpper = poolPositions.tickUppers[i];
            uint128 amount = poolPositions.amounts[i];

            if (i % 2 == 0) {
                (,, uint256 tokenId) = minter.doMintWithoutStake(tickLower, tickUpper, amount, poolParams.startPrice);
                unstakedPositions.push(tokenId);
            } else {
                (,, uint256 tokenId) = minter.doMintAndStake(tickLower, tickUpper, amount, poolParams.startPrice);
                stakedPositions.push(tokenId);
            }

            bool lowerAlreadyUsed = false;
            bool upperAlreadyUsed = false;
            for (uint8 j = 0; j < usedTicks.length; j++) {
                if (usedTicks[j] == tickLower) lowerAlreadyUsed = true;
                else if (usedTicks[j] == tickUpper) upperAlreadyUsed = true;
            }
            if (!lowerAlreadyUsed) usedTicks.push(tickLower);
            if (!upperAlreadyUsed) usedTicks.push(tickUpper);
        }

        inited = true;
    }

    //
    //
    // Functions to fuzz
    //
    //
    function testEchidna_swap_exactIn_zeroForOne(uint128 _amount, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);

        GaugeFeesBeforeAndAfter memory gfba = GaugeFeesBeforeAndAfter({
            gaugeFees_sell_bfre: bfre.gaugeFees0,
            gaugeFees_sell_aftr: aftr.gaugeFees0,
            gaugeFees_buy_bfre: bfre.gaugeFees1,
            gaugeFees_buy_aftr: aftr.gaugeFees1
        });

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal0,
            aftr.bal0,
            bfre.bal1,
            aftr.bal1,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128,
            gfba
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
        check_pool_staked_liquidity_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_swap_exactIn_oneForZero(uint128 _amount, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token1.balanceOf(address(swapper)) >= uint256(_amount));
        int256 _amountSpecified = int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(false, _amountSpecified, sqrtPriceLimitX96);

        GaugeFeesBeforeAndAfter memory gfba = GaugeFeesBeforeAndAfter({
            gaugeFees_sell_bfre: bfre.gaugeFees1,
            gaugeFees_sell_aftr: aftr.gaugeFees1,
            gaugeFees_buy_bfre: bfre.gaugeFees0,
            gaugeFees_buy_aftr: aftr.gaugeFees0
        });

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal1,
            aftr.bal1,
            bfre.bal0,
            aftr.bal0,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128,
            gfba
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
        check_pool_staked_liquidity_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_swap_exactOut_zeroForOne(uint128 _amount, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_zeroForOne_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(true, _amountSpecified, sqrtPriceLimitX96);

        GaugeFeesBeforeAndAfter memory gfba = GaugeFeesBeforeAndAfter({
            gaugeFees_sell_bfre: bfre.gaugeFees0,
            gaugeFees_sell_aftr: aftr.gaugeFees0,
            gaugeFees_buy_bfre: bfre.gaugeFees1,
            gaugeFees_buy_aftr: aftr.gaugeFees1
        });

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal0,
            aftr.bal0,
            bfre.bal1,
            aftr.bal1,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128,
            gfba
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
        check_pool_staked_liquidity_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_swap_exactOut_oneForZero(uint128 _amount, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(token0.balanceOf(address(swapper)) > 0);
        int256 _amountSpecified = -int256(_amount);

        uint160 sqrtPriceLimitX96 = get_random_oneForZero_priceLimit(_amount);
        // console.log('sqrtPriceLimitX96 = %s', sqrtPriceLimitX96);

        (UniswapSwapper.SwapperStats memory bfre, UniswapSwapper.SwapperStats memory aftr) =
            swapper.doSwap(false, _amountSpecified, sqrtPriceLimitX96);

        GaugeFeesBeforeAndAfter memory gfba = GaugeFeesBeforeAndAfter({
            gaugeFees_sell_bfre: bfre.gaugeFees1,
            gaugeFees_sell_aftr: aftr.gaugeFees1,
            gaugeFees_buy_bfre: bfre.gaugeFees0,
            gaugeFees_buy_aftr: aftr.gaugeFees0
        });

        check_swap_invariants(
            bfre.tick,
            aftr.tick,
            bfre.liq,
            aftr.liq,
            bfre.bal1,
            aftr.bal1,
            bfre.bal0,
            aftr.bal0,
            bfre.feeGrowthGlobal1X128,
            aftr.feeGrowthGlobal1X128,
            bfre.feeGrowthGlobal0X128,
            aftr.feeGrowthGlobal0X128,
            gfba
        );

        check_liquidityNet_invariant();
        check_liquidity_invariant();
        check_tick_feegrowth_invariant();
        check_pool_staked_liquidity_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_emission_claiming_with_get_rewards(uint128 _amount, uint8 _position, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(stakedPositions.length > 0);
        uint256 tokenId = stakedPositions[_position % stakedPositions.length];

        uint256 rewardGrowthBefore = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveBefore = pool.rewardReserve();

        uint256 collected = minter.getReward(tokenId);

        totalClaimed += collected;

        uint256 rewardGrowthAfter = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveAfter = pool.rewardReserve();

        check_pool_reward_invariant(rewardGrowthBefore, rewardGrowthAfter, rewardReserveBefore, rewardReserveAfter);
        check_pool_staked_liquidity_invariant();
        check_total_claimed_and_distributed_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_unstake_position(uint128 _amount, uint8 _position, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(stakedPositions.length > 0);
        uint256 index = _position % stakedPositions.length;
        uint256 tokenId = stakedPositions[index];

        uint256 rewardGrowthBefore = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveBefore = pool.rewardReserve();

        (UniswapMinter.StakingData memory sd) = minter.withdraw(tokenId);
        check_withdraw_invariant(sd);

        (uint256 amount0, uint256 amount1) = minter.nftCollect(tokenId);
        check_nft_collect_invariant(amount0, amount1);

        removeFromArray(index, stakedPositions);
        unstakedPositions.push(tokenId);

        totalClaimed += sd.collectedReward;

        uint256 rewardGrowthAfter = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveAfter = pool.rewardReserve();

        check_pool_reward_invariant(rewardGrowthBefore, rewardGrowthAfter, rewardReserveBefore, rewardReserveAfter);
        check_pool_staked_liquidity_invariant();
        check_total_claimed_and_distributed_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_stake_position(uint128 _amount, uint8 _position, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(unstakedPositions.length > 0);
        uint256 index = _position % unstakedPositions.length;
        uint256 tokenId = unstakedPositions[index];

        uint256 rewardGrowthBefore = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveBefore = pool.rewardReserve();

        (UniswapMinter.StakingData memory sd) = minter.deposit(tokenId);
        check_deposit_invariant(sd);

        removeFromArray(index, unstakedPositions);
        stakedPositions.push(tokenId);

        uint256 rewardGrowthAfter = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveAfter = pool.rewardReserve();

        check_pool_reward_invariant(rewardGrowthBefore, rewardGrowthAfter, rewardReserveBefore, rewardReserveAfter);
        check_pool_staked_liquidity_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_gauge_increase_staked_liqudity(uint128 _amount, uint8 _position, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(stakedPositions.length > 0);
        uint256 tokenId = stakedPositions[_position % stakedPositions.length];

        uint256 rewardGrowthBefore = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveBefore = pool.rewardReserve();

        (UniswapMinter.LiquidityManagementData memory lmd) = minter.increaseStakedLiquidity(tokenId, _amount);
        check_increase_staked_liquidity_invariant(lmd);

        totalClaimed += lmd.collectedReward;

        uint256 rewardGrowthAfter = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveAfter = pool.rewardReserve();

        check_pool_reward_invariant(rewardGrowthBefore, rewardGrowthAfter, rewardReserveBefore, rewardReserveAfter);
        check_pool_staked_liquidity_invariant();
        check_total_claimed_and_distributed_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }

    function testEchidna_gauge_decrease_staked_liqudity(uint128 _amount, uint8 _position, uint256 _time) public {
        require(_amount != 0);

        if (!inited) _init(_amount);

        require(stakedPositions.length > 0);
        uint256 tokenId = stakedPositions[_position % stakedPositions.length];

        uint256 rewardGrowthBefore = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveBefore = pool.rewardReserve();

        (UniswapMinter.LiquidityManagementData memory lmd) = minter.decreaseStakedLiquidity(tokenId, _amount);
        check_decrease_staked_liquidity_invariant(lmd);

        totalClaimed += lmd.collectedReward;

        uint256 rewardGrowthAfter = pool.rewardGrowthGlobalX128();
        uint256 rewardReserveAfter = pool.rewardReserve();

        check_pool_reward_invariant(rewardGrowthBefore, rewardGrowthAfter, rewardReserveBefore, rewardReserveAfter);
        check_pool_staked_liquidity_invariant();
        check_total_claimed_and_distributed_invariant();
        check_stakedLiquidityNet_invariant();
        check_tick_rewardgrowth_invariant();

        skip_some_time(_time);
    }
}
