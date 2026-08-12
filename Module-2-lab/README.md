# Web3 Course — Module 2 Exercises

Exercise material for **Module 2, "Building Decentralized Applications"** (lectures 2.1–2.15).
Every contract, page, and script here appears on a lecture slide or is the reference solution to a
slide's exercise. All Solidity targets **`^0.8.20`**; OpenZeppelin imports are **v5**; the DApp pages
use **ethers.js v6**.

## How this repository is organized

One folder per lecture, named `2.<n>-<topic>`. Inside each lecture folder:

```
2.<n>-<topic>/
├── reference implementations/   ← the worked solution(s) to that lecture's exercise
├── *_start.sol                  ← starter scaffold to complete (only where the lecture provides one)
└── demos/                       ← code shown live in the lecture (not a deliverable)
```

- **`reference implementations/`** holds the *solution*. Do the exercise from the slides first, then
  compare against these.
- **`*_start.sol`** files are the scaffolds with `TODO`s to fill in (present for the 2.13–2.15 game).
- **`demos/`** holds the code the instructor runs on screen — attack demos, live scripts — kept
  separate from the solutions.

The exercise *prompts* live on the lecture slides; this repository is the **code companion** to them.

## Lecture map

| Lecture | Folder | Exercise | Reference solution demonstrates |
|---|---|---|---|
| 2.1 | `2.1-first-deployment` | Compile & deploy `SimpleCounter` on the Remix VM | A minimal contract: state, `view`, checked arithmetic |
| 2.2 | `2.2-transactions-and-gas` | Deploy `SimpleCounter` to Sepolia; record gas, hash, block | A real testnet transaction and its cost |
| 2.3 | `2.3-verify-and-inspect` | Verify `SimpleCounter` on Etherscan; read the tx fields | Source verification and transaction anatomy |
| 2.4 | `2.4-solidity-basics` | Build `SimpleCounter → …Owner → …Value` (Ex. 1–3) | `immutable`, custom errors, `onlyOwner`, `payable`/events, CEI `withdraw`; `Vault` = OZ `Ownable` |
| 2.5 | `2.5-structs-and-mappings` | `Counters`, then `CountersStructs` (Ex. 4–5) | `struct` + array + `mapping`, 1-based ids, refunds, block metadata |
| 2.6 | `2.6-pausable-and-composition` | `CounterStructsPausable`, `CounterMultiManager` (Ex. 6–7) | Owner-controlled freeze; contract-to-contract calls forwarding `msg.value` (`07` imports `06`) |
| 2.7 | `2.7-erc20-basics` | An ERC-20 with mint, cap, burn, pause | OZ `ERC20` + `ERC20Burnable`/`ERC20Pausable`/`Ownable` |
| 2.8 | `2.8-erc20-permit-and-votes` | Add `ERC20Permit` and `ERC20Votes` | EIP-2612 gasless approval (`permit-demo.html`) and checkpointed voting |
| 2.9 | `2.9-erc721-and-erc1155` | An NFT collection and a multi-token | `ERC721` (+ `URIStorage`) and `ERC1155` |
| 2.10 | `2.10-provider-and-reads` | Pages 01–05: read-only provider → send a tx | `JsonRpcProvider`, `BrowserProvider`, reading a contract with an ABI |
| 2.11 | `2.11-deploy-and-call-token` | Deploy `CourseToken`, call it from a page | An OZ ERC-20 driven read+write from ethers |
| 2.12 | `2.12-events-and-mini-dapp` | Subscribe to events; assemble the mini-DApp | Event subscriptions and a full client |
| 2.13 | `2.13-commit-reveal` | Build the commit-reveal `FairRPS` | Fixing `SillyRPS`'s front-running with `keccak256(move, salt, sender)` |
| 2.14 | `2.14-reentrancy-and-testing` | Make payout safe; write Foundry tests | CEI + pull payments (vs the `ReentrancyBank`/`Attacker` demo); a fuzz test |
| 2.15 | `2.15-static-analysis-and-audit` | Run Slither/SMTChecker/Echidna; triage | Property tests (`RPSProperties`) and an audit write-up (`report.md`) |

## Compiling and running

- **Solidity contracts** compile with `solc 0.8.20` or in Remix; OpenZeppelin imports resolve through
  Remix, a solc remapping, or `npm i @openzeppelin/contracts`.
- **DApp pages** (2.10–2.12) load ethers from a CDN — open the file directly or serve the folder with
  any static server; no build step. For `09-minidapp.html`, deploy `CourseToken` yourself and paste its
  address into the `TOKEN` constant.
- **The Rock-Paper-Scissors game** (2.13–2.15) is one cumulative project. The contracts compile
  standalone; running the **Foundry test** (`RockPaperScissors.t.sol`) and **Echidna properties**
  (`RPSProperties.sol`) needs a Foundry project (`forge init`, with `forge-std`). Both reference the
  game via a folder-local `import "./TimedFairRPS.sol";`.
