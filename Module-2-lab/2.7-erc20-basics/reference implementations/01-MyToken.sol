// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part II — "A minimal ERC-20 in OpenZeppelin"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  The smallest possible production-grade ERC-20 token. By inheriting from
//  OpenZeppelin's base ERC20.sol the contract acquires, for free:
//    • The full EIP-20 public surface: name(), symbol(), decimals() (= 18),
//      totalSupply(), balanceOf(account), transfer(to, value), allowance(),
//      approve(spender, value), transferFrom(from, to, value).
//    • The standard events: Transfer(from, to, value) and Approval(...).
//    • The internal accounting hooks (_mint, _burn, _update) used by every
//      other ERC-20 extension to add functionality.
//  The constructor pre-mints 1 000 000 whole tokens (= 1 000 000 · 10**18
//  base units) to a chosen `initialHolder` address.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//  Compile the file in Remix and select the "Remix VM" environment so you
//  have several pre-funded accounts to switch between.
//
//    1.  Deploy with `initialHolder = ACCOUNT-A` (copy the address from the
//        Account dropdown).
//    2.  Read state. In the Deployed Contracts panel expand the contract and
//        click each blue button:
//          - name()         → "My Token"
//          - symbol()       → "MTK"
//          - decimals()     → 18
//          - totalSupply()  → 1000000000000000000000000   (= 10^24)
//          - balanceOf(ACCOUNT-A) → same value
//          - balanceOf(ACCOUNT-B) → 0
//    3.  Transfer.  Still on ACCOUNT-A, call
//          transfer(ACCOUNT-B, 100000000000000000000)    (= 100 · 10^18)
//        Open the orange "Transfer" entry in the transaction log: one
//        Transfer(from=A, to=B, value=100·10^18) event was emitted.
//        Re-read balances — A has 999 900·10^18, B has 100·10^18.
//    4.  Allowance flow.
//          a. As ACCOUNT-A: approve(ACCOUNT-B, 50000000000000000000).
//          b. Switch the Account dropdown to ACCOUNT-B.
//          c. Call transferFrom(ACCOUNT-A, ACCOUNT-C, 50000000000000000000).
//          d. Read allowance(ACCOUNT-A, ACCOUNT-B) → 0 (consumed).
//          e. Read balances — A lost 50, C gained 50.
//    5.  Negative paths (Remix shows the red error message in the console,
//        including the custom-error name decoded from the revert data):
//          - As ACCOUNT-B, try transfer(ACCOUNT-C, 99999999999999999999999)
//            → reverts with ERC20InsufficientBalance(B, balance, requested).
//          - As ACCOUNT-A, try transfer to 0x0000000000000000000000000000000000000000
//            → reverts with ERC20InvalidReceiver(0x0).
//          - As ACCOUNT-C (no allowance), try
//            transferFrom(ACCOUNT-A, C, 1) → ERC20InsufficientAllowance(...).
// ============================================================================

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(address initialHolder)
        ERC20("My Token", "MTK")
    {
        _mint(initialHolder, 1_000_000 * 10 ** decimals());   // pre-mint
    }
}
