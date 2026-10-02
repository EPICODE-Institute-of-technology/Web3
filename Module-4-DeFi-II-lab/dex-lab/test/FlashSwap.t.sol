// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Pair} from "../src/Pair.sol";
import {FlashSwapArbitrageur} from "../src/periphery/FlashSwapArbitrageur.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @notice Flash-swap tests: a cross-pool arbitrage with no upfront capital, and the
/// proof that the invariant check makes an unprofitable flash swap impossible.
contract FlashSwapTest is Test {
    Factory dex1;
    Factory dex2;
    Pair pairA; // on dex1
    Pair pairB; // on dex2
    MockERC20 tokenX;
    MockERC20 tokenY;
    FlashSwapArbitrageur arb;

    address deployer = address(this);

    function setUp() public {
        tokenX = new MockERC20("Token X", "XXX");
        tokenY = new MockERC20("Token Y", "YYY");
        dex1 = new Factory(deployer);
        dex2 = new Factory(deployer);

        pairA = Pair(dex1.createPair(address(tokenX), address(tokenY)));
        pairB = Pair(dex2.createPair(address(tokenX), address(tokenY)));

        // Pool A: 100k X : 100k Y  (price 1 X = 1 Y).
        _seed(pairA, 100_000 ether, 100_000 ether);
        // Pool B: 100k X : 130k Y  (Y is cheaper / X pricier here) — the arbitrage gap.
        _seed(pairB, 100_000 ether, 130_000 ether);

        arb = new FlashSwapArbitrageur();
    }

    function _seed(Pair p, uint256 xAmt, uint256 yAmt) internal {
        // Deposit in (token0, token1) order regardless of X/Y sorting.
        (uint256 a0, uint256 a1) =
            p.token0() == address(tokenX) ? (xAmt, yAmt) : (yAmt, xAmt);
        MockERC20(p.token0()).mint(address(p), a0);
        MockERC20(p.token1()).mint(address(p), a1);
        p.mint(address(this));
    }

    /// @notice X is dearer on pool B (1 X = 1.3 Y) than on pool A (1 X = 1 Y). The
    /// profitable move: borrow X from A, sell it on B for Y, repay A in Y, keep the Y
    /// profit — all in one transaction, starting with zero capital in the arbitrageur.
    function test_flashSwap_arbitrageIsProfitable() public {
        assertEq(tokenY.balanceOf(address(arb)), 0, "arb starts with nothing");

        address profitTo = address(0xBEEF);
        arb.start(
            address(pairA),      // borrow from A
            address(tokenX),     // borrow X
            address(tokenY),     // repay in Y
            5_000 ether,         // borrow amount
            address(pairB),      // sell on B
            profitTo
        );
        assertGt(tokenY.balanceOf(profitTo), 0, "arbitrage produced a profit in Y");
        assertEq(tokenX.balanceOf(address(arb)), 0, "no funds stranded in the arbitrageur");
        assertEq(tokenY.balanceOf(address(arb)), 0, "no funds stranded in the arbitrageur");
    }

    /// @notice When the pools are priced identically there is no profit, the repayment
    /// falls short, and pool A's invariant check reverts the entire flash swap.
    function test_flashSwap_revertsWhenNotProfitable() public {
        // Re-seed pool B to the same price as A.
        Pair pairBEqual = Pair(new Factory(deployer).createPair(address(tokenX), address(tokenY)));
        (uint256 a0, uint256 a1) =
            pairBEqual.token0() == address(tokenX) ? (100_000 ether, 100_000 ether) : (100_000 ether, 100_000 ether);
        MockERC20(pairBEqual.token0()).mint(address(pairBEqual), a0);
        MockERC20(pairBEqual.token1()).mint(address(pairBEqual), a1);
        pairBEqual.mint(address(this));

        vm.expectRevert(); // Arb: NOT_PROFITABLE (fee gap) — the tx cannot settle
        arb.start(
            address(pairA), address(tokenX), address(tokenY), 5_000 ether,
            address(pairBEqual), address(0xBEEF)
        );
    }
}
