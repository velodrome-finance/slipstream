pragma solidity ^0.7.6;
pragma abicoder v2;

import {CLGauge} from "contracts/gauge/CLGauge.sol";
import {CLGaugeTest} from "./CLGauge.t.sol";

contract InitializeTest is CLGaugeTest {
    function test_RevertIf_AlreadyInitialized() public {
        address pool =
            poolFactory.createPool({tokenA: TEST_TOKEN_0, tokenB: TEST_TOKEN_1, tickSpacing: TICK_SPACING_LOW});
        address gauge = voter.gauges(pool);
        address feesVotingReward = voter.gaugeToFees(gauge);

        vm.expectRevert(abi.encodePacked("AI"));
        CLGauge(gauge).initialize({
            _forwarder: forwarder,
            _pool: pool,
            _feesVotingReward: feesVotingReward,
            _rewardToken: address(rewardToken),
            _voter: address(voter),
            _nft: address(nft),
            _token0: address(token0),
            _token1: address(token1),
            _isPool: true
        });
    }
}
