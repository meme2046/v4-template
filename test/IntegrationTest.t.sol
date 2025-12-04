// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

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
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import {Planner, Plan} from "@uniswap/v4-periphery/test/shared/Planner.sol";

import {Counter} from "../src/Counter.sol";
import {BaseTest} from "./utils/BaseTest.sol";

contract IntegrationTest is BaseTest {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Counter hook;
    PoolKey poolKey;
    PoolId poolId;
    // setUp()是一个特殊的方法，每个测试合约中如果定义了它，会在运行任何测试函数之前自动执行。
    function setUp() public {
        // 部署所有需要的组件
        deployArtifactsAndLabel();

        // 部署代币对
        (Currency currency0, Currency currency1) = deployCurrencyPair();
        // 输出代币信息用于调试
        console2.log("currency0 balance: ",currency0.balanceOf(address(this)));
        console2.log("Currency0:", Currency.unwrap(currency0));
        console2.log("Currency0-uint160",uint160(Currency.unwrap(currency0)));
        console2.log("Currency1:", Currency.unwrap(currency1));

        // 部署带有所需权限的Hook
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            ) ^ (0x4444 << 144) // 命名空间化Hook以避免冲突
        );
        bytes memory constructorArgs = abi.encode(poolManager);
        deployCodeTo("Counter.sol:Counter", constructorArgs, flags);
        hook = Counter(flags);

        // 创建池
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = poolKey.toId();
        // 输出池信息用于调试
        console2.log("Pool ID:", uint256(PoolId.unwrap(poolId)));
        console2.log("Hook address:", address(hook));
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // 添加流动性
        int24 tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);
        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        // 使用Planner添加流动性
        Plan memory planner = Planner.init();
        planner.add(
            Actions.MINT_POSITION,
            abi.encode(
                poolKey,
                tickLower,
                tickUpper,
                liquidityAmount,
                amount0Expected + 1,
                amount1Expected + 1,
                address(this),
                Constants.ZERO_BYTES
            )
        );
        bytes memory actions = planner.finalizeModifyLiquidityWithClose(poolKey);
        positionManager.modifyLiquidities(actions, block.timestamp + 1);
    }

    function testCompleteFlow() public {
        // 初始状态检查
        assertEq(hook.beforeAddLiquidityCount(poolId), 1);
        assertEq(hook.beforeRemoveLiquidityCount(poolId), 0);
        assertEq(hook.beforeSwapCount(poolId), 0);
        assertEq(hook.afterSwapCount(poolId), 0);
        
        // 输出初始状态
        console2.log("Initial beforeAddLiquidityCount:", hook.beforeAddLiquidityCount(poolId));
        console2.log("Initial beforeSwapCount:", hook.beforeSwapCount(poolId));
        console2.log("Initial afterSwapCount:", hook.afterSwapCount(poolId));

        // 执行swap
        uint256 amountIn = 1e18;
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // 验证Hook被触发
        assertEq(hook.beforeSwapCount(poolId), 1);
        assertEq(hook.afterSwapCount(poolId), 1);
        
        // 输出swap后状态
        console2.log("After first swap - beforeSwapCount:", hook.beforeSwapCount(poolId));
        console2.log("After first swap - afterSwapCount:", hook.afterSwapCount(poolId));
        
        // 再执行一次swap
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: false,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
        
        // 验证计数器增加
        assertEq(hook.beforeSwapCount(poolId), 2);
        assertEq(hook.afterSwapCount(poolId), 2);
        
        // 输出第二次swap后状态
        console2.log("After second swap - beforeSwapCount:", hook.beforeSwapCount(poolId));
        console2.log("After second swap - afterSwapCount:", hook.afterSwapCount(poolId));
    }
}