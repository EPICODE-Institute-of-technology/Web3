// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./06-CounterStructsPausable.sol";

/// @title  CounterMultiManager
/// @notice Counter 7 of 7
///         A SEPARATE smart contract that wraps an existing
///         CounterStructsPausable instance:
///           * during deployment, it creates its own counter inside the
///             target contract (the target sees this contract's address
///             as the creator of that counter);
///           * the counter is then operated jointly by THREE distinct
///             addresses fixed at deployment time — any one of them can
///             call increase / decrease / reset on behalf of the group.
///
/// @dev    Demonstrates inter-contract calls, the difference between
///         msg.sender at each call level, and a tiny access-control
///         pattern (manager whitelist) other than `onlyOwner`.
contract CounterMultiManager {
    // ---------------------------------------------------------
    //  Immutable wiring — every field is decided once at deploy
    // ---------------------------------------------------------
    CounterStructsPausable public immutable target; // the wrapped contract
    uint256                public immutable counterId; // 1-based id inside `target`

    address public immutable manager1;
    address public immutable manager2;
    address public immutable manager3;

    // ---------------------------------------------------------
    //  Events
    // ---------------------------------------------------------
    event Managed(
        address indexed manager,
        string  what,    // "increase" / "decrease" / "reset"
        uint256 units,
        uint256 paid
    );

    // ---------------------------------------------------------
    //  Errors
    // ---------------------------------------------------------
    error NotAManager(address caller);
    error ZeroManager();
    error DuplicateManager();

    // ---------------------------------------------------------
    //  Access control
    // ---------------------------------------------------------
    modifier onlyManager() {
        if (
            msg.sender != manager1 &&
            msg.sender != manager2 &&
            msg.sender != manager3
        ) {
            revert NotAManager(msg.sender);
        }
        _;
    }

    // ---------------------------------------------------------
    //  Constructor
    //  -----------
    //  Takes:
    //    _target  : an already-deployed CounterStructsPausable
    //    name_    : the name of the new counter to be created
    //               inside _target by THIS contract
    //    m1, m2, m3: the three addresses authorised to manage it
    //
    //  Side effect: calls _target.createCounter(name_).
    //  Reverts if any address is the zero address, if two of them are
    //  equal, or if _target is paused at deployment time.
    // ---------------------------------------------------------
    constructor(
        CounterStructsPausable _target,
        string memory          name_,
        address                m1,
        address                m2,
        address                m3
    ) {
        // Validate the manager set.
        if (m1 == address(0) || m2 == address(0) || m3 == address(0)) {
            revert ZeroManager();
        }
        if (m1 == m2 || m1 == m3 || m2 == m3) {
            revert DuplicateManager();
        }

        target   = _target;
        manager1 = m1;
        manager2 = m2;
        manager3 = m3;

        // Create our counter inside the wrapped contract.
        // After this call, target.counterOf(address(this)) == counterId.
        // The "creator" recorded by the target is address(this).
        counterId = _target.createCounter(name_);
    }

    // ---------------------------------------------------------
    //  Managed operations — forward `msg.value` to the target
    //  so the >= 2 * units wei pricing rule keeps working.
    // ---------------------------------------------------------

    /// @notice Increase the wrapped counter by `units`. Forwards the
    ///         caller's wei to the target so the target's price check
    ///         is satisfied as if the call had come directly.
    function increase(uint256 units) external payable onlyManager {
        target.increase{value: msg.value}(units);
        emit Managed(msg.sender, "increase", units, msg.value);
    }

    /// @notice Decrease the wrapped counter by `units`.
    function decrease(uint256 units) external payable onlyManager {
        target.decrease{value: msg.value}(units);
        emit Managed(msg.sender, "decrease", units, msg.value);
    }

    /// @notice Reset the wrapped counter to zero (price = 2 wei).
    function reset() external payable onlyManager {
        target.reset{value: msg.value}();
        emit Managed(msg.sender, "reset", 0, msg.value);
    }

    // ---------------------------------------------------------
    //  Public views — anyone can inspect
    // ---------------------------------------------------------

    function getCounter()
        external
        view
        returns (CounterStructsPausable.Counter memory)
    {
        return target.getCounter(counterId);
    }

    function getValue() external view returns (uint256) {
        return target.getValue(counterId);
    }

    /// @notice True iff `who` is one of the three configured managers.
    function isManager(address who) external view returns (bool) {
        return who == manager1 || who == manager2 || who == manager3;
    }
}
