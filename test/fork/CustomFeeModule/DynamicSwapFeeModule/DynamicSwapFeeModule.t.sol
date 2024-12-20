pragma solidity ^0.7.6;
pragma abicoder v2;

import "../../BaseForkFixture.sol";

abstract contract DynamicSwapFeeModuleForkTest is BaseForkFixture {
    address[] pools;
    uint24[] fees;

    string public poolAddresses;

    function setUp() public virtual override {
        blockNumber = 128301098;
        super.setUp();

        poolFactory = CLFactory(vm.parseJsonAddress(addresses, ".CLFactory"));

        dynamicSwapFeeModule = new DynamicSwapFeeModule({
            _factory: address(poolFactory),
            _defaultScalingFactor: 100 * 1e6,
            _defaultFeeCap: 20_000,
            _pools: pools,
            _fees: fees
        });

        vm.label({account: address(poolFactory), newLabel: "Pool Factory"});
        vm.label({account: address(dynamicSwapFeeModule), newLabel: "Dynamic Swap Fee Module"});
    }
}
