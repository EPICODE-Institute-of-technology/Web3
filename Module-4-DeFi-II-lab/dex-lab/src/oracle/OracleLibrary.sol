// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Pair} from "../Pair.sol";
import {UQ112x112} from "../libraries/UQ112x112.sol";

/// @notice Helper to read a pair's price accumulators brought up to the current instant
/// (mirrors Uniswap v2's OracleLibrary.currentCumulativePrices). The pair only advances
/// its accumulators when a state-changing call touches it, so a correct TWAP reader must
/// add the price that has held since the pair's last update.
library OracleLibrary {
    using UQ112x112 for uint224;

    function currentCumulativePrices(address pair)
        internal
        view
        returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp)
    {
        blockTimestamp = uint32(block.timestamp % 2 ** 32);
        price0Cumulative = Pair(pair).price0CumulativeLast();
        price1Cumulative = Pair(pair).price1CumulativeLast();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            unchecked {
                uint32 timeElapsed = blockTimestamp - blockTimestampLast; // wraps like the pair
                price0Cumulative += uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) * timeElapsed;
                price1Cumulative += uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) * timeElapsed;
            }
        }
    }
}
