// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

interface ILpMigrator {
    event MigratedSlipstreamToSliptream(address indexed sender, uint256 indexed fromTokenId, uint256 indexed toTokenId);

    // @param nft Position manager you wish to burn from
    // @param tokenId Token id of position you wish to burn
    // @param amount0Min Minimum amount of token0 to receive
    // @param amount1Min Minimum amount of token1 to receive
    // @param amount0Extra Additional token0 you wish to add to new position
    // @param amount1Extra Additional token1 you wish to add to new position
    struct FromParams {
        address nft;
        uint256 tokenId;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 amount0Extra;
        uint256 amount1Extra;
    }

    // @param nft Position manager you wish to mint from
    // @param tickSpacing Tick spacing of new pool
    // @param tickLower Lower tick of new position
    // @param tickUpper Upper tick of new position
    // @param amount0Min Minimum amount of token0 to expect from deposit
    // @param amount1Min Minimum amount of token1 to expect from deposit
    // @param recipient Address to receive position mint
    // @param deadline Deadline for minting
    // @param pool Address of pool to mint to, or address(0) to mint to a new pool
    struct ToParams {
        address nft;
        int24 tickSpacing;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
        address pool;
    }

    /// @notice Migrates a position from one slipstream pool to another
    /// @notice Removes all tokens from the position, and collects any outstanding fees
    /// @dev This also burns the position
    /// @dev Supply ToParams.pool == address(0) to migrate a pool at the same price.
    /// @param fromParams Parameters for the position to burn (see notes for struct)
    /// @param toParams Parameters for the position to mint (see notes for struct)
    /// @return tokenId The id of the new position
    /// @return liquidity The amount of liquidity in the position
    /// @return amount0 The amount of token0 deposited
    /// @return amount1 The amount of token1 deposited
    function migrateSlipstreamToSlipstream(FromParams memory fromParams, ToParams memory toParams)
        external
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
}
