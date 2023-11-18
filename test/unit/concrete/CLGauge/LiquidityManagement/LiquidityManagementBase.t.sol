pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGauge.t.sol";

contract LiquidityManagementBase is CLGaugeTest {
    UniswapV3Pool public pool;
    CLGauge public gauge;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(voter.gauges(address(pool)));

        deal({token: address(token0), to: users.bob, give: TOKEN_1 * 100});
        deal({token: address(token1), to: users.bob, give: TOKEN_1 * 100});

        vm.startPrank(users.bob);
        token0.approve(address(gauge), type(uint256).max);
        token1.approve(address(gauge), type(uint256).max);
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
        token0.approve(address(nftCallee), type(uint256).max);
        token1.approve(address(nftCallee), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(users.alice);
        token0.approve(address(gauge), type(uint256).max);
        token1.approve(address(gauge), type(uint256).max);

        vm.label({account: address(gauge), newLabel: "Gauge"});
        vm.label({account: address(pool), newLabel: "Pool"});

        skipToNextEpoch(0);
    }
}
