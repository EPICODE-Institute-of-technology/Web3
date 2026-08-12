// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part III — "ERC721URIStorage — example"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  By default, ERC721's tokenURI(id) returns _baseURI() + id.toString() —
//  uniform across the collection. URIStorage replaces this with a per-token
//  mapping (uint256 → string), letting each NFT point at its own JSON
//  metadata (typically IPFS-pinned).
//
//  Internal API used here:
//    • _setTokenURI(tokenId, uri)    — sets the URI for a specific token
//    • super.tokenURI(id)             — returns the per-token URI if set,
//                                        falls back to base + id otherwise
//  Two overrides are required:
//    • tokenURI       — to disambiguate ERC721's and URIStorage's versions.
//    • supportsInterface — to advertise IERC4906 (MetadataUpdate, 0x49064906)
//                          which marketplaces use to detect off-chain refresh.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//    1.  Deploy with `o = ACCOUNT-A`.
//    2.  Mint a token with a real IPFS URI. As A:
//          safeMint(ACCOUNT-B, "ipfs://QmTzQ1bA9k6vG7HfQ.../1.json")
//        The transaction log shows Transfer(0x0, B, 1).
//    3.  Read it back:
//          tokenURI(1) → "ipfs://QmTzQ1bA9k6vG7HfQ.../1.json"
//          ownerOf(1)  → B
//    4.  Mint a second one with a different URI:
//          safeMint(B, "ipfs://Qm.../2.json")
//        tokenURI(2) returns its own URI.
//    5.  Negative paths:
//          - tokenURI(99) for a non-existent id → ERC721NonexistentToken.
//          - Switch to ACCOUNT-B and try safeMint(B, "x")
//            → OwnableUnauthorizedAccount(B).
//    6.  ERC-165 check:
//          supportsInterface(0x49064906) → true  (IERC4906, metadata updates)
//          supportsInterface(0x80ac58cd) → true  (IERC721)
//    7.  End-to-end with a real marketplace (optional, requires Sepolia):
//          - Switch Environment to "Injected Provider — MetaMask" on Sepolia.
//          - Deploy and mint as above with a real IPFS URI containing
//            {"name":"#1","image":"ipfs://..."} JSON.
//          - Verify the contract on Sepolia Etherscan.
//          - Look up the token on https://testnets.opensea.io — name and
//            image should render.
// ============================================================================

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Art is ERC721, ERC721URIStorage, Ownable {
    uint256 private _id;

    constructor(address o) ERC721("Art", "ART") Ownable(o) {}

    function safeMint(address to, string calldata uri)
        external
        onlyOwner
        returns (uint256 id)
    {
        id = ++_id;
        _safeMint(to, id);
        _setTokenURI(id, uri);
    }

    function tokenURI(uint256 id)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(id);
    }

    function supportsInterface(bytes4 i)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(i);
    }
}
