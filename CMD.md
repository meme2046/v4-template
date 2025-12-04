# forge test

```shell
# DeployHook
forge script script/00_DeployHook.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# 只运行名称匹配的测试函数 testCompleteFlow
forge test --match-test testCompleteFlow -vvv

# 运行所有测试
forge test

# 运行特定文件中的所有测试
forge test --match-path test/IntegrationTest.t.sol

# 以不同详细级别运行
forge test -v    # 基本详细信息
forge test -vv   # 包含日志输出
forge test -vvv  # 包含追踪信息

# 显示气体报告
forge test --gas-report

# 匹配特定合约中的测试
forge test --match-contract IntegrationTest
```
