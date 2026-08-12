// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  SimpleCounterValue
/// @notice Counter 3 of 7
///         The counter now charges wei for every state-changing call:
///           * increase(units) and decrease(units) require msg.value >= 2 * units
///         Only the owner can withdraw the wei accumulated by the contract.
///
/// @dev    Demonstrates: payable functions, msg.value, custom errors with
///         arguments, and the call{value:}() pattern for ETH transfers.
contract SimpleCounterValue {

    uint256 private counter;
    address public immutable owner;

    error NotOwner(address caller);
    error InsufficientPayment(uint256 required, uint256 sent);
    error WithdrawFailed();

    event Increased   (address indexed payer, uint256 units, uint256 paid);
    event Decreased   (address indexed payer, uint256 units, uint256 paid);
    event Withdrawn   (address indexed to,    uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        counter = 0;
        owner   = msg.sender;
    }

    /// @notice Increase the counter by `units`. Requires msg.value >= 2 * units.
    function increase(uint256 units) external payable {
        uint256 required = 2 * units;
        if (msg.value < required) revert InsufficientPayment(required, msg.value);
        counter += units;
        emit Increased(msg.sender, units, msg.value);
    }

    /// @notice Decrease the counter by `units`. Requires msg.value >= 2 * units.
    function decrease(uint256 units) external payable {
        uint256 required = 2 * units;
        if (msg.value < required) revert InsufficientPayment(required, msg.value);
        counter -= units;     // checked arithmetic; reverts on underflow
        emit Decreased(msg.sender, units, msg.value);
    }

    function getValue() external view returns (uint256) {
        return counter;
    }

    /// @notice Withdraw the entire balance of the contract to the owner.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner).call{value: amount}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(owner, amount);
    }
}
