// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {console2} from "forge-std/console2.sol";
import {EasyPosm} from "./utils/libraries/EasyPosm.sol";

import {LPSellHook} from "../src/LPSellHook.sol";
import {LPBuyHook} from "../src/LPBuyHook.sol";
import {BaseTest} from "./utils/BaseTest.sol";

contract HookTests is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency currency0;
    Currency currency1;

    PoolKey sellHookPoolKey;
    PoolKey buyHookPoolKey;

    LPSellHook sellHook;
    LPBuyHook buyHook;
    
    PoolId sellHookPoolId;
    PoolId buyHookPoolId;

    function setUp() public {
        // Deploys all required artifacts.
        deployArtifactsAndLabel();

        (currency0, currency1) = deployCurrencyPair();

        /// 部署带有所需权限的Hook
        address sellFlags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG ^ (0x4445 << 144)) // Namespace the hook to avoid collisions
        );
        bytes memory sellConstructorArgs = abi.encode(poolManager);
        deployCodeTo("LPSellHook.sol:LPSellHook", sellConstructorArgs, sellFlags);
        sellHook = LPSellHook(sellFlags);

        // Deploy the LPBuyHook to an address with the correct flags
        address buyFlags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG ^ (0x4446 << 144)) // Namespace the hook to avoid collisions
        );
        bytes memory buyConstructorArgs = abi.encode(poolManager);
        deployCodeTo("LPBuyHook.sol:LPBuyHook", buyConstructorArgs, buyFlags);
        buyHook = LPBuyHook(buyFlags);

        // Create the pools
        sellHookPoolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(sellHook));
        buyHookPoolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(buyHook));
        
        sellHookPoolId = sellHookPoolKey.toId();
        buyHookPoolId = buyHookPoolKey.toId();
        
        poolManager.initialize(sellHookPoolKey, Constants.SQRT_PRICE_1_1);
        poolManager.initialize(buyHookPoolKey, Constants.SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pools
        int24 tickLower = TickMath.minUsableTick(60);
        int24 tickUpper = TickMath.maxUsableTick(60);

        uint128 liquidityAmount = 10000e18;

        // Add liquidity to sell hook pool
        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        positionManager.mint(
            sellHookPoolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );
        
        // Add liquidity to buy hook pool
        positionManager.mint(
            buyHookPoolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );
    }

    function testLPSellHook() public {
        console2.log("balance0", currency0.balanceOf(address(this)));
        console2.log("balance1", currency1.balanceOf(address(this)));
        // token1->token0
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: 10e18,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: sellHookPoolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        // amount0() 方法返回的是 token0 的数量变化
        assert(swapDelta.amount0() > 0);
        // token0->token1
        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 10e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: sellHookPoolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        console2.log("balance0", currency0.balanceOf(address(this)));
        console2.log("balance1", currency1.balanceOf(address(this)));
    }

    function testLPBuyHook() public {
        console2.log("balance0", currency0.balanceOf(address(this)));
        console2.log("balance1", currency1.balanceOf(address(this)));
        // token0->token1
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: 10e18,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: buyHookPoolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        
        assert(swapDelta.amount0() < 0);

        // token1->token0
        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 10e18,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: buyHookPoolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        console2.log("balance0", currency0.balanceOf(address(this)));
        console2.log("balance1", currency1.balanceOf(address(this)));
    }
}