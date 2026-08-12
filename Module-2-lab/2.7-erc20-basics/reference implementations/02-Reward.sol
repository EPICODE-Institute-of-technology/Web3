// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part II — "ERC20Burnable — example"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  Composes three OpenZeppelin building blocks:
//    • ERC20         — the standard balances / allowances / Transfer.
//    • ERC20Burnable — adds two public functions:
//         burn(amount)           — caller destroys `amount` of their own balance
//         burnFrom(acc, amount)  — caller destroys `amount` from `acc`,
//                                   consuming an allowance the same way
//                                   transferFrom does.
//      Both emit Transfer(caller, 0x0, amount) and decrease totalSupply.
//    • Ownable       — single privileged account, used here to gate `mint`.
//  Pre-mints 1 000 000 RWD to the deployer-chosen owner; the owner may
//  later issue more supply via mint(to, amount). Burning is irreversible.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//    1.  Deploy with `o = ACCOUNT-A`. The deployer doesn't need to be the
//        owner — the constructor arg decides.
//    2.  Read invariants:  owner() = A,  balanceOf(A) = 10^24,
//        totalSupply() = 10^24.
//    3.  Owner mints. Still on ACCOUNT-A:
//          mint(ACCOUNT-B, 500000000000000000000)   (= 500 · 10^18)
//        Re-read totalSupply (1 000 500 · 10^18) and balanceOf(B).
//    4.  Non-owner cannot mint. Switch the Account dropdown to ACCOUNT-B
//        and call mint(B, 1). Remix shows a red error containing
//        OwnableUnauthorizedAccount(B).
//    5.  Anyone burns their OWN tokens. Still on ACCOUNT-B:
//          burn(100000000000000000000)              (= 100 · 10^18)
//        balanceOf(B) drops; totalSupply drops by the same amount.
//        The transaction log shows Transfer(B, 0x0, 100·10^18).
//    6.  Allowance-based burnFrom. On ACCOUNT-A: approve(ACCOUNT-B, 30·10^18).
//        Switch to ACCOUNT-B and call burnFrom(ACCOUNT-A, 30·10^18).
//        - allowance(A, B) is now 0
//        - balanceOf(A) decreased by 30
//        - totalSupply decreased by 30
//    7.  Negative paths:
//          - burn(amount > balance)       → ERC20InsufficientBalance(...)
//          - burnFrom without allowance    → ERC20InsufficientAllowance(...)
//    8.  Ownership rotation. As ACCOUNT-A call transferOwnership(ACCOUNT-C).
//        Now owner() = C. ACCOUNT-A's next mint attempt reverts with
//        OwnableUnauthorizedAccount(A); ACCOUNT-C can mint freely.
// ============================================================================

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Reward is ERC20, ERC20Burnable, Ownable {
    constructor(address o) ERC20("Reward", "RWD") Ownable(o) {
        _mint(o, 1_000_000 ether);
    }

    function mint(address to, uint256 a) external onlyOwner {
        _mint(to, a);
    }
}
