// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import "contracts/core/interfaces/ICLPool.sol";
import "@uniswap/contracts/libraries/SafeERC20Namer.sol";
import "base64-sol/base64.sol";

import "./libraries/ChainId.sol";
import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/INonfungibleTokenPositionDescriptor.sol";
import "./interfaces/IERC20Metadata.sol";
import "./libraries/PoolAddress.sol";
import "./libraries/NFTDescriptor.sol";
import "./libraries/TokenRatioSortOrder.sol";
import "./libraries/NFTSVG.sol";

/// @title Describes NFT token positions
/// @notice Produces a string containing the data URI for a JSON metadata string
contract NonfungibleTokenPositionDescriptor is INonfungibleTokenPositionDescriptor {
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant TBTC = 0x8dAEBADE922dF735c38C80C7eBD708Af50815fAa;
    address private constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address public immutable WETH9;
    /// @dev A null-terminated string
    bytes32 public immutable nativeCurrencyLabelBytes;

    constructor(address _WETH9, bytes32 _nativeCurrencyLabelBytes) {
        WETH9 = _WETH9;
        nativeCurrencyLabelBytes = _nativeCurrencyLabelBytes;
    }

    /// @notice Returns the native currency label as a string
    function nativeCurrencyLabel() public view returns (string memory) {
        uint256 len = 0;
        while (len < 32 && nativeCurrencyLabelBytes[len] != 0) {
            len++;
        }
        bytes memory b = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            b[i] = nativeCurrencyLabelBytes[i];
        }
        return string(b);
    }

    /// @inheritdoc INonfungibleTokenPositionDescriptor
    function tokenURI(INonfungiblePositionManager positionManager, uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        (,, address token0, address token1, int24 tickSpacing, int24 tickLower, int24 tickUpper,,,,,) =
            positionManager.positions(tokenId);

        ICLPool pool = ICLPool(
            PoolAddress.computeAddress(
                positionManager.factory(),
                PoolAddress.PoolKey({token0: token0, token1: token1, tickSpacing: tickSpacing})
            )
        );

        bool _flipRatio = flipRatio(token0, token1, ChainId.get());
        address quoteTokenAddress = !_flipRatio ? token1 : token0;
        address baseTokenAddress = !_flipRatio ? token0 : token1;
        NFTDescriptor.ConstructTokenURIParams memory params = NFTDescriptor.ConstructTokenURIParams({
            tokenId: tokenId,
            quoteTokenAddress: quoteTokenAddress,
            baseTokenAddress: baseTokenAddress,
            quoteTokenSymbol: quoteTokenAddress == WETH9
                ? nativeCurrencyLabel()
                : SafeERC20Namer.tokenSymbol(quoteTokenAddress),
            baseTokenSymbol: baseTokenAddress == WETH9
                ? nativeCurrencyLabel()
                : SafeERC20Namer.tokenSymbol(baseTokenAddress),
            quoteTokenDecimals: IERC20Metadata(quoteTokenAddress).decimals(),
            baseTokenDecimals: IERC20Metadata(baseTokenAddress).decimals(),
            flipRatio: _flipRatio,
            tickLower: tickLower,
            tickUpper: tickUpper,
            tickSpacing: tickSpacing,
            poolAddress: address(pool)
        });

        string memory image = Base64.encode(bytes(generateSVG(positionManager, params)));

        string memory nameAndDescription = NFTDescriptor.constructTokenURI(params);

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            "{", nameAndDescription, ', "image": "', "data:image/svg+xml;base64,", image, '"}'
                        )
                    )
                )
            )
        );
    }

    function generateSVG(
        INonfungiblePositionManager positionManager,
        NFTDescriptor.ConstructTokenURIParams memory params
    ) internal view returns (string memory) {
        (uint256 quoteTokensOwed, uint256 baseTokensOwed) =
            tokensOwed({positionManager: positionManager, tokenId: params.tokenId, flipRatio: params.flipRatio});
        return NFTSVG.generateSVG({
            quoteTokenSymbol: params.quoteTokenSymbol,
            baseTokenSymbol: params.baseTokenSymbol,
            quoteTokensOwed: quoteTokensOwed,
            baseTokensOwed: baseTokensOwed,
            tokenId: params.tokenId,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            tickSpacing: params.tickSpacing,
            quoteTokenDecimals: params.quoteTokenDecimals,
            baseTokenDecimals: params.baseTokenDecimals
        });
    }

    function tokensOwed(INonfungiblePositionManager positionManager, uint256 tokenId, bool flipRatio)
        internal
        view
        returns (uint256 quoteTokensOwed, uint256 baseTokensOwed)
    {
        (,,,,,,,,,, uint256 tokensOwed0, uint256 tokensOwed1) = positionManager.positions(tokenId);
        quoteTokensOwed = flipRatio ? tokensOwed1 : tokensOwed0;
        baseTokensOwed = flipRatio ? tokensOwed0 : tokensOwed1;
    }

    function flipRatio(address token0, address token1, uint256 chainId) public view returns (bool) {
        return tokenRatioPriority(token0, chainId) > tokenRatioPriority(token1, chainId);
    }

    function tokenRatioPriority(address token, uint256 chainId) public view returns (int256) {
        if (token == WETH9) {
            return TokenRatioSortOrder.DENOMINATOR;
        }
        if (chainId == 1) {
            if (token == USDC) {
                return TokenRatioSortOrder.NUMERATOR_MOST;
            } else if (token == USDT) {
                return TokenRatioSortOrder.NUMERATOR_MORE;
            } else if (token == DAI) {
                return TokenRatioSortOrder.NUMERATOR;
            } else if (token == TBTC) {
                return TokenRatioSortOrder.DENOMINATOR_MORE;
            } else if (token == WBTC) {
                return TokenRatioSortOrder.DENOMINATOR_MOST;
            } else {
                return 0;
            }
        }
        return 0;
    }
}
