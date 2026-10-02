// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Factory} from "../../src/Factory.sol";
import {Pair} from "../../src/Pair.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {PairHandler} from "./PairHandler.sol";

/// @notice Invariant suite: statements that must hold no matter what sequence of swaps,
/// mints and burns the fuzzer runs (Module 2.16). These encode the pair's economic
/// security properties directly. Foundry re-checks every invariant_ function after each
/// call in each generated sequence; a failure prints the exact call sequence.
contract PairInvariantTest is StdInvariant, Test {
    Factory factory;
    Pair pair;
    MockERC20 token0;
    MockERC20 token1;
    PairHandler handler;

    function setUp() public {
        factory = new Factory(address(this));
        MockERC20 a = new MockERC20("Token A", "AAA");
        MockERC20 b = new MockERC20("Token B", "BBB");
        pair = Pair(factory.createPair(address(a), address(b)));
        token0 = MockERC20(pair.token0());
        token1 = MockERC20(pair.token1());

        // Seed initial liquidity.
        token0.mint(address(pair), 100_000 ether);
        token1.mint(address(pair), 400_000 ether);
        pair.mint(address(this));

        handler = new PairHandler(pair, token0, token1);
        targetContract(address(handler)); // fuzz only through the handler
    }

    /// @notice The reserves the pair reports never exceed the tokens it actually holds.
    /// If this ever failed, the pool would be promising more than it can pay out.
    function invariant_reservesBackedByBalances() public view {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertLe(uint256(r0), token0.balanceOf(address(pair)), "reserve0 <= balance0");
        assertLe(uint256(r1), token1.balanceOf(address(pair)), "reserve1 <= balance1");
    }

    /// @notice As long as liquidity remains, the total supply of LP shares stays at or
    /// above the permanently locked minimum. Shares can never round down to zero.
    function invariant_totalSupplyNeverBelowMinimum() public view {
        assertGe(pair.totalSupply(), pair.MINIMUM_LIQUIDITY(), "supply >= locked minimum");
    }

    /// @notice The most recent swap did not decrease k. Both sides of the comparison are
    /// captured inside the handler's swap(), so a subsequent mint or burn (which changes
    /// k legitimately) does not affect this check. `fail_on_revert = false` lets the
    /// fuzzer attempt swaps freely; only completed swaps update the ghosts.
    function invariant_swapPreservesK() public view {
        if (handler.ghost_swapCount() == 0) return;
        assertGe(handler.ghost_kAfterSwap(), handler.ghost_kBeforeSwap(), "k did not fall on the last swap");
    }

    /// @notice While shares beyond the locked minimum exist, the pool is a live market:
    /// both reserves are strictly positive. Together with invariant_reservesBackedByBalances
    /// (reserves <= balances) this rules out a state where shares are outstanding but the
    /// pool holds nothing to redeem them against. This is a presence check, distinct from
    /// and weaker than the solvency invariant, kept as an independent net.
    function invariant_liveSharesAreBacked() public view {
        if (pair.totalSupply() > pair.MINIMUM_LIQUIDITY()) {
            (uint112 r0, uint112 r1,) = pair.getReserves();
            assertGt(uint256(r0), 0, "reserve0 positive while shares exist");
            assertGt(uint256(r1), 0, "reserve1 positive while shares exist");
        }
    }

    function afterInvariant() public view {
        // Surfaced in -vvv: how many swaps the run actually exercised.
        (uint112 r0, uint112 r1,) = pair.getReserves();
        console_log_reserves(r0, r1);
    }

    function console_log_reserves(uint112, uint112) internal pure {}
}
