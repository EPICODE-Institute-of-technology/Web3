// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part IV — "Ownable — one privileged address"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  Ownable stores a single address (owner) and gates privileged functions
//  behind the onlyOwner modifier. In OpenZeppelin v5, the initial owner is
//  an EXPLICIT constructor argument — there is no implicit "msg.sender
//  becomes owner" privilege grab. This was a deliberate breaking change
//  versus v4 to prevent factory-deploy-then-self-promote attack patterns.
//
//  API:
//    • owner()                       — view: current owner
//    • onlyOwner modifier            — gates a function on owner()==msg.sender
//    • transferOwnership(newOwner)   — one-step transfer (typo-unsafe)
//    • renounceOwnership()           — owner = address(0); IRREVOCABLE
//  Events:  OwnershipTransferred(prev, next)  emitted on every change.
//
//  This sample exposes a `rescue` function that sends an arbitrary ERC-20
//  back to the owner — the typical "recover tokens accidentally sent here"
//  utility every production contract should have.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//  You will need an ERC-20 to exercise the rescue path. Deploy MyToken
//  from the erc20/ folder first.
//
//    1.  Deploy MyToken with `initialHolder = ACCOUNT-A`.
//    2.  Deploy Vault with `initialOwner = ACCOUNT-A`.
//        Confirm owner() = A.
//    3.  Simulate an "accidental" token transfer into the vault. As A,
//        on MyToken:
//          transfer(<Vault address>, 100000000000000000000)    (100·10^18)
//    4.  Authorisation revert.  Switch to ACCOUNT-B and on Vault call:
//          rescue(<MyToken address>, 1)
//        → red OwnableUnauthorizedAccount(B).
//    5.  Successful rescue. Switch back to A and call:
//          rescue(<MyToken address>, 100000000000000000000)
//        Check MyToken.balanceOf(A) increased by 100·10^18 and
//        MyToken.balanceOf(<Vault address>) is back to 0.
//    6.  One-step ownership transfer. Still on A:
//          transferOwnership(ACCOUNT-C)
//        owner() = C immediately. As A, try rescue again
//          → OwnableUnauthorizedAccount(A).
//        As C, rescue succeeds.
//    7.  Renouncement is irreversible — be careful in production. As C:
//          renounceOwnership()
//        owner() now = 0x0000000000000000000000000000000000000000.
//        Every onlyOwner call from anyone reverts forever.
//    8.  Event verification — open the Transaction logs for each of the
//        steps above; you should see OwnershipTransferred(prev, next)
//        emitted on (2), (6), and (7).
// ============================================================================

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vault is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}

    function rescue(IERC20 token, uint256 amount) external onlyOwner {
        token.transfer(owner(), amount);
    }
}
