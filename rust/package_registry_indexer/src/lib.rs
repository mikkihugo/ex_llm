#![allow(unused)]
#![allow(clippy::multiple_crate_versions)]
//! # FACT - Fast Augmented Context Tools
//!
//! A high-performance context processing engine for Rust.
//!
//! ## Features
//!
//! - **High Performance**: Optimized data structures and algorithms
//! - **Intelligent Caching**: Multi-tier caching with LRU eviction
//! - **Cognitive Templates**: Pre-built templates for common patterns
//! - **Async Support**: Full async/await support with Tokio
//! - **Cross-Platform**: Works on Linux, macOS, and Windows
//!
//! ## Example
//!
//! ```rust
//! use fact_tools::Fact;
//!
//! # async fn example() -> Result<(), Box<dyn std::error::Error>> {
//! // Create a new FACT instance
//! let fact = Fact::new();
//!
//! // Process with a template
//! let result = fact.process(
//!     "analysis-basic",
//!     serde_json::json!({
//!         "data": [1, 2, 3, 4, 5],
//!         "operation": "sum"
//!     })
//! ).await?;
//!
//! println!("Result: {}", result);
//! # Ok(())
//! # }
//! ```
//!
//! ## Native Node.js Module Example
//!
//! ```typescript
//! import { FactNativeModule } from './fact-native-bindings';
//! const factModule = new FactNativeModule();
//! const result = await factModule.process('analysis-basic', { data: [1, 2, 3] });
//! console.log(result);
//! ```

use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use thiserror::Error;

pub mod auto_orchestrator;
pub mod cache;
pub mod engine;
pub mod processor;
pub mod template;

// Native module bindings will be handled separately

// Only export GitHub module when feature is enabled
#[cfg(feature = "github")]
pub mod github;

// Only export GraphQL module when feature is enabled
#[cfg(feature = "github-graphql")]
pub mod graphql;

// Storage modules
pub mod storage;

// NEW: Vector embeddings and search
pub mod embedding;
pub mod search;

// NEW: Package collectors - download and analyze packages from registries
pub mod collector;

// NEW: Code snippet extractor - temporary analysis for extraction
pub mod extractor;

// NEW: Framework detection (optional feature)
#[cfg(feature = "detection")]
pub mod detection;

// NEW: Prompt management (will connect to detection)
#[cfg(feature = "detection")]
pub mod prompts;

pub use cache::{Cache, CacheStats};
pub use engine::{EngineConfig, EngineFact, ProcessingOptions};
pub use processor::QueryExecutor;
pub use template::{RegistryTemplate, Template};

// Conditional exports
#[cfg(feature = "github")]
pub use github::{GitHubAnalyzer, RepoAnalysis, RepoInfo};

#[cfg(feature = "github-graphql")]
pub use graphql::{GitHubGraphQLClient, GitHubVersionAnalysis};

// Auto orchestrator - use correct export name
#[cfg(feature = "auto")]
pub use auto_orchestrator::AutoFactOrchestrator;

// Storage - filesystem-based global facts storage
// Export storage traits/helpers; filesystem backend is internal
pub use storage::{create_storage, FactStorage, StorageConfig};

// NEW: Embeddings and search
pub use embedding::EmbeddingGenerator;
pub use search::{IndexStats, VectorIndex};

// NEW: Detection and prompts (optional)
#[cfg(feature = "detection")]
pub use detection::{
  DetectionMethod, DetectionResult, FrameworkDetector, FrameworkInfo,
  TechnologyDetector,
};

/// Result type for FACT operations
pub type Result<T> = std::result::Result<T, FactError>;

/// Errors that can occur in FACT operations
#[derive(Error, Debug)]
pub enum FactError {
  #[error("Template not found: {0}")]
  TemplateNotFound(String),

  #[error("Processing error: {0}")]
  ProcessingError(String),

  #[error("Serialization error: {0}")]
  SerializationError(#[from] serde_json::Error),

  #[error("IO error: {0}")]
  IoError(#[from] std::io::Error),

  #[error("Cache error: {0}")]
  CacheError(String),

  #[error("Timeout exceeded: {0:?}")]
  Timeout(Duration),
}

/// Main entry point for FACT functionality
pub struct Fact {
  engine: EngineFact,
  cache: Arc<RwLock<Cache>>,
}

impl Fact {
  /// Create a new FACT instance
  #[must_use]
  pub fn new() -> Self {
    Self {
      engine: EngineFact::new(),
      cache: Arc::new(RwLock::new(Cache::new())),
    }
  }

  /// Create a new FACT instance with custom configuration
  #[must_use]
  pub fn with_config(config: FactConfig) -> Self {
    Self {
      engine: EngineFact::with_config(config.engine_config),
      cache: Arc::new(RwLock::new(Cache::with_capacity(config.cache_size))),
    }
  }

  /// Process a query using a cognitive template
  /// Process a template with the given context
  ///
  /// # Errors
  /// Returns an error if template processing fails or template is not found
  pub async fn process(
    &self,
    template_id: &str,
    context: serde_json::Value,
  ) -> Result<serde_json::Value> {
    // Check cache first
    let cache_key = Self::generate_cache_key(template_id, &context);

    // Need to use write lock for get() since it updates access stats
    let cached_value = self.cache.write().get(&cache_key);
    if let Some(cached) = cached_value {
      return Ok(cached);
    }

    // Process with engine
    let result = self.engine.process(template_id, context).await?;

    // Cache the result
    self.cache.write().put(cache_key, result.clone());

    Ok(result)
  }

  /// Get cache statistics
  #[must_use]
  pub fn cache_stats(&self) -> CacheStats {
    self.cache.read().stats()
  }

  /// Clear the cache
  pub fn clear_cache(&self) {
    self.cache.write().clear();
  }

  fn generate_cache_key(
    template_id: &str,
    context: &serde_json::Value,
  ) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let mut hasher = DefaultHasher::new();
    template_id.hash(&mut hasher);
    context.to_string().hash(&mut hasher);

    format!("fact:{}:{:x}", template_id, hasher.finish())
  }
}

impl Default for Fact {
  fn default() -> Self {
    Self::new()
  }
}

/// Configuration for FACT
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FactConfig {
  /// Engine configuration
  pub engine_config: engine::EngineConfig,

  /// Cache size in bytes
  pub cache_size: usize,

  /// Enable performance monitoring
  pub enable_monitoring: bool,

  /// Maximum processing timeout
  pub timeout: Option<Duration>,
}

impl Default for FactConfig {
  fn default() -> Self {
    Self {
      engine_config: EngineConfig::default(),
      cache_size: 100 * 1024 * 1024, // 100MB
      enable_monitoring: true,
      timeout: Some(Duration::from_secs(30)),
    }
  }
}

/// Performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Metrics {
  pub total_requests: u64,
  pub cache_hits: u64,
  pub cache_misses: u64,
  pub avg_processing_time_ms: f64,
  pub error_count: u64,
}
