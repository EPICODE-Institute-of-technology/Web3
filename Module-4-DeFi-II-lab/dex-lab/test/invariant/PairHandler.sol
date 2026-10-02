// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Pair} from "../../src/Pair.sol";
import {PairLibrary} from "../../src/libraries/PairLibrary.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @notice The handler bounds the fuzzer to *valid* action sequences on the pair, and
/// tracks ghost variables the invariants read (Module 2.16). Pointing the fuzzer
/// straight at the pair would make almost every random call revert on the require
/// guards; the handler reshapes raw fuzz words into realistic swaps, mints and burns.
contract PairHandler is Test {
    Pair public pair;
    MockERC20 public token0;
    MockERC20 public token1;

    address[] internal actors = [address(0x1001), address(0x1002), address(0x1003)];
    address internal currentActor;

    // Ghost variables: cumulative flows, checked by the invariants.
    uint256 public ghost_deposited0;
    uint256 public ghost_deposited1;
    uint256 public ghost_withdrawn0;
    uint256 public ghost_withdrawn1;
    uint256 public ghost_swapCount;
    // Reserve product immediately before and after the most recent swap. Both are
    // captured inside swap(), so a later mint or burn cannot disturb the comparison.
    uint256 public ghost_kBeforeSwap;
    uint256 public ghost_kAfterSwap;

    modifier useActor(uint256 seed) {
        currentActor = actors[bound(seed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(Pair _pair, MockERC20 _t0, MockERC20 _t1) {
        pair = _pair;
        token0 = _t0;
        token1 = _t1;
    }

    // --------------------------- fuzzed actions ---------------------------

    function swap(uint256 actorSeed, uint256 amountIn, bool zeroForOne) external useActor(actorSeed) {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        if (r0 == 0 || r1 == 0) return;
        amountIn = bound(amountIn, 1e6, uint256(zeroForOne ? r0 : r1) / 3);
        if (amountIn == 0) return;

        (uint256 reserveIn, uint256 reserveOut) =
            zeroForOne ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        uint256 out = PairLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        if (out == 0) return;

        ghost_kBeforeSwap = uint256(r0) * r1;
        MockERC20 tin = zeroForOne ? token0 : token1;
        tin.mint(currentActor, amountIn);
        tin.transfer(address(pair), amountIn);
        (uint256 a0, uint256 a1) = zeroForOne ? (uint256(0), out) : (out, uint256(0));
        pair.swap(a0, a1, currentActor, new bytes(0));
        (uint112 n0, uint112 n1,) = pair.getReserves();
        ghost_kAfterSwap = uint256(n0) * n1;
        ghost_swapCount++;
    }

    function addLiquidity(uint256 actorSeed, uint256 amount0) external useActor(actorSeed) {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        if (r0 == 0 || r1 == 0) return;
        amount0 = bound(amount0, 1e12, 10_000 ether);
        uint256 amount1 = PairLibrary.quote(amount0, r0, r1); // deposit in ratio
        token0.mint(currentActor, amount0);
        token1.mint(currentActor, amount1);
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        pair.mint(currentActor);
        ghost_deposited0 += amount0;
        ghost_deposited1 += amount1;
    }

    function removeLiquidity(uint256 actorSeed, uint256 shareBips) external useActor(actorSeed) {
        uint256 bal = pair.balanceOf(currentActor);
        if (bal == 0) return;
        shareBips = bound(shareBips, 1, 10_000);
        uint256 shares = bal * shareBips / 10_000;
        if (shares == 0) return;
        pair.transfer(address(pair), shares);
        (uint256 a0, uint256 a1) = pair.burn(currentActor);
        ghost_withdrawn0 += a0;
        ghost_withdrawn1 += a1;
    }
}
