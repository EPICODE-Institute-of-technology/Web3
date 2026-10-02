# Web3 — course code companion

Code and data labs for the EPICODE **Web3** course. This repository is the hands-on companion to the
lectures: it contains only the modules that have code. The remaining modules are lecture-only and ship
no code.

| Module | Folder | Contents |
|---|---|---|
| **Module 2 · Building Decentralized Applications** | [`Module-2-lab/`](Module-2-lab/) | Reference implementations for lectures 2.1–2.15: Solidity (Foundry), the ethers.js mini-DApp, the commit-reveal game, and smart-contract security & auditing. |
| **Module 4 · Decentralized Finance II** | [`Module-4-DeFi-II-lab/`](Module-4-DeFi-II-lab/) | Jupyter data labs (tokenomics and RWA, lectures 4.2–4.8) and a from-scratch Uniswap-v2-style AMM in Foundry ([`dex-lab/`](Module-4-DeFi-II-lab/dex-lab/), lectures 4.10–4.15). |

Modules **1** (Foundations), **3** (Decentralized Finance), **5** (Real-World Applications) and
**6** (Decentralized Governance) are lecture-only and contain no code.

## Setup

**Python data labs** (Module 4 notebooks):
```bash
pip install requests pandas numpy matplotlib jupyter nbconvert   # notebooks 02, 03, 06
pip install cadCAD z3-solver                                     # notebook 04 (design & validation)
```
Each notebook caches its data under `notebooks/data/`, so the labs re-run **offline** with no API key
(delete a cache file to force a fresh pull).

**Solidity labs** (Foundry — Module 2's `2.14-reentrancy-and-testing/` and Module 4's `dex-lab/`):
```bash
# install Foundry once: https://book.getfoundry.sh/getting-started/installation
cd Module-4-DeFi-II-lab/dex-lab
forge install foundry-rs/forge-std   # lib/ is gitignored, so fetch the test library once
forge test
```

Each module folder has its own `README.md` with the full lecture-by-lecture breakdown.

> **Teaching code.** The contracts are written to be read and to demonstrate the lecture concepts; they
> omit production concerns and must not be deployed to a live network.
