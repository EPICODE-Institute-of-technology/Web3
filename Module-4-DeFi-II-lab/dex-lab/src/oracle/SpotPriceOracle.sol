// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IPriceOracle} from "./IPriceOracle.sol";
import {Pair} from "../Pair.sol";

/// @title SpotPriceOracle — VULNERABLE oracle for teaching.
/// @notice Reads the pair's instantaneous reserves and reports the spot price. This is
/// the single most common oracle mistake: the spot price is whatever the reserves are
/// at this instant, and the reserves can be moved arbitrarily far within one transaction
/// by a large swap (funded outright or with a flash loan). Any contract that makes a
/// financial decision on this number can be manipulated. Do not use in production; it is
/// here to be attacked in the penetration test, then replaced by the TWAP oracle.
contract SpotPriceOracle is IPriceOracle {
    Pair public immutable pair;
    address public immutable token0;
    address public immutable token1;

    constructor(address _pair) {
        pair = Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
    }

    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 > 0 && reserve1 > 0, "SpotOracle: NO_LIQUIDITY");
        if (token == token0) {
            amountOut = amountIn * reserve1 / reserve0; // value of token0 in token1
        } else {
            require(token == token1, "SpotOracle: UNKNOWN_TOKEN");
            amountOut = amountIn * reserve0 / reserve1;
        }
    }
}
