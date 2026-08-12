// demo3-events.mjs — Demo 3 of Module 2.12 (SLD20): events, history then live.
// Read-only, no wallet. Run:  node demo3-events.mjs   (it stops itself after ~20s)
//
// The LIVE part uses a WebSocket provider: the node PUSHES each new event, so it
// appears within a second or two. (Over a plain HTTP provider ethers can only POLL,
// which is slow and may show nothing in a short window — fine for queryFilter, poor
// for a live subscription.)
import { ethers } from "ethers";

// WebSocket endpoint (note the wss://). WETH sees constant activity.
const p = new ethers.WebSocketProvider("wss://ethereum-rpc.publicnode.com");
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

// Step 1 — an ABI with only the Transfer event is all ethers needs to decode the logs.
const abi = ["event Transfer(address indexed from, address indexed to, uint256 value)"];
const token = new ethers.Contract(WETH, abi, p);

// Step 2 — HISTORIC: the Transfer logs from the last 20 blocks.
const logs = await token.queryFilter("Transfer", -20, "latest");
console.log("historic Transfers (last 20 blocks):", logs.length);
if (logs[0]) console.log("  example:", logs[0].args.from, "->", logs[0].args.to, logs[0].args.value.toString());

// Step 3 — LIVE: one line per new Transfer as it is mined.
console.log("subscribing live for ~20s...");
const handler = (from, to, value) => console.log("  live:", from, "->", to, value.toString());
await token.on("Transfer", handler);

// Step 4 — ERC-20 convention: from 0x0 = mint, to 0x0 = burn. Then stop and close the socket.
setTimeout(async () => {
  await token.off("Transfer", handler);
  console.log("stopped.");
  p.destroy();
  process.exit(0);
}, 20000);
