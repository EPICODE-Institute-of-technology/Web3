// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part III — "ERC-1155 — the multitoken standard"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  A single ERC-1155 contract that holds BOTH kinds of token at once:
//    * GOLD  (id 0) is FUNGIBLE     — many identical, interchangeable units.
//    * SWORD (id 1) is NON-FUNGIBLE — exactly one copy in existence.
//  The same contract therefore replaces what would otherwise be one ERC-20
//  (for the gold) plus one ERC-721 (for the sword), and it can move both in
//  a single batch transaction.
//
//  KEY INTERFACE DIFFERENCES vs ERC-20 / ERC-721
//  ---------------------------------------------
//    * balanceOf(account, id)                     — balance is per (account, id)
//    * balanceOfBatch(accounts[], ids[])          — many balances in one call
//    * safeTransferFrom(from, to, id, amount, "") — move `amount` of one id
//    * safeBatchTransferFrom(from, to, ids[], amounts[], "") — many ids at once
//    * one metadata URI template with "{id}" serves every id.
//  "Non-fungible" here is a convention: an id whose total supply is 1. The
//  standard itself does not distinguish the two; the deployer decides.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//    1.  Deploy with `o = ACCOUNT-A`. Read:
//          balanceOf(A, 0) -> 1000     (GOLD)
//          balanceOf(A, 1) -> 1        (SWORD)
//          balanceOf(A, 2) -> 0        (an id never minted reads as 0)
//    2.  Fungible transfer. As A:
//          safeTransferFrom(A, B, 0, 100, "0x")   -> B now holds 100 gold.
//    3.  Non-fungible transfer. As A:
//          safeTransferFrom(A, C, 1, 1, "0x")     -> C now owns the sword.
//        Trying to send amount 2 of id 1 reverts (ERC1155InsufficientBalance).
//    4.  Batch read/move (the point of ERC-1155). As C (owns 1 sword) after
//        also receiving some gold, call:
//          safeBatchTransferFrom(C, D, [0,1], [10,1], "0x")
//        -> one transaction moves 10 gold AND the sword to D.
//          balanceOfBatch([D,D],[0,1]) -> [10, 1]
//    5.  Owner-only mint. As A: mintGold(B, 500) succeeds; as B it reverts
//        with OwnableUnauthorizedAccount(B).
// ============================================================================

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItems is ERC1155, Ownable {
    uint256 public constant GOLD  = 0;   // fungible id: many identical units
    uint256 public constant SWORD = 1;   // non-fungible id: a single copy

    /// @param o the owner (sole minter) and initial holder of the supply.
    constructor(address o)
        ERC1155("ipfs://<your-CID>/{id}.json")   // one URI template for all ids
        Ownable(o)
    {
        _mint(o, GOLD,  1000, "");   // 1000 interchangeable gold coins
        _mint(o, SWORD, 1,    "");   // exactly one unique sword
    }

    /// @notice Mint more of the fungible GOLD id. Owner only.
    function mintGold(address to, uint256 amount) external onlyOwner {
        _mint(to, GOLD, amount, "");
    }
}
