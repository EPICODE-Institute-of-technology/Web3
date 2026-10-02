# DEX Lab — rebuilding a constant-product exchange (Module 4, Topics 4–5)

A from-scratch rebuild of a Uniswap-v2-style automated market maker, written to be read.
Every contract corresponds to a lecture, and every economic property from the DeFi
lectures (Module 3) reappears here as a line of tested code. The lab reuses the testing
methods from the Solidity module (Module 2): example-based tests, **fuzz testing**, and
**invariant testing**, applied to the exchange's economic-security properties.

> Teaching code. It is faithful to Uniswap v2's mechanisms but omits production concerns
> (permit signatures, fee-on-transfer token support, full router paths). Do not deploy it
> to mainnet.

## Layout

```
src/
├── Factory.sol                     4.10 — deploys one Pair per token pair (CREATE2 registry)
├── Pair.sol                        4.10–4.13 — the core AMM: reserves, mint/burn, swap, TWAP
├── PairERC20.sol                   4.11 — the LP share token (the pair IS an ERC-20)
├── Router.sol                      4.11–4.12 — periphery: ratios, slippage, deadline
├── interfaces/                     IERC20, IPairCallee (the flash-swap callback)
├── libraries/                      Math (sqrt), UQ112x112 (fixed point), PairLibrary (pricing)
├── periphery/
│   └── FlashSwapArbitrageur.sol    4.14 — no-capital cross-pool arbitrage via a flash swap
└── oracle/
    ├── IPriceOracle.sol            4.13 — one interface, two implementations
    ├── OracleLibrary.sol           4.13 — cumulative prices brought to the current instant
    ├── SpotPriceOracle.sol         4.13 — VULNERABLE: reads instantaneous reserves
    ├── TWAPOracle.sol              4.13 — SECURE: time-weighted average price
    └── CollateralVault.sol         4.15 — a lending vault that consumes an oracle

test/
├── Pair.t.sol                      unit + fuzz: fee, K-check, mint/burn, protocol fee
├── Router.t.sol                    liquidity ratio, slippage, deadline, price impact
├── FlashSwap.t.sol                 arbitrage profit, and revert when unprofitable
├── OracleTWAP.t.sol                unit: the TWAP accumulator tracks a sustained price; PERIOD guard
├── OracleAttack.t.sol              PENETRATION TEST: spot oracle drained, TWAP resists
├── invariant/                      handler + ghost variables; economic invariants
│   ├── PairHandler.sol
│   └── Pair.invariant.t.sol
├── attacks/OracleAttacker.sol      the one-transaction price-manipulation exploit
└── mocks/MockERC20.sol

script/
└── Deploy.s.sol                    deploys a Factory and Router (local/testnet helper)
```

## The economic-security properties, as tests

| Property | Where | Method |
|---|---|---|
| A swap never decreases `k` (no value extracted beyond the fee) | `Pair.t.sol`, `Pair.invariant.t.sol` | fuzz + invariant |
| The pool's reserves are always backed by real balances | `Pair.invariant.t.sol` | invariant |
| LP supply never rounds to zero (first-depositor lock) | `Pair.invariant.t.sol` | invariant |
| A larger trade gets a strictly worse average price (price impact) | `Router.t.sol` | fuzz |
| Slippage and deadline bounds are enforced | `Router.t.sol` | unit |
| An unprofitable flash swap cannot settle (invariant check) | `FlashSwap.t.sol` | unit |
| A spot-price oracle can be manipulated to drain a lending vault | `OracleAttack.t.sol` | pen test |
| A TWAP oracle resists the identical manipulation | `OracleAttack.t.sol` | pen test |

## Running

```bash
forge install foundry-rs/forge-std   # one-time: fetch the test library (lib/ is gitignored, not in the repo)
forge build
forge test                 # all suites
forge test --match-path "test/invariant/*"     # invariant suite only
forge test --match-path "test/OracleAttack.t.sol" -vv   # the oracle pen test, with numbers
forge coverage --no-match-coverage test/       # source coverage
```

Requires [Foundry](https://getfoundry.sh) (same toolchain as Module 2). Pinned to Solidity
`0.8.20`. Fuzz runs and invariant depth are set in `foundry.toml`.

## The oracle penetration test, in one glance

`OracleAttack.t.sol` runs the same attack against two vaults that differ only in their
oracle. Printed output (`-vv`):

```
spot price x1000 before/after: 1000 15963     # a single swap moves the spot price ~16x
twap price x1000 before/after: 1000  1000     # the time-weighted average does not move
spot: borrowed 7981   true collateral 1000    # the vault lends ~8x the true value -> bad debt
twap: borrowed  500   true collateral 1000    # the loan is capped at the honest LTV
```

The manipulation is funded from the attacker's own balance here; a flash loan
(`FlashSwapArbitrageur`, Lecture 4.14; and Module 3.13's flash attacks) supplies it with
no capital, which is what makes the attack cheap in practice.

## Sources

- Adams, H., Zinsmeister, N. & Robinson, D. (2020). *Uniswap v2 Core.* Whitepaper.
- Zhang, Y., Chen, X. & Park, D. (2018). *Formal Specification of Constant Product (x·y=k)
  Market Maker Model and Implementation.* Runtime Verification.
- Xu, J., Paruch, K., Cousaert, S. & Feng, Y. (2023). *SoK: Decentralized Exchanges (DEX)
  with Automated Market Maker Protocols.* ACM Computing Surveys 55(11).
- Ottina, M., Steffensen, P. J. & Kristensen, J. (2023). *Automated Market Makers.* (in the bibliography)
