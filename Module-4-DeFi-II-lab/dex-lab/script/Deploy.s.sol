// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {Router} from "../src/Router.sol";

/// @notice Deploys the DEX: a factory and the router that drives it. The fee-to setter
/// is the deployer, who may later switch the protocol fee on. Run against a local anvil
/// node (Module 2.16's `yarn chain` / `anvil`) with:
///   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
contract Deploy is Script {
    function run() external returns (Factory factory, Router router) {
        vm.startBroadcast();
        factory = new Factory(msg.sender); // deployer is the feeToSetter
        router = new Router(address(factory));
        vm.stopBroadcast();

        console2.log("Factory:", address(factory));
        console2.log("Router: ", address(router));
    }
}
