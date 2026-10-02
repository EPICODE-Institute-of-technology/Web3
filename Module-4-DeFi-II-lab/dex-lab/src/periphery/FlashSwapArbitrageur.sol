// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Pair} from "../Pair.sol";
import {IPairCallee} from "../interfaces/IPairCallee.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {PairLibrary} from "../libraries/PairLibrary.sol";

/// @title FlashSwapArbitrageur — profits from a price gap between two pools with no
/// upfront capital, using a flash swap.
/// @notice Demonstrates the uniswapV2Call-style callback. The contract borrows the
/// output token from pool A optimistically, sells it on pool B where it is priced
/// higher, repays pool A the required input inside the same call, and keeps the rest.
/// If the trade is not profitable the repayment falls short, pool A's invariant check
/// reverts, and the whole transaction is undone. No capital, no risk of a bad fill.
contract FlashSwapArbitrageur is IPairCallee {
    struct Params {
        address pairB;      // the pool to sell the borrowed token on
        address tokenBorrow; // token taken out of pool A
        address tokenRepay;  // token paid back to pool A
        address profitTo;    // recipient of the arbitrage profit
    }

    /// @notice Start the arbitrage: flash-borrow `amountBorrow` of `tokenBorrow` from
    /// pool A, which triggers pairCall below.
    function start(
        address pairA,
        address tokenBorrow,
        address tokenRepay,
        uint256 amountBorrow,
        address pairB,
        address profitTo
    ) external {
        address t0 = Pair(pairA).token0();
        (uint256 a0, uint256 a1) =
            tokenBorrow == t0 ? (amountBorrow, uint256(0)) : (uint256(0), amountBorrow);
        bytes memory data = abi.encode(Params(pairB, tokenBorrow, tokenRepay, profitTo));
        Pair(pairA).swap(a0, a1, address(this), data); // non-empty data => flash swap
    }

    /// @notice Called back by pool A after it has sent us the borrowed token.
    function pairCall(address, uint256 amount0, uint256 amount1, bytes calldata data) external {
        Params memory p = abi.decode(data, (Params));
        address pairA = msg.sender; // only pool A can be the caller of its own callback
        uint256 amountBorrowed = amount0 > 0 ? amount0 : amount1;

        // 1. How much tokenRepay does pool A require back for what we took?
        (uint256 reserveRepayA, uint256 reserveBorrowA) =
            PairLibrary.getReserves(pairA, p.tokenRepay, p.tokenBorrow);
        uint256 amountToRepay = PairLibrary.getAmountIn(amountBorrowed, reserveRepayA, reserveBorrowA);

        // 2. Sell the borrowed token on pool B for tokenRepay.
        uint256 received = _sellOnPairB(p, amountBorrowed);
        require(received > amountToRepay, "Arb: NOT_PROFITABLE");

        // 3. Repay pool A and keep the surplus.
        _safeTransfer(p.tokenRepay, pairA, amountToRepay);
        _safeTransfer(p.tokenRepay, p.profitTo, received - amountToRepay);
    }

    function _sellOnPairB(Params memory p, uint256 amountIn) private returns (uint256 received) {
        (uint256 reserveInB, uint256 reserveOutB) =
            PairLibrary.getReserves(p.pairB, p.tokenBorrow, p.tokenRepay);
        received = PairLibrary.getAmountOut(amountIn, reserveInB, reserveOutB);
        _safeTransfer(p.tokenBorrow, p.pairB, amountIn);
        address t0B = Pair(p.pairB).token0();
        (uint256 o0, uint256 o1) =
            p.tokenRepay == t0B ? (received, uint256(0)) : (uint256(0), received);
        Pair(p.pairB).swap(o0, o1, address(this), new bytes(0));
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "Arb: TRANSFER_FAILED");
    }
}
