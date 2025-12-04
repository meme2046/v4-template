def main [] {
    print 'uniswap v4 template'
}

def "main anvil" [] {
    ^anvil --code-size-limit 40000
}

def "main tcf" [] {
    
    forge test --match-test testCompleteFlow -vvv
}

def "main ts" [] {
    
    forge test --match-test testLPSellHook  -vvv
}



def "main tb" [] {
    
    forge test --match-test testLPBuyHook  -vvv
}

def "main deploy" [] {
    (forge script script/DeployBuyAndSellHooks.s.sol
    --rpc-url $env.INFURA_ETH
    --private-key $env.A1
    --broadcast)
}

def "main env" [] {
    print $env.INFURA_ETH
}
