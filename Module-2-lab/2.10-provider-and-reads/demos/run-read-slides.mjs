// run-read-slides.mjs — the READ-ONLY code from the slides, with the blanks filled in.
// This is Lecture 2.10 SLD7 (Provider), SLD9 (ABI), SLD11 top half (Contract read),
// and SLD20 historic half (events). No wallet, no gas: every call is a free read.
//
// RUN IT:
//   1. mkdir dapp-demo && cd dapp-demo
//   2. npm init -y && npm install ethers
//   3. save this file here, then:  node run-read-slides.mjs

import { ethers } from "ethers";

// ---- SLD7: Reading the chain with a Provider ----
// The slide writes:  new ethers.JsonRpcProvider("https://…sepolia-rpc-url")
// A real public Sepolia URL (no key needed) goes in place of that placeholder:
const provider = new ethers.JsonRpcProvider("https://ethereum-sepolia-rpc.publicnode.com");
const address  = "0x779877A7B0D9E8603169DdbD7836e478b4624789"; // the slide's `address`

console.log("blockNumber:", await provider.getBlockNumber());
console.log("balance    :", (await provider.getBalance(address)).toString(), "wei");
console.log("network    :", await provider.getNetwork());
console.log("feeData    :", await provider.getFeeData());

// resolveName needs mainnet, because ENS names live there — so a second Provider:
const mainnet = new ethers.JsonRpcProvider("https://ethereum-rpc.publicnode.com");
console.log("ens.eth    :", await mainnet.resolveName("ens.eth"));   // SLD7 resolveName

// ---- SLD9 + SLD11 (read): the ABI, and a Contract on a Provider ----
const abi = [                                              // SLD9 human-readable ABI
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function balanceOf(address) view returns (uint256)"
];
const c  = new ethers.Contract(address, abi, provider);    // SLD11: address + abi + runner
const me = address;
console.log("name       :", await c.name());
console.log("symbol     :", await c.symbol());
console.log("balanceOf  :", (await c.balanceOf(me)).toString());   // SLD11: a free read

// ---- SLD20 (historic half): events over a block range ----
const weth = new ethers.Contract(
  "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",             // WETH, a very busy token
  ["event Transfer(address indexed from, address indexed to, uint256 value)"],
  mainnet
);
const logs = await weth.queryFilter("Transfer", -20, "latest");    // SLD20 queryFilter
console.log("WETH Transfers in last 20 blocks:", logs.length);
if (logs[0]) console.log("first log args:", logs[0].args);
