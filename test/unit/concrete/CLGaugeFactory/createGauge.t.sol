pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLGaugeFactoryTest} from "./CLGaugeFactory.t.sol";
import {CLGauge} from "contracts/gauge/CLGauge.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CreateGaugeTest is CLGaugeFactoryTest {
    address public pool;
    address public feesVotingReward;

    function setUp() public override {
        super.setUp();

        vm.startPrank({msgSender: address(voter)});
    }

    function test_RevertIf_NotVoter() public {
        pool = poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: TICK_SPACING_LOW});
        vm.expectRevert(abi.encodePacked("NV"));
        changePrank(users.charlie);
        CLGauge(
            gaugeFactory.createGauge({
                _forwarder: forwarder,
                _pool: pool,
                _feesVotingReward: address(feesVotingReward),
                _rewardToken: address(rewardToken),
                _isPool: true
            })
        );
    }

    function test_RevertIf_AlreadyCreated() public {
        pool = poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: TICK_SPACING_LOW});
        vm.expectRevert(abi.encodePacked("ERC1167: create2 failed"));
        CLGauge(
            gaugeFactory.createGauge({
                _forwarder: forwarder,
                _pool: pool,
                _feesVotingReward: address(feesVotingReward),
                _rewardToken: address(rewardToken),
                _isPool: true
            })
        );
    }

    function test_CreateGauge() public {
        pool = poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: TICK_SPACING_LOW});
        CLGauge gauge = CLGauge(voter.gauges(pool));
        feesVotingReward = voter.gaugeToFees(address(gauge));

        assertEq(gauge.forwarder(), forwarder);
        assertEq(address(gauge.pool()), pool);
        assertEq(gauge.feesVotingReward(), address(feesVotingReward));
        assertEq(gauge.rewardToken(), address(rewardToken));
        assertEq(gauge.isPool(), true);
    }
}
