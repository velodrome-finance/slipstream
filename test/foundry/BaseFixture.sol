pragma solidity ^0.7.6;
pragma abicoder v2;

import 'forge-std/Test.sol';
import {UniswapV3Factory} from 'contracts/core/UniswapV3Factory.sol';
import {UniswapV3Pool} from 'contracts/core/UniswapV3Pool.sol';
import {Constants} from './utils/Constants.sol';
import {Events} from './utils/Events.sol';
import {PoolUtils} from './utils/PoolUtils.sol';
import {Users} from './utils/Users.sol';

contract BaseFixture is Test, Constants, Events, PoolUtils {
    UniswapV3Factory public poolFactory;
    UniswapV3Pool public poolImplementation;

    Users internal users;

    function setUp() public virtual {
        users = Users({
            owner: createUser('Owner'),
            feeManager: createUser('FeeManager'),
            alice: createUser('Alice'),
            bob: createUser('Bob'),
            charlie: createUser('Charlie')
        });

        poolImplementation = new UniswapV3Pool();
        poolFactory = new UniswapV3Factory(address(poolImplementation));

        poolFactory.setOwner(users.owner);
        poolFactory.setFeeManager(users.feeManager);

        labelContracts();
    }

    function labelContracts() internal {
        vm.label({account: address(poolImplementation), newLabel: 'Pool Implementation'});
        vm.label({account: address(poolFactory), newLabel: 'Pool Factory'});
    }

    function createUser(string memory name) internal returns (address payable user) {
        user = payable(makeAddr({name: name}));
        vm.deal({account: user, newBalance: TOKEN_1 * 1000});
    }
}
