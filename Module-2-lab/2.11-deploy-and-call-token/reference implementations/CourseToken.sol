// SPDX-License-Identifier: MIT
//
// The line above is a machine-readable licence tag. Solidity (and tools such
// as Etherscan) read it to know how the source may be reused. "MIT" is a very
// permissive open-source licence — the same one OpenZeppelin itself uses.

pragma solidity ^0.8.20;
//
// `pragma solidity` fixes the compiler version. The caret `^0.8.20` means
// "any 0.8.x release from 0.8.20 up to (but NOT including) 0.9.0". OpenZeppelin
// Contracts v5 requires at least 0.8.20, so this is the minimum we can use.
// From Solidity 0.8.0 onward, arithmetic is overflow-checked by default — a +
// that would wrap around reverts instead of producing a wrong number.

// ─── Imports ────────────────────────────────────────────────────────────────
// Each import pulls in a fully-audited base contract from the OpenZeppelin
// library. In Remix these `@openzeppelin/...` paths are resolved automatically
// from npm; in Foundry/Hardhat they come from a `remappings.txt` / node_modules.
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";                     // the core fungible-token logic
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";  // adds burn() / burnFrom()
import "@openzeppelin/contracts/access/Ownable.sol";                        // adds a single privileged "owner"

/// @title  CourseToken — the ERC-20 used across lectures 2.11-2.12 of the ethers.js topic.
/// @notice An ERC-20 is the Ethereum standard for a *fungible* token: every
///         unit is interchangeable, like coins of the same currency. The
///         standard (EIP-20) defines a fixed set of functions — balanceOf,
///         transfer, approve, transferFrom, allowance, totalSupply — and two
///         events — Transfer and Approval. Wallets, exchanges and block
///         explorers all rely on this exact interface.
///
///         This token is built by *composition*: we inherit three OpenZeppelin
///         building blocks and the Solidity compiler stitches them together.
///           * `ERC20`         — the standard balances / allowances / Transfer.
///           * `ERC20Burnable` — adds `burn(amount)` and `burnFrom(spender, amount)`.
///           * `Ownable`       — restricts `mint` to a single privileged address.
///
///         Note that EVERY state-changing operation ultimately emits the same
///         `Transfer` event, which is what lets the dApp (lecture 2.12) streams
///         one unified live feed of activity:
///           * mint     = Transfer FROM the zero address (0x000…0) TO someone
///           * burn     = Transfer FROM someone TO the zero address
///           * transfer = Transfer between two non-zero addresses
contract CourseToken is ERC20, ERC20Burnable, Ownable {
    //                  ▲      ▲              ▲
    //                  │      │              └─ gives us owner(), onlyOwner, transferOwnership(...)
    //                  │      └──────────────── gives us burn(...) and burnFrom(...)
    //                  └─────────────────────── gives us the whole ERC-20 surface + _mint/_burn internals

    /// @param initialOwner Receives the entire initial supply and gains the
    ///                     exclusive right to mint new tokens later.
    /// @dev   The constructor runs ONCE, at deployment time. It forwards
    ///        arguments to the two parent constructors that need them:
    ///          * ERC20("Course Token", "CRS")  sets the human name and ticker.
    ///          * Ownable(initialOwner)         records who the owner is.
    ///        (ERC20Burnable has no constructor arguments, so it is not listed.)
    constructor(address initialOwner)
        ERC20("Course Token", "CRS")   // name = "Course Token", symbol = "CRS"
        Ownable(initialOwner)          // OZ v5 requires the owner to be passed in explicitly
    {
        // `_mint` is an INTERNAL function from ERC20: it creates new tokens out
        // of nothing and credits them to an address, increasing totalSupply.
        // It is internal (not public) precisely so that we control WHO may mint
        // and WHEN — here, only the deployer, only at construction.
        //
        // `decimals()` returns 18 by default. Like ETH's 18 decimals (wei),
        // one whole CRS token = 10**18 of the smallest indivisible unit. So the
        // line below mints 1,000,000 whole tokens, stored on-chain as the
        // integer 1_000_000 * 10**18 (the underscores are just digit grouping).
        _mint(initialOwner, 1_000_000 * 10 ** decimals());
    }

    /// @notice Mint new tokens to `to`. Restricted to the contract owner.
    /// @dev    The `onlyOwner` modifier (from Ownable) inserts a check before
    ///         the function body: if msg.sender != owner() it reverts with
    ///         OwnableUnauthorizedAccount(msg.sender). This is why, in Lecture 2.11,
    ///         a non-owner account that presses "mint()" gets a revert.
    ///         A successful mint emits Transfer(address(0), to, amount).
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // WHAT WE DID NOT HAVE TO WRITE (and why):
    //   * transfer / transferFrom / approve / allowance / balanceOf / totalSupply
    //       → inherited from ERC20.
    //   * burn(amount) / burnFrom(account, amount)
    //       → inherited from ERC20Burnable; anyone may burn THEIR OWN tokens,
    //         and burnFrom spends an allowance just like transferFrom.
    //   * owner() / transferOwnership(newOwner) / renounceOwnership()
    //       → inherited from Ownable.
    // Composition keeps OUR file tiny and leans on audited code for the risky
    // parts — the central lesson of the OpenZeppelin module.
}
