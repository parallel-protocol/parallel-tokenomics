// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal subset of the Balancer V3 Vault, also implemented by its forks (e.g. Frontier).
interface IBalancerV3Vault {
    struct TokenInfo {
        uint8 tokenType;
        address rateProvider;
        bool paysYieldFees;
    }

    /// @notice Gets the raw data for a pool: tokens, token info, raw balances, and last live balances.
    /// @param pool Address of the pool
    /// @return tokens The pool tokens, sorted in registration order
    /// @return tokenInfo Token type, rate provider, and value flags, sorted in token registration order
    /// @return balancesRaw Current native decimal balances of the pool tokens, sorted in token registration order
    /// @return lastBalancesLiveScaled18 Last saved live balances, sorted in token registration order
    function getPoolTokenInfo(address pool)
        external
        view
        returns (
            IERC20[] memory tokens,
            TokenInfo[] memory tokenInfo,
            uint256[] memory balancesRaw,
            uint256[] memory lastBalancesLiveScaled18
        );
}

/// @notice Minimal subset of a Balancer V3 pool.
interface IBalancerV3Pool {
    /// @notice Returns the Vault the pool is registered in.
    function getVault() external view returns (IBalancerV3Vault);
}

/// @notice Swap entry point of the Balancer V3 Router, also implemented by its forks (e.g. Frontier).
interface IBalancerV3SwapRouter {
    /// @notice Executes a swap operation specifying an exact input token amount.
    /// @param pool Address of the liquidity pool
    /// @param tokenIn Token to be swapped from
    /// @param tokenOut Token to be swapped to
    /// @param exactAmountIn Exact amounts of input tokens to send
    /// @param minAmountOut Minimum amount of tokens to be received
    /// @param deadline Deadline for the swap, after which it will revert
    /// @param wethIsEth If true, incoming ETH will be wrapped to WETH and outgoing WETH will be unwrapped to ETH
    /// @param userData Additional (optional) data sent with the swap request
    /// @return amountOut Calculated amount of output tokens to be received in exchange for the given input tokens
    function swapSingleTokenExactIn(
        address pool,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 exactAmountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool wethIsEth,
        bytes calldata userData
    )
        external
        payable
        returns (uint256 amountOut);
}
