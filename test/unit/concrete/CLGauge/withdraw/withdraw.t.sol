pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGauge.t.sol";

contract WithdrawConcreteUnitTest is CLGaugeTest {
    using stdStorage for StdStorage;
    using SafeCast for uint128;

    uint256 public minStakeTime = 10;
    uint256 public penaltyRate = 10_000;

    function setUp() public override {
        super.setUp();

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        skipToNextEpoch(0);
    }

    function test_WhenTheCallerIsNotTheTokenOwner() external {
        // It should revert with {NA}
        (uint256 tokenId,) = _mintAndDepositFullRange();

        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.withdraw({tokenId: tokenId});
    }

    modifier whenTheCallerIsTheTokenOwner() {
        _;
    }

    modifier whenThereAreNoAccruedRewards() {
        _;
    }

    function test_WhenThereAreNoAccruedRewards() external whenTheCallerIsTheTokenOwner whenThereAreNoAccruedRewards {
        // It should unstake liquidity from the pool
        // It should clear the deposit timestamp
        (uint256 tokenId,) = _mintAndDepositFullRange();

        vm.startPrank(users.alice);
        gauge.withdraw({tokenId: tokenId});

        assertEq(nft.ownerOf(tokenId), users.alice);
        assertEqUint(pool.stakedLiquidity(), 0);
        assertEq(gauge.stakedLength(users.alice), 0);
        assertEq(gauge.depositTimestamp(tokenId), 0);
        // No rewards — nothing transferred to alice
        assertEq(rewardToken.balanceOf(users.alice), 0);
    }

    modifier whenThereAreAccruedRewards() {
        _;
    }

    modifier whenPenaltyRateIsZero() {
        // default: penalty params not configured
        _;
    }

    function test_WhenPenaltyRateIsZero()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenPenaltyRateIsZero
    {
        // It should transfer full rewards to owner
        // It should emit a {ClaimRewards} event
        // It should unstake liquidity from the pool
        // It should return the NFT to the owner
        // It should emit a {Withdraw} event
        (uint256 tokenId, uint128 liquidity) = _mintAndDepositFullRange();

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(1 days);

        vm.startPrank(users.alice);
        uint256 expectedReward = gauge.earned(users.alice, tokenId);
        vm.expectEmit(address(gauge));
        emit ClaimRewards({from: users.alice, amount: expectedReward});
        vm.expectEmit(address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        assertEq(rewardToken.balanceOf(users.alice), expectedReward);
        assertEq(rewardToken.balanceOf(address(minter)), 0);
        assertEq(nft.ownerOf(tokenId), users.alice);
        assertEqUint(pool.stakedLiquidity(), 0);
    }

    modifier whenPenaltyRateIsGreaterThanZero() {
        vm.startPrank(users.owner);
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: minStakeTime});
        gaugeFactory.setPenaltyRate({_penaltyRate: penaltyRate});
        vm.stopPrank();
        _;
    }

    modifier whenCalledWithinMinStakeTime() {
        _;
    }

    function test_WhenPenaltyRoundsDownToZero()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenPenaltyRateIsGreaterThanZero
        whenCalledWithinMinStakeTime
    {
        // It should transfer full rewards to owner
        // penaltyRate = 1 bps, reward = 1 wei → penalty rounds to 0
        penaltyRate = 1;
        vm.startPrank(users.owner);
        gaugeFactory.setPenaltyRate({_penaltyRate: penaltyRate});
        vm.stopPrank();

        (uint256 tokenId,) = _mintAndDepositFullRange();

        addRewardToGauge(address(voter), address(gauge), 1209600); // rate = 2 wei/sec → earned = 1 after 1s
        skip(1); // penalty = 1 * 1 / 10_000 = 0 (rounds down)

        vm.startPrank(users.alice);
        gauge.withdraw({tokenId: tokenId});

        assertGt(rewardToken.balanceOf(users.alice), 0);
        assertEq(rewardToken.balanceOf(address(minter)), 0);
    }

    modifier whenPenaltyDoesNotRoundDownToZero() {
        _;
    }

    modifier whenThereAreNoRemainingRewardsAfterPenalty() {
        _;
    }

    function test_WhenThereAreNoRemainingRewardsAfterPenalty()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenPenaltyRateIsGreaterThanZero
        whenCalledWithinMinStakeTime
        whenPenaltyDoesNotRoundDownToZero
        whenThereAreNoRemainingRewardsAfterPenalty
    {
        // It should transfer penalty to minter
        // It should emit a {EarlyWithdrawPenalty} event
        // It should unstake liquidity from the pool
        // It should return the NFT to the owner
        // It should emit a {Withdraw} event
        (uint256 tokenId, uint128 liquidity) = _mintAndDepositFullRange();

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime / 2); // within penalty window

        vm.startPrank(users.alice);
        // earned() returns 0 at 100% penalty
        assertEq(gauge.earned(users.alice, tokenId), 0);
        uint256 gaugeBalBefore = rewardToken.balanceOf(address(gauge));
        vm.expectEmit(address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        // 100% penalty — alice gets no rewards, minter gets all accrued rewards
        assertEq(rewardToken.balanceOf(users.alice), 0);
        assertEq(rewardToken.balanceOf(address(minter)), gaugeBalBefore - rewardToken.balanceOf(address(gauge)));
        assertEq(nft.ownerOf(tokenId), users.alice);
        assertEqUint(pool.stakedLiquidity(), 0);
    }

    modifier whenThereAreRemainingRewardsAfterPenalty() {
        _;
    }

    function test_WhenThereAreRemainingRewardsAfterPenalty()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenPenaltyRateIsGreaterThanZero
        whenCalledWithinMinStakeTime
        whenPenaltyDoesNotRoundDownToZero
        whenThereAreRemainingRewardsAfterPenalty
    {
        // It should transfer penalty to minter
        // It should emit a {EarlyWithdrawPenalty} event
        // It should transfer remaining rewards to owner
        // It should unstake liquidity from the pool
        // It should return the NFT to the owner
        // It should emit a {Withdraw} event
        penaltyRate = 5_000;
        vm.startPrank(users.owner);
        gaugeFactory.setPenaltyRate({_penaltyRate: penaltyRate});
        vm.stopPrank();

        (uint256 tokenId, uint128 liquidity) = _mintAndDepositFullRange();

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime / 2);

        vm.startPrank(users.alice);
        uint256 netEarned = gauge.earned(users.alice, tokenId);
        uint256 expectedPenalty = netEarned * penaltyRate / (10_000 - penaltyRate);
        vm.expectEmit(address(gauge));
        emit EarlyWithdrawPenalty({from: users.alice, tokenId: tokenId, penalty: expectedPenalty});
        vm.expectEmit(address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        assertEq(rewardToken.balanceOf(users.alice), netEarned);
        assertEq(rewardToken.balanceOf(address(minter)), expectedPenalty);
        assertEq(nft.ownerOf(tokenId), users.alice);
        assertEqUint(pool.stakedLiquidity(), 0);
    }

    modifier whenCalledAfterMinStakeTime() {
        _;
    }

    function test_WhenCalledAfterMinStakeTime()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenPenaltyRateIsGreaterThanZero
        whenCalledAfterMinStakeTime
    {
        // It should transfer full rewards to owner
        // It should emit a {ClaimRewards} event
        // It should unstake liquidity from the pool
        // It should return the NFT to the owner
        // It should emit a {Withdraw} event
        (uint256 tokenId, uint128 liquidity) = _mintAndDepositFullRange();

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime); // at exact boundary — condition is <, so penalty does not apply

        vm.startPrank(users.alice);
        uint256 expectedReward = gauge.earned(users.alice, tokenId);
        vm.expectEmit(address(gauge));
        emit ClaimRewards({from: users.alice, amount: expectedReward});
        vm.expectEmit(address(gauge));
        emit Withdraw({user: users.alice, tokenId: tokenId, liquidityToStake: liquidity});
        gauge.withdraw({tokenId: tokenId});

        assertEq(rewardToken.balanceOf(users.alice), expectedReward);
        assertEq(rewardToken.balanceOf(address(minter)), 0);
        assertEq(nft.ownerOf(tokenId), users.alice);
        assertEqUint(pool.stakedLiquidity(), 0);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    function _mintAndDepositFullRange() internal returns (uint256 tokenId, uint128 liquidity) {
        vm.startPrank(users.alice);
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            tickSpacing: TICK_SPACING_60,
            tickLower: -TICK_SPACING_60,
            tickUpper: TICK_SPACING_60,
            recipient: users.alice,
            amount0Desired: TOKEN_1,
            amount1Desired: TOKEN_1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp,
            sqrtPriceX96: 0
        });
        (tokenId, liquidity,,) = nft.mint(params);
        nft.approve(address(gauge), tokenId);
        gauge.deposit({tokenId: tokenId});
    }
}
