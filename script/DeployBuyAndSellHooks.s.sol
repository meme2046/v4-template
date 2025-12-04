// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import {BaseScript} from "./base/BaseScript.sol";
import {console2} from "forge-std/console2.sol";
import {LPBuyHook} from "../src/LPBuyHook.sol";
import {LPSellHook} from "../src/LPSellHook.sol";

/// @notice Mines the addresses and deploys the LPBuyHook.sol and LPSellHook.sol Hook contracts
contract DeployBuyAndSellHooksScript is BaseScript {
    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 buyFlags = uint160(
            Hooks.BEFORE_SWAP_FLAG
        );
        
        uint160 sellFlags = uint160(
            Hooks.BEFORE_SWAP_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags for Buy Hook
        bytes memory buyConstructorArgs = abi.encode(poolManager);
        (address buyHookAddress, bytes32 buySalt) =
            HookMiner.find(CREATE2_FACTORY, buyFlags, type(LPBuyHook).creationCode, buyConstructorArgs);

        // Mine a salt that will produce a hook address with the correct flags for Sell Hook
        bytes memory sellConstructorArgs = abi.encode(poolManager);
        (address sellHookAddress, bytes32 sellSalt) =
            HookMiner.find(CREATE2_FACTORY, sellFlags, type(LPSellHook).creationCode, sellConstructorArgs);

        // Deploy the hooks using CREATE2
        vm.startBroadcast();
        LPBuyHook buyHook = new LPBuyHook{salt: buySalt}(poolManager);
        LPSellHook sellHook = new LPSellHook{salt: sellSalt}(poolManager);
        vm.stopBroadcast();

        require(address(buyHook) == buyHookAddress, "DeployBuyAndSellHooksScript: Buy Hook Address Mismatch");
        require(address(sellHook) == sellHookAddress, "DeployBuyAndSellHooksScript: Sell Hook Address Mismatch");
        
        // Print deployed addresses
        console2.log("Buy Hook deployed at: %s", address(buyHook));
        console2.log("Sell Hook deployed at: %s", address(sellHook));
    }
}