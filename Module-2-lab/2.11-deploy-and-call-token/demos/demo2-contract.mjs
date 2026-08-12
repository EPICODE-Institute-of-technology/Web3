// demo2-contract.mjs — Demo 2 of Module 2.11 (SLD11): reading a deployed token
// with a hand-written ABI. Read-only, no wallet. Run:  node demo2-contract.mjs
import { ethers } from "ethers";

// The read-only Sepolia provider (Step 2 of Demo 1 used the same one).
const p = new ethers.JsonRpcProvider("https://ethereum-sepolia-rpc.publicnode.com");

// Step 1 — write the ABI by hand: only the three read functions we need.
const abi = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function balanceOf(address) view returns (uint256)"
];

// Step 2 — build the Contract on the LINK token that already exists on Sepolia.
const LINK_SEPOLIA = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
const link = new ethers.Contract(LINK_SEPOLIA, abi, p);   // runner = provider -> read only

// Step 3 — each ABI entry is now a JavaScript method.
console.log("name   :", await link.name());
console.log("symbol :", await link.symbol());
const bal = await link.balanceOf(LINK_SEPOLIA);           // any address works
console.log("balance:", ethers.formatUnits(bal, 18), "LINK");

// Step 4 — a WRITE would differ only in the runner: a signer instead of a provider.
//          It needs MetaMask, and you can only move tokens you hold, so it is not run
//          here. Building that write path on a token you deploy yourself is the exercise.
//   const linkRW = new ethers.Contract(LINK_SEPOLIA,
//     ["function transfer(address,uint256) returns (bool)"], signer);
