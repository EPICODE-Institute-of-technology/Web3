// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title  SimpleCounterValueOwnable
/// @notice Counter 3 of 7 (OpenZeppelin variant)
///         Same behaviour as 03-SimpleCounterValue.sol, but the access
///         control is inherited from OpenZeppelin's audited `Ownable`
///         instead of a hand-written owner + modifier + error.
///
/// @dev    What is DELETED versus the hand-written version:
///           - the `address public immutable owner;` state variable
///           - the `error NotOwner(address caller);`
///           - the `modifier onlyOwner() { ... }`
///           - the `owner = msg.sender;` line in the constructor
///         Ownable provides, audited: `owner()`, the `onlyOwner` modifier,
///         `transferOwnership` / `renounceOwnership`, and the errors
///         `OwnableUnauthorizedAccount(caller)` / `OwnableInvalidOwner(owner)`.
///         (Compile/deploy in Remix, where the OpenZeppelin import resolves
///         automatically.)
///
///  HOW TO TEST (Remix walkthrough)
///  -------------------------------
///    1. Deploy from ACCOUNT-A. Read owner() -> A.
///    2. As A, call increase(3) with a Value of 6 wei (= 2 * units). getValue() -> 3.
///       Try increase(3) with 5 wei -> reverts InsufficientPayment(6, 5).
///    3. Fund it via a couple of paid calls, then as A call withdraw() -> balance to A.
///    4. Switch to ACCOUNT-B and call withdraw()
///         -> reverts OwnableUnauthorizedAccount(B)   (the Ownable guard).
///    5. As A, transferOwnership(B); now B can withdraw() and A cannot.
contract SimpleCounterValueOwnable is Ownable {

    uint256 private counter;

    error InsufficientPayment(uint256 required, uint256 sent);
    error WithdrawFailed();

    event Increased(address indexed payer, uint256 units, uint256 paid);
    event Decreased(address indexed payer, uint256 units, uint256 paid);
    event Withdrawn(address indexed to,    uint256 amount);

    /// @dev The deployer becomes the owner. To hand the role to a different
    ///      address at deploy time, take an `address initialOwner` argument
    ///      and pass `Ownable(initialOwner)` instead.
    constructor() Ownable(msg.sender) {}

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
    ///         `onlyOwner` and `owner()` are provided by OpenZeppelin's Ownable.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner()).call{value: amount}("");
        if (!ok) revert WithdrawFailed();
        emit Withdrawn(owner(), amount);
    }
}
