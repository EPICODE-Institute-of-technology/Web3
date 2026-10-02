// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IPriceOracle} from "./IPriceOracle.sol";
import {Pair} from "../Pair.sol";
import {OracleLibrary} from "./OracleLibrary.sol";
import {UQ112x112} from "../libraries/UQ112x112.sol";

/// @title TWAPOracle — a fixed-window time-weighted average price oracle (SECURE).
/// @notice Mirrors Uniswap v2's example oracle. It samples the pair's price accumulator
/// and reports the average price over the last full PERIOD. Because the report is an
/// average over time, a price that exists for only part of a block (a flash manipulation)
/// barely moves it: to shift a T-second average by a large amount, an attacker must hold
/// the manipulated price for a large fraction of T, which costs arbitrage losses every
/// block. This is why time-weighting is the defence against single-transaction oracle
/// manipulation. The trade-off is lag: the price is stale by up to PERIOD.
contract TWAPOracle is IPriceOracle {
    using UQ112x112 for uint224;

    Pair public immutable pair;
    address public immutable token0;
    address public immutable token1;
    uint256 public immutable period;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    uint224 public price0Average; // UQ112x112: token1 per token0
    uint224 public price1Average; // UQ112x112: token0 per token1

    constructor(address _pair, uint256 _period) {
        pair = Pair(_pair);
        token0 = pair.token0();
        token1 = pair.token1();
        period = _period;
        price0CumulativeLast = pair.price0CumulativeLast();
        price1CumulativeLast = pair.price1CumulativeLast();
        (,, blockTimestampLast) = pair.getReserves();
    }

    /// @notice Advance the window: compute the average price since the last update and
    /// store it. Must be called at least once per PERIOD by anyone (a keeper). Reverts if
    /// a full period has not elapsed, so the stored average always spans >= PERIOD.
    function update() external {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) =
            OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast; // wraps like the pair
        }
        require(timeElapsed >= period, "TWAP: PERIOD_NOT_ELAPSED");

        unchecked {
            // average = (cumulative_now - cumulative_then) / elapsed, in UQ112x112.
            price0Average = uint224((price0Cumulative - price0CumulativeLast) / timeElapsed);
            price1Average = uint224((price1Cumulative - price1CumulativeLast) / timeElapsed);
        }
        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    /// @notice Value `amountIn` of `token` using the stored time-weighted average.
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut) {
        if (token == token0) {
            amountOut = _mul(price0Average, amountIn);
        } else {
            require(token == token1, "TWAP: UNKNOWN_TOKEN");
            amountOut = _mul(price1Average, amountIn);
        }
    }

    // Multiply a UQ112x112 average by an integer amount and drop the 112 fractional bits.
    function _mul(uint224 avg, uint256 amountIn) private pure returns (uint256) {
        return (uint256(avg) * amountIn) >> 112;
    }
}
