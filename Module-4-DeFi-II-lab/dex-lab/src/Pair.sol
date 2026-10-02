// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {PairERC20} from "./PairERC20.sol";
import {Math} from "./libraries/Math.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IPairCallee} from "./interfaces/IPairCallee.sol";

interface IFactory {
    function feeTo() external view returns (address);
}

/// @title Pair — a constant-product automated market maker for one token pair.
/// @notice A faithful, teaching-oriented rebuild of Uniswap v2's core pair contract.
/// It holds reserves of two tokens and enforces the invariant x * y = k (with a 0.30%
/// fee) on every swap. The pair is also the LP token: liquidity shares are its own
/// ERC-20 balance. It maintains time-weighted price accumulators (a TWAP oracle) and
/// optionally mints a protocol fee equal to 1/6 of the growth in sqrt(k).
contract Pair is PairERC20 {
    using UQ112x112 for uint224;

    /// @notice Permanently locked on the first mint so totalSupply can never return to
    /// zero. This stops the "first depositor" share-price attack: without the lock, an
    /// attacker could mint 1 wei of liquidity then donate tokens to inflate the share
    /// price and make later small deposits round to zero shares.
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    /// @notice Swap fee numerator/denominator: 997/1000 keeps 0.30% of every input.
    uint256 private constant FEE_NUM = 997;
    uint256 private constant FEE_DEN = 1000;

    address public immutable factory;
    address public token0;
    address public token1;

    // Reserves and the last-update timestamp are packed into one storage slot, exactly
    // as in Uniswap v2, so reading the pool state costs a single SLOAD.
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    /// @notice Cumulative price accumulators (UQ112x112, summed over seconds). The TWAP
    /// over an interval is the difference of two readings divided by the elapsed time.
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    /// @notice reserve0 * reserve1 immediately after the most recent liquidity event;
    /// used only to size the protocol fee. Zero when the protocol fee is off.
    uint256 public kLast;

    uint256 private unlocked = 1;

    /// @notice Single-slot reentrancy guard, as in Uniswap v2. Every state-changing
    /// entry point takes it, which is what makes optimistic transfers in swap() safe.
    modifier lock() {
        require(unlocked == 1, "Pair: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    /// @notice Called once by the factory right after deployment to set the tokens.
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "Pair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves()
        public
        view
        returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /// @dev Write the new reserves and advance the price accumulators by the price that
    /// held over the elapsed interval. The accumulators use unchecked arithmetic that is
    /// designed to overflow (a wrap-around is harmless because consumers only ever read
    /// differences), which is why this block is `unchecked`.
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1)
        private
    {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Pair: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        unchecked {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast; // wraps intentionally
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // price0 = reserve1/reserve0, accumulated over the elapsed seconds.
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        // Safe: the require above proves both balances are < 2^112.
        // forge-lint: disable-next-line(unsafe-typecast)
        reserve0 = uint112(balance0);
        // forge-lint: disable-next-line(unsafe-typecast)
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /// @dev If the protocol fee is on, mint LP tokens worth 1/6 of the growth in
    /// sqrt(k) since the last liquidity event. Fees earned by the pool show up as a
    /// larger k; this hands one sixth of that growth to feeTo, leaving 5/6 to LPs.
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @notice Mint LP tokens to `to` for whatever was deposited since the last sync.
    /// The router transfers both tokens in first, then calls this; the pair measures
    /// the deposit as the balance minus the stored reserve.
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // read after _mintFee, which may have minted
        if (_totalSupply == 0) {
            // First provision: shares = sqrt(x*y), minus the permanent lock.
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY); // lock to a non-zero burn address
        } else {
            // Later provisions: the smaller of the two proportional shares, which
            // penalises depositing tokens in the wrong ratio.
            liquidity = Math.min(
                amount0 * _totalSupply / _reserve0,
                amount1 * _totalSupply / _reserve1
            );
        }
        require(liquidity > 0, "Pair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    /// @notice Burn the LP tokens this contract holds and send the underlying back to
    /// `to`, pro rata to the share of the pool burned.
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;
        amount0 = liquidity * balance0 / _totalSupply; // pro rata of the real balance
        amount1 = liquidity * balance1 / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "Pair: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice Swap out `amount0Out`/`amount1Out`, having been paid the input either
    /// before the call or, if `data` is non-empty, inside the uniswapV2Call-style hook
    /// (a flash swap). The invariant check at the end is the single line that enforces
    /// x*y=k with the fee and, for a flash swap, that the borrowed tokens were returned.
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data)
        external
        lock
    {
        require(amount0Out > 0 || amount1Out > 0, "Pair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Pair: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "Pair: INVALID_TO");
            // Optimistic transfer: send the output FIRST.
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            // Flash-swap hook: the callee must pay the pair before it returns.
            if (data.length > 0) {
                IPairCallee(to).pairCall(msg.sender, amount0Out, amount1Out, data);
            }
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        // How much actually came in = new balance minus what remained after paying out.
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "Pair: INSUFFICIENT_INPUT_AMOUNT");
        {
            // Balances net of the 0.30% fee must satisfy x*y >= k. Scaling by 1000 and
            // subtracting 3*amountIn applies the fee without floating point.
            uint256 balance0Adjusted = balance0 * FEE_DEN - amount0In * (FEE_DEN - FEE_NUM);
            uint256 balance1Adjusted = balance1 * FEE_DEN - amount1In * (FEE_DEN - FEE_NUM);
            require(
                balance0Adjusted * balance1Adjusted
                    >= uint256(_reserve0) * _reserve1 * (FEE_DEN ** 2),
                "Pair: K"
            );
        }
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /// @notice Force the reserves to match balances (recover tokens sent by mistake).
    function skim(address to) external lock {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    /// @notice Force reserves to match balances the other way (update to current balance).
    function sync() external lock {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "Pair: TRANSFER_FAILED");
    }
}
