//! CoFHE Operations API
//!
//! High-level API for CoFHE operations that replicates FHE.sol library functions.
//! This module provides convenient wrappers around ITaskManager calls.

use crate::cofhe_interfaces::{ITaskManager, FunctionId, InEuint64, InEuint8, InEuint32, InEuint256, EncryptedInput, Utils};
use crate::types::{Euint64, Euint8, Euint32, Euint256, Ebool};
use stylus_sdk::call::Call;
use stylus_sdk::alloy_primitives::{Address, U256};
use stylus_sdk::msg;
use alloc::vec::Vec;
use alloc::vec;

/// Errors that can occur during CoFHE operations
#[derive(Debug)]
pub enum CoFHEError {
    /// TaskManager call failed
    TaskManagerCallFailed,
    /// Invalid input provided
    InvalidInput,
    /// Access denied
    AccessDenied,
    /// Operation failed
    OperationFailed,
}

/// Main CoFHE operations struct
///
/// Provides high-level API similar to FHE.sol library
pub struct CoFHE;

impl CoFHE {
    /// Convert encrypted input to euint64
    ///
    /// Equivalent to `FHE.asEuint64(InEuint64 memory input)` in Solidity
    pub fn as_euint64(
        input: InEuint64,
        task_manager: Address
    ) -> Result<Euint64, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        // Convert InEuint64 to EncryptedInput
        let encrypted_input = EncryptedInput {
            ct_hash: input.ct_hash,
            security_zone: input.security_zone,
            utype: Utils::EUINT64_TFHE,
            signature: input.signature,
        };
        
        // Call verifyInput
        let result = tm.verifyInput(
            Call::new(),
            encrypted_input.ct_hash,
            encrypted_input.security_zone,
            encrypted_input.utype,
            encrypted_input.signature.into(),
            msg::sender()
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint64::from(result))
    }
    
    /// Convert encrypted input to euint8
    pub fn as_euint8(
        input: InEuint8,
        task_manager: Address
    ) -> Result<Euint8, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let encrypted_input = EncryptedInput {
            ct_hash: input.ct_hash,
            security_zone: input.security_zone,
            utype: Utils::EUINT8_TFHE,
            signature: input.signature,
        };
        
        let result = tm.verifyInput(
            Call::new(),
            encrypted_input.ct_hash,
            encrypted_input.security_zone,
            encrypted_input.utype,
            encrypted_input.signature.into(),
            msg::sender()
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint8::from(result))
    }
    
    /// Convert encrypted input to euint32
    pub fn as_euint32(
        input: InEuint32,
        task_manager: Address
    ) -> Result<Euint32, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let encrypted_input = EncryptedInput {
            ct_hash: input.ct_hash,
            security_zone: input.security_zone,
            utype: Utils::EUINT32_TFHE,
            signature: input.signature,
        };
        
        let result = tm.verifyInput(
            Call::new(),
            encrypted_input.ct_hash,
            encrypted_input.security_zone,
            encrypted_input.utype,
            encrypted_input.signature.into(),
            msg::sender()
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint32::from(result))
    }
    
    /// Convert encrypted input to euint256
    pub fn as_euint256(
        input: InEuint256,
        task_manager: Address
    ) -> Result<Euint256, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let encrypted_input = EncryptedInput {
            ct_hash: input.ct_hash,
            security_zone: input.security_zone,
            utype: Utils::EUINT256_TFHE,
            signature: input.signature,
        };
        
        let result = tm.verifyInput(
            Call::new(),
            encrypted_input.ct_hash,
            encrypted_input.security_zone,
            encrypted_input.utype,
            encrypted_input.signature.into(),
            msg::sender()
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint256::from(result))
    }
    
    /// Convert boolean to ebool
    ///
    /// Equivalent to `FHE.asEbool(bool value)` in Solidity
    /// Uses trivialEncrypt internally
    pub fn as_ebool(
        value: bool,
        task_manager: Address
    ) -> Result<Ebool, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        // Use trivialEncrypt to create encrypted bool
        let value_uint = if value { U256::from(1) } else { U256::from(0) };
        let result = tm.createTask(
            Call::new(),
            Utils::EBOOL_TFHE,
            FunctionId::TrivialEncrypt as u8,
            Vec::new(),  // encryptedInputs (empty for trivialEncrypt)
            vec![value_uint, U256::from(Utils::EBOOL_TFHE), U256::from(0)],  // extraInputs: value, type, securityZone
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Ebool::from(result))
    }
    
    /// Add two encrypted integers
    ///
    /// Equivalent to `FHE.add(euint64 lhs, euint64 rhs)` in Solidity
    pub fn add(
        lhs: Euint64,
        rhs: Euint64,
        task_manager: Address
    ) -> Result<Euint64, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let result = tm.createTask(
            Call::new(),
            Utils::EUINT64_TFHE,
            FunctionId::Add as u8,
            vec![lhs.into_inner(), rhs.into_inner()],  // encryptedInputs
            Vec::new(),  // extraInputs
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint64::from(result))
    }
    
    /// Subtract two encrypted integers (lhs - rhs)
    pub fn sub(
        lhs: Euint64,
        rhs: Euint64,
        task_manager: Address
    ) -> Result<Euint64, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let result = tm.createTask(
            Call::new(),
            Utils::EUINT64_TFHE,
            FunctionId::Sub as u8,
            vec![lhs.into_inner(), rhs.into_inner()],
            Vec::new(),
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint64::from(result))
    }
    
    /// Multiply two encrypted integers
    pub fn mul(
        lhs: Euint64,
        rhs: Euint64,
        task_manager: Address
    ) -> Result<Euint64, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let result = tm.createTask(
            Call::new(),
            Utils::EUINT64_TFHE,
            FunctionId::Mul as u8,
            vec![lhs.into_inner(), rhs.into_inner()],
            Vec::new(),
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint64::from(result))
    }
    
    /// Encrypted equality comparison
    pub fn eq(
        lhs: Euint256,
        rhs: Euint256,
        task_manager: Address
    ) -> Result<Ebool, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let result = tm.createTask(
            Call::new(),
            Utils::EBOOL_TFHE,
            FunctionId::Eq as u8,
            vec![lhs.into_inner(), rhs.into_inner()],
            Vec::new(),
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Ebool::from(result))
    }
    
    /// Encrypted AND operation
    pub fn and(
        lhs: Ebool,
        rhs: Ebool,
        task_manager: Address
    ) -> Result<Ebool, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let result = tm.createTask(
            Call::new(),
            Utils::EBOOL_TFHE,
            FunctionId::And as u8,
            vec![lhs.into_inner(), rhs.into_inner()],
            Vec::new(),
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Ebool::from(result))
    }
    
    /// Encrypted OR operation
    pub fn or(
        lhs: Ebool,
        rhs: Ebool,
        task_manager: Address
    ) -> Result<Ebool, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let result = tm.createTask(
            Call::new(),
            Utils::EBOOL_TFHE,
            FunctionId::Or as u8,
            vec![lhs.into_inner(), rhs.into_inner()],
            Vec::new(),
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Ebool::from(result))
    }
    
    /// Conditional selection: if condition then ifTrue else ifFalse
    pub fn select(
        condition: Ebool,
        if_true: Euint32,
        if_false: Euint32,
        task_manager: Address
    ) -> Result<Euint32, CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let result = tm.createTask(
            Call::new(),
            Utils::EUINT32_TFHE,
            FunctionId::Select as u8,
            vec![condition.into_inner(), if_true.into_inner(), if_false.into_inner()],
            Vec::new(),
        ).map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(Euint32::from(result))
    }
    
    /// Allow contract to access encrypted value
    ///
    /// Equivalent to `FHE.allowThis(euint64 ct)` in Solidity
    pub fn allow_this(
        ct: Euint64,
        task_manager: Address
    ) -> Result<(), CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        // allowGlobal allows the contract itself
        tm.allowGlobal(Call::new(), ct.into_inner())
            .map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(())
    }
    
    /// Allow sender to access encrypted value
    ///
    /// Equivalent to `FHE.allowSender(euint64 ct)` in Solidity
    pub fn allow_sender(
        ct: Euint64,
        task_manager: Address
    ) -> Result<(), CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        tm.allow(Call::new(), ct.into_inner(), msg::sender())
            .map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(())
    }
    
    /// Allow specific address to access encrypted value
    ///
    /// Equivalent to `FHE.allow(euint64 ct, address account)` in Solidity
    pub fn allow(
        ct: Euint64,
        account: Address,
        task_manager: Address
    ) -> Result<(), CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        tm.allow(Call::new(), ct.into_inner(), account)
            .map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(())
    }
    
    /// Request decryption of encrypted value
    ///
    /// Equivalent to `FHE.decrypt(euint64 ct)` in Solidity
    pub fn decrypt(
        ct: Euint64,
        task_manager: Address
    ) -> Result<(), CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        tm.createDecryptTask(Call::new(), ct.into_inner(), msg::sender())
            .map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok(())
    }
    
    /// Get decryption result safely
    ///
    /// Equivalent to `FHE.getDecryptResultSafe(euint64 ct)` in Solidity
    pub fn get_decrypt_result_safe(
        ct: Euint64,
        task_manager: Address
    ) -> Result<(U256, bool), CoFHEError> {
        let tm = ITaskManager::new(task_manager);
        
        let (result, decrypted) = tm.getDecryptResultSafe(Call::new(), ct.into_inner())
            .map_err(|_| CoFHEError::TaskManagerCallFailed)?;
        
        Ok((result, decrypted))
    }
}

// Re-export for convenience
pub use CoFHEError as Error;

