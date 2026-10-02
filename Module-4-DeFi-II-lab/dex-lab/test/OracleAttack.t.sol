// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Pair} from "../src/Pair.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {SpotPriceOracle} from "../src/oracle/SpotPriceOracle.sol";
import {TWAPOracle} from "../src/oracle/TWAPOracle.sol";
import {CollateralVault} from "../src/oracle/CollateralVault.sol";
import {OracleAttacker} from "./attacks/OracleAttacker.sol";

/// @notice Penetration test for oracle manipulation. The SAME attack is run against two
/// vaults that differ only in their price oracle. The spot-oracle vault is drained; the
/// TWAP-oracle vault is not. This is the concrete, executable form of Module 3.14's
/// oracle-risk lecture and the "how it is overcome" half of it.
contract OracleAttackTest is Test {
    Factory factory;
    Pair pair;
    MockERC20 coll;   // collateral token
    MockERC20 stable; // borrowable token

    uint256 constant POOL = 100_000 ether; // 100k : 100k  =>  honest price 1 COLL = 1 STABLE
    uint256 constant LTV_BPS = 5_000;       // 50%
    uint256 constant PERIOD = 1 hours;

    // Attack parameters (shared by both runs).
    uint256 constant PUSH = 300_000 ether;      // stable spent to spike the spot price
    uint256 constant POST = 1_000 ether;        // collateral posted to the vault
    uint256 constant TRUE_VALUE = 1_000 ether;  // POST * honest price (1:1)

    function setUp() public {
        vm.warp(1_000);
        factory = new Factory(address(this));
        coll = new MockERC20("Collateral", "COLL");
        stable = new MockERC20("Stable", "USD");
        pair = Pair(factory.createPair(address(coll), address(stable)));

        // Seed the pool at 1:1.
        coll.mint(address(pair), POOL);
        stable.mint(address(pair), POOL);
        pair.mint(address(this));
    }

    function _deployVault(address oracle) internal returns (CollateralVault vault) {
        vault = new CollateralVault(address(coll), address(stable), oracle, LTV_BPS);
        // Fund the vault with borrowable stable liquidity.
        stable.mint(address(this), 100_000 ether);
        stable.approve(address(vault), 100_000 ether);
        vault.fund(100_000 ether);
    }

    function _fundAttacker(OracleAttacker attacker) internal {
        stable.mint(address(attacker), PUSH); // capital for the price push
        coll.mint(address(attacker), POST);   // collateral to post
    }

    // ------------------------------ the exploit ------------------------------

    function test_spotOracle_isDrained() public {
        SpotPriceOracle oracle = new SpotPriceOracle(address(pair));
        CollateralVault vault = _deployVault(address(oracle));
        OracleAttacker attacker = new OracleAttacker(address(pair), address(vault), address(coll), address(stable));
        _fundAttacker(attacker);

        uint256 vaultStableBefore = stable.balanceOf(address(vault));
        uint256 borrowed = attacker.attack(PUSH, POST);

        console2.log("spot: borrowed          ", borrowed / 1e18);
        console2.log("spot: true collateral   ", TRUE_VALUE / 1e18);

        // The exploit: the vault lent far more than the collateral is really worth.
        assertGt(borrowed, TRUE_VALUE, "spot oracle let the attacker over-borrow");
        // Concretely, bad debt: the debt exceeds even the full (un-haircut) true value.
        assertGt(vault.debtOf(address(attacker)), TRUE_VALUE, "vault now holds bad debt");
        // Stable really left the vault.
        assertEq(stable.balanceOf(address(vault)), vaultStableBefore - borrowed);
        // And the attacker walks away with a net stable profit.
        assertGt(stable.balanceOf(address(attacker)), PUSH, "attacker net profit in stable");
    }

    function test_twapOracle_resistsTheSameAttack() public {
        TWAPOracle oracle = new TWAPOracle(address(pair), PERIOD);
        // A keeper establishes the honest average over one full period.
        vm.warp(block.timestamp + PERIOD);
        oracle.update();

        CollateralVault vault = _deployVault(address(oracle));
        OracleAttacker attacker = new OracleAttacker(address(pair), address(vault), address(coll), address(stable));
        _fundAttacker(attacker);

        uint256 borrowed = attacker.attack(PUSH, POST);

        console2.log("twap: borrowed          ", borrowed / 1e18);
        console2.log("twap: true collateral   ", TRUE_VALUE / 1e18);

        // The manipulated spot price never entered the time-weighted average, so the
        // valuation stayed honest and the vault capped the loan at LTV * true value.
        assertLe(borrowed, TRUE_VALUE * LTV_BPS / 10_000, "TWAP capped the loan at the honest LTV");
        assertLe(vault.debtOf(address(attacker)), TRUE_VALUE, "no bad debt: debt <= true value");
    }

    /// @notice Side-by-side: the same manipulation makes the spot oracle report a wildly
    /// inflated price while the TWAP oracle barely moves, quantifying the defence.
    function test_comparison_spotVsTwapUnderManipulation() public {
        SpotPriceOracle spot = new SpotPriceOracle(address(pair));
        TWAPOracle twap = new TWAPOracle(address(pair), PERIOD);
        vm.warp(block.timestamp + PERIOD);
        twap.update();

        uint256 spotBefore = spot.consult(address(coll), 1 ether);
        uint256 twapBefore = twap.consult(address(coll), 1 ether);

        // Manipulate the pool in one transaction (buy collateral with stable).
        stable.mint(address(this), PUSH);
        stable.transfer(address(pair), PUSH);
        (uint112 r0, uint112 r1,) = pair.getReserves();
        // compute out for the raw swap (stable -> coll)
        (uint256 rIn, uint256 rOut) = address(stable) == pair.token0() ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        uint256 out = (PUSH * 997 * rOut) / (rIn * 1000 + PUSH * 997);
        (uint256 a0, uint256 a1) = address(stable) == pair.token0() ? (uint256(0), out) : (out, uint256(0));
        pair.swap(a0, a1, address(this), new bytes(0));

        uint256 spotAfter = spot.consult(address(coll), 1 ether);
        uint256 twapAfter = twap.consult(address(coll), 1 ether); // no update() called

        console2.log("spot price x1000 before/after:", spotBefore * 1000 / 1e18, spotAfter * 1000 / 1e18);
        console2.log("twap price x1000 before/after:", twapBefore * 1000 / 1e18, twapAfter * 1000 / 1e18);

        assertGt(spotAfter, spotBefore * 5, "spot price moved by more than 5x");
        assertEq(twapAfter, twapBefore, "twap reading unchanged by the flash manipulation");
    }
}
