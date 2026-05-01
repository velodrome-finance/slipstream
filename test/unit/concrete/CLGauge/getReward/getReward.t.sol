pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGauge.t.sol";

contract GetRewardConcreteUnitTest is CLGaugeTest {
    uint256 public minStakeTime = 10;
    uint256 public penaltyRate = 10_000;

    function setUp() public override {
        super.setUp();
        skipToNextEpoch(0);
    }

    function test_WhenTheCallerIsNotTheTokenOwner() external {
        // It should revert with {NA}
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        vm.startPrank(users.charlie);
        vm.expectRevert(abi.encodePacked("NA"));
        gauge.getReward(tokenId);
    }

    modifier whenTheCallerIsTheTokenOwner() {
        _;
    }

    function test_WhenThereAreNoAccruedRewards() external whenTheCallerIsTheTokenOwner {
        // It should not transfer any tokens
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        gauge.getReward(tokenId);

        assertEq(rewardToken.balanceOf(users.alice), 0);
        assertEq(gauge.rewards(tokenId), 0);
    }

    modifier whenThereAreAccruedRewards() {
        _;
    }

    function test_WhenPenaltyRateIsZero() external whenTheCallerIsTheTokenOwner whenThereAreAccruedRewards {
        // It should transfer full rewards to owner
        // It should emit a {ClaimRewards} event
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(1 days);

        vm.startPrank(users.alice);
        uint256 expectedReward = gauge.earned(users.alice, tokenId);
        vm.expectEmit(address(gauge));
        emit ClaimRewards({from: users.alice, amount: expectedReward});
        gauge.getReward(tokenId);

        assertEq(rewardToken.balanceOf(users.alice), expectedReward);
        assertEq(rewardToken.balanceOf(address(minter)), 0);
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

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), 1209600); // rate = 2 wei/sec → earned = 1 after 1s
        skip(1); // penalty = 1 * 1 / 10_000 = 0 (rounds down)

        vm.startPrank(users.alice);
        gauge.getReward(tokenId);

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
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime / 2); // within penalty window

        vm.startPrank(users.alice);
        // earned() returns 0 at 100% penalty
        assertEq(gauge.earned(users.alice, tokenId), 0);
        uint256 gaugeBalBefore = rewardToken.balanceOf(address(gauge));
        gauge.getReward(tokenId);

        // 100% penalty — alice gets nothing, minter gets all accrued rewards
        assertEq(rewardToken.balanceOf(users.alice), 0);
        assertEq(rewardToken.balanceOf(address(minter)), gaugeBalBefore - rewardToken.balanceOf(address(gauge)));
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
        // It should emit a {ClaimRewards} event
        penaltyRate = 5_000;
        vm.startPrank(users.owner);
        gaugeFactory.setPenaltyRate({_penaltyRate: penaltyRate});
        vm.stopPrank();

        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime / 2);

        vm.startPrank(users.alice);
        uint256 netEarned = gauge.earned(users.alice, tokenId);
        uint256 expectedPenalty = netEarned * penaltyRate / (10_000 - penaltyRate);
        vm.expectEmit(address(gauge));
        emit EarlyWithdrawPenalty({from: users.alice, tokenId: tokenId, penalty: expectedPenalty});
        vm.expectEmit(address(gauge));
        emit ClaimRewards({from: users.alice, amount: netEarned});
        gauge.getReward(tokenId);

        assertEq(rewardToken.balanceOf(users.alice), netEarned);
        assertEq(rewardToken.balanceOf(address(minter)), expectedPenalty);
    }

    function test_WhenCalledAfterMinStakeTime()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreAccruedRewards
        whenPenaltyRateIsGreaterThanZero
    {
        // It should transfer full rewards to owner
        // It should emit a {ClaimRewards} event
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime); // at exact boundary — condition is <, so penalty does not apply

        vm.startPrank(users.alice);
        uint256 expectedReward = gauge.earned(users.alice, tokenId);
        vm.expectEmit(address(gauge));
        emit ClaimRewards({from: users.alice, amount: expectedReward});
        gauge.getReward(tokenId);

        assertEq(rewardToken.balanceOf(users.alice), expectedReward);
        assertEq(rewardToken.balanceOf(address(minter)), 0);
    }
}
