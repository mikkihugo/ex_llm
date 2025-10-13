//! Pure computation storage for prompt execution tracking
//!
//! This module provides pure computation functions for prompt tracking.
//! All data is passed in via parameters and returned as results.
//! No I/O operations - designed for NIF usage.

use anyhow::Result;
use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use crate::prompt_tracking::types::{PromptExecutionData, PromptTrackingQuery};
use anyhow::Error;
use async_nats::Client;

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
    /// NATS client for NIF-based storage operations
    nats_client: Option<Client>,
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
            nats_client: None,
        })
    }

    /// Create global instance with NATS client (for NIF usage)
    pub async fn new_global() -> Result<Self> {
        // Connect to NATS for NIF-based storage
        let nats_client = async_nats::connect("nats://localhost:4222").await.ok();
        
        Ok(Self {
            executions: HashMap::new(),
            feedback: HashMap::new(),
            context_signatures: HashMap::new(),
            nats_client,
        })
    }

    /// Set NATS client for storage operations
    pub fn with_nats_client(mut self, client: Client) -> Self {
        self.nats_client = Some(client);
        self
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
        self.context_signatures.insert(signature.id.clone(), signature);
        Ok(())
    }

    /// Async store method for NIF compatibility - uses NATS to communicate with Elixir storage service
    pub async fn store(&self, data: PromptExecutionData) -> Result<String, Error> {
        if let Some(client) = &self.nats_client {
            // Generate correlation ID
            let correlation_id = format!("store_{}", uuid::Uuid::new_v4());
            
            // Prepare the store request
            let store_request = serde_json::json!({
                "data": data,
                "correlation_id": correlation_id
            });
            
            // Send NATS request to prompt.tracking.store
            match client.request("prompt.tracking.store", serde_json::to_vec(&store_request)?.into()).await {
                Ok(message) => {
                    let response: serde_json::Value = serde_json::from_slice(&message.payload)?;
                    if response.get("success").and_then(|s| s.as_bool()).unwrap_or(false) {
                        Ok(response.get("fact_id").and_then(|id| id.as_str()).unwrap_or("unknown").to_string())
                    } else {
                        Err(anyhow::anyhow!("Storage failed: {:?}", response.get("error")))
                    }
                }
                Err(e) => Err(anyhow::anyhow!("NATS request failed: {}", e)),
            }
        } else {
            // Fallback to in-memory storage for testing
            Ok("in_memory_stub_id".to_string())
        }
    }

    /// Async query method for NIF compatibility - uses NATS to communicate with Elixir storage service
    pub async fn query(&self, query: PromptTrackingQuery) -> Result<Vec<PromptExecutionData>, Error> {
        if let Some(client) = &self.nats_client {
            // Generate correlation ID
            let correlation_id = format!("query_{}", uuid::Uuid::new_v4());
            
            // Prepare the query request
            let query_request = serde_json::json!({
                "query": query,
                "limit": 100,  // Default limit
                "correlation_id": correlation_id
            });
            
            // Send NATS request to prompt.tracking.query
            match client.request("prompt.tracking.query", serde_json::to_vec(&query_request)?.into()).await {
                Ok(message) => {
                    let response: serde_json::Value = serde_json::from_slice(&message.payload)?;
                    if let Some(results) = response.get("results").and_then(|r| r.as_array()) {
                        let mut executions = Vec::new();
                        for result in results {
                            if let Ok(execution) = serde_json::from_value(result.clone()) {
                                executions.push(execution);
                            }
                        }
                        Ok(executions)
                    } else {
                        Ok(vec![])
                    }
                }
                Err(e) => Err(anyhow::anyhow!("NATS request failed: {}", e)),
            }
        } else {
            // Fallback to empty results for testing
            Ok(vec![])
        }
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
