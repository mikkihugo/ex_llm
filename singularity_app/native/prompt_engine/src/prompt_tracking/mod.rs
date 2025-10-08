//! Prompt tracking module for prompt-engine
//!
//! **Global Cross-Project Prompt Execution Tracking**
//!
//! Provides intelligent storage and retrieval of prompt execution data
//! using redb for performance-critical data and JSON for git-trackable prompt definitions.
//!
//! ## Storage Separation
//!
//! - **prompt_tracking** (this module): Global cross-project prompt execution tracking
//!   - Location: `~/.cache/sparc-engine/global/prompt_tracking.redb`
//!   - Stores: Prompt executions, feedback, evolutions, A/B tests
//!
//! - **analysis-suite::CodeStorage**: Per-project code analysis
//!   - Location: `~/.cache/sparc-engine/<project-id>/code_storage.redb`
//!   - Stores: Parsed code, metrics, dependencies, VectorDAG
//!
//! - **fact-system** (external): GitHub code snippet downloads
//!   - Location: `~/.primecode/facts/`
//!   - Stores: GitHub snippets, documentation, examples
//!
//! This separation prevents duplication and keeps concerns focused.

pub mod storage;
pub mod storage_impl;
pub mod types;

pub use storage::PromptTrackingStorage;
pub use types::*;

// Backward compatibility aliases
pub type FactStorage = PromptTrackingStorage;
// Framework detection is now handled by the unified detector in sparc-engine

use std::collections::HashMap;

use anyhow::Result;

/// Initialize the prompt tracking system for prompt-engine using global storage
pub async fn initialize_prompt_tracking() -> Result<PromptTrackingStorage> {
  PromptTrackingStorage::new_global()
}

/// Initialize the prompt tracking system with custom path (for testing/backward compatibility)
pub async fn initialize_prompt_tracking_custom(storage_path: impl AsRef<std::path::Path>) -> Result<PromptTrackingStorage> {
  PromptTrackingStorage::new(storage_path)
}

/// Quick helper to store a prompt execution
pub async fn track_execution(
  storage: &PromptTrackingStorage,
  prompt_id: &str,
  context_hash: &str,
  success: bool,
  duration: std::time::Duration,
) -> Result<String> {
  let execution_data = PromptExecutionData::PromptExecution(PromptExecutionFact {
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
