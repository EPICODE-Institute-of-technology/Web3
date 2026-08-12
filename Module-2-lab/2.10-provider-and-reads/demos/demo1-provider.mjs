// demo1-provider.mjs — Demo 1 of Module 2.10 (SLD7): the Provider, reading the
// chain live, with no wallet. This is the first demo of the batch, on its own.
//
// RUN:  npm init -y && npm install ethers   (once), then:  node demo1-provider.mjs
// It performs exactly the four demo steps and prints each result.

import { ethers } from "ethers";

// Step 1 — a read-only Provider on Sepolia. No wallet; every call below is free.
const p = new ethers.JsonRpcProvider("https://ethereum-sepolia-rpc.publicnode.com");

// Step 2 — two questions about the chain's present state.
console.log("blockNumber:", await p.getBlockNumber());
console.log("feeData    :", await p.getFeeData());

// Step 3 — a balance, in wei, then formatted to ether.
//          Replace this with your own funded Sepolia address to see a non-zero value.
const SAMPLE_ADDRESS = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
const bal = await p.getBalance(SAMPLE_ADDRESS);
console.log("balance wei:", bal.toString());
console.log("balance eth:", ethers.formatEther(bal));

// Step 4 — ENS names live on mainnet, so resolve against a mainnet Provider.
const pMain = new ethers.JsonRpcProvider("https://ethereum-rpc.publicnode.com");
console.log("ens.eth    :", await pMain.resolveName("ens.eth"));
