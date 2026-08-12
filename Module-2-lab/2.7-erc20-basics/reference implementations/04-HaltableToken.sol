// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part II — "ERC20Pausable — example with the _update plumbing"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  ERC20Pausable overrides the internal _update hook so that ANY transfer,
//  mint or burn reverts with EnforcedPause() while the contract is paused.
//  Read-only views (balanceOf, totalSupply, allowance, …) keep working —
//  Pausable is a "write breaker", not a complete circuit breaker.
//
//  Two events are emitted: Paused(account) and Unpaused(account), useful
//  for off-chain monitoring (e.g. a security-team dashboard).
//
//  The contract ALSO illustrates the canonical multiple-inheritance
//  plumbing in OZ v5: both ERC20 and ERC20Pausable declare a virtual
//  _update; Solidity needs an explicit override(...) listing both parents
//  and calling super to disambiguate the linearised graph.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//    1.  Deploy with `o = ACCOUNT-A` (the owner). Confirm paused() → false.
//    2.  Normal operation. Still on A, call
//          transfer(ACCOUNT-B, 100000000000000000000)
//        → success; Transfer event in the log.
//    3.  Pause the contract. As ACCOUNT-A:  pause()
//        → emits Paused(A); paused() now returns true.
//    4.  Mutations should now revert:
//          - Switch to ACCOUNT-B; transfer(ACCOUNT-C, 1)
//            → red error EnforcedPause().
//          - Same for transferFrom (set up an allowance before pausing
//            so you can try it) — also EnforcedPause.
//          - Note: approve(...) is NOT gated by Pausable; allowance changes
//            still work. This is intentional and worth pointing out.
//    5.  Unpause and verify recovery. Back on ACCOUNT-A:
//          unpause()    → emits Unpaused(A); paused() → false.
//          transfer between B and C now succeeds again.
//    6.  Authorisation check. Switch to ACCOUNT-B and call pause()
//        → red error OwnableUnauthorizedAccount(B).
//    7.  Double-state reverts:
//          pause() while paused   → EnforcedPause
//          unpause() while running → ExpectedPause
//        Both surface as red errors in the Remix console.
// ============================================================================

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HaltableToken is ERC20, ERC20Pausable, Ownable {
    constructor(address o) ERC20("Haltable", "HLT") Ownable(o) {
        _mint(o, 1_000_000 ether);
    }

    function pause()   external onlyOwner { _pause();   }
    function unpause() external onlyOwner { _unpause(); }

    // multiple-inheritance plumbing
    function _update(address f, address t, uint256 v)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(f, t, v);
    }
}
