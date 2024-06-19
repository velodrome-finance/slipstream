pragma solidity ^0.7.6;
pragma abicoder v2;

import "../BaseForkFixture.sol";

contract LpMigratorTest is BaseForkFixture {
    INonfungiblePositionManager public nftFrom;

    function setUp() public override {
        blockNumber = 121376323;
        super.setUp();

        nftFrom = INonfungiblePositionManager(0xbB5DFE1380333CEE4c2EeBd7202c80dE2256AdF4);
    }

    function testFork_MigrateSlipstreamToSlipstream_WithOldNftAndNewNft() public {
        vm.startPrank(users.alice);
        uint256 amount0In = 1_748958694696034312; // ~1.75 WETH
        uint256 amount1In = 2999_999999999999999962; // ~3k OP

        deal(address(weth), users.alice, amount0In);
        deal(address(op), users.alice, amount1In);

        op.approve(address(nftFrom), type(uint256).max);
        weth.approve(address(nftFrom), type(uint256).max);

        // create position
        (uint256 tokenId,, uint256 amount0, uint256 amount1) = nftFrom.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(weth),
                token1: address(op),
                tickSpacing: TICK_SPACING_200,
                tickLower: getMinTick(TICK_SPACING_200),
                tickUpper: getMaxTick(TICK_SPACING_200),
                recipient: users.alice,
                amount0Desired: amount0In,
                amount1Desired: amount1In,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );

        assertEq(op.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(nftFrom.ownerOf(tokenId), users.alice);

        ILpMigrator.FromParams memory fromParams = ILpMigrator.FromParams({
            nft: address(nftFrom),
            tokenId: tokenId,
            amount0Min: 0,
            amount1Min: 0,
            amount0Extra: 0,
            amount1Extra: 0
        });
        ILpMigrator.ToParams memory toParams = ILpMigrator.ToParams({
            nft: address(nft),
            tickSpacing: TICK_SPACING_200,
            tickLower: getMinTick(TICK_SPACING_200),
            tickUpper: getMaxTick(TICK_SPACING_200),
            amount0Min: 0,
            amount1Min: 0,
            recipient: users.alice,
            deadline: block.timestamp,
            pool: address(0)
        });

        // migrate position
        nftFrom.approve(address(lpMigrator), tokenId);

        uint256 newTokenId;
        (newTokenId,, amount0, amount1) = lpMigrator.migrateSlipstreamToSlipstream(fromParams, toParams);

        // checks
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.ownerOf(newTokenId), users.alice);
        assertEq(op.allowance(address(lpMigrator), address(nft)), 0);
        assertEq(weth.allowance(address(lpMigrator), address(nft)), 0);
        vm.expectRevert("ERC721: owner query for nonexistent token");
        nftFrom.ownerOf(tokenId);

        assertApproxEqAbs(amount0, amount0In, 1e3);
        assertApproxEqAbs(amount1, amount1In, 1e3);
    }

    function testFork_MigrateSlipstreamToSlipstream_WithOldNftAndNewNftAndExtraTokens() public {
        vm.startPrank(users.alice);
        uint256 amount0In = 1_748958694696034312; // ~1.75 WETH
        uint256 amount1In = 2999_999999999999999962; // ~3k OP

        deal(address(weth), users.alice, amount0In);
        deal(address(op), users.alice, amount1In);

        op.approve(address(nftFrom), type(uint256).max);
        weth.approve(address(nftFrom), type(uint256).max);

        // create position
        (uint256 tokenId,, uint256 amount0, uint256 amount1) = nftFrom.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(weth),
                token1: address(op),
                tickSpacing: TICK_SPACING_200,
                tickLower: getMinTick(TICK_SPACING_200),
                tickUpper: getMaxTick(TICK_SPACING_200),
                recipient: users.alice,
                amount0Desired: amount0In,
                amount1Desired: amount1In,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );

        assertEq(op.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(nftFrom.ownerOf(tokenId), users.alice);

        deal(address(weth), users.alice, amount0In);
        deal(address(op), users.alice, amount1In);
        op.approve(address(lpMigrator), type(uint256).max);
        weth.approve(address(lpMigrator), type(uint256).max);

        ILpMigrator.FromParams memory fromParams = ILpMigrator.FromParams({
            nft: address(nftFrom),
            tokenId: tokenId,
            amount0Min: 0,
            amount1Min: 0,
            amount0Extra: amount0In,
            amount1Extra: amount1In
        });
        ILpMigrator.ToParams memory toParams = ILpMigrator.ToParams({
            nft: address(nft),
            tickSpacing: TICK_SPACING_200,
            tickLower: getMinTick(TICK_SPACING_200),
            tickUpper: getMaxTick(TICK_SPACING_200),
            amount0Min: 0,
            amount1Min: 0,
            recipient: users.alice,
            deadline: block.timestamp,
            pool: address(0)
        });

        // migrate position
        nftFrom.approve(address(lpMigrator), tokenId);

        uint256 newTokenId;
        (newTokenId,, amount0, amount1) = lpMigrator.migrateSlipstreamToSlipstream(fromParams, toParams);

        // checks
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.ownerOf(newTokenId), users.alice);
        assertEq(op.allowance(address(lpMigrator), address(nft)), 0);
        assertEq(weth.allowance(address(lpMigrator), address(nft)), 0);
        vm.expectRevert("ERC721: owner query for nonexistent token");
        nftFrom.ownerOf(tokenId);

        assertEq(op.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertApproxEqAbs(amount0, amount0In * 2, 1e3);
        assertApproxEqAbs(amount1, amount1In * 2, 1e3);
    }

    function testFork_MigrateSlipstreamToSlipstream_WithOldNftAndNewNftAndExcessTokens() public {
        vm.startPrank(users.alice);
        uint256 amount0In = 1_748958694696034312; // ~1.75 WETH
        uint256 amount1In = 2999_999999999999999962; // ~3k OP

        deal(address(weth), users.alice, amount0In);
        deal(address(op), users.alice, amount1In);

        op.approve(address(nftFrom), type(uint256).max);
        weth.approve(address(nftFrom), type(uint256).max);

        // create position
        (uint256 tokenId,, uint256 amount0, uint256 amount1) = nftFrom.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(weth),
                token1: address(op),
                tickSpacing: TICK_SPACING_200,
                tickLower: getMinTick(TICK_SPACING_200),
                tickUpper: getMaxTick(TICK_SPACING_200),
                recipient: users.alice,
                amount0Desired: amount0In,
                amount1Desired: amount1In,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                sqrtPriceX96: 0
            })
        );

        assertEq(op.balanceOf(users.alice), 0);
        assertEq(weth.balanceOf(users.alice), 0);
        assertEq(nftFrom.ownerOf(tokenId), users.alice);

        deal(address(weth), users.alice, amount0In);
        deal(address(op), users.alice, amount1In * 2);
        op.approve(address(lpMigrator), type(uint256).max);
        weth.approve(address(lpMigrator), type(uint256).max);

        ILpMigrator.FromParams memory fromParams = ILpMigrator.FromParams({
            nft: address(nftFrom),
            tokenId: tokenId,
            amount0Min: 0,
            amount1Min: 0,
            amount0Extra: amount0In,
            amount1Extra: amount1In * 2
        });
        ILpMigrator.ToParams memory toParams = ILpMigrator.ToParams({
            nft: address(nft),
            tickSpacing: TICK_SPACING_200,
            tickLower: getMinTick(TICK_SPACING_200),
            tickUpper: getMaxTick(TICK_SPACING_200),
            amount0Min: 0,
            amount1Min: 0,
            recipient: users.alice,
            deadline: block.timestamp,
            pool: address(0)
        });

        // migrate position
        nftFrom.approve(address(lpMigrator), tokenId);

        uint256 newTokenId;
        (newTokenId,, amount0, amount1) = lpMigrator.migrateSlipstreamToSlipstream(fromParams, toParams);

        // checks
        assertEq(nft.balanceOf(users.alice), 1);
        assertEq(nft.ownerOf(newTokenId), users.alice);
        assertEq(op.allowance(address(lpMigrator), address(nft)), 0);
        assertEq(weth.allowance(address(lpMigrator), address(nft)), 0);
        vm.expectRevert("ERC721: owner query for nonexistent token");
        nftFrom.ownerOf(tokenId);

        assertApproxEqAbs(op.balanceOf(users.alice), amount1In, 1e4);
        assertEq(weth.balanceOf(users.alice), 0);
        assertApproxEqAbs(amount0, amount0In * 2, 1e4);
        assertApproxEqAbs(amount1, amount1In * 2, 1e4);
    }
}
