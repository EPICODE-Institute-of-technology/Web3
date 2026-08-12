// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  CountersStructs
/// @notice Counter 5 of 7
///         Extends 04-Counters.sol with two pieces of metadata captured at
///         creation time:
///           * a human-readable `name` chosen by the creator;
///           * the `block.number` and `block.timestamp` of the creation.
///         Adds a public `getCounter(id)` view that returns the full record
///         (in memory) so anyone can query a counter without having to
///         decode the auto-generated tuple field by field.
///
/// @dev    Same pricing rule as 04 (>= 2 * units wei per state mutation,
///         reset = 2 wei). Same Checks-Effects-Interactions refund flow.
contract CountersStructs {
    // ----------------------------------------------------
    // STORAGE
    // ----------------------------------------------------
    struct Counter {
        address creator;
        string name; // chosen at creation, immutable afterwards
        uint256 value;
        uint256 deposited; // running total of wei the creator paid
        uint256 createdAtBlock; // block.number at creation
        uint256 createdAtTimestamp; // block.timestamp at creation
        bool exists;
    }

    address public immutable owner;
    Counter[] public counters; // 0-based internal storage
    mapping(address => uint256) public counterOf; // 1-based id; 0 = no counter

    // ----------------------------------------------------
    // EVENTS
    // ----------------------------------------------------
    event CounterCreated(
        uint256 indexed id,
        address indexed creator,
        string name,
        uint256 atBlock,
        uint256 atTimestamp
    );
    event Increased(
        uint256 indexed id,
        uint256 units,
        uint256 paid,
        uint256 newValue
    );
    event Decreased(
        uint256 indexed id,
        uint256 units,
        uint256 paid,
        uint256 newValue
    );
    event ResetDone(uint256 indexed id, uint256 paid);
    event Withdrawn(address indexed to, uint256 amount);
    event CounterDeleted(
        uint256 indexed id,
        address indexed creator,
        uint256 refunded
    );

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
    error EmptyName();

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

    /// @notice Create a fresh counter for the caller, named `name_`.
    ///         Reverts on empty name or if the caller already owns one.
    ///         The block number and timestamp of creation are stored.
    function createCounter(
        string calldata name_
    ) external returns (uint256 id) {
        if (bytes(name_).length == 0) revert EmptyName();
        uint256 existing = counterOf[msg.sender];
        if (existing != 0) revert AlreadyHasCounter(existing);

        counters.push(
            Counter({
                creator: msg.sender,
                name: name_,
                value: 0,
                deposited: 0,
                createdAtBlock: block.number,
                createdAtTimestamp: block.timestamp,
                exists: true
            })
        );
        id = counters.length; // 1-based
        counterOf[msg.sender] = id;

        emit CounterCreated(
            id,
            msg.sender,
            name_,
            block.number,
            block.timestamp
        );
    }

    function increase(uint256 units) external payable {
        Counter storage c = _accessOwnCounter();
        uint256 required = 2 * units;
        if (msg.value < required)
            revert InsufficientPayment(required, msg.value);

        c.value += units;
        c.deposited += msg.value;
        emit Increased(counterOf[msg.sender], units, msg.value, c.value);
    }

    function decrease(uint256 units) external payable {
        Counter storage c = _accessOwnCounter();
        uint256 required = 2 * units;
        if (msg.value < required)
            revert InsufficientPayment(required, msg.value);

        c.value -= units; // checked arithmetic; reverts on underflow
        c.deposited += msg.value;
        emit Decreased(counterOf[msg.sender], units, msg.value, c.value);
    }

    function reset() external payable {
        Counter storage c = _accessOwnCounter();
        if (msg.value < 2) revert InsufficientPayment(2, msg.value);

        c.value = 0;
        c.deposited += msg.value;
        emit ResetDone(counterOf[msg.sender], msg.value);
    }

    // ----------------------------------------------------
    // PUBLIC QUERIES — anyone can read
    // ----------------------------------------------------

    /// @notice Return the full record of a counter (memory copy).
    ///         Reverts if the id does not refer to an existing counter.
    function getCounter(uint256 id) external view returns (Counter memory) {
        if (id == 0 || id > counters.length) revert NoSuchCounter(id);
        Counter storage c = counters[id - 1];
        if (!c.exists) revert NoSuchCounter(id);
        return c; // storage -> memory copy
    }

    /// @notice Convenience: just the value (cheaper than reading the whole struct).
    function getValue(uint256 id) external view returns (uint256) {
        if (id == 0 || id > counters.length) revert NoSuchCounter(id);
        Counter storage c = counters[id - 1];
        if (!c.exists) revert NoSuchCounter(id);
        return c.value;
    }

    function counterCount() external view returns (uint256) {
        return counters.length;
    }

    // ----------------------------------------------------
    // OWNER-ONLY API
    // ----------------------------------------------------

    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(owner, amount);
    }

    /// @notice Delete a counter and refund the creator the full amount they
    ///         have deposited so far. Reverts if the contract balance is
    ///         insufficient (e.g. after a withdraw()).
    function deleteCounter(uint256 id) external onlyOwner {
        if (id == 0 || id > counters.length) revert NoSuchCounter(id);
        Counter storage c = counters[id - 1];
        if (!c.exists) revert NoSuchCounter(id);

        uint256 refund = c.deposited;
        if (address(this).balance < refund) {
            revert InsufficientBalanceForRefund(refund, address(this).balance);
        }

        address creator = c.creator;
        // Effects first (Checks-Effects-Interactions)
        c.exists = false;
        c.deposited = 0;
        counterOf[creator] = 0;

        // Interaction last
        if (refund > 0) {
            (bool ok, ) = payable(creator).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }
        emit CounterDeleted(id, creator, refund);
    }

    // ----------------------------------------------------
    // INTERNAL HELPERS
    // ----------------------------------------------------

    /// @dev Returns a storage pointer to the caller's own counter; reverts
    ///      if the caller does not own one.
    function _accessOwnCounter() internal view returns (Counter storage c) {
        uint256 id = counterOf[msg.sender];
        if (id == 0) revert NoSuchCounter(0);
        c = counters[id - 1];
        if (!c.exists || c.creator != msg.sender) {
            revert NotCreator(msg.sender, c.creator);
        }
    }
}
