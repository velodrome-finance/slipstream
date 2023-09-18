pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/StdJson.sol";
import "../BaseFixture.sol";

contract LiquidityFlow is BaseFixture {
    using stdJson for string;

    string public addresses;

    function setUp() public virtual override {
        vm.createSelectFork({urlOrAlias: "optimism", blockNumber: 109241151});

        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/test/fork/addresses.json"));
        addresses = vm.readFile(path);

        // set up contracts after fork
        BaseFixture.setUp();
    }

    function deployDependencies() public virtual override {
        factoryRegistry = IFactoryRegistry(vm.parseJsonAddress(addresses, ".FactoryRegistry"));
        weth = IERC20(vm.parseJsonAddress(addresses, ".WETH"));
        voter = IVoter(vm.parseJsonAddress(addresses, ".Voter"));
        rewardToken = ERC20(vm.parseJsonAddress(addresses, ".Velo"));
        votingRewardsFactory = IVotingRewardsFactory(vm.parseJsonAddress(addresses, ".VotingRewardsFactory"));
        escrow = IVotingEscrow(vm.parseJsonAddress(addresses, ".VotingEscrow"));
    }

    function testStub() public {
        console2.log("stub");
    }
}
