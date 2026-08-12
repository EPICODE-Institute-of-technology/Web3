// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part II — "ERC20Votes — example & delegation gotcha"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  ERC20Votes implements EIP-5805 ("Voting with Delegation"). On top of a
//  standard ERC-20 it adds:
//    • A per-account CHECKPOINT history: after every transfer, the contract
//      stores (block, votingPower) so that historical voting power can be
//      reconstructed without scanning the chain.
//    • delegate(delegatee)            — assigns voting power to `delegatee`.
//    • delegateBySig(...)             — gasless delegation via EIP-712 sig.
//    • getVotes(account)              — current voting power of `account`.
//    • getPastVotes(acc, blockNumber) — binary-search the checkpoint history.
//    • getPastTotalSupply(blk)        — quorum denominator at `blk`.
//  The CRITICAL gotcha: voting power is ZERO until a holder calls delegate()
//  — even to delegate to themselves. This intentional design prevents
//  passively-held tokens from counting; only intentional participants vote.
//
//  Composition with ERC20Permit forces TWO override functions because
//  ERC20Permit and Nonces both implement nonces(address) — Solidity needs
//  an explicit override(...) listing both, plus the standard _update one
//  for ERC20Votes' checkpoint hook.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//    1.  Deploy with `o = ACCOUNT-A`. balanceOf(A) is 10^24.
//    2.  Observe the zero-voting-power gotcha. Click:
//          getVotes(ACCOUNT-A)  →  0      (yes, zero!)
//        Holding tokens is NOT the same as having votes.
//    3.  Activate A's voting power. As ACCOUNT-A:
//          delegate(ACCOUNT-A)
//        Now getVotes(A) → 1 000 000 · 10^18.
//    4.  Snapshot lookups need a PAST block. Each Remix VM transaction
//        advances block.number by 1 — note the current block number from
//        the latest tx receipt.  Then call:
//          getPastVotes(ACCOUNT-A, <previousBlock>)  →  the value as of
//                                                         that block.
//        Trying getPastVotes(A, currentBlock) reverts with
//        ERC5805FutureLookup — you can only look at past blocks.
//    5.  Transfer + automatic vote follow-through. As ACCOUNT-A:
//          transfer(ACCOUNT-B, 400000000000000000000000)  (400 k · 10^18)
//        getVotes(A) → 600 000 · 10^18    (votes moved with the tokens)
//        getVotes(B) → 0                  (B hasn't delegated yet!)
//    6.  B activates voting power. Switch to ACCOUNT-B:
//          delegate(ACCOUNT-B)
//        getVotes(B) → 400 000 · 10^18.
//    7.  Cross-delegation. Switch back to ACCOUNT-A:
//          delegate(ACCOUNT-C)
//        getVotes(A) → 0;  getVotes(C) → 600 000 · 10^18.
//        delegates(A) → C.
//    8.  delegateBySig (gasless delegation). Same pattern as ERC20Permit:
//        in the Remix terminal, sign the typed-data
//          Delegation(address delegatee,uint256 nonce,uint256 expiry)
//        with the holder's private key, then submit
//          delegateBySig(delegatee, nonce, expiry, v, r, s)
//        from ANY account. Verify delegates(originalSigner) updated.
// ============================================================================

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

contract VotesToken is ERC20, ERC20Permit, ERC20Votes {
    constructor(address o)
        ERC20("Votes", "VOT")
        ERC20Permit("Votes")
    {
        _mint(o, 1_000_000 ether);
    }

    function _update(address f, address t, uint256 v)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(f, t, v);
    }

    function nonces(address u)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(u);
    }
}
