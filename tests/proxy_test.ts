import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Proxy contract initialization and basic functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('proxy', 'get-proxy-info', [], deployer.address),
        ]);
        
        const proxyInfo = block.receipts[0].result.expectOk().expectTuple();
        assertEquals(proxyInfo['admin'], deployer.address);
        
        block = chain.mineBlock([
            Tx.contractCall('proxy', 'initialize', [types.principal(deployer.address + '.counter-v1')], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk();
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v1', 'set-proxy-contract', [types.principal(deployer.address + '.proxy')], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk();
    },
});

Clarinet.test({
    name: "Counter functionality through proxy",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('proxy', 'initialize', [types.principal(deployer.address + '.counter-v1')], deployer.address),
            Tx.contractCall('counter-v1', 'set-proxy-contract', [types.principal(deployer.address + '.proxy')], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v1', 'increment', [], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v1', 'get-counter', [], deployer.address),
        ]);
        
        block.receipts[0].result.expectUint(1);
    },
});

Clarinet.test({
    name: "Contract upgrade preserves state",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('proxy', 'initialize', [types.principal(deployer.address + '.counter-v1')], deployer.address),
            Tx.contractCall('counter-v1', 'set-proxy-contract', [types.principal(deployer.address + '.proxy')], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v1', 'increment', [], deployer.address),
            Tx.contractCall('counter-v1', 'increment', [], deployer.address),
            Tx.contractCall('counter-v1', 'set-name', [types.ascii("Test Counter")], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        block.receipts[1].result.expectOk().expectUint(2);
        block.receipts[2].result.expectOk();
        
        block = chain.mineBlock([
            Tx.contractCall('proxy', 'upgrade-implementation', [types.principal(deployer.address + '.counter-v2')], deployer.address),
            Tx.contractCall('counter-v2', 'set-proxy-contract', [types.principal(deployer.address + '.proxy')], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v2', 'get-counter', [], deployer.address),
            Tx.contractCall('counter-v2', 'get-name', [], deployer.address),
        ]);
        
        block.receipts[0].result.expectUint(2);
        block.receipts[1].result.expectAscii("Test Counter");
    },
});

Clarinet.test({
    name: "V2 contract new features",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('proxy', 'initialize', [types.principal(deployer.address + '.counter-v2')], deployer.address),
            Tx.contractCall('counter-v2', 'set-proxy-contract', [types.principal(deployer.address + '.proxy')], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk();
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v2', 'set-multiplier', [types.uint(5)], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectUint(5);
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v2', 'increment', [], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk().expectUint(5);
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v2', 'pause', [], deployer.address),
        ]);
        
        block.receipts[0].result.expectOk();
        
        block = chain.mineBlock([
            Tx.contractCall('counter-v2', 'increment', [], deployer.address),
        ]);
        
        block.receipts[0].result.expectErr().expectUint(100);
    },
});
