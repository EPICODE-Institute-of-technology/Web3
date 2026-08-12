// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  SimpleCounter
/// @notice Counter 1 of 7
///         The simplest stateful contract: a single uint256 that can be
///         incremented or decremented by a caller-chosen amount, plus a
///         read-only accessor. The constructor initialises the counter to 0.
///
/// @dev    Solidity 0.8.x has built-in checked arithmetic, so any underflow
///         in decrease() reverts automatically without an explicit guard.
contract SimpleCounter {

    uint256 private counter;

    constructor() {
        counter = 0;
    }

    /// @notice Increase the counter by `units`.
    function increase(uint256 units) external {
        counter += units;
    }

    /// @notice Decrease the counter by `units`. Reverts on underflow.
    function decrease(uint256 units) external {
        counter -= units;     // reverts on underflow under solc >= 0.8.0
    }

    /// @notice Current value of the counter.
    function getValue() external view returns (uint256) {
        return counter;
    }
}
