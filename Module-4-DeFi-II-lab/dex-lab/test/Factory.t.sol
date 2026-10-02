// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Pair} from "../src/Pair.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// @notice Tests for the factory's guarantees (Lecture 4.10): one pool per pair,
/// canonical token ordering, a both-directions registry, and access control on the
/// protocol-fee switch. These cover the revert guards the lecture describes.
contract FactoryTest is Test {
    Factory factory;
    MockERC20 tokenA;
    MockERC20 tokenB;

    function setUp() public {
        factory = new Factory(address(this));
        tokenA = new MockERC20("Token A", "AAA");
        tokenB = new MockERC20("Token B", "BBB");
    }

    function test_createPair_sortsTokensAndRegistersBothDirections() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        (address lo, address hi) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB)) : (address(tokenB), address(tokenA));
        assertEq(Pair(pair).token0(), lo, "token0 is the smaller address");
        assertEq(Pair(pair).token1(), hi, "token1 is the larger address");
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair, "registered A,B");
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair, "registered B,A");
        assertEq(factory.allPairsLength(), 1, "one pair recorded");
    }

    function test_createPair_revertsOnDuplicate() public {
        factory.createPair(address(tokenA), address(tokenB));
        vm.expectRevert(bytes("Factory: PAIR_EXISTS"));
        factory.createPair(address(tokenA), address(tokenB));
        // and in the reversed order, which maps to the same pool
        vm.expectRevert(bytes("Factory: PAIR_EXISTS"));
        factory.createPair(address(tokenB), address(tokenA));
    }

    function test_createPair_revertsOnIdenticalTokens() public {
        vm.expectRevert(bytes("Factory: IDENTICAL_ADDRESSES"));
        factory.createPair(address(tokenA), address(tokenA));
    }

    function test_createPair_revertsOnZeroAddress() public {
        // address(0) sorts to token0, so the ZERO_ADDRESS guard fires.
        vm.expectRevert(bytes("Factory: ZERO_ADDRESS"));
        factory.createPair(address(0), address(tokenA));
    }

    function test_feeSwitch_onlyFeeToSetterMayChange() public {
        // The deployer is the feeToSetter and may set the recipient.
        factory.setFeeTo(address(0xFEE));
        assertEq(factory.feeTo(), address(0xFEE));
        // Anyone else is rejected.
        vm.prank(address(0xBEEF));
        vm.expectRevert(bytes("Factory: FORBIDDEN"));
        factory.setFeeTo(address(0xBAD));
        vm.prank(address(0xBEEF));
        vm.expectRevert(bytes("Factory: FORBIDDEN"));
        factory.setFeeToSetter(address(0xBAD));
    }
}
