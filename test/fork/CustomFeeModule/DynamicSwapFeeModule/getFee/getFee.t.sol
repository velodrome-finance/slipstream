pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/Strings.sol";

import "../DynamicSwapFeeModule.t.sol";

import {TickMath} from "contracts/core/libraries/TickMath.sol";
import {FullMath} from "contracts/core/libraries/FullMath.sol";
import {ICLPoolState} from "contracts/core/interfaces/pool/ICLPoolState.sol";

contract GetFeeForkTest is DynamicSwapFeeModuleForkTest {
    address pool;
    int24 tickSpacing;
    uint24 originalSwapFee;
    uint24 newBaseSwapFee;

    function setUp() public virtual override {
        super.setUp();

        // CL100UsdcWeth - TVL at the time of the tests written: ~$4,670,585.28
        pool = 0x478946BcD4a5a22b316470F5486fAfb928C0bA25;

        originalSwapFee = poolFactory.getSwapFee(pool);

        vm.prank(poolFactory.swapFeeManager());
        poolFactory.setSwapFeeModule({_swapFeeModule: address(dynamicSwapFeeModule)});

        newBaseSwapFee = originalSwapFee / 2;
        // set back the original swap fee / 2 as base fee
        vm.prank(poolFactory.swapFeeManager());
        dynamicSwapFeeModule.setCustomFee({_pool: pool, _fee: newBaseSwapFee});

        token0 = ERC20(CLPool(pool).token0());
        token1 = ERC20(CLPool(pool).token1());

        tickSpacing = CLPool(pool).tickSpacing();

        nftCallee = new NFTManagerCallee(address(token0), address(token1), address(nft));

        vm.startPrank(users.alice);
        token0.approve(address(nft), type(uint256).max);
        token1.approve(address(nft), type(uint256).max);
        token0.approve(address(clCallee), type(uint256).max);
        token1.approve(address(clCallee), type(uint256).max);
        token0.approve(address(nftCallee), type(uint256).max);
        token1.approve(address(nftCallee), type(uint256).max);
        vm.stopPrank();

        // give some extra tokens to alice
        if (token0.decimals() == 6) {
            deal({token: address(token0), to: users.alice, give: USDC_1 * 1_000_000_000});
        } else {
            deal({token: address(token0), to: users.alice, give: TOKEN_1 * 1_000_000_000});
        }
        deal({token: address(token1), to: users.alice, give: TOKEN_1 * 1_000_000_000});

        vm.label({account: address(pool), newLabel: "Pool"});
        vm.label({account: address(token0), newLabel: "Token 0"});
        vm.label({account: address(token1), newLabel: "Token 1"});
    }

    modifier whenScalingFactorIsSetOnThePool() {
        vm.startPrank(poolFactory.swapFeeManager());
        dynamicSwapFeeModule.setFeeCap({_pool: pool, _feeCap: 30_000});
        dynamicSwapFeeModule.setScalingFactor({
            _pool: pool,
            _scalingFactor: uint64(200 * dynamicSwapFeeModule.SCALING_PRECISION())
        });
        vm.stopPrank();
        _;
    }

    function testGasFork_WhenTxOriginIsNotDiscounted() external whenScalingFactorIsSetOnThePool {
        vm.startPrank({msgSender: users.alice, txOrigin: users.alice});

        clCallee.swapExact0For1(address(pool), USDC_1 * 300_000, users.alice, MIN_SQRT_RATIO + 1);
        skip(20 minutes);

        (, int24 currentTick,,,,) = ICLPool(pool).slot0();

        int24 twAvgTick = getTwAvgTick();

        uint256 expectedDynamicFee = getPoolExpectedDynamicFee(currentTick, twAvgTick);

        uint24 totalFee = newBaseSwapFee + uint24(expectedDynamicFee);

        uint24 fee = dynamicSwapFeeModule.getFee(pool);
        vm.snapshotGasLastCall("DynamicSwapFeeModule_getFee_fork");

        assertEqUint(fee, totalFee);
    }

    /// HELPERS

    function getPoolExpectedDynamicFee(int24 _currentTick, int24 _twAvgTick) internal pure returns (uint256) {
        uint24 absCurrentTick = _currentTick < 0 ? uint24(-_currentTick) : uint24(_currentTick);
        uint24 absTwAvgTick = _twAvgTick < 0 ? uint24(-_twAvgTick) : uint24(_twAvgTick);

        uint24 tickDelta = absCurrentTick > absTwAvgTick ? absCurrentTick - absTwAvgTick : absTwAvgTick - absCurrentTick;

        return tickDelta * 200;
    }

    function getTwAvgTick() public view returns (int24) {
        uint32 _twapDuration = 600;
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = _twapDuration;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives,) = CLPool(pool).observe(secondsAgo);
        return int24((tickCumulatives[1] - tickCumulatives[0]) / _twapDuration);
    }
}
