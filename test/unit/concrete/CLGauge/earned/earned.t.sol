pragma solidity ^0.7.6;
pragma abicoder v2;

import "../CLGauge.t.sol";

contract EarnedConcreteUnitTest is CLGaugeTest {
    uint256 public minStakeTime = 10;
    uint256 public penaltyRate = 5_000;

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
        gauge.earned(users.charlie, tokenId);
    }

    modifier whenTheCallerIsTheTokenOwner() {
        _;
    }

    function test_WhenThereAreNoClaimableRewards() external whenTheCallerIsTheTokenOwner {
        // It should return zero
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        assertEq(gauge.earned(users.alice, tokenId), 0);
    }

    modifier whenThereAreClaimableRewards() {
        _;
    }

    function test_WhenPenaltyRateIsZero() external whenTheCallerIsTheTokenOwner whenThereAreClaimableRewards {
        // It should return full rewards
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(1 days);

        vm.startPrank(users.alice);
        uint256 earned = gauge.earned(users.alice, tokenId);
        assertApproxEqAbs(earned, TOKEN_1 / 7, 1e6);
        gauge.getReward(tokenId);

        assertEq(rewardToken.balanceOf(users.alice), earned);
    }

    modifier whenPenaltyRateIsGreaterThanZero() {
        vm.startPrank(users.owner);
        gaugeFactory.setDefaultMinStakeTime({_minStakeTime: minStakeTime});
        gaugeFactory.setPenaltyRate({_penaltyRate: penaltyRate});
        vm.stopPrank();
        _;
    }

    function test_WhenCalledWithinMinStakeTime()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreClaimableRewards
        whenPenaltyRateIsGreaterThanZero
    {
        // It should return rewards minus penalty
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime / 2); // within penalty window

        vm.startPrank(users.alice);
        uint256 netEarned = gauge.earned(users.alice, tokenId);
        // 5s of TOKEN_1 over 604800s epoch, minus 50% penalty
        assertApproxEqAbs(netEarned, TOKEN_1 * (minStakeTime / 2) / WEEK / 2, 1e6);
        uint256 expectedPenalty = netEarned * penaltyRate / (10_000 - penaltyRate);
        gauge.getReward(tokenId);

        assertEq(rewardToken.balanceOf(users.alice), netEarned);
        assertEq(rewardToken.balanceOf(address(minter)), expectedPenalty);
    }

    function test_WhenCalledAfterMinStakeTime()
        external
        whenTheCallerIsTheTokenOwner
        whenThereAreClaimableRewards
        whenPenaltyRateIsGreaterThanZero
    {
        // It should return full rewards
        uint256 tokenId = nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1, TOKEN_1, users.alice);

        vm.startPrank(users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);

        addRewardToGauge(address(voter), address(gauge), TOKEN_1);
        skip(minStakeTime); // at exact boundary — condition is <, so penalty does not apply

        vm.startPrank(users.alice);
        uint256 earned = gauge.earned(users.alice, tokenId);
        gauge.getReward(tokenId);

        // no penalty — earned matches full claim
        assertEq(rewardToken.balanceOf(users.alice), earned);
        assertEq(rewardToken.balanceOf(address(minter)), 0);
    }
}
