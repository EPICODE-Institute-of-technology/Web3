// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";
import {Pair} from "../src/Pair.sol";
import {PairLibrary} from "../src/libraries/PairLibrary.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @notice Tests for the periphery router: adding liquidity in the right ratio, and
/// swapping with slippage and deadline protection (Module 3's economics as parameters).
contract RouterTest is Test {
    Factory factory;
    Router router;
    MockERC20 tokenA;
    MockERC20 tokenB;

    address user = address(0xCAFE);
    uint256 constant DEADLINE = 1 days;

    function setUp() public {
        vm.warp(1000);
        factory = new Factory(address(this));
        router = new Router(address(factory));
        tokenA = new MockERC20("Token A", "AAA");
        tokenB = new MockERC20("Token B", "BBB");

        // Fund the user and pre-approve the router.
        tokenA.mint(user, 1_000_000 ether);
        tokenB.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Seed the pool: 100k A : 400k B.
        vm.prank(user);
        router.addLiquidity(
            address(tokenA), address(tokenB),
            100_000 ether, 400_000 ether, 0, 0, user, block.timestamp + DEADLINE
        );
    }

    function test_addLiquidity_secondDepositUsesReserveRatio() public {
        // Offer A and far too much B; the router should only pull B in the 1:4 ratio.
        uint256 bBefore = tokenB.balanceOf(user);
        vm.prank(user);
        (uint256 amountA, uint256 amountB,) = router.addLiquidity(
            address(tokenA), address(tokenB),
            1_000 ether, 100_000 ether, 0, 0, user, block.timestamp + DEADLINE
        );
        assertEq(amountA, 1_000 ether, "all offered A used");
        assertEq(amountB, 4_000 ether, "B pulled in the 1:4 reserve ratio, not the 100k offered");
        assertEq(tokenB.balanceOf(user), bBefore - 4_000 ether, "only the ratio amount of B left the wallet");
    }

    function test_removeLiquidity_returnsBothTokensAndEnforcesMinimums() public {
        Pair pair = Pair(factory.getPair(address(tokenA), address(tokenB)));
        uint256 shares = pair.balanceOf(user);
        assertGt(shares, 0, "user holds LP shares from setUp");

        // The provider approves the router to move their LP tokens, then withdraws.
        vm.startPrank(user);
        pair.approve(address(router), type(uint256).max);

        // The min-out guard rejects an unrealistic floor.
        vm.expectRevert(bytes("Router: INSUFFICIENT_A_AMOUNT"));
        router.removeLiquidity(
            address(tokenA), address(tokenB), shares,
            1_000_000 ether, 0, user, block.timestamp + DEADLINE
        );

        // A withdrawal with sane floors returns both tokens near the deposited amounts.
        (uint256 amountA, uint256 amountB) = router.removeLiquidity(
            address(tokenA), address(tokenB), shares, 0, 0, user, block.timestamp + DEADLINE
        );
        vm.stopPrank();
        assertApproxEqRel(amountA, 100_000 ether, 1e12, "recovers ~token A deposited");
        assertApproxEqRel(amountB, 400_000 ether, 1e12, "recovers ~token B deposited");
        assertEq(pair.balanceOf(user), 0, "all shares burned");
    }

    function test_swapExactTokens_deliversQuotedOutput() public {
        address pair = factory.getPair(address(tokenA), address(tokenB));
        (uint256 rIn, uint256 rOut) = PairLibrary.getReserves(pair, address(tokenA), address(tokenB));
        uint256 expected = PairLibrary.getAmountOut(5_000 ether, rIn, rOut);

        uint256 outBefore = tokenB.balanceOf(user);
        vm.prank(user);
        uint256 out = router.swapExactTokensForTokens(
            5_000 ether, expected, address(tokenA), address(tokenB), user, block.timestamp + DEADLINE
        );
        assertEq(out, expected);
        assertEq(tokenB.balanceOf(user) - outBefore, expected, "user receives exactly the quote");
    }

    function test_swap_revertsOnSlippage() public {
        address pair = factory.getPair(address(tokenA), address(tokenB));
        (uint256 rIn, uint256 rOut) = PairLibrary.getReserves(pair, address(tokenA), address(tokenB));
        uint256 expected = PairLibrary.getAmountOut(5_000 ether, rIn, rOut);
        // Demand one wei more than achievable: slippage guard must revert.
        vm.prank(user);
        vm.expectRevert(bytes("Router: INSUFFICIENT_OUTPUT_AMOUNT"));
        router.swapExactTokensForTokens(
            5_000 ether, expected + 1, address(tokenA), address(tokenB), user, block.timestamp + DEADLINE
        );
    }

    function test_swap_revertsAfterDeadline() public {
        vm.prank(user);
        vm.expectRevert(bytes("Router: EXPIRED"));
        router.swapExactTokensForTokens(
            1 ether, 0, address(tokenA), address(tokenB), user, block.timestamp - 1
        );
    }

    /// @notice Slippage grows with trade size: a large trade gets a strictly worse
    /// average price than a small one, the price-impact property of Module 3.
    function testFuzz_largerTradeWorseAveragePrice(uint256 small, uint256 large) public {
        address pair = factory.getPair(address(tokenA), address(tokenB));
        (uint256 rIn, uint256 rOut) = PairLibrary.getReserves(pair, address(tokenA), address(tokenB));
        small = bound(small, 1 ether, 1_000 ether);
        large = bound(large, 10_000 ether, 50_000 ether);

        uint256 outSmall = PairLibrary.getAmountOut(small, rIn, rOut);
        uint256 outLarge = PairLibrary.getAmountOut(large, rIn, rOut);
        // price = out/in; compare as cross-multiplication to stay in integers.
        assertLt(outLarge * small, outSmall * large, "large trade has worse out/in ratio");
    }
}
