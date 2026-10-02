// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

/// @notice Binary fixed-point numbers with 112 integer and 112 fractional bits,
/// stored in a uint224 (mirrors Uniswap v2's UQ112x112.sol). A price is a ratio
/// of two uint112 reserves, so the quotient always fits this format; the range
/// [0, 2^112) with resolution 1/2^112 is what the pair's price accumulators use.
library UQ112x112 {
    uint224 internal constant Q112 = 2 ** 112;

    /// @notice Encode a uint112 as a UQ112x112 (multiply by 2^112).
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows: y < 2^112
    }

    /// @notice Divide a UQ112x112 by a uint112, returning a UQ112x112.
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
