pragma solidity ^0.7.6;
pragma abicoder v2;

import "./BaseForkFixture.sol";

contract NotifyRewardAmountWithoutClaimForkTest is BaseForkFixture {
    UniswapV3Pool public pool;
    CLGauge public gauge;
    address public feesVotingReward;

    function setUp() public override {
        super.setUp();

        pool = UniswapV3Pool(
            poolFactory.createPool({
                tokenA: address(weth),
                tokenB: address(op),
                tickSpacing: TICK_SPACING_60,
                sqrtPriceX96: encodePriceSqrt(1, 1)
            })
        );

        vm.prank(users.feeManager);
        customUnstakedFeeModule.setCustomFee(address(pool), 420);

        gauge = CLGauge(voter.gauges(address(pool)));
        feesVotingReward = voter.gaugeToFees(address(gauge));

        skipToNextEpoch(0);
    }

    function testFork_NotifyRewardAmountWithoutClaimResetsRewardRateInKilledGauge() public {
        skip(1 days);

        uint256 reward = TOKEN_1;

        vm.startPrank(users.alice);
        uint256 tokenId =
            nftCallee.mintNewFullRangePositionForUserWith60TickSpacing(TOKEN_1 * 10, TOKEN_1 * 10, users.alice);
        nft.approve(address(gauge), tokenId);
        gauge.deposit(tokenId);
        vm.stopPrank();

        deal(address(rewardToken), address(voter), reward);
        vm.startPrank(address(voter));
        rewardToken.approve(address(gauge), reward);
        gauge.notifyRewardAmount(reward);
        vm.stopPrank();

        uint256 gaugeRewardTokenBalance = rewardToken.balanceOf(address(gauge));
        assertEq(gaugeRewardTokenBalance, reward);

        assertEq(gauge.rewardRate(), reward / 6 days);
        assertEq(gauge.lastUpdateTime(tokenId), block.timestamp);
        assertEq(gauge.periodFinish(), block.timestamp + 6 days);

        vm.prank(voter.emergencyCouncil());
        voter.killGauge(address(gauge));

        skipToNextEpoch(0);

        vm.startPrank(escrow.team());
        deal(address(rewardToken), escrow.team(), 604_800);
        rewardToken.approve(address(gauge), 604_800);
        gauge.notifyRewardWithoutClaim(604_800); // requires minimum value of 604800

        assertEq(gauge.rewardRate(), 1); // reset to token amount
        assertEq(gauge.lastUpdateTime(tokenId), block.timestamp - 6 days);
        assertEq(gauge.periodFinish(), block.timestamp + WEEK);
    }
}
