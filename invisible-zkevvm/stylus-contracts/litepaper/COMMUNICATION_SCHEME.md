# EVVM Communication Scheme - Data Flow Architecture

## Overview

This document describes the complete data flow and communication architecture for EVVM, detailing how encrypted data, proofs, and state updates propagate through the system.

---

## 1. System Components & Data Types

### Components
- **User Client**: Wallet/application interface
- **zkFisher Relayer**: Transaction coordinator and proof generator
- **EVVM Core (Arbitrum)**: Smart contracts (Payments, Staking, Treasury)
- **Stylus Interface**: Rust-based high-performance layer
- **Zama FHE Network**: Homomorphic encryption computation
- **Aztec (Noir)**: Merkle tree storage and proof generation
- **Arbitrum Noir Verifier**: On-chain proof verification

### Data Types
- **Encrypted Transaction Data**: FHE-encrypted values
- **Merkle Proofs**: Inclusion proofs for transactions
- **ZK Proofs**: Noir proofs verified via Groth16
- **Snapshots**: Merkle roots for epoch boundaries
- **State Updates**: Encrypted balance changes

---

## 2. Communication Flow - Step by Step

### Phase 1: Transaction Initiation (User → zkFisher)

```
┌─────────────┐
│ User Client │
└──────┬──────┘
       │
       │ [1] Transaction Request
       │ ─────────────────────────
       │ • transaction_id: uuid
       │ • encrypted_amount: FHE_Ciphertext
       │ • sender_address: Address
       │ • recipient_address: Address (encrypted)
       │ • timestamp: uint64
       │ • signature: ECDSA_Signature
       │ • validity_proof: ClientProof
       │
       ▼
┌──────────────────┐
│  zkFisher Relay  │
└──────────────────┘
```

**Data Structure:**
```json
{
  "transaction_id": "0x1a2b3c...",
  "encrypted_data": {
    "amount": "FHE_Enc(5.00)",
    "recipient": "FHE_Enc(0xABC...)"
  },
  "metadata": {
    "sender": "0x123...",
    "timestamp": 1699999999,
    "nonce": 42
  },
  "proof": {
    "type": "validity_proof",
    "data": "0x..."
  },
  "signature": "0x..."
}
```

---

### Phase 2: Transaction Batching (zkFisher Internal)

```
┌──────────────────┐
│  zkFisher Relay  │
└────────┬─────────┘
         │
         │ [2] Create Healthy Block
         │ ─────────────────────────
         │ • block_id: hash
         │ • transactions[]: Array<EncryptedTx>
         │ • block_header: BlockHeader
         │ • prev_block_hash: hash
         │
         ▼
┌──────────────────┐
│  Pending Pool    │
│  (zkFisher)      │
└──────────────────┘
```

**Healthy Block Structure:**
```json
{
  "block_id": "0xABCD1234...",
  "header": {
    "version": 1,
    "prev_block": "0x...",
    "timestamp": 1699999999,
    "tx_count": 0
  },
  "transactions": [],
  "state": "healthy"
}
```

**Block Filling Process:**
```json
{
  "block_id": "0xABCD1234...",
  "header": {
    "version": 1,
    "prev_block": "0x...",
    "timestamp": 1699999999,
    "tx_count": 25
  },
  "transactions": [
    {
      "tx_id": "0x1a2b3c...",
      "encrypted_amount": "FHE_Enc(...)",
      "sender": "0x123...",
      "recipient_enc": "FHE_Enc(0xABC...)",
      "signature": "0x..."
    },
    // ... 24 more transactions
  ],
  "state": "filled"
}
```

---

### Phase 3: Merkle Tree Creation (zkFisher → Aztec)

```
┌──────────────────┐
│  zkFisher Relay  │
└────────┬─────────┘
         │
         │ [3] Store Transaction Metadata
         │ ─────────────────────────────────
         │ • tx_hashes[]: Array<hash>
         │ • block_metadata: BlockMeta
         │
         ▼
┌──────────────────┐
│  Aztec (Noir)    │
│  Merkle Storage  │
└────────┬─────────┘
         │
         │ [4] Generate Merkle Tree
         │ ─────────────────────────
         │ • merkle_root: hash
         │ • inclusion_proofs[]: Array<Proof>
         │
         ▼
     Merkle Root
     (Snapshot)
```

**Merkle Tree Data:**
```json
{
  "tree_id": "0xTREE123...",
  "root": "0xROOT456...",
  "depth": 5,
  "leaves": [
    {
      "index": 0,
      "tx_hash": "0x1a2b3c...",
      "metadata": {
        "block_id": "0xABCD...",
        "timestamp": 1699999999
      }
    },
    // ... more leaves
  ],
  "proofs": {
    "tx_0x1a2b3c": {
      "siblings": ["0xA1...", "0xB2...", "0xC3..."],
      "path": [1, 0, 1, 0, 1]
    }
  }
}
```

---

### Phase 4: Snapshot Creation (Epoch Boundary)

```
Every X blocks:

┌──────────────────┐
│  zkFisher Relay  │
└────────┬─────────┘
         │
         │ [5] Create Snapshot
         │ ────────────────────
         │ • epoch_id: uint64
         │ • merkle_root: hash
         │ • block_range: [start, end]
         │ • state_commitment: hash
         │
         ▼
┌──────────────────┐
│  Snapshot Store  │
└──────────────────┘
```

**Snapshot Structure:**
```json
{
  "snapshot_id": "epoch_42",
  "epoch": 42,
  "merkle_root": "0xROOT456...",
  "block_range": {
    "start": 4200,
    "end": 4299
  },
  "state_commitment": "0xSTATE789...",
  "timestamp": 1699999999,
  "tx_count": 2500,
  "metadata": {
    "total_volume_encrypted": "FHE_Enc(...)",
    "active_accounts": 1337
  }
}
```

---

### Phase 5: ZK Proof Generation (zkFisher → Noir)

```
┌──────────────────┐
│  zkFisher Relay  │
└────────┬─────────┘
         │
         │ [6] Request Proof Generation
         │ ──────────────────────────────
         │ • snapshot: SnapshotData
         │ • merkle_proofs: Array<Proof>
         │ • circuit_inputs: CircuitData
         │
         ▼
┌──────────────────┐
│  Noir Prover     │
└────────┬─────────┘
         │
         │ [7] Generate ZK Proof
         │ ───────────────────────
         │ • proof: Groth16Proof
         │ • public_inputs: Array<Field>
         │
         ▼
┌──────────────────┐
│  Groth16 Proof   │
└──────────────────┘
```

**Proof Generation Request:**
```json
{
  "proof_request_id": "0xPROOF123...",
  "circuit": "merkle_inclusion_v1",
  "inputs": {
    "public": {
      "merkle_root": "0xROOT456...",
      "snapshot_hash": "0xSNAP789...",
      "epoch": 42
    },
    "private": {
      "tx_data": [...],
      "merkle_siblings": [...],
      "paths": [...]
    }
  }
}
```

**Generated Proof:**
```json
{
  "proof": {
    "a": ["0x...", "0x..."],
    "b": [["0x...", "0x..."], ["0x...", "0x..."]],
    "c": ["0x...", "0x..."]
  },
  "public_signals": [
    "0xROOT456...",
    "0xSNAP789...",
    "42"
  ],
  "backend": "groth16",
  "size_bytes": 256
}
```

---

### Phase 6: On-Chain Verification (zkFisher → Arbitrum)

```
┌──────────────────┐
│  zkFisher Relay  │
└────────┬─────────┘
         │
         │ [8] Submit Proof to Arbitrum
         │ ─────────────────────────────
         │ • proof: Groth16Proof
         │ • public_inputs: Array<Field>
         │ • snapshot_id: uint64
         │
         ▼
┌──────────────────────┐
│  Arbitrum Network    │
│  (Stylus Interface)  │
└──────────┬───────────┘
           │
           │ [9] Call Verifier
           │ ─────────────────
           │ • verifyProof(proof, inputs)
           │
           ▼
┌──────────────────────┐
│  Noir Verifier       │
│  (Groth16 Backend)   │
└──────────┬───────────┘
           │
           │ [10] Verification Result
           │ ────────────────────────
           │ • valid: bool
           │ • gas_used: uint256
           │
           ▼
```

**Verification Transaction:**
```json
{
  "to": "0xEVVMCore...",
  "function": "submitSnapshot",
  "params": {
    "snapshot_id": 42,
    "merkle_root": "0xROOT456...",
    "proof": {
      "a": [...],
      "b": [...],
      "c": [...]
    },
    "public_inputs": [...]
  },
  "gas_limit": 500000
}
```

---

### Phase 7: State Update (Arbitrum → EVVM Core)

```
┌──────────────────────┐
│  Noir Verifier       │
└──────────┬───────────┘
           │
           │ Proof Valid ✓
           │
           ▼
┌──────────────────────┐
│  EVVM Core Contract  │
└──────────┬───────────┘
           │
           │ [11] Update Encrypted State
           │ ────────────────────────────
           │ • Call Zama FHE precompiles
           │ • Update encrypted balances
           │ • Emit events
           │
           ▼
┌──────────────────────┐
│  Zama FHE Network    │
└──────────┬───────────┘
           │
           │ [12] Process FHE Operations
           │ ────────────────────────────
           │ • fheAdd(enc_a, enc_b)
           │ • fheSub(enc_a, enc_b)
           │ • Return encrypted results
           │
           ▼
┌──────────────────────┐
│  Updated State       │
└──────────────────────┘
```

**FHE Operation Request:**
```json
{
  "operation": "transfer",
  "params": {
    "from_balance": "FHE_Enc(1000)",
    "to_balance": "FHE_Enc(500)",
    "amount": "FHE_Enc(5)",
    "operation_type": "subtract_add"
  }
}
```

**FHE Operation Response:**
```json
{
  "result": {
    "from_balance_new": "FHE_Enc(995)",
    "to_balance_new": "FHE_Enc(505)"
  },
  "computation_proof": "0x...",
  "gas_cost": 50000
}
```

---

### Phase 8: Confirmation (EVVM Core → User)

```
┌──────────────────────┐
│  EVVM Core Contract  │
└──────────┬───────────┘
           │
           │ [13] Emit Events
           │ ─────────────────
           │ • TransactionProcessed
           │ • StateUpdated
           │ • SnapshotCommitted
           │
           ▼
┌──────────────────┐
│  Event Log       │
│  (Arbitrum)      │
└────────┬─────────┘
         │
         │ [14] Listen for Events
         │ ───────────────────────
         │
         ▼
┌──────────────────┐
│  zkFisher Relay  │
└────────┬─────────┘
         │
         │ [15] Send Confirmation
         │ ───────────────────────
         │ • tx_id: hash
         │ • status: "confirmed"
         │ • block_number: uint64
         │ • snapshot_id: uint64
         │
         ▼
┌─────────────┐
│ User Client │
└─────────────┘
```

**Event Structure:**
```json
{
  "event": "TransactionProcessed",
  "data": {
    "tx_id": "0x1a2b3c...",
    "block_number": 4242,
    "snapshot_id": 42,
    "timestamp": 1699999999,
    "gas_used": 10000
  },
  "topics": [
    "0xTransactionProcessed...",
    "0x1a2b3c..."
  ]
}
```

**User Confirmation:**
```json
{
  "tx_id": "0x1a2b3c...",
  "status": "confirmed",
  "confirmations": 15,
  "block": {
    "number": 4242,
    "hash": "0xBLOCK..."
  },
  "snapshot": {
    "id": 42,
    "merkle_root": "0xROOT456..."
  },
  "receipt": {
    "encrypted_balance_new": "FHE_Enc(...)",
    "gas_paid_by_relayer": 10000
  }
}
```

---

## 3. Complete Data Flow Diagram

```
┌─────────────┐
│    User     │
│   Client    │
└──────┬──────┘
       │
       │ (1) Encrypted Tx
       │ ─────────────────────────────────────┐
       │                                      │
       ▼                                      │
┌──────────────────┐                         │
│   zkFisher       │                         │
│   Relayer        │                         │
└────┬─────────┬───┘                         │
     │         │                              │
     │         │ (3) Tx Metadata              │
     │         │ ──────────────►┌──────────┐  │
     │         │                │  Aztec   │  │
     │         │                │  (Noir)  │  │
     │         │ (4) Merkle     └──────────┘  │
     │         │ ◄──────────────     │        │
     │         │     Proofs          │        │
     │         │                     │        │
     │         │ (6) Gen Proof       │        │
     │         │ ────────────────────┘        │
     │         │                              │
     │         │ (7) ZK Proof                 │
     │         │ ◄───────────────────         │
     │         │                              │
     │ (2) Healthy Block                      │
     │                                        │
     │ (8) Submit Proof                       │
     │ ──────────────►┌──────────────────┐   │
     │                │   Arbitrum       │   │
     │                │   (Stylus)       │   │
     │                └────┬─────────────┘   │
     │                     │                  │
     │                     │ (9) Verify       │
     │                     │ ───────►┌──────────────┐
     │                     │         │ Noir Verifier│
     │                     │         │  (Groth16)   │
     │                     │ (10)    └──────────────┘
     │                     │ ◄────── Valid ✓
     │                     │
     │                     │ (11) Update State
     │                     │ ───────►┌──────────────┐
     │                     │         │ EVVM Core    │
     │                     │         │  Contracts   │
     │                     │         └───┬──────────┘
     │                     │             │
     │                     │             │ (12) FHE Ops
     │                     │             │ ─────►┌─────────┐
     │                     │             │       │  Zama   │
     │                     │             │       │  FHE    │
     │                     │             │ ◄─────└─────────┘
     │                     │             │
     │                     │ (13) Events │
     │                     │ ◄───────────┘
     │                     │
     │ (14) Listen Events  │
     │ ◄───────────────────┘
     │
     │ (15) Confirmation
     │ ────────────────────────────────────────┘
     │
     ▼
┌─────────────┐
│    User     │
│   Client    │
└─────────────┘
```

---

## 4. Data Privacy Matrix

| Component | Data Type | Encryption Status | Visibility |
|-----------|-----------|-------------------|------------|
| User Client | Transaction Amount | FHE Encrypted | User only |
| User Client | Signature | Plain | Public |
| zkFisher | Encrypted Tx | FHE Encrypted | Cannot decrypt |
| zkFisher | Tx Metadata | Plain (hashes) | Internal |
| Aztec | Merkle Tree | Plain (hashes) | Public (hashes only) |
| Noir Prover | ZK Proof | Plain | Public |
| Arbitrum | Encrypted State | FHE Encrypted | Cannot decrypt |
| Zama FHE | Encrypted Operations | FHE Encrypted | Computed encrypted |
| EVVM Core | Balances | FHE Encrypted | No one can see |

---

## 5. Performance Metrics

### Latency Breakdown

```
Total Transaction Time: ~5 seconds

┌─────────────────────────────────────────────────┐
│ Phase 1: User Encryption          │ 100ms      │
│ Phase 2: zkFisher Batching         │ 500ms      │
│ Phase 3: Merkle Creation           │ 200ms      │
│ Phase 4: Snapshot (periodic)       │ -          │
│ Phase 5: ZK Proof Generation       │ 2000ms     │
│ Phase 6: On-chain Verification     │ 1500ms     │
│ Phase 7: State Update (FHE)        │ 500ms      │
│ Phase 8: Confirmation Propagation  │ 200ms      │
└─────────────────────────────────────────────────┘
```

### Data Size

```
Transaction Size Breakdown:

┌────────────────────────────────────┐
│ Encrypted Amount:        128 bytes │
│ Signature:                65 bytes │
│ Address:                  20 bytes │
│ Metadata:                 64 bytes │
│ Client Proof:            256 bytes │
├────────────────────────────────────┤
│ Total per Transaction:   533 bytes │
└────────────────────────────────────┘

Block Size (25 transactions):  ~13 KB
Merkle Proof Size:             ~1 KB
ZK Proof Size (Groth16):       256 bytes
```

---

## 6. Error Handling & Communication

### Error Response Format

```json
{
  "error": {
    "code": "INVALID_SIGNATURE",
    "message": "Transaction signature verification failed",
    "tx_id": "0x1a2b3c...",
    "timestamp": 1699999999,
    "details": {
      "expected_signer": "0x123...",
      "recovered_signer": "0x456..."
    }
  },
  "retry": {
    "allowed": true,
    "max_attempts": 3,
    "backoff_ms": 1000
  }
}
```

### Status Codes

| Code | Status | Description |
|------|--------|-------------|
| 200 | TX_RECEIVED | Transaction received by zkFisher |
| 201 | TX_BATCHED | Transaction added to block |
| 202 | PROOF_GENERATING | ZK proof being generated |
| 203 | PROOF_SUBMITTED | Proof submitted to Arbitrum |
| 204 | TX_CONFIRMED | Transaction confirmed on-chain |
| 400 | INVALID_TX | Invalid transaction format |
| 401 | INVALID_SIGNATURE | Signature verification failed |
| 402 | INSUFFICIENT_BALANCE | Insufficient encrypted balance |
| 500 | PROOF_FAILED | ZK proof generation failed |
| 501 | VERIFICATION_FAILED | On-chain verification failed |

---

## 7. WebSocket Communication Protocol

### User ↔ zkFisher Real-time Updates

```json
// Connection
{
  "type": "connect",
  "version": "1.0",
  "client_id": "0xUSER123..."
}

// Subscribe to transaction
{
  "type": "subscribe",
  "tx_id": "0x1a2b3c..."
}

// Status updates (pushed by zkFisher)
{
  "type": "tx_update",
  "tx_id": "0x1a2b3c...",
  "status": "TX_BATCHED",
  "block_id": "0xBLOCK...",
  "timestamp": 1699999999
}

{
  "type": "tx_update",
  "tx_id": "0x1a2b3c...",
  "status": "TX_CONFIRMED",
  "block_number": 4242,
  "snapshot_id": 42,
  "confirmations": 15
}
```

---

## 8. Security Considerations

### Data Integrity Checks

1. **Transaction Level**: ECDSA signature verification
2. **Block Level**: Merkle root validation
3. **Epoch Level**: Snapshot state commitment
4. **Proof Level**: Groth16 ZK proof verification
5. **State Level**: FHE computation verification

### Encrypted Data Flow

```
User Balance (FHE_Enc)
    ↓
Never decrypted at any point
    ↓
Zama FHE operations (on encrypted data)
    ↓
Updated Balance (FHE_Enc)
    ↓
Only user can decrypt with private key
```

---

## Summary

This communication scheme ensures:
- ✅ Complete privacy through end-to-end FHE encryption
- ✅ Trustless verification via ZK proofs
- ✅ Efficient batching and processing
- ✅ Gasless user experience
- ✅ Real-time status updates
- ✅ Secure state management
- ✅ Scalable architecture

The data never gets decrypted during the entire flow, ensuring complete confidentiality while maintaining verifiability through zero-knowledge proofs.

---

## 9. Privacy Schema - Public vs Private Inputs

This section defines the **privacy boundaries** for all data in EVVM, categorized into three tiers based on on-chain visibility.

### Privacy Tiers

| Tier | Description | On-Chain Visibility | Protection Method |
|------|-------------|---------------------|-------------------|
| **Observed** | Fully public on-chain | Yes - visible in calldata/storage | None - plaintext |
| **Committed** | Cryptographically bound but content hidden | Hash/Root only | Merkle commitment + signature |
| **Private** | Never revealed on-chain | No - encrypted or off-chain only | FHE encryption (Zama euint64) |

---

### 9.1 Transaction Data Schema

Based on `EVVMCore.sol` **PaymentParams** structure:

```solidity
struct PaymentParams {
    address from;                           // Observed
    address to;                             // Observed
    string toIdentity;                      // Observed
    address token;                          // Observed
    uint256 amountPlaintext;                // Committed (in signature only)
    externalEuint64 inputEncryptedAmount;   // Private (FHE handle)
    bytes inputAmountProof;                 // Observed (ZK proof)
    uint256 priorityFeePlaintext;           // Committed (in signature only)
    externalEuint64 inputEncryptedPriorityFee; // Private (FHE handle)
    bytes inputFeeProof;                    // Observed (ZK proof)
    uint256 nonce;                          // Observed
    bool priorityFlag;                      // Observed
    address executor;                       // Observed
    bytes signature;                        // Observed
}
```

#### Privacy Level Breakdown

| Field | Type | Privacy Tier | Notes |
|-------|------|--------------|-------|
| `from` | address | **Observed** | Sender identity public |
| `to` | address | **Observed** | Recipient public |
| `toIdentity` | string | **Observed** | Username resolution (optional) |
| `token` | address | **Observed** | Token contract address |
| `amountPlaintext` | uint256 | **Committed** | Only in signed message, never in calldata |
| `inputEncryptedAmount` | euint64 | **Private** | FHE-encrypted amount (Zama) |
| `inputAmountProof` | bytes | **Observed** | ZK proof that encryption is correct |
| `priorityFeePlaintext` | uint256 | **Committed** | Only in signed message |
| `inputEncryptedPriorityFee` | euint64 | **Private** | FHE-encrypted fee |
| `inputFeeProof` | bytes | **Observed** | ZK proof for fee |
| `nonce` | uint256 | **Observed** | Replay protection |
| `priorityFlag` | bool | **Observed** | Sync/async mode |
| `executor` | address | **Observed** | Transaction executor |
| `signature` | bytes | **Observed** | EIP-191 signature over committed data |

**What's Actually On-Chain (Calldata):**
```
from, to, toIdentity, token,
inputEncryptedAmount (handle only),
inputAmountProof,
inputEncryptedPriorityFee (handle only),
inputFeeProof,
nonce, priorityFlag, executor, signature
```

**Key Privacy Property:** Real amounts (`amountPlaintext`, `priorityFeePlaintext`) are **never** sent on-chain. They exist only:
1. Locally for encryption
2. In the signed message hash (commitment)
3. User can prove correctness via ZK proof

---

### 9.2 zkFisher Snapshot Schema

Every **epoch** (every X Arbitrum blocks), zkFisher commits a batch of transactions.

#### Merkle Leaf Structure (per transaction)

```rust
// Aztec/Noir Merkle leaf
struct TxLeaf {
    tx_hash: Field,                    // Committed
    encrypted_amount_handle: Field,    // Private (FHE handle)
    encrypted_fee_handle: Field,       // Private (FHE handle)
    amount_proof_hash: Field,          // Committed
    fee_proof_hash: Field,             // Committed
    signature_hash: Field,             // Committed
    nonce: Field,                      // Observed
    from: Field,                       // Observed
    to: Field,                         // Observed
}
```

#### Public Inputs (Noir → Groth16 Proof)

These inputs are **revealed on-chain** during snapshot verification:

| Public Input | Type | Purpose |
|--------------|------|---------|
| `old_merkle_root` | bytes32 | Previous epoch state commitment |
| `new_merkle_root` | bytes32 | New epoch state commitment |
| `epoch_number` | uint64 | Epoch counter |
| `block_hash` | bytes32 | Arbitrum "healthy block" anchor |
| `fisher_address` | address | Relayer receiving reward |

#### Private Inputs (Witness - Never On-Chain)

| Private Input | Purpose |
|---------------|---------|
| Transaction leaves (all fields) | Merkle tree construction |
| Merkle inclusion proofs | Prove each tx in tree |
| Signature recoveries | Verify all signatures |
| Validity checks | Nonce unused, proofs valid |

#### On-Chain Snapshot Submission

```solidity
// Stylus verifier call
verifySnapshot(
    bytes32 old_root,
    bytes32 new_root,
    uint64 epoch,
    bytes32 block_hash,
    Groth16Proof proof,  // ~256 bytes
    address fisher
)
```

**Privacy Result:** Only roots + metadata are public. Entire epoch's encrypted transactions remain invisible.

---

### 9.3 On-Chain State Schema

From `EVVMCore.sol` state variables:

| State Variable | Type | Privacy Tier | Notes |
|----------------|------|--------------|-------|
| `virtualBlocks[blockNum]` | VirtualBlock | **Mixed** | Hash public, data encrypted |
| `balances[user][token]` | euint64 | **Private** | FHE encrypted balances |
| `nextSyncUsedNonce[user]` | uint256 | **Observed** | Public nonce tracking |
| `asyncUsedNonce[user][nonce]` | bool | **Observed** | Public replay protection |
| `stakerList[address]` | bool | **Observed** | Public staker registry |
| `evvmMetadata.totalSupply` | euint64 | **Private** | Encrypted supply |
| `evvmMetadata.reward` | euint64 | **Private** | Encrypted reward amount |

**VirtualBlock Structure:**
```solidity
struct VirtualBlock {
    euint64 blockNumber;       // Private
    euint256 timestamp;        // Private
    euint256 gasLimit;         // Private
    address[] validators;      // Observed
    ebool isFinalized;         // Private
    bytes32 blockHash;         // Observed
}
```

---

### 9.4 Complete Privacy Flow

```
User Side (Off-Chain)
|-- amountPlaintext = 5 USDC               [Never leaves user device]
|-- encryptedAmount = FHE.encrypt(5)       [Private - handle sent]
|-- proof = ZK.prove(encrypted == 5)       [Observed - proof sent]
 -- signature = sign(hash(5, nonce, ...))  [Observed - sent]

On-Chain (Arbitrum)
|-- Receives: encryptedAmount handle       [Private]
|-- Receives: proof                        [Observed]
|-- Receives: signature                    [Observed]
|-- Verifies: proof valid                  [Contract execution]
|-- Verifies: signature valid              [Contract execution]
 -- Updates: balance[from] -= enc(5)       [Private - FHE operation]
            balance[to] += enc(5)          [Private - FHE operation]

zkFisher (Off-Chain)
|-- Collects: All encrypted tx handles     [Private]
|-- Builds: Merkle tree of tx hashes       [Committed]
|-- Generates: Groth16 proof               [Observed]
 -- Submits: merkle_root + proof           [Observed]

Arbitrum Noir Verifier
|-- Receives: merkle_root                  [Observed]
|-- Receives: Groth16 proof                [Observed]
|-- Verifies: proof                        [Contract execution]
 -- Commits: snapshot to state             [Observed]
```

---

### 9.5 Privacy Guarantees Summary

| Data | Visible to Blockchain | Visible to User | Visible to zkFisher | Visible to Anyone |
|------|----------------------|-----------------|---------------------|-------------------|
| Transaction amount | No | Yes (owns plaintext) | No | No |
| Encrypted handle | Yes (meaningless) | Yes | Yes | Yes |
| User balance | No | Yes (can decrypt) | No | No |
| From/To addresses | Yes | Yes | Yes | Yes |
| Merkle root | Yes | Yes | Yes | Yes |
| ZK proofs | Yes | Yes | Yes | Yes |

**Core Privacy Invariant:**
```
For all transactions t:
  amount_plaintext(t) NOT IN On-Chain Data
  amount_encrypted(t) IN On-Chain Data
  decrypt(amount_encrypted(t)) -> only by owner with FHE key
```

---

### 9.6 Gas Cost Comparison

| Operation | Gas Cost | Privacy Level |
|-----------|----------|---------------|
| Plain transfer (ERC20) | ~50k | None - public amounts |
| EVVM encrypted transfer | ~100k | Full - private amounts |
| zkFisher snapshot (per epoch) | ~30-50k | Full - batch commitment |
| Groth16 verification | ~250k | N/A - proof verification |

**Privacy Cost:** ~2x gas for full confidentiality via FHE operations.

---

### 9.7 Security Properties

1. **Computational Privacy**: Encrypted data is secure under FHE assumptions (Zama TFHE)
2. **Integrity**: All state transitions proven via ZK (Groth16)
3. **Non-Repudiation**: Signatures bind plaintext commitments
4. **Replay Protection**: Nonce management prevents replay attacks
5. **Auditability**: Merkle roots enable proof of inclusion
6. **Liveness**: Honest zkFisher can always progress epochs

---

## Summary

The EVVM privacy schema achieves **complete confidentiality** of financial data while maintaining:
- Trustless verification via ZK proofs
- Public auditability via Merkle commitments
- Efficient batching via epochs (~30-50k gas per epoch)
- Gasless UX via relayer subsidy
- Regulatory compliance option via selective disclosure (user can prove amounts)

**Trade-off:** ~2x gas cost vs. plain ERC20, but infinite privacy gain.

