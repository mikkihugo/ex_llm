//! Configuration for codebase analysis
//!
//! Unified configuration structure for all codebase operations.

use serde::{Deserialize, Serialize};
use std::time::Duration;
use universal_parser::UniversalParserFrameworkConfig;

/// Unified configuration for codebase analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodebaseConfig {
  /// Vector configuration
  pub vectors: VectorConfig,
  /// Graph configuration
  pub graphs: GraphConfig,
  /// Storage configuration
  pub storage: StorageConfig,
  /// Performance configuration
  pub performance: PerformanceConfig,
  /// Analysis configuration
  pub analysis: UniversalParserFrameworkConfig,
}

impl Default for CodebaseConfig {
  fn default() -> Self {
    Self {
      vectors: VectorConfig::default(),
      graphs: GraphConfig::default(),
      storage: StorageConfig::default(),
      performance: PerformanceConfig::default(),
      analysis: UniversalParserFrameworkConfig::default(),
    }
  }
}

// AnalysisConfig moved to universal-parser - use UniversalParserFrameworkConfig instead

/// Vector analysis configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VectorConfig {
  /// Vector dimensions
  pub dimensions: usize,
  /// Model type for vectorization
  pub model_type: String,
  /// Enable TF-IDF weighting
  pub enable_tfidf: bool,
  /// Minimum word length for tokenization
  pub min_word_length: usize,
  /// Enable semantic similarity search
  pub enable_similarity_search: bool,
  /// Similarity threshold for search
  pub similarity_threshold: f32,
  /// Maximum similarity results
  pub max_similarity_results: usize,
}

impl Default for VectorConfig {
  fn default() -> Self {
    Self {
      dimensions: 128,
      model_type: "tfidf".to_string(),
      enable_tfidf: true,
      min_word_length: 3,
      enable_similarity_search: true,
      similarity_threshold: 0.7,
      max_similarity_results: 10,
    }
  }
}

/// Graph analysis configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphConfig {
  /// Enable PageRank calculation
  pub enable_pagerank: bool,
  /// PageRank damping factor
  pub pagerank_damping: f64,
  /// PageRank max iterations
  pub pagerank_max_iterations: usize,
  /// PageRank convergence threshold
  pub pagerank_convergence: f64,
  /// Enable cycle detection
  pub enable_cycle_detection: bool,
  /// Enable topological sorting
  pub enable_topological_sort: bool,
  /// Enable dependency analysis
  pub enable_dependency_analysis: bool,
}

impl Default for GraphConfig {
  fn default() -> Self {
    Self {
      enable_pagerank: true,
      pagerank_damping: 0.85,
      pagerank_max_iterations: 100,
      pagerank_convergence: 1e-6,
      enable_cycle_detection: true,
      enable_topological_sort: true,
      enable_dependency_analysis: true,
    }
  }
}

/// Storage configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageConfig {
  /// Enable persistent storage
  pub enable_persistence: bool,
  /// Storage directory path
  pub storage_path: String,
  /// Enable compression
  pub enable_compression: bool,
  /// Compression level (1-9)
  pub compression_level: u8,
  /// Enable encryption
  pub enable_encryption: bool,
  /// Maximum cache size (entries)
  pub max_cache_size: usize,
  /// Cache eviction policy
  pub cache_eviction_policy: CacheEvictionPolicy,
}

impl Default for StorageConfig {
  fn default() -> Self {
    Self {
      enable_persistence: true,
      storage_path: "~/.cache/sparc-engine/codebase".to_string(),
      enable_compression: true,
      compression_level: 6,
      enable_encryption: false,
      max_cache_size: 10000,
      cache_eviction_policy: CacheEvictionPolicy::LRU,
    }
  }
}

/// Performance monitoring configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceConfig {
  /// Enable performance monitoring
  pub enable_monitoring: bool,
  /// Enable profiling
  pub enable_profiling: bool,
  /// Profiling sampling interval
  pub profiling_interval: Duration,
  /// Maximum profiling stack depth
  pub max_profiling_depth: usize,
  /// Enable memory monitoring
  pub enable_memory_monitoring: bool,
  /// Memory monitoring interval
  pub memory_monitoring_interval: Duration,
  /// Enable anomaly detection
  pub enable_anomaly_detection: bool,
  /// Anomaly detection threshold
  pub anomaly_threshold: f64,
}

impl Default for PerformanceConfig {
  fn default() -> Self {
    Self {
      enable_monitoring: true,
      enable_profiling: false,
      profiling_interval: Duration::from_millis(100),
      max_profiling_depth: 10,
      enable_memory_monitoring: true,
      memory_monitoring_interval: Duration::from_secs(5),
      enable_anomaly_detection: true,
      anomaly_threshold: 2.0, // 2 standard deviations
    }
  }
}

/// Cache eviction policy
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CacheEvictionPolicy {
  /// Least Recently Used
  LRU,
  /// Least Frequently Used
  LFU,
  /// First In First Out
  FIFO,
  /// Random eviction
  Random,
}

impl Default for CacheEvictionPolicy {
  fn default() -> Self {
    Self::LRU
  }
}

/// Configuration builder for easy setup
pub struct CodebaseConfigBuilder {
  config: CodebaseConfig,
}

impl CodebaseConfigBuilder {
  /// Create a new configuration builder
  pub fn new() -> Self {
    Self {
      config: CodebaseConfig::default(),
    }
  }

  /// Set analysis configuration
  pub fn analysis(mut self, config: AnalysisConfig) -> Self {
    self.config.analysis = config;
    self
  }

  /// Set vector configuration
  pub fn vectors(mut self, config: VectorConfig) -> Self {
    self.config.vectors = config;
    self
  }

  /// Set graph configuration
  pub fn graphs(mut self, config: GraphConfig) -> Self {
    self.config.graphs = config;
    self
  }

  /// Set storage configuration
  pub fn storage(mut self, config: StorageConfig) -> Self {
    self.config.storage = config;
    self
  }

  /// Set performance configuration
  pub fn performance(mut self, config: PerformanceConfig) -> Self {
    self.config.performance = config;
    self
  }

  /// Build the final configuration
  pub fn build(self) -> CodebaseConfig {
    self.config
  }
}

impl Default for CodebaseConfigBuilder {
  fn default() -> Self {
    Self::new()
  }
}