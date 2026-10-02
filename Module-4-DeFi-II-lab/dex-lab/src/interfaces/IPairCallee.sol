// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

/// @notice Receiver of an optimistic transfer from Pair.swap. When swap() is called
/// with a non-empty data argument, the pair transfers the output FIRST and then calls
/// this hook; by the end of the hook the caller must have paid the pair (input tokens
/// or the borrowed tokens back plus fee), or the pair's invariant check reverts the
/// whole transaction. This is the flash-swap mechanism (uniswapV2Call in Uniswap v2).
interface IPairCallee {
    function pairCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
