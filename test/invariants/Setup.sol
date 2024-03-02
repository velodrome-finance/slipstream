// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "./helpers/Hevm.sol";
import {CoreTestERC20} from "contracts/core/test/CoreTestERC20.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import {CLPool} from "contracts/core/CLPool.sol";
import {CLFactory} from "contracts/core/CLFactory.sol";
import {IVoter, MockVoter} from "contracts/test/MockVoter.sol";
import {IVotingEscrow, MockVotingEscrow} from "contracts/test/MockVotingEscrow.sol";
import {IFactoryRegistry, MockFactoryRegistry} from "contracts/test/MockFactoryRegistry.sol";
import {
    INonfungiblePositionManager, NonfungiblePositionManager
} from "contracts/periphery/NonfungiblePositionManager.sol";
import {CLGaugeFactory} from "contracts/gauge/CLGaugeFactory.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {MockWETH} from "contracts/test/MockWETH.sol";
import {IVotingRewardsFactory, MockVotingRewardsFactory} from "contracts/test/MockVotingRewardsFactory.sol";
import {CustomUnstakedFeeModule} from "contracts/core/fees/CustomUnstakedFeeModule.sol";
import {CustomSwapFeeModule} from "contracts/core/fees/CustomSwapFeeModule.sol";
import {LiquidityAmounts} from "contracts/periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "contracts/core/libraries/TickMath.sol";

contract SetupToken {
    CoreTestERC20 public token;

    constructor() {
        // this contract will receive the total supply of 100 tokens
        token = new CoreTestERC20(1e12 ether);
    }

    function mintTo(address _recipient, uint256 _amount) public {
        token.transfer(_recipient, _amount);
    }
}

contract SetupTokens {
    SetupToken tokenSetup0;
    SetupToken tokenSetup1;

    CoreTestERC20 public token0;
    CoreTestERC20 public token1;

    constructor() {
        // create the token wrappers
        tokenSetup0 = new SetupToken();
        tokenSetup1 = new SetupToken();

        // switch them around so that token0's address is lower than token1's
        // since this is what the cl poolFactory will do when you create the pool
        if (address(tokenSetup0.token()) > address(tokenSetup1.token())) {
            (tokenSetup0, tokenSetup1) = (tokenSetup1, tokenSetup0);
        }

        // save the CoreTestERC20 tokens
        token0 = tokenSetup0.token();
        token1 = tokenSetup1.token();
    }

    // mint either token0 or token1 to a chosen account
    function mintTo(uint256 _tokenIdx, address _recipient, uint256 _amount) public {
        require(_tokenIdx == 0 || _tokenIdx == 1, "invalid token idx");
        if (_tokenIdx == 0) tokenSetup0.mintTo(_recipient, _amount);
        if (_tokenIdx == 1) tokenSetup1.mintTo(_recipient, _amount);
    }
}

contract SetupCL {
    CLPool poolImplementation;
    CLPool public pool;
    CoreTestERC20 token0;
    CoreTestERC20 token1;
    IFactoryRegistry public factoryRegistry;
    IVoter public voter;
    IVotingEscrow public escrow;
    CoreTestERC20 public rewardToken;
    IERC20 public weth;
    IVotingRewardsFactory public votingRewardsFactory;
    CustomSwapFeeModule public customSwapFeeModule;
    CustomUnstakedFeeModule public customUnstakedFeeModule;

    //NonfungibleTokenPositionDescriptor public nftDescriptor;
    NonfungiblePositionManager public nft;
    CLGaugeFactory public gaugeFactory;
    CLGauge public gaugeImplementation;
    CLGauge public gauge;

    // will create the following enabled fees and corresponding tickSpacing
    // fee 500   + tickSpacing 10
    // fee 3000  + tickSpacing 60
    // fee 10000 + tickSpacing 200
    CLFactory poolFactory;

    constructor(CoreTestERC20 _token0, CoreTestERC20 _token1) {
        rewardToken = new CoreTestERC20(1e12 ether);
        factoryRegistry = IFactoryRegistry(new MockFactoryRegistry());
        escrow = IVotingEscrow(new MockVotingEscrow(msg.sender));

        votingRewardsFactory = IVotingRewardsFactory(new MockVotingRewardsFactory());
        weth = IERC20(address(new MockWETH()));

        voter = IVoter(
            new MockVoter({
                _rewardToken: address(rewardToken),
                _factoryRegistry: address(factoryRegistry),
                _ve: address(escrow)
            })
        );

        rewardToken.mint(address(voter), 10000000000e18);

        poolImplementation = new CLPool();

        poolFactory = new CLFactory({_voter: address(voter), _poolImplementation: address(poolImplementation)});

        poolFactory.enableTickSpacing(10, 500);
        poolFactory.enableTickSpacing(60, 3_000);
        // manually override fee in pool creation for tick spacing 200

        // deploy gauges and associated contracts
        gaugeImplementation = new CLGauge();
        gaugeFactory = new CLGaugeFactory({_voter: address(voter), _implementation: address(gaugeImplementation)});

        // deploy nft manager
        nft = new NonfungiblePositionManager({
            _factory: address(poolFactory),
            _WETH9: address(weth),
            _tokenDescriptor: address(100),
            name: "Slipstream Position NFT v1",
            symbol: "CL-POS"
        });

        // set nft manager in the factories
        gaugeFactory.setNonfungiblePositionManager(address(nft));

        factoryRegistry.approve({
            poolFactory: address(poolFactory),
            votingRewardsFactory: address(votingRewardsFactory),
            gaugeFactory: address(gaugeFactory)
        });

        customSwapFeeModule = new CustomSwapFeeModule(address(poolFactory));
        customUnstakedFeeModule = new CustomUnstakedFeeModule(address(poolFactory));
        poolFactory.setSwapFeeModule(address(customSwapFeeModule));
        poolFactory.setUnstakedFeeModule(address(customUnstakedFeeModule));

        token0 = _token0;
        token1 = _token1;
    }

    function createPool(int24 _tickSpacing, uint160 _startPrice) public {
        pool = CLPool(
            poolFactory.createPool({
                tokenA: address(token0),
                tokenB: address(token1),
                tickSpacing: _tickSpacing,
                sqrtPriceX96: _startPrice
            })
        );

        gauge = CLGauge(voter.gauges(address(pool)));

        hevm.prank(address(voter));
        rewardToken.approve(address(gauge), 1000000000e18);

        // manually override fee to match fee used in univ3 test
        if (_tickSpacing == 200) customSwapFeeModule.setCustomFee(address(pool), 10_000);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);
    }
}

contract CLMinter is ERC721Holder {
    CLPool pool;
    CoreTestERC20 token0;
    CoreTestERC20 token1;

    NonfungiblePositionManager nft;
    CLGauge gauge;

    CoreTestERC20 rewardToken;

    struct MinterStats {
        uint128 liq;
        uint128 tL_liqGross;
        int128 tL_liqNet;
        uint128 tU_liqGross;
        int128 tU_liqNet;
    }

    constructor(CoreTestERC20 _token0, CoreTestERC20 _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function setPool(CLPool _pool) public {
        pool = _pool;
    }

    function setGauge(CLGauge _gauge) public {
        gauge = _gauge;
    }

    function setNft(NonfungiblePositionManager _nft) public {
        nft = _nft;
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
    }

    function setRewardToken(CoreTestERC20 _rewardToken) public {
        rewardToken = _rewardToken;
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        if (amount0Owed > 0) token0.transfer(address(pool), amount0Owed);
        if (amount1Owed > 0) token1.transfer(address(pool), amount1Owed);
    }

    function get_random_decrease_amount(uint128 _seed, uint128 _positionAmount)
        internal
        pure
        returns (uint128 burnAmount)
    {
        burnAmount = _seed % _positionAmount;
        require(burnAmount < _positionAmount);
        require(burnAmount > 0);
    }

    function getTickLiquidityVars(int24 _tickLower, int24 _tickUpper)
        internal
        view
        returns (uint128, int128, uint128, int128)
    {
        (uint128 tL_liqGross, int128 tL_liqNet,,,,,,,,) = pool.ticks(_tickLower);
        (uint128 tU_liqGross, int128 tU_liqNet,,,,,,,,) = pool.ticks(_tickUpper);
        return (tL_liqGross, tL_liqNet, tU_liqGross, tU_liqNet);
    }

    function getStats(int24 _tickLower, int24 _tickUpper) internal view returns (MinterStats memory stats) {
        (uint128 tL_lg, int128 tL_ln, uint128 tU_lg, int128 tU_ln) = getTickLiquidityVars(_tickLower, _tickUpper);
        return MinterStats(pool.liquidity(), tL_lg, tL_ln, tU_lg, tU_ln);
    }

    function doMint(int24 _tickLower, int24 _tickUpper, uint128 _amount)
        public
        returns (MinterStats memory bfre, MinterStats memory aftr)
    {
        bfre = getStats(_tickLower, _tickUpper);
        pool.mint(address(this), _tickLower, _tickUpper, _amount, new bytes(0));
        aftr = getStats(_tickLower, _tickUpper);
    }

    function doMintWithoutStake(int24 _tickLower, int24 _tickUpper, uint128 _amount, uint160 startingPrice)
        public
        returns (MinterStats memory bfre, MinterStats memory aftr, uint256 tokenId)
    {
        bfre = getStats(_tickLower, _tickUpper);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            startingPrice, TickMath.getSqrtRatioAtTick(_tickLower), TickMath.getSqrtRatioAtTick(_tickUpper), _amount
        );

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: pool.tickSpacing(),
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            recipient: address(this),
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp,
            sqrtPriceX96: 0
        });

        (tokenId,,,) = nft.mint(params);

        aftr = getStats(_tickLower, _tickUpper);
    }

    function doMintAndStake(int24 _tickLower, int24 _tickUpper, uint128 _amount, uint160 startingPrice)
        public
        returns (MinterStats memory bfre, MinterStats memory aftr, uint256 tokenId)
    {
        bfre = getStats(_tickLower, _tickUpper);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            startingPrice, TickMath.getSqrtRatioAtTick(_tickLower), TickMath.getSqrtRatioAtTick(_tickUpper), _amount
        );

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: pool.tickSpacing(),
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            recipient: address(this),
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp,
            sqrtPriceX96: 0
        });

        (tokenId,,,) = nft.mint(params);

        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        aftr = getStats(_tickLower, _tickUpper);
    }

    function doBurn(int24 _tickLower, int24 _tickUpper, uint128 _amount)
        public
        returns (MinterStats memory bfre, MinterStats memory aftr)
    {
        bfre = getStats(_tickLower, _tickUpper);
        pool.burn(_tickLower, _tickUpper, _amount);
        aftr = getStats(_tickLower, _tickUpper);
    }

    function getReward(uint256 tokenId) public returns (uint256 collected) {
        uint256 balanceBefore = rewardToken.balanceOf(address(this));
        gauge.getReward(tokenId);
        uint256 balanceAfter = rewardToken.balanceOf(address(this));
        collected = balanceAfter - balanceBefore;
    }

    struct Balances {
        uint256 rewardToken;
        uint256 token0;
        uint256 token1;
    }

    function getBalances() internal view returns (Balances memory b) {
        b.rewardToken = rewardToken.balanceOf(address(this));
        b.token0 = token0.balanceOf(address(this));
        b.token1 = token1.balanceOf(address(this));
    }

    // collectedReward reward tokens collected
    // collectedToken0 token0 tokens collected
    // collectedToken1 token1 tokens collected
    // feeGrowthInside0LastX128Before fee growth inside (from nft) for token0 before action
    // feeGrowthInside1LastX128Before fee growth inside (from nft) for token1 before action
    // feeGrowthInside0LastX128After fee growth inside (from nft) for token0 after action
    // feeGrowthInside1LastX128After fee growth inside (from nft) for token1 after action
    // tokensOwed0 tokens owed for token0 (from nft)
    // tokensOwed1 tokens owed for token1 (from nft)
    struct StakingData {
        uint256 collectedReward;
        uint256 collectedToken0;
        uint256 collectedToken1;
        uint256 feeGrowthInside0LastX128Before;
        uint256 feeGrowthInside1LastX128Before;
        uint256 feeGrowthInside0LastX128After;
        uint256 feeGrowthInside1LastX128After;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function deposit(uint256 tokenId) public returns (StakingData memory sd) {
        Balances memory beforeBalance = getBalances();
        (,,,,,,,, sd.feeGrowthInside0LastX128Before, sd.feeGrowthInside1LastX128Before,,) = nft.positions(tokenId);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        Balances memory afterBalance = getBalances();

        (,,,,,,,, sd.feeGrowthInside0LastX128After, sd.feeGrowthInside1LastX128After, sd.tokensOwed0, sd.tokensOwed1) =
            nft.positions(tokenId);
        sd.collectedReward = afterBalance.rewardToken - beforeBalance.rewardToken;
        sd.collectedToken0 = afterBalance.token0 - beforeBalance.token0;
        sd.collectedToken1 = afterBalance.token1 - beforeBalance.token1;
    }

    function withdraw(uint256 tokenId) public returns (StakingData memory sd) {
        Balances memory beforeBalance = getBalances();
        (,,,,,,,, sd.feeGrowthInside0LastX128Before, sd.feeGrowthInside1LastX128Before,,) = nft.positions(tokenId);
        gauge.withdraw(tokenId);
        Balances memory afterBalance = getBalances();

        (,,,,,,,, sd.feeGrowthInside0LastX128After, sd.feeGrowthInside1LastX128After, sd.tokensOwed0, sd.tokensOwed1) =
            nft.positions(tokenId);
        sd.collectedReward = afterBalance.rewardToken - beforeBalance.rewardToken;
        sd.collectedToken0 = afterBalance.token0 - beforeBalance.token0;
        sd.collectedToken1 = afterBalance.token1 - beforeBalance.token1;
    }

    // collectedReward reward tokens collected
    // feeGrowthInside0LastX128Before fee growth inside (from nft) for token0 before action
    // feeGrowthInside1LastX128Before fee growth inside (from nft) for token1 before action
    // feeGrowthInside0LastX128After fee growth inside (from nft) for token0 after action
    // feeGrowthInside1LastX128After fee growth inside (from nft) for token1 after action
    // tokensOwed0 tokens owed for token0 (from nft)
    // tokensOwed1 tokens owed for token1 (from nft)
    // liquidityBefore liquidity (from nft) before action
    // liquidityAfter liquidity (from nft) after action
    // token0Change change in tokens for token0 (from gauge) after action
    // token1Change change in tokens for token1 (from gauge) after action
    // actualToken0Change realized change in token0 after action
    // actualToken1Change realized change in token1 after action
    struct LiquidityManagementData {
        uint256 collectedReward;
        uint256 feeGrowthInside0LastX128Before;
        uint256 feeGrowthInside1LastX128Before;
        uint256 feeGrowthInside0LastX128After;
        uint256 feeGrowthInside1LastX128After;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
        uint128 liquidityBefore;
        uint128 liquidityAfter;
        uint256 token0Change;
        uint256 token1Change;
        uint256 actualToken0Change;
        uint256 actualToken1Change;
    }

    function increaseStakedLiquidity(uint256 tokenId, uint128 liquidity)
        public
        returns (LiquidityManagementData memory lmd)
    {
        (,,,,,,, lmd.liquidityBefore, lmd.feeGrowthInside0LastX128Before, lmd.feeGrowthInside1LastX128Before,,) =
            nft.positions(tokenId);

        uint256 amount0;
        uint256 amount1;
        {
            (, int24 currentTick,,,,) = pool.slot0();
            (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nft.positions(tokenId);

            (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                TickMath.getSqrtRatioAtTick(currentTick),
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );
        }

        Balances memory beforeBalance = getBalances();

        token0.approve(address(gauge), amount0);
        token1.approve(address(gauge), amount1);
        (, lmd.token0Change, lmd.token1Change) =
            gauge.increaseStakedLiquidity(tokenId, amount0, amount1, 0, 0, block.timestamp);

        Balances memory afterBalance = getBalances();

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            lmd.liquidityAfter,
            lmd.feeGrowthInside0LastX128After,
            lmd.feeGrowthInside1LastX128After,
            lmd.tokensOwed0,
            lmd.tokensOwed1
        ) = nft.positions(tokenId);
        lmd.collectedReward = afterBalance.rewardToken - beforeBalance.rewardToken;
        lmd.actualToken0Change = beforeBalance.token0 - afterBalance.token0;
        lmd.actualToken1Change = beforeBalance.token1 - afterBalance.token1;
    }

    function decreaseStakedLiquidity(uint256 tokenId, uint128 seed)
        public
        returns (LiquidityManagementData memory lmd)
    {
        (,,,,,,, lmd.liquidityBefore, lmd.feeGrowthInside0LastX128Before, lmd.feeGrowthInside1LastX128Before,,) =
            nft.positions(tokenId);

        uint128 liquidityToRemove = get_random_decrease_amount(seed, lmd.liquidityBefore);

        Balances memory beforeBalance = getBalances();

        (lmd.token0Change, lmd.token1Change) =
            gauge.decreaseStakedLiquidity(tokenId, liquidityToRemove, 0, 0, block.timestamp);

        Balances memory afterBalance = getBalances();

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            lmd.liquidityAfter,
            lmd.feeGrowthInside0LastX128After,
            lmd.feeGrowthInside1LastX128After,
            lmd.tokensOwed0,
            lmd.tokensOwed1
        ) = nft.positions(tokenId);
        lmd.collectedReward = afterBalance.rewardToken - beforeBalance.rewardToken;
        lmd.actualToken0Change = afterBalance.token0 - beforeBalance.token0;
        lmd.actualToken1Change = afterBalance.token1 - beforeBalance.token1;
    }

    function nftCollect(uint256 tokenId) public returns (uint256 amount0, uint256 amount1) {
        return nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
    }
}

contract CLSwapper {
    CLPool pool;
    CoreTestERC20 token0;
    CoreTestERC20 token1;

    CLGauge gauge;

    struct SwapperStats {
        uint128 liq;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
        uint256 bal0;
        uint256 bal1;
        uint128 gaugeFees0;
        uint128 gaugeFees1;
        int24 tick;
    }

    constructor(CoreTestERC20 _token0, CoreTestERC20 _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function setPool(CLPool _pool) public {
        pool = _pool;
    }

    function setGauge(CLGauge _gauge) public {
        gauge = _gauge;
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) token0.transfer(address(pool), uint256(amount0Delta));
        if (amount1Delta > 0) token1.transfer(address(pool), uint256(amount1Delta));
    }

    function getStats() internal view returns (SwapperStats memory stats) {
        (, int24 currentTick,,,,) = pool.slot0();
        (uint128 gf0, uint128 gf1) = pool.gaugeFees();
        return SwapperStats(
            pool.liquidity(),
            pool.feeGrowthGlobal0X128(),
            pool.feeGrowthGlobal1X128(),
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            gf0,
            gf1,
            currentTick
        );
    }

    function doSwap(bool _zeroForOne, int256 _amountSpecified, uint160 _sqrtPriceLimitX96)
        public
        returns (SwapperStats memory bfre, SwapperStats memory aftr)
    {
        bfre = getStats();
        pool.swap(address(this), _zeroForOne, _amountSpecified, _sqrtPriceLimitX96, new bytes(0));
        aftr = getStats();
    }
}
