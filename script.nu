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


