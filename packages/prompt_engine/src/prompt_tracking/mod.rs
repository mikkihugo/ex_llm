//! Prompt tracking module for prompt-engine
//!
//! **Global Cross-Project Prompt Execution Tracking**
//!
//! Provides intelligent storage and retrieval of prompt execution data
//! using NATS for communication with the Elixir storage service.
//!
//! ## Storage Architecture
//!
//! - **prompt_tracking** (this module): Global cross-project prompt execution tracking
//!   - Communication: NATS subjects (`prompt.tracking.store`, `prompt.tracking.query`)
//!   - Storage: PostgreSQL via Elixir service
//!   - Stores: Prompt executions, feedback, evolutions, A/B tests, learned patterns
//!
//! - **code_engine::CodeStorage**: Per-project code analysis
//!   - Location: Per-project storage
//!   - Stores: Parsed code, metrics, dependencies, VectorDAG
//!
//! This separation keeps prompt execution tracking focused on learning and optimization.

pub mod storage;
pub mod storage_impl;
pub mod types;

pub use storage::PromptTrackingStorage;
pub use types::*;

use std::collections::HashMap;

use anyhow::Result;

/// Initialize the prompt tracking system for prompt-engine using global storage
pub async fn initialize_prompt_tracking() -> Result<PromptTrackingStorage> {
    PromptTrackingStorage::new_global().await
}

/// Initialize the prompt tracking system with custom path (for testing/backward compatibility)
pub async fn initialize_prompt_tracking_custom(
    storage_path: impl AsRef<std::path::Path>,
) -> Result<PromptTrackingStorage> {
    // For backward compatibility, we ignore the custom path and use global storage
    // The path parameter is kept for API compatibility but not currently used
    // since storage is handled via NATS to the Elixir service
    let _path = storage_path.as_ref();
    PromptTrackingStorage::new_global().await
}

/// Quick helper to store a prompt execution
pub async fn track_execution(
    storage: &PromptTrackingStorage,
    prompt_id: &str,
    context_hash: &str,
    success: bool,
    duration: std::time::Duration,
) -> Result<String> {
    let execution_data = PromptExecutionData::PromptExecution(PromptExecutionEntry {
        prompt_id: prompt_id.to_string(),
        execution_time_ms: duration.as_millis() as u64,
        success,
        confidence_score: if success { 1.0 } else { 0.0 },
        context_signature: context_hash.to_string(),
        response_length: 0,
        timestamp: chrono::Utc::now(),
        metadata: HashMap::new(),
    });

    storage.store(execution_data).await
}
