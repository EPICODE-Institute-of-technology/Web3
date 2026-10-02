# Web3 Course — Module 4 (DeFi II) · Exercises & data labs

Code and data companions for **Module 4 · DeFi II**.

**Topic 1 — advanced tokenomics (analysis).** These labs *measure* the supply-side quantities of the
token-economy models — supply inflation, burn coverage, and velocity — on **real, current crypto
protocols**, using only free, no-key data sources. Grounded in Domenicale, Avanzo & Schifanella (2026),
*Six Failure Modes*, and Campajola et al. (2022) for velocity.

**Topic 2 — methods for token-economy design & validation (design).** One merged lab (Lectures
4.5–4.6) turns the framework around: instead of measuring live tokens, it **designs and validates** a
community token economy *before* deployment. The design's token flows are simulated forward in
**cadCAD** (baseline, parameter sweeps, Monte Carlo demand shocks), and the threshold conditions are
checked over declared parameter ranges with the **Z3** SMT solver, giving **sound / fragile / broken**
verdicts that reproduce the paper's cross-case risk profiles. Design method: Kivilo et al. (2026), the
Token Economy Design Method.

> The Six Failure Modes framework is written for community-scale token economies. Topic 1 reuses the
> part that transfers to large, market-priced DeFi tokens (the model-free supply-side measures); Topic 2
> applies the whole framework in its native design-stage, community-scale setting.

## Structure
```
Module-4-DeFi-II-lab/
├── README.md
├── materials/        the primary papers (read these first)
│   ├── Domenicale_Avanzo_Schifanella_2026_Six_Failure_Modes.pdf
│   └── Campajola_DErrico_Tessone_2022_MicroVelocity_arXiv_2201.13416.pdf
├── notebooks/
│   ├── 02_supply_inflation_burn.ipynb             Lecture 4.2 — supply inflation (oversupply) + burn/emission
│   ├── 03_velocity_turnover.ipynb                 Lecture 4.3 — velocity: turnover & NVT
│   ├── 04_token_economy_lab.ipynb                 Lectures 4.5–4.6 — cadCAD model, simulation, Z3 validation, sweeps, Monte Carlo
│   ├── 06_rwa_realt_replication.ipynb             Lecture 4.8 — replication of Swinkels (2023) on RealT real-estate tokens
│   ├── 06_rwa_realt_replication_solutions.ipynb   worked solutions to the 06 exercises
│   ├── data/                                      cached API responses (offline, reproducible re-runs)
│   └── figs/                                      figures exported by the notebooks (used in the lecture slides)
└── dex-lab/          Lectures 4.10–4.15 — from-scratch Uniswap-v2-style AMM (Foundry); see dex-lab/README.md
```

## The notebooks
| Notebook | Lecture | Topic | What it does |
|---|---|---|---|
| `02_supply_inflation_burn` | 4.2 | 1 · analysis | annual inflation π, dilution overhang, burn/net-issuance ρ on ETH/BNB/CRV |
| `03_velocity_turnover`     | 4.3 | 1 · analysis | turnover (vol/mcap), NVT, on-chain activity on ETH/BNB/CRV |
| `04_token_economy_lab` | 4.5–4.6 | 2 · design | one merged lab: cadCAD stock-flow model of three community cases; validation of the six conditions (dynamic / partial / static, scope stated); parameter sweeps; Monte Carlo demand shocks; Z3 verdicts over ranges; pre-deployment risk profile |
| `06_rwa_realt_replication` | 4.8 | 3 · RWA | replication of Swinkels (2023), *Financial Innovation* 9, Article 45, on current RealT tokenized-real-estate data |

**Verified figures — Topic 1 (2026-08-13, from the executed notebooks):**
- Annual inflation — **ETH ≈ +0.30 %/yr** (ultrasound.money; ~0 by CoinGecko), **BNB −4.4 %/yr** (auto-burn), **CRV +11.5 %/yr**.
- Burn coverage — **ρ_ETH ≈ 0.59** (burn 2.01M ÷ issuance 3.44M ETH since the Merge; ρ<1, net +0.30%/yr), ρ_CRV = 0.
- Dilution overhang — **BNB 33.4 %**, **CRV 48.9 %**, ETH uncapped.
- Turnover (velocity proxy) — **BNB 0.006**, **ETH 0.030**, **CRV 0.152**; NVT 158 / 33 / 6.6.

**Verified results — Topic 2 (2026-09-03, from the executed merged notebook `04_token_economy_lab`):**
- Baseline (104 weeks): NLAB4CIT 79,000 tokens (×263 its M* = 300), CORPUS 7,240 (×12.7), FoodReborn flat at 1,000 (×3.0, credited coupon burn).
- Design checks reproduce the paper's Table 3: E/M* = 2.5 (NLAB4CIT), ≈0.10 (CORPUS).
- Verdicts: NLAB4CIT broken on FM1/FM3; CORPUS sound on FM1, broken on FM3 (token layer), and on FM5 failing at the point values (40 < 121) while fragile over the declared range; FoodReborn fragile on FM1, sound on FM3, at the FM4 boundary; Γ ≥ 0.8 everywhere (FM6 fails).
- Stress tests: NLAB4CIT balance needs burn_frac = E/Q = 3.75 (implausible) or E ↓ to Q = 200; Monte Carlo (σ_Q = 0.25, N = 50): mean final ratio 3.69, 5–95% [0.46, 7.89], 24/50 runs dip below half the starting supply.
- Requires `pip install cadCAD z3-solver` (cadCAD 0.5.3, z3-solver 4.x); deterministic runs re-execute identically; the stochastic experiment is seeded per (run, week).

## Data sources (all free, no API key)
- **CoinGecko** — `/coins/{id}` (supply, market cap, volume, price) and `/coins/{id}/market_chart` (supply history → inflation). *(Topic 1)*
- **ultrasound.money** — `/api/v2/fees/supply-over-time` (ETH net issuance / EIP-1559 burn). *(Topic 1)*
- **DeFiLlama datasets** — `defillama-datasets.llama.fi/emissions/{protocol}` (emission/unlock schedules). *(Topic 1)*
- **Coin Metrics community API** — market cap, supply, tx count, active addresses (transfer-value NVT is a paid metric). *(Topic 1)*
- Topic 2 uses **no external data**: the design labs are parametric/synthetic, with parameters calibrated to the three community cases in the paper's Tables 2–3.

## Running
```bash
pip install requests pandas numpy matplotlib jupyter nbconvert   # Topic 1 (02, 03)
pip install cadCAD z3-solver                                     # Topic 2 (04)
jupyter notebook            # open a notebook and Run All
```
The Topic-1 notebooks cache every API response under `notebooks/data/`, so they re-run offline and never
hit rate limits (delete a cache file to force a fresh pull). The Topic-2 notebooks are deterministic and
need no network at all.

## Sources / references
- Domenicale, I., Avanzo, S. & Schifanella, C. (2026). *Six Failure Modes…* (in `materials/`).
- Campajola, C., D'Errico, M. & Tessone, C. J. (2022). *MicroVelocity…* arXiv:2201.13416 (in `materials/`).
- Kivilo, S., Norta, A., Hattingh, M., Avanzo, S. & Pennella, L. (2026). *Designing a Token Economy: Incentives, Governance, and Tokenomics.* arXiv:2602.09608.
- Voshmgir, S. & Zargham, M. (2019). *Foundations of Cryptoeconomic Systems.* Research Institute for Cryptoeconomics, Vienna.
- Fisher, I. (1911). *The Purchasing Power of Money*; Sidrauski, M. (1967). *Rational choice and patterns of growth*; Ostrom, E. (1990). *Governing the Commons*; Gesell, S. (1958). *The Natural Economic Order*; Lietaer, B. & Dunne, J. (2013). *Rethinking Money*.

*(The governance-concentration notebook is course material for **Module 6 — Decentralized Governance**, not this module.)*
