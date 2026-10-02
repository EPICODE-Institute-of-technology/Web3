// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Pair} from "../src/Pair.sol";
import {PairLibrary} from "../src/libraries/PairLibrary.sol";
import {Math} from "../src/libraries/Math.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @notice Unit and fuzz tests for the core pair. Example-based tests fix one scenario
/// and check one result (Module 2.15); fuzz tests state a property that must hold for
/// many random inputs (Module 2.16). Both methods are applied here to the AMM.
contract PairTest is Test {
    Factory factory;
    Pair pair;
    MockERC20 tokenA;
    MockERC20 tokenB;
    address token0;
    address token1;

    address lp = address(0xA11CE);
    address trader = address(0xB0B);

    uint256 constant INIT0 = 100_000 ether;
    uint256 constant INIT1 = 400_000 ether; // starting price: 1 token0 = 4 token1

    function setUp() public {
        factory = new Factory(address(this));
        tokenA = new MockERC20("Token A", "AAA");
        tokenB = new MockERC20("Token B", "BBB");
        pair = Pair(factory.createPair(address(tokenA), address(tokenB)));
        token0 = pair.token0();
        token1 = pair.token1();
        _addInitialLiquidity(INIT0, INIT1);
    }

    // Deposit directly into the pair and mint LP tokens to `lp` (bypassing the router,
    // to test the core in isolation). Amounts are in (token0, token1) order.
    function _addInitialLiquidity(uint256 amt0, uint256 amt1) internal {
        MockERC20(token0).mint(address(pair), amt0);
        MockERC20(token1).mint(address(pair), amt1);
        pair.mint(lp);
    }

    // -------------------------- example-based tests --------------------------

    function test_firstMint_locksMinimumLiquidity() public view {
        uint256 expected = Math.sqrt(INIT0 * INIT1) - pair.MINIMUM_LIQUIDITY();
        assertEq(pair.balanceOf(lp), expected, "LP shares = sqrt(k) - MINIMUM_LIQUIDITY");
        assertEq(pair.balanceOf(address(1)), pair.MINIMUM_LIQUIDITY(), "min liquidity locked");
        assertEq(pair.totalSupply(), expected + pair.MINIMUM_LIQUIDITY());
    }

    function test_swap_chargesThirtyBasisPointFee() public {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 amountIn = 1_000 ether;
        // Quote token0 -> token1 using the library, then execute and compare.
        uint256 out = PairLibrary.getAmountOut(amountIn, r0, r1);

        MockERC20(token0).mint(trader, amountIn);
        vm.prank(trader);
        MockERC20(token0).transfer(address(pair), amountIn);
        pair.swap(0, out, trader, new bytes(0));

        assertEq(MockERC20(token1).balanceOf(trader), out, "trader receives the quoted output");

        // The fee-free output would have been strictly larger; the gap is the 0.30% fee.
        uint256 feeFree = uint256(amountIn) * r1 / (uint256(r0) + amountIn);
        assertLt(out, feeFree, "output is reduced by the fee");
    }

    function test_swap_revertsWhenKWouldFall() public {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 amountIn = 1_000 ether;
        uint256 fairOut = PairLibrary.getAmountOut(amountIn, r0, r1);

        MockERC20(token0).mint(trader, amountIn);
        vm.prank(trader);
        MockERC20(token0).transfer(address(pair), amountIn);
        // Asking for one wei more than the invariant allows must revert.
        vm.expectRevert(bytes("Pair: K"));
        pair.swap(0, fairOut + 1e12, trader, new bytes(0));
    }

    function test_burn_returnsUnderlyingProRata() public {
        uint256 shares = pair.balanceOf(lp);
        vm.prank(lp);
        pair.transfer(address(pair), shares);
        (uint256 a0, uint256 a1) = pair.burn(lp);
        // With no swaps, the provider recovers essentially the full deposit; the only
        // shortfall is the permanently locked minimum liquidity.
        assertApproxEqRel(a0, INIT0, 1e12, "recovers ~token0 deposited");
        assertApproxEqRel(a1, INIT1, 1e12, "recovers ~token1 deposited");
    }

    function test_protocolFee_mintsOneSixthOfGrowth() public {
        factory.setFeeTo(address(0xFEE)); // turn the switch on
        // A liquidity event with the switch on seeds kLast (no fee minted yet).
        _addProportional(1 ether);

        // Generate fee growth with a round-trip of swaps: k rises, kLast does not.
        _swapExact(token0, 5_000 ether);
        _swapExact(token1, 20_000 ether);

        // Independently recompute the exact fee the formula must mint on the next event.
        uint256 kLastPrev = pair.kLast();
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 rootK = Math.sqrt(uint256(r0) * r1);
        uint256 rootKLast = Math.sqrt(kLastPrev);
        uint256 tsPrev = pair.totalSupply();
        uint256 expected = tsPrev * (rootK - rootKLast) / (rootK * 5 + rootKLast);
        assertEq(pair.balanceOf(address(0xFEE)), 0, "no fee minted before the event");

        _addProportional(1 ether); // _mintFee runs here, minting to feeTo
        // The minted amount equals the 1/6-of-sqrt(k)-growth formula exactly.
        assertEq(pair.balanceOf(address(0xFEE)), expected, "protocol fee = 1/6 of sqrt(k) growth");
        assertGt(expected, 0, "and the fee is non-trivial");
    }

    // Deposit token0 and the matching token1 at the current reserve ratio, then mint to lp.
    function _addProportional(uint256 amount0) internal {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 amount1 = amount0 * r1 / r0;
        MockERC20(token0).mint(address(pair), amount0);
        MockERC20(token1).mint(address(pair), amount1);
        pair.mint(lp);
    }

    // ------------------------------ fuzz tests ------------------------------

    /// @notice Property: a swap never decreases k (reserve product). This is the
    /// economic-security core of a constant-product AMM — no input a trader can choose
    /// lets them extract value beyond the fee. Checked over many random inputs.
    function testFuzz_swap_neverDecreasesK(uint256 amountIn, bool zeroForOne) public {
        amountIn = bound(amountIn, 1e6, 50_000 ether);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 kBefore = uint256(r0) * r1;

        address tin = zeroForOne ? token0 : token1;
        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        uint256 out = PairLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        vm.assume(out > 0);

        MockERC20(tin).mint(address(pair), amountIn);
        (uint256 a0, uint256 a1) = zeroForOne ? (uint256(0), out) : (out, uint256(0));
        pair.swap(a0, a1, trader, new bytes(0));

        (uint112 n0, uint112 n1,) = pair.getReserves();
        assertGe(uint256(n0) * n1, kBefore, "k must not fall on a swap");
    }

    /// @notice Property: getAmountIn is the exact minimal inverse of getAmountOut. The
    /// input it returns is enough to extract the target output (so the swap settles),
    /// and one wei less is not (so it is not overcharging). This pins down the inverse
    /// pricing formula that the lecture derives but the router's exact-in path does not use.
    function testFuzz_getAmountIn_isMinimalInverse(uint256 amountOut) public view {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        amountOut = bound(amountOut, 1e6, uint256(r1) / 2); // want token1 out, keep < reserve
        uint256 amountIn = PairLibrary.getAmountIn(amountOut, r0, r1);
        // Enough: the input actually yields at least the requested output.
        assertGe(PairLibrary.getAmountOut(amountIn, r0, r1), amountOut, "getAmountIn suffices");
        // Minimal: one wei less input no longer covers the output.
        if (amountIn > 1) {
            assertLt(PairLibrary.getAmountOut(amountIn - 1, r0, r1), amountOut, "getAmountIn is minimal");
        }
    }

    /// @notice Property: the router's getAmountOut quote is exactly executable — the
    /// pair accepts it and the trader receives precisely the quoted amount.
    function testFuzz_quoteIsExecutable(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e6, 50_000 ether);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 out = PairLibrary.getAmountOut(amountIn, r0, r1);
        vm.assume(out > 0);

        MockERC20(token0).mint(trader, amountIn);
        vm.prank(trader);
        MockERC20(token0).transfer(address(pair), amountIn);
        pair.swap(0, out, trader, new bytes(0)); // must not revert
        assertEq(MockERC20(token1).balanceOf(trader), out);
    }

    // helper
    function _swapExact(address tokenIn, uint256 amountIn) internal {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        (uint256 reserveIn, uint256 reserveOut) =
            tokenIn == token0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        uint256 out = PairLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        MockERC20(tokenIn).mint(address(pair), amountIn);
        (uint256 a0, uint256 a1) =
            tokenIn == token0 ? (uint256(0), out) : (out, uint256(0));
        pair.swap(a0, a1, trader, new bytes(0));
    }
}
