// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part III — "A minimal ERC-721 in OpenZeppelin"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  The smallest possible production-grade ERC-721 (NFT) collection. By
//  inheriting from ERC721 the contract acquires:
//    • The standard EIP-721 surface: ownerOf, balanceOf, transferFrom,
//      safeTransferFrom (two overloads), approve, getApproved,
//      setApprovalForAll, isApprovedForAll.
//    • The standard events: Transfer, Approval, ApprovalForAll.
//    • ERC-165 interface advertisement via supportsInterface.
//    • The internal accounting hooks (_safeMint, _mint, _burn, _update,
//      _increaseBalance) used by every other ERC-721 extension.
//  An incrementing counter (`_id`) generates sequential, gap-less token
//  ids starting at 1. The owner is the sole minter.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//    1.  Deploy with `o = ACCOUNT-A`. Confirm owner() = A.
//    2.  Mint a couple of NFTs. Still on A:
//          safeMint(ACCOUNT-B)        → emits Transfer(0x0, B, 1)
//          safeMint(ACCOUNT-C)        → emits Transfer(0x0, C, 2)
//        Check:
//          ownerOf(1) = B,  ownerOf(2) = C
//          balanceOf(B) = 1, balanceOf(C) = 1
//    3.  Transfer. Switch to ACCOUNT-B:
//          transferFrom(B, ACCOUNT-D, 1)    → ownerOf(1) is now D.
//    4.  Approval flow.
//          a. As D:  approve(ACCOUNT-E, 1)        → getApproved(1) = E.
//          b. As E:  transferFrom(D, E, 1)        → ownerOf(1) = E.
//    5.  Negative paths:
//          - Switch to B and try safeMint(B):
//              red error OwnableUnauthorizedAccount(B).
//          - Read ownerOf(99):
//              red error ERC721NonexistentToken(99).
//          - As any account not holding/approved for token 1, call
//            transferFrom(...) → ERC721InsufficientApproval(caller, 1).
//    6.  ERC-165 interface advertisement. Use the auto-generated getter:
//          supportsInterface(0x80ac58cd) → true   (IERC721)
//          supportsInterface(0x5b5e139f) → true   (IERC721Metadata)
//          supportsInterface(0xffffffff) → false  (sentinel)
//    7.  Safe-transfer to a contract. If you have a contract address that
//        does NOT implement IERC721Receiver (e.g. the contract itself), try
//        safeTransferFrom(currentOwner, that contract, 1, "0x").
//        Remix shows the red error ERC721InvalidReceiver.
// ============================================================================

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, Ownable {
    uint256 private _id;

    constructor(address o) ERC721("My NFT", "NFT") Ownable(o) {}

    function safeMint(address to) external onlyOwner {
        _safeMint(to, ++_id);
    }
}
