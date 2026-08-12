// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Reentrancy — the attack that drained ~3.6M ETH from The DAO in 2016.
// This file holds TWO banks side by side so the demo can drain one and fail on the other.
// See Attacker.sol for the exploit, and the folder README for the Remix walkthrough.

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @dev DO NOT DEPLOY for real. Pays the caller BEFORE zeroing the balance, so a
///      malicious receive() can re-enter withdraw() while the balance is still set.
contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 a = balances[msg.sender];
        require(a > 0, "nothing to withdraw");
        (bool ok, ) = msg.sender.call{value: a}("");   // hands control to the caller
        require(ok, "transfer failed");
        balances[msg.sender] = 0;                       // too late: already re-entered
    }
}

/// @dev Two defences at once: (1) checks-effects-interactions — state is zeroed BEFORE
///      the external call; (2) the nonReentrant guard reverts a re-entrant call outright.
///      balanceOf() and totalDeposits let a test assert solvency.
contract SafeBank is ReentrancyGuard {
    mapping(address => uint256) private _balances;
    uint256 public totalDeposits;

    function deposit() external payable {
        _balances[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 a = _balances[msg.sender];
        require(a > 0, "nothing to withdraw");
        _balances[msg.sender] = 0;                      // effect FIRST
        totalDeposits -= a;
        (bool ok, ) = msg.sender.call{value: a}("");    // interaction LAST
        require(ok, "transfer failed");
    }

    function balanceOf(address who) external view returns (uint256) {
        return _balances[who];
    }
}
