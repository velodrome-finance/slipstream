pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLGaugeFactoryTest} from "./CLGaugeFactory.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CreateGaugeTest is CLGaugeFactoryTest {
    address pool;

    function setUp() public override {
        super.setUp();

        pool = poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: TICK_SPACING_LOW});

        vm.startPrank({msgSender: address(voter)});
    }

    function test_RevertIf_NotVoter() public {
        vm.expectRevert(abi.encodePacked("NV"));
        changePrank(users.charlie);
        CLGauge(
            gaugeFactory.createGauge({
                _forwarder: forwarder,
                _pool: pool,
                _feesVotingReward: feesVotingReward,
                _rewardToken: rewardToken,
                _isPool: true
            })
        );
    }

    function test_CreateGauge() public {
        CLGauge gauge = CLGauge(
            gaugeFactory.createGauge({
                _forwarder: forwarder,
                _pool: pool,
                _feesVotingReward: feesVotingReward,
                _rewardToken: rewardToken,
                _isPool: true
            })
        );

        assertEq(gauge.forwarder(), forwarder);
        assertEq(address(gauge.pool()), pool);
        assertEq(gauge.feesVotingReward(), feesVotingReward);
        assertEq(gauge.rewardToken(), rewardToken);
        assertEq(gauge.isPool(), true);
    }
}
