# Sample audit report — TimedFairRockPaperScissors

Reference report for the Lecture 2.15 exercise. It shows the expected *shape* of the
write-up: which tool was run, what it reported, and — for each finding — a verdict with a
one-line reason. Your own report will differ; what matters is that every finding is triaged,
not just listed.

## Tools run

| Tool | Command | Technique |
|---|---|---|
| Slither | `slither contracts/TimedFairRPS.sol` | static analysis |
| SMTChecker | `solc --model-checker-engine chc --model-checker-targets assert,overflow contracts/TimedFairRPS.sol` | model checking |
| Echidna | `echidna audit/RPSProperties.sol --contract RPSProperties` | property fuzzing |

## Findings

| # | Tool | Finding | Severity | Verdict | Reason |
|---|---|---|---|---|---|
| 1 | Slither | `withdraw()` performs an external call (`msg.sender.call`) | Info (reentrancy-benign) | False positive | The balance is zeroed **before** the call (checks-effects-interactions); a re-entrant call reads zero and reverts. |
| 2 | Slither | `block.timestamp` used for comparison in the timeout functions | Low | Accepted risk | Deadlines are hours long; a validator's few-second influence on the timestamp cannot change the outcome. |
| 3 | Slither | low-level `call` return value | — | False positive | The returned `ok` **is** checked; the function reverts on failure. |
| 4 | SMTChecker | assertion `address(this).balance >= 0` | — | Proven | Holds for all inputs. |
| 5 | Echidna | `echidna_balance_within_stakes` | — | Passed (no counterexample) | After many random plays, the balance never exceeded `totalStaked`. |
| 6 | Echidna | `echidna_no_game_past_counter` | — | Passed | No id beyond `nextGameId` ever left the Empty phase. |

## What each tool did — and did not — catch

- **Slither** found the reentrancy *pattern* instantly but could not tell that the ordering already
  neutralises it; that judgement was human. It does not reason about game logic.
- **SMTChecker** proved the arithmetic and the assertions, but only the properties written as
  `assert`s — it says nothing about properties you did not state.
- **Echidna** searched behaviours no unit test enumerated, but a *passing* run is not a proof: it
  explored a bounded number of sequences, so absence of a counterexample is evidence, not certainty.

## Conclusion

No tool certified the contract. The real risks (a griefing player who lets the commit window
elapse; reliance on `block.timestamp`) are documented and accepted, not silently ignored. A
production review would add a second reader and, for a contract holding significant value, a formal
specification (Certora or Halmos).
