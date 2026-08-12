// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Reference Echidna property for Lecture 2.15.
// Run with:  echidna "reference implementations/RPSProperties.sol" --contract RPSProperties --config echidna.yaml
//
// It inherits the game, so Echidna drives the real functions (createGame, joinGame,
// commit, reveal, withdraw, the timeouts) with random senders, values, and arguments,
// and after every step it checks each echidna_* function still returns true.

import "./TimedFairRPS.sol";

contract RPSProperties is TimedFairRockPaperScissors {
    // The contract must never hold more ether than has ever been staked into it:
    // ether enters only through createGame / joinGame (counted in totalStaked) and
    // leaves only through withdraw. If this is ever false, funds appeared from nowhere.
    function echidna_balance_within_stakes() public view returns (bool) {
        return address(this).balance <= totalStaked;
    }

    // No game id beyond the counter can already be in play.
    function echidna_no_game_past_counter() public view returns (bool) {
        return games[nextGameId].phase == Phase.Empty;
    }
}
