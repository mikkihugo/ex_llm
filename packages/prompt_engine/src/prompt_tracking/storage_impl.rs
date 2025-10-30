//! Pure computation storage for prompt execution tracking
//!
//! This module provides pure computation functions for prompt tracking.
//! All data is passed in via parameters and returned as results.
//! No I/O operations - designed for NIF usage.
//!
//! NOTE: NATS-based storage disabled (Phase 4 NATS removal)
//! Use ex_pgflow/pgmq via Elixir for persistent storage

use crate::prompt_tracking::types::{PromptExecutionData, PromptTrackingQuery};
use anyhow::Error;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Pure computation prompt tracking storage
///
/// This struct holds tracking data in memory for the current computation.
/// No persistent storage - data is passed in via NIF parameters.
#[derive(Clone)]
pub struct PromptTrackingStorage {
    /// In-memory cache of execution data
    executions: HashMap<String, PromptExecution>,
    /// In-memory cache of feedback data
    feedback: HashMap<String, PromptFeedback>,
    /// In-memory cache of context signatures
    context_signatures: HashMap<String, ContextSignature>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptExecution {
    pub id: String,
    pub prompt_id: String,
    pub input: String,
    pub output: String,
    pub execution_time_ms: u64,
    pub success: bool,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptFeedback {
    pub id: String,
    pub execution_id: String,
    pub rating: f64,
    pub comments: String,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContextSignature {
    pub id: String,
    pub signature: String,
    pub context_hash: String,
    pub metadata: HashMap<String, String>,
}

impl PromptTrackingStorage {
    /// Create new prompt tracking storage
    pub fn new() -> Result<Self> {
        Ok(Self {
            executions: HashMap::new(),
            feedback: HashMap::new(),
            context_signatures: HashMap::new(),
        })
    }

    /// Create global instance with NATS client (for NIF usage)
    /// NOTE: NATS disabled - use ex_pgflow/pgmq via Elixir for persistent storage
    pub async fn new_global() -> Result<Self> {
        // NATS-based storage disabled - use local cache with Elixir integration
        log::info!("PromptTrackingStorage using local cache (NATS disabled, use ex_pgflow/pgmq via Elixir)");

        Ok(Self {
            executions: HashMap::new(),
            feedback: HashMap::new(),
            context_signatures: HashMap::new(),
        })
    }

    /// Store execution in memory
    pub fn store_execution(&mut self, execution: PromptExecution) -> Result<()> {
        self.executions.insert(execution.id.clone(), execution);
        Ok(())
    }

    /// Store feedback in memory
    pub fn store_feedback(&mut self, feedback: PromptFeedback) -> Result<()> {
        self.feedback.insert(feedback.id.clone(), feedback);
        Ok(())
    }

    /// Store context signature in memory
    pub fn store_context_signature(&mut self, signature: ContextSignature) -> Result<()> {
        self.context_signatures
            .insert(signature.id.clone(), signature);
        Ok(())
    }

    /// Async store method for NIF compatibility
    /// NOTE: NATS-based storage disabled (Phase 4 NATS removal)
    /// Use ex_pgflow/pgmq via Elixir for persistent storage
    pub async fn store(&self, _data: PromptExecutionData) -> Result<String, Error> {
        // NATS-based storage disabled - use in-memory stub with Elixir integration
        // Generate correlation ID
        let correlation_id = format!("store_{}", uuid::Uuid::new_v4());
        Ok(correlation_id)
    }

    /// Async query method for NIF compatibility
    /// NOTE: NATS-based storage disabled (Phase 4 NATS removal)
    /// Use ex_pgflow/pgmq via Elixir for persistent storage
    pub async fn query(
        &self,
        _query: PromptTrackingQuery,
    ) -> Result<Vec<PromptExecutionData>, Error> {
        // NATS-based storage disabled - return empty results with Elixir integration
        // For persistent queries, use ex_pgflow/pgmq via Elixir
        Ok(Vec::new())
    }

    /// Get execution by ID
    pub fn get_execution(&self, id: &str) -> Option<&PromptExecution> {
        self.executions.get(id)
    }

    /// Get feedback by ID
    pub fn get_feedback(&self, id: &str) -> Option<&PromptFeedback> {
        self.feedback.get(id)
    }

    /// Get context signature by ID
    pub fn get_context_signature(&self, id: &str) -> Option<&ContextSignature> {
        self.context_signatures.get(id)
    }

    /// Get all executions
    pub fn get_all_executions(&self) -> Vec<&PromptExecution> {
        self.executions.values().collect()
    }

    /// Get all feedback
    pub fn get_all_feedback(&self) -> Vec<&PromptFeedback> {
        self.feedback.values().collect()
    }

    /// Get statistics
    pub fn get_stats(&self) -> StorageStats {
        StorageStats {
            execution_count: self.executions.len(),
            feedback_count: self.feedback.len(),
            context_signature_count: self.context_signatures.len(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct StorageStats {
    pub execution_count: usize,
    pub feedback_count: usize,
    pub context_signature_count: usize,
}

impl Default for PromptTrackingStorage {
    fn default() -> Self {
        Self::new().unwrap()
    }
}
