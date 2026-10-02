// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Factory} from "./Factory.sol";
import {Pair} from "./Pair.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {PairLibrary} from "./libraries/PairLibrary.sol";

/// @title Router — the periphery contract users actually call.
/// @notice Mirrors UniswapV2Router. The core pair holds funds and enforces the
/// invariant but has a raw interface; the router adds the ergonomics: computing the
/// right deposit ratio, pulling tokens from the user, and enforcing slippage and
/// deadline protection. Separating core (holds value, minimal, immutable) from
/// periphery (stateless, replaceable) is the architectural pattern of the lecture.
contract Router {
    address public immutable factory;

    modifier ensure(uint256 deadline) {
        // The canonical deadline guard: a user's signed swap must not execute after the
        // time they chose, even if a validator delays it. The block.timestamp lint does
        // not apply here — a few seconds of validator leeway is the intended tolerance.
        // forge-lint: disable-next-line(block-timestamp)
        require(deadline >= block.timestamp, "Router: EXPIRED");
        _;
    }

    constructor(address _factory) {
        factory = _factory;
    }

    // ----------------------------- liquidity -----------------------------

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) private returns (uint256 amountA, uint256 amountB, address pair) {
        pair = Factory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = Factory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = PairLibrary.getReserves(pair, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired); // first provision sets the price
        } else {
            uint256 amountBOptimal = PairLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = PairLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair;
        (amountA, amountB, pair) =
            _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = Pair(pair).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = Factory(factory).getPair(tokenA, tokenB);
        // Send the LP tokens to the pair to be burned. The pair's own ERC-20 reverts on
        // an insufficient balance or allowance, so a false return is impossible here.
        require(Pair(pair).transferFrom(msg.sender, pair, liquidity), "Router: LP_TRANSFER_FAILED");
        (uint256 amount0, uint256 amount1) = Pair(pair).burn(to);
        (address token0,) = PairLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "Router: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "Router: INSUFFICIENT_B_AMOUNT");
    }

    // ------------------------------- swaps -------------------------------

    /// @notice Swap an exact input for as much output as possible, reverting if the
    /// output would fall below amountOutMin (slippage protection) or the deadline passed.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountOut) {
        address pair = Factory(factory).getPair(tokenIn, tokenOut);
        require(pair != address(0), "Router: NO_PAIR");
        (uint256 reserveIn, uint256 reserveOut) = PairLibrary.getReserves(pair, tokenIn, tokenOut);
        amountOut = PairLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Router: INSUFFICIENT_OUTPUT_AMOUNT");

        _safeTransferFrom(tokenIn, msg.sender, pair, amountIn);
        (address token0,) = PairLibrary.sortTokens(tokenIn, tokenOut);
        (uint256 amount0Out, uint256 amount1Out) =
            tokenIn == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
        Pair(pair).swap(amount0Out, amount1Out, to, new bytes(0));
    }

    // ------------------------------ helpers ------------------------------

    function _safeTransferFrom(address token, address from, address to, uint256 value) private {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "Router: TRANSFER_FROM_FAILED");
    }
}
