// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Self-contained target for the LECTURE 2.15 Slither demo (SLD33): no external
// imports, so `slither ReentrancyDemo.sol` runs with zero setup. It holds the same
// two banks as ../contracts/ReentrancyBank.sol, but SafeBank here uses an inline
// reentrancy lock instead of OpenZeppelin's ReentrancyGuard (the production choice
// taught in 2.14), so nothing needs to be installed for the static analyser to run.

/// @dev DO NOT DEPLOY. Sends ether BEFORE zeroing the balance -> reentrancy.
contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 a = balances[msg.sender];
        require(a > 0, "nothing");
        (bool ok, ) = msg.sender.call{value: a}("");   // external call FIRST
        require(ok, "transfer failed");
        balances[msg.sender] = 0;                       // state update TOO LATE
    }
}

/// @dev Safe: checks-effects-interactions (state before the call) plus an inline
///      reentrancy lock. Slither reports no reentrancy here.
contract SafeBank {
    mapping(address => uint256) private _balances;
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "reentrant");
        _locked = true;
        _;
        _locked = false;
    }

    function deposit() external payable {
        _balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 a = _balances[msg.sender];
        require(a > 0, "nothing");
        _balances[msg.sender] = 0;                      // effect FIRST
        (bool ok, ) = msg.sender.call{value: a}("");    // interaction LAST
        require(ok, "transfer failed");
    }

    function balanceOf(address who) external view returns (uint256) {
        return _balances[who];
    }
}
