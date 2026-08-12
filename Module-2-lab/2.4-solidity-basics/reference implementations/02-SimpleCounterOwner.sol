// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  SimpleCounterOwner
/// @notice Counter 2 of 7
///         Adds an owner-only reset() function. The owner is the address
///         that deployed the contract (msg.sender inside the constructor).
///
/// @dev    Demonstrates: immutable storage, custom errors, and the
///         classic `onlyOwner` modifier pattern. increase() and decrease()
///         take a caller-chosen amount, exactly as in the first counter.
contract SimpleCounterOwner {

    uint256 private counter;
    address public immutable owner;     // set once at deployment, never changes

    error NotOwner(address caller);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        counter = 0;
        owner   = msg.sender;
    }

    /// @notice Increase the counter by `units`.
    function increase(uint256 units) external {
        counter += units;
    }

    /// @notice Decrease the counter by `units`. Reverts on underflow.
    function decrease(uint256 units) external {
        counter -= units;
    }

    /// @notice Reset the counter back to 0. Only the deployer can call it.
    function reset() external onlyOwner {
        counter = 0;
    }

    function getValue() external view returns (uint256) {
        return counter;
    }
}
