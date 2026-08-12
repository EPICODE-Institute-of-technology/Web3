#!/usr/bin/env bash
# Lecture 2.15 demo (SLD33) — Slither static analysis.
# Runs the static analyser on the self-contained ReentrancyDemo.sol.
set -e
cd "$(dirname "$0")"

# --- one-time setup (Python 3) ---------------------------------------------
#   pip install slither-analyzer
#   solc 0.8.20 is required; with solc-select:
#     pip install solc-select && solc-select install 0.8.20 && solc-select use 0.8.20
# ---------------------------------------------------------------------------

echo ">> slither ReentrancyDemo.sol"
slither ReentrancyDemo.sol

# Expected output:
#   HIGH  reentrancy-eth  in VulnerableBank.withdraw()
#         external call:  msg.sender.call{value: a}("")
#         state written after:  balances[msg.sender] = 0
#   (no reentrancy-eth on SafeBank — it updates state before the call and locks)
echo
echo ">> The HIGH finding is on VulnerableBank.withdraw(); SafeBank is clean."
