pragma solidity ^0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/periphery/interfaces/INonfungiblePositionManager.sol";
import "./NonfungiblePositionManager.t.sol";

contract DecreaseLiquidityTest is NonfungiblePositionManagerTest {
    function test_RevertIf_CallerIsNotGauge() public {
        pool.initialize({sqrtPriceX96: encodePriceSqrt(1, 1)});

        uint256 tokenId = mintNewCustomRangePositionForUserWith60TickSpacing(
            TOKEN_1, TOKEN_1, getMinTick(TICK_SPACING_60), getMaxTick(TICK_SPACING_60), users.alice
        );

        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});

        vm.expectRevert(bytes("Not approved"));
        nft.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: uint128(TOKEN_1),
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );
    }

    // TODO Check feeGrowth once #42 is done
}
