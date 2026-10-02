// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

/// @notice A price oracle values one token in terms of the pool's other token.
/// consult(token, amountIn) answers: how much of the other token is `amountIn` of
/// `token` worth right now, according to this oracle? Both the vulnerable spot oracle
/// and the safe TWAP oracle implement this single interface, so the same lending vault
/// can be wired to either one and the difference is isolated to the oracle.
interface IPriceOracle {
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut);
}
