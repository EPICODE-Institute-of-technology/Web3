// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
//  Slide:  Part II — "ERC20Permit — example contract"
//
//  WHAT THIS EXAMPLE DEMONSTRATES
//  ------------------------------
//  ERC20Permit implements EIP-2612: it lets the token holder authorise a
//  spender by signing an EIP-712 typed message OFF-CHAIN. The spender (or
//  any third party) then submits a single permit(...) call on chain that
//  verifies the signature and sets the allowance — collapsing the classical
//  two-transaction approve + transferFrom flow into ONE on-chain
//  transaction, with NO gas paid by the holder for the approval.
//
//  Replay protection: each owner has a strictly increasing nonces(owner);
//  every successful permit bumps it, so the same signature cannot be
//  resubmitted twice.
//
//  Deadline: every permit signature carries an expiry timestamp; if
//  block.timestamp > deadline the contract reverts with
//  ERC2612ExpiredSignature.
//
//  HOW TO TEST IT EFFECTIVELY (Remix walkthrough)
//  ----------------------------------------------
//  Two flavours work in Remix:
//
//  --- Flavour A — "Injected Provider" (MetaMask on Sepolia) ---
//  Use MetaMask to produce a real EIP-712 signature.
//
//    1.  Switch the Environment to "Injected Provider — MetaMask",
//        connected to Sepolia.
//    2.  Deploy PermitToken with `o = MetaMask Account 1`.
//    3.  Read the public values you will need to build the signature:
//          - name()                → "Permit Token"
//          - DOMAIN_SEPARATOR()    → 0x... (used as the EIP-712 domain digest)
//          - nonces(Account 1)     → 0 initially
//          - chainId               → 11155111 (Sepolia)
//          - this contract address → shown in Deployed Contracts
//    4.  In the Remix terminal (it exposes the ethers v6 library), run:
//          const value = 100n * 10n**18n;
//          const deadline = Math.floor(Date.now()/1000) + 3600;
//          const sig = await ethers.provider.getSigner().signTypedData(
//            { name:"Permit Token", version:"1",
//              chainId: 11155111, verifyingContract: "<token address>" },
//            { Permit: [
//                {name:"owner",   type:"address"},
//                {name:"spender", type:"address"},
//                {name:"value",   type:"uint256"},
//                {name:"nonce",   type:"uint256"},
//                {name:"deadline",type:"uint256"} ] },
//            { owner: "<Account 1>", spender: "<Account 2>",
//              value, nonce: 0, deadline });
//          const split = ethers.Signature.from(sig);
//          console.log(split.v, split.r, split.s);
//    5.  Switch the Account dropdown to Account 2 and submit
//          permit(Account 1, Account 2, value, deadline, v, r, s).
//        Inspect: allowance(Account 1, Account 2) now equals `value`,
//        and nonces(Account 1) is 1.
//    6.  Negative paths (re-run the test with deliberate mistakes):
//          - Submit the SAME (v,r,s) tuple again
//              → red error ERC2612InvalidSigner (nonce already consumed).
//          - Set deadline = now - 1, sign, submit
//              → red error ERC2612ExpiredSignature.
//          - Tamper with the value before submitting
//              → red error ERC2612InvalidSigner.
//
//  --- Flavour B — "Remix VM" (no MetaMask) ---
//  The default Remix VM does not let you sign on behalf of its sandbox
//  accounts via EIP-712, so build the digest with a tiny helper contract
//  and then use a signing tool (e.g. https://eips.ethereum.org/assets/eip-712/Example.js
//  or a small Node script) to produce (v, r, s) for a known private key.
//  Then load that private key into MetaMask, switch Remix to "Injected
//  Provider" and submit as in Flavour A.
// ============================================================================

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PermitToken is ERC20, ERC20Permit, Ownable {
    constructor(address o)
        ERC20("Permit Token", "PMT")
        ERC20Permit("Permit Token")    // EIP-712 domain name
        Ownable(o)
    {
        _mint(o, 1_000_000 ether);
    }
}
