// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title  CounterStructsPausable
/// @notice Counter 6 of 7
///         Extends 05-CountersStructs.sol with the classic Pausable pattern:
///         the contract owner can flip a global `paused` flag that gates
///         every user-facing state-changing function. Read-only views and
///         administrative operations (withdraw, deleteCounter) remain
///         available even while paused, so the owner can keep operating
///         the contract during an incident.
///
/// @dev    The Pausable behaviour is implemented locally rather than
///         imported from OpenZeppelin so the file stays self-contained
///         for the lab. Semantics match the OpenZeppelin Pausable.sol
///         standard (paused() view, Paused(address) / Unpaused(address)
///         events, whenNotPaused / whenPaused modifiers).
contract CounterStructsPausable {
    // ----------------------------------------------------
    // STORAGE
    // ----------------------------------------------------
    struct Counter {
        address creator;
        string name;
        uint256 value;
        uint256 deposited;
        uint256 createdAtBlock;
        uint256 createdAtTimestamp;
        bool exists;
    }

    address public immutable owner;
    Counter[] public counters;
    mapping(address => uint256) public counterOf; // 1-based id; 0 = no counter

    bool public paused; // <-- NEW (false by default)

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
    event Paused(address indexed account); // <-- NEW
    event Unpaused(address indexed account); // <-- NEW

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
    error EnforcedPause(); // <-- NEW
    error ExpectedPause(); // <-- NEW

    // ----------------------------------------------------
    // MODIFIERS
    // ----------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    /// @dev Reverts when the contract is paused.
    modifier whenNotPaused() {
        if (paused) revert EnforcedPause();
        _;
    }

    /// @dev Reverts when the contract is NOT paused.
    modifier whenPaused() {
        if (!paused) revert ExpectedPause();
        _;
    }

    constructor() {
        owner = msg.sender;
        paused = false;
    }

    // ----------------------------------------------------
    // PAUSE CONTROL — owner only
    // ----------------------------------------------------

    /// @notice Pause every state-changing user-facing function.
    function pause() external onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Resume normal operation.
    function unpause() external onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ----------------------------------------------------
    // PUBLIC API — gated by `whenNotPaused`
    // ----------------------------------------------------

    function createCounter(
        string calldata name_
    ) external whenNotPaused returns (uint256 id) {
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
        id = counters.length;
        counterOf[msg.sender] = id;

        emit CounterCreated(
            id,
            msg.sender,
            name_,
            block.number,
            block.timestamp
        );
    }

    function increase(uint256 units) external payable whenNotPaused {
        Counter storage c = _accessOwnCounter();
        uint256 required = 2 * units;
        if (msg.value < required)
            revert InsufficientPayment(required, msg.value);

        c.value += units;
        c.deposited += msg.value;
        emit Increased(counterOf[msg.sender], units, msg.value, c.value);
    }

    function decrease(uint256 units) external payable whenNotPaused {
        Counter storage c = _accessOwnCounter();
        uint256 required = 2 * units;
        if (msg.value < required)
            revert InsufficientPayment(required, msg.value);

        c.value -= units;
        c.deposited += msg.value;
        emit Decreased(counterOf[msg.sender], units, msg.value, c.value);
    }

    function reset() external payable whenNotPaused {
        Counter storage c = _accessOwnCounter();
        if (msg.value < 2) revert InsufficientPayment(2, msg.value);

        c.value = 0;
        c.deposited += msg.value;
        emit ResetDone(counterOf[msg.sender], msg.value);
    }

    // ----------------------------------------------------
    // PUBLIC QUERIES — always available, even while paused
    // ----------------------------------------------------

    function getCounter(uint256 id) external view returns (Counter memory) {
        if (id == 0 || id > counters.length) revert NoSuchCounter(id);
        Counter storage c = counters[id - 1];
        if (!c.exists) revert NoSuchCounter(id);
        return c;
    }

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
    // OWNER-ONLY API — kept available while paused so the
    // owner can still recover funds and clean up state.
    // ----------------------------------------------------

    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner).call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(owner, amount);
    }

    function deleteCounter(uint256 id) external onlyOwner {
        if (id == 0 || id > counters.length) revert NoSuchCounter(id);
        Counter storage c = counters[id - 1];
        if (!c.exists) revert NoSuchCounter(id);

        uint256 refund = c.deposited;
        if (address(this).balance < refund) {
            revert InsufficientBalanceForRefund(refund, address(this).balance);
        }

        address creator = c.creator;
        c.exists = false;
        c.deposited = 0;
        counterOf[creator] = 0;

        if (refund > 0) {
            (bool ok, ) = payable(creator).call{value: refund}("");
            if (!ok) revert TransferFailed();
        }
        emit CounterDeleted(id, creator, refund);
    }

    // ----------------------------------------------------
    // INTERNAL HELPERS
    // ----------------------------------------------------

    function _accessOwnCounter() internal view returns (Counter storage c) {
        uint256 id = counterOf[msg.sender];
        if (id == 0) revert NoSuchCounter(0);
        c = counters[id - 1];
        if (!c.exists || c.creator != msg.sender) {
            revert NotCreator(msg.sender, c.creator);
        }
    }
}
