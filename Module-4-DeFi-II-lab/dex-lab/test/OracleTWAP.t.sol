// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Pair} from "../src/Pair.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {SpotPriceOracle} from "../src/oracle/SpotPriceOracle.sol";
import {TWAPOracle} from "../src/oracle/TWAPOracle.sol";
import {PairLibrary} from "../src/libraries/PairLibrary.sol";

/// @notice Positive correctness tests for the TWAP oracle (Lecture 4.13). The
/// penetration test shows the TWAP RESISTS a flash manipulation; these show it also
/// TRACKS a genuine, sustained price change, which a broken oracle stuck at its initial
/// value would fail. Together they establish that the oracle is both correct and safe.
contract OracleTWAPTest is Test {
    Factory factory;
    Pair pair;
    MockERC20 coll;
    MockERC20 stable;
    uint256 constant POOL = 100_000 ether;
    uint256 constant PERIOD = 1 hours;

    function setUp() public {
        vm.warp(1_000);
        factory = new Factory(address(this));
        coll = new MockERC20("Collateral", "COLL");
        stable = new MockERC20("Stable", "USD");
        pair = Pair(factory.createPair(address(coll), address(stable)));
        coll.mint(address(pair), POOL);
        stable.mint(address(pair), POOL); // opens at 1 COLL = 1 STABLE
        pair.mint(address(this));
    }

    function _swap(address tokenIn, uint256 amountIn) internal {
        address tokenOut = tokenIn == pair.token0() ? pair.token1() : pair.token0();
        (uint256 rIn, uint256 rOut) = PairLibrary.getReserves(address(pair), tokenIn, tokenOut);
        uint256 out = PairLibrary.getAmountOut(amountIn, rIn, rOut);
        MockERC20(tokenIn).mint(address(this), amountIn);
        MockERC20(tokenIn).transfer(address(pair), amountIn);
        (uint256 a0, uint256 a1) =
            tokenIn == pair.token0() ? (uint256(0), out) : (out, uint256(0));
        pair.swap(a0, a1, address(this), new bytes(0));
    }

    /// @notice A price change held for a full period is reflected by the TWAP after the
    /// next update, and closely matches the new spot price (the average of a constant).
    function test_twap_tracksSustainedPrice() public {
        TWAPOracle twap = new TWAPOracle(address(pair), PERIOD);
        vm.warp(block.timestamp + PERIOD);
        twap.update(); // baseline over a period at 1:1
        assertApproxEqRel(twap.consult(address(coll), 1 ether), 1 ether, 1e15, "baseline ~1:1");

        // Move the price and hold it: buy collateral with stable, making COLL dearer.
        _swap(address(stable), 50_000 ether);
        SpotPriceOracle spot = new SpotPriceOracle(address(pair));
        uint256 newSpot = spot.consult(address(coll), 1 ether); // the sustained price

        vm.warp(block.timestamp + PERIOD); // hold the new price for a full period
        twap.update();
        uint256 twapPrice = twap.consult(address(coll), 1 ether);

        assertGt(twapPrice, 1 ether, "TWAP moved up with the sustained price");
        // Over a period at a constant price, the average equals that price.
        assertApproxEqRel(twapPrice, newSpot, 1e15, "TWAP tracks the new spot within 0.1%");
    }

    /// @notice update reverts until a full period has elapsed, so the stored average
    /// always spans at least PERIOD (the guard that makes the average hard to move).
    function test_twap_updateRevertsBeforePeriod() public {
        TWAPOracle twap = new TWAPOracle(address(pair), PERIOD);
        vm.warp(block.timestamp + PERIOD / 2);
        vm.expectRevert(bytes("TWAP: PERIOD_NOT_ELAPSED"));
        twap.update();
    }

    /// @notice Both oracles reject a token that is not in the pair.
    function test_oracles_rejectUnknownToken() public {
        SpotPriceOracle spot = new SpotPriceOracle(address(pair));
        TWAPOracle twap = new TWAPOracle(address(pair), PERIOD);
        vm.warp(block.timestamp + PERIOD);
        twap.update();
        vm.expectRevert(bytes("SpotOracle: UNKNOWN_TOKEN"));
        spot.consult(address(0xDEAD), 1 ether);
        vm.expectRevert(bytes("TWAP: UNKNOWN_TOKEN"));
        twap.consult(address(0xDEAD), 1 ether);
    }
}
