// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  Counters
/// @notice Counter 4 of 7
///         A multi-user counter registry. Each user creates AT MOST one
///         counter; only the creator can mutate it; every mutation costs
///         at least 2 * units wei. The contract owner can withdraw the
///         accumulated wei or delete a counter (which refunds the
///         creator the full amount they have deposited so far).
///
/// @dev    Demonstrates:
///           * struct + dynamic array + mapping (1-based index convention)
///           * modifiers and custom errors
///           * payable receive of wei plus refund via call{value:}()
///           * the "deposited" field per counter for accurate refund accounting
contract Counters {

    // ----------------------------------------------------
    // STORAGE
    // ----------------------------------------------------
    struct Counter {
        address creator;
        uint256 value;
        uint256 deposited;     // running total of wei the creator has paid
        bool    exists;
    }

    address   public immutable owner;
    Counter[] public counters;                          // 0-based internal storage
    mapping(address => uint256) public counterOf;       // 1-based id; 0 = no counter

    // ----------------------------------------------------
    // EVENTS
    // ----------------------------------------------------
    event CounterCreated (uint256 indexed id, address indexed creator);
    event Increased      (uint256 indexed id, uint256 units, uint256 paid, uint256 newValue);
    event Decreased      (uint256 indexed id, uint256 units, uint256 paid, uint256 newValue);
    event ResetDone      (uint256 indexed id, uint256 paid);
    event Withdrawn      (address indexed to, uint256 amount);
    event CounterDeleted (uint256 indexed id, address indexed creator, uint256 refunded);

    // ----------------------------------------------------
    // ERRORS
    // ----------------------------------------------------
    error NotOwner(address caller);
    error NotCreator(address caller, address actualCreator);
    error AlreadyHasCounter(uint256 existingId);
    error NoSuchCounter(uint256 id);
    error InsufficientPayment(uint256 required, uint256 sent);
    error InsufficientBalanceForRefund(uint256 required, uint256 available);
    error TransferFailed();

    // ----------------------------------------------------
    // MODIFIERS
    // ----------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ----------------------------------------------------
    // PUBLIC API
    // ----------------------------------------------------

    /// @notice Create a fresh counter for the caller. Reverts if the caller
    ///         already owns one. Returns the 1-based id.
    function createCounter() external returns (uint256 id) {
        uint256 existing = counterOf[msg.sender];
        if (existing != 0) revert AlreadyHasCounter(existing);

        counters.push(Counter({
            creator:   msg.sender,
            value:     0,
            deposited: 0,
            exists:    true
        }));
        id = counters.length;          // 1-based
        counterOf[msg.sender] = id;
        emit CounterCreated(id, msg.sender);
    }

    /// @notice Increase the caller's counter by `units`. Requires
    ///         msg.value >= 2 * units.
    function increase(uint256 units) external payable {
        Counter storage c = _accessOwnCounter();
        uint256 required = 2 * units;
        if (msg.value < required) revert InsufficientPayment(required, msg.value);

        c.value     += units;
        c.deposited += msg.value;
        emit Increased(counterOf[msg.sender], units, msg.value, c.value);
    }

    /// @notice Decrease the caller's counter by `units`. Requires
    ///         msg.value >= 2 * units. Reverts on underflow.
    function decrease(uint256 units) external payable {
        Counter storage c = _accessOwnCounter();
        uint256 required = 2 * units;
        if (msg.value < required) revert InsufficientPayment(required, msg.value);

        c.value     -= units;          // checked arithmetic, reverts on underflow
        c.deposited += msg.value;
        emit Decreased(counterOf[msg.sender], units, msg.value, c.value);
    }

    /// @notice Reset the caller's counter to 0. Treated as units = 1, so
    ///         it requires msg.value >= 2 wei.
    function reset() external payable {
        Counter storage c = _accessOwnCounter();
        if (msg.value < 2) revert InsufficientPayment(2, msg.value);

        c.value      = 0;
        c.deposited += msg.value;
        emit ResetDone(counterOf[msg.sender], msg.value);
    }

    /// @notice Read the current value of a counter by its 1-based id.
    function getValue(uint256 id) external view returns (uint256) {
        Counter storage c = _readCounter(id);
        return c.value;
    }

    // ----------------------------------------------------
    // OWNER-ONLY API
    // ----------------------------------------------------

    /// @notice Withdraw the entire contract balance to the owner.
    ///         WARNING: leaving the contract without enough balance
    ///         will make later deleteCounter() calls revert.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(owner, amount);
    }

    /// @notice Delete a counter and refund the creator the full amount
    ///         they have deposited so far. Reverts if the contract does
    ///         not currently hold enough wei to perform the refund.
    function deleteCounter(uint256 id) external onlyOwner {
        Counter storage c = _readCounter(id);
        uint256 refund = c.deposited;
        if (address(this).balance < refund) {
            revert InsufficientBalanceForRefund(refund, address(this).balance);
        }

        address creator = c.creator;
        // Effects first (Checks-Effects-Interactions)
        c.exists       = false;
        c.deposited    = 0;
        counterOf[creator] = 0;

        // Interaction
        if (refund > 0) {
            (bool ok, ) = payable(creator).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }
        emit CounterDeleted(id, creator, refund);
    }

    // ----------------------------------------------------
    // VIEWS
    // ----------------------------------------------------

    function counterCount() external view returns (uint256) {
        return counters.length;
    }

    // ----------------------------------------------------
    // INTERNAL HELPERS
    // ----------------------------------------------------

    /// @dev Returns the storage pointer to the caller's own counter.
    ///      Reverts if the caller has no counter.
    function _accessOwnCounter() internal view returns (Counter storage c) {
        uint256 id = counterOf[msg.sender];
        if (id == 0) revert NoSuchCounter(0);
        c = counters[id - 1];
        // sanity: in this contract ownership and existence are consistent
        if (!c.exists || c.creator != msg.sender) {
            revert NotCreator(msg.sender, c.creator);
        }
    }

    /// @dev Validates a 1-based id and returns a storage pointer.
    function _readCounter(uint256 id) internal view returns (Counter storage c) {
        if (id == 0 || id > counters.length) revert NoSuchCounter(id);
        c = counters[id - 1];
        if (!c.exists) revert NoSuchCounter(id);
    }
}
