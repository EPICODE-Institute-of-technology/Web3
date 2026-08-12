// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Reference test suite for Lecture 2.14 (Foundry).
// Run with:  forge test -vv     (needs forge-std; see the folder README for setup)
//
// It covers a full happy path, a rejected out-of-phase call, and a fuzz test whose
// property holds for every generated salt.

import "forge-std/Test.sol";
import "./TimedFairRPS.sol";

contract RockPaperScissorsTest is Test {
    TimedFairRockPaperScissors game;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");
    uint256 constant STAKE = 0.01 ether;

    // Move enum: None=0, Rock=1, Paper=2, Scissors=3
    TimedFairRockPaperScissors.Move constant ROCK     = TimedFairRockPaperScissors.Move.Rock;
    TimedFairRockPaperScissors.Move constant SCISSORS = TimedFairRockPaperScissors.Move.Scissors;

    function setUp() public {
        game = new TimedFairRockPaperScissors();
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    // A full path: create -> join -> commit -> reveal -> settle -> withdraw.
    function test_FullGame_RockBeatsScissors() public {
        bytes32 saltA = keccak256("alice-salt");
        bytes32 saltB = keccak256("bob-salt");

        vm.prank(alice);
        uint256 id = game.createGame{value: STAKE}();
        vm.prank(bob);
        game.joinGame{value: STAKE}(id);

        // precompute the commitments BEFORE pranking (makeCommitment is itself a
        // call and would otherwise consume the vm.prank meant for commit)
        bytes32 cA = game.makeCommitment(ROCK, saltA, alice);
        bytes32 cB = game.makeCommitment(SCISSORS, saltB, bob);
        vm.prank(alice);
        game.commit(id, cA);
        vm.prank(bob);
        game.commit(id, cB);

        vm.prank(alice);
        game.reveal(id, ROCK, saltA);
        vm.prank(bob);
        game.reveal(id, SCISSORS, saltB);   // Rock beats Scissors -> Alice wins

        assertEq(game.pendingWithdrawals(alice), 2 * STAKE);
        assertEq(game.pendingWithdrawals(bob), 0);

        uint256 before = alice.balance;
        vm.prank(alice);
        game.withdraw();
        assertEq(alice.balance, before + 2 * STAKE);
    }

    // An out-of-phase call must revert: you cannot commit before an opponent joins.
    function test_RevertWhen_CommitBeforeJoin() public {
        vm.prank(alice);
        uint256 id = game.createGame{value: STAKE}();

        bytes32 c = game.makeCommitment(ROCK, keccak256("s"), alice);
        vm.prank(alice);
        vm.expectRevert();                  // phase is AwaitingP2, not Committing
        game.commit(id, c);
    }

    // Fuzz the salts: for a fixed matchup the winner always takes the pot,
    // whatever random salts the players chose.
    function testFuzz_WinnerTakesPot(bytes32 saltA, bytes32 saltB) public {
        vm.assume(saltA != saltB);

        vm.prank(alice);
        uint256 id = game.createGame{value: STAKE}();
        vm.prank(bob);
        game.joinGame{value: STAKE}(id);

        // precompute the commitments BEFORE pranking (makeCommitment is itself a
        // call and would otherwise consume the vm.prank meant for commit)
        bytes32 cA = game.makeCommitment(ROCK, saltA, alice);
        bytes32 cB = game.makeCommitment(SCISSORS, saltB, bob);
        vm.prank(alice);
        game.commit(id, cA);
        vm.prank(bob);
        game.commit(id, cB);

        vm.prank(alice);
        game.reveal(id, ROCK, saltA);
        vm.prank(bob);
        game.reveal(id, SCISSORS, saltB);

        assertEq(game.pendingWithdrawals(alice), 2 * STAKE);
    }
}
