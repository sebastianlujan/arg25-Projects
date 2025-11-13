import { createLogger, Logger, SponsoredFeePaymentMethod, Fr, AztecAddress } from "@aztec/aztec.js";
import { createServer } from 'http';
// Viem imports
import { 
    createPublicClient, 
    http, 
    parseAbi, 
    type Address, 
    type Hash,
    keccak256,
    toHex
} from 'viem';
import { arbitrumSepolia, stylus } from 'viem/chains';

const EVVM_CAFHE_ADDRESS = "" as Address;
const EVVM_CAFHE_RPC_URL = "https://celo-sepolia.drpc.org";
const HTTP_PORT = process.env.RELAYER_PORT ? parseInt(process.env.RELAYER_PORT) : 3001;

const logger: Logger = createLogger("poc-relayer");

const publicClient = createPublicClient({
    chain: arbitrumSepolia,
    transport: http(EVVM_CAFHE_RPC_URL),
});

 // Get current block number
 let lastProcessedBlock = await publicClient.getBlockNumber();
 logger.info(`📦 Starting from block: ${lastProcessedBlock}`);

 logger.info(`✅ Simple Relayer initialized`);
 logger.info(`📍 EVVM CAFHE: ${EVVM_CAFHE_ADDRESS}`);
 logger.info(`👂 Listening for ANY transactions to EVVM CAFHE...`);

async function checkForNewTransactions() {
    try {
        const currentBlock = await publicClient.getBlockNumber();
        
        if (currentBlock > lastProcessedBlock) {
            logger.info(`🔍 Checking blocks ${lastProcessedBlock + 1n} to ${currentBlock}`);
            
            // Check each new block
            for (let blockNum = this.lastProcessedBlock + 1n; blockNum <= currentBlock; blockNum++) {
                await this.processBlock(blockNum);
            }
            
            this.lastProcessedBlock = currentBlock;
        }
    } catch (error) {
        this.logger.error(`❌ Error checking for new transactions: ${error}`);
    }
}

async function processBlock(blockNumber: bigint) {
    try {
        const block = await publicClient.getBlock({ 
            blockNumber,
            includeTransactions: true 
        });

        if (!block.transactions) return;

        // Check each transaction in the block
        for (const tx of block.transactions) {
            if (typeof tx === 'object' && tx.to && tx.to.toLowerCase() === EVVM_CAFHE_ADDRESS.toLowerCase()) {
                await processTransaction(tx as any, blockNumber);
            }
        }
    } catch (error) {
        this.logger.error(`❌ Error processing block ${blockNumber}: ${error}`);
    }
}

async function processTransaction(tx: any, blockNumber: bigint) {
    try {
        logger.info(`🔍 Found transaction to EVVM CAFHE: ${tx.hash}`);
        logger.info(`   - Block: ${blockNumber}`);
        logger.info(`   - From: ${tx.from}`);
        logger.info(`   - To: ${tx.to}`);
        logger.info(`   - Input: ${tx.input}`);

        // Process ANY transaction to the EVVM CAFHE contract
        logger.info(`✅ Processing transaction to EVVM CAFHE: ${tx.hash}`);
        // TODO: Implement transaction processing
        
    } catch (error) {
        logger.error(`❌ Error processing transaction ${tx.hash}: ${error}`);
    }
}