pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLFactoryTest} from "./CLFactory.t.sol";

contract EnableTickSpacingTest is CLFactoryTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank({msgSender: users.owner});
    }

    function test_RevertIf_NotOwner() public {
        vm.expectRevert();
        vm.startPrank({msgSender: users.charlie});
        poolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});
    }

    function test_RevertIf_TickSpacingTooSmall() public {
        vm.expectRevert();
        poolFactory.enableTickSpacing({tickSpacing: 0, fee: 5_000});
    }

    function test_RevertIf_TickSpacingTooLarge() public {
        vm.expectRevert();
        poolFactory.enableTickSpacing({tickSpacing: 16_834, fee: 5_000});
    }

    function test_RevertIf_TickSpacingAlreadyEnabled() public {
        poolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});
        vm.expectRevert();
        poolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});
    }

    function test_RevertIf_FeeTooHigh() public {
        vm.expectRevert();
        poolFactory.enableTickSpacing({tickSpacing: 250, fee: 1_000_000});
    }

    function test_RevertIf_FeeIsZero() public {
        vm.expectRevert();
        poolFactory.enableTickSpacing({tickSpacing: 250, fee: 0});
    }

    function test_EnableTickSpacing() public {
        vm.expectEmit(true, false, false, false, address(poolFactory));
        emit TickSpacingEnabled({tickSpacing: 250, fee: 5_000});
        poolFactory.enableTickSpacing({tickSpacing: 250, fee: 5_000});

        assertEqUint(poolFactory.tickSpacingToFee(250), 5_000);
        assertEq(poolFactory.tickSpacings().length, 8);
        assertEq(poolFactory.tickSpacings()[7], 250);

        createAndCheckPool({
            factory: poolFactory,
            token0: TEST_TOKEN_0,
            token1: TEST_TOKEN_1,
            tickSpacing: 250,
            sqrtPriceX96: encodePriceSqrt(1, 1)
        });
    }
}
