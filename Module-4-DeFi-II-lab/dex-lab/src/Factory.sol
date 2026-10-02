// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Pair} from "./Pair.sol";

/// @title Factory — deploys one Pair per token pair and records the registry.
/// @notice Mirrors Uniswap v2's factory. Pairs are created with CREATE2 using the
/// sorted token addresses as the salt, so a pair's address is deterministic and can be
/// computed off-chain without a lookup. Holds the protocol-fee switch (feeTo / feeToSetter).
contract Factory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /// @notice Deploy the pair for (tokenA, tokenB). Reverts if it already exists.
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Factory: IDENTICAL_ADDRESSES");
        // Sort so (A,B) and (B,A) map to the same pair and token0 < token1 always.
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Factory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "Factory: PAIR_EXISTS");

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(new Pair{salt: salt}());
        Pair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // both directions
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "Factory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "Factory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
