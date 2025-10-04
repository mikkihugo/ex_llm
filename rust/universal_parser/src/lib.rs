//! # Universal Parser Framework
//!
//! Unified dependency layer and interfaces for all language parsers in the SPARC Engine.
//! This crate provides:
//!
//! - **Universal Dependencies**: Shared `tokei`, our Mozilla code analysis port, and tree-sitter integration
//! - **Standardized Interfaces**: Common traits and types for all language parsers
//! - **Performance Optimizations**: Caching, async execution, and memory management
//! - **Error Handling**: Consistent error types and recovery patterns
//!
//! ## Architecture
//!
//! ```text
//! Universal Parser Framework
//! ├── dependencies/          # Shared tokei, Mozilla code analysis, tree-sitter
//! ├── interfaces/            # Universal traits and types
//! ├── optimizations/         # Performance, caching, async execution
//! └── errors/               # Standardized error handling
//! ```
//!
//! ## Usage
//!
//! Language-specific parsers implement the `UniversalParser` trait and use shared dependencies:
//!
//! ```rust,ignore
//! use universal_parser::{UniversalParser, UniversalDependencies, Language};
//!
//! struct MyLanguageParser {
//!     deps: UniversalDependencies,
//! }
//!
//! impl UniversalParser for MyLanguageParser {
//!     async fn analyze_content(&self, content: &str, file_path: &str) -> Result<AnalysisResult> {
//!         self.deps.analyze_with_all_tools(content, ProgrammingLanguage::MyLanguage).await
//!     }
//! }
//! ```

pub mod dependencies;
pub mod errors;
pub mod interfaces;
pub mod languages;
pub mod optimizations;
pub mod refactoring_suggestions;

// ML predictions (merged from parser-coordinator)
pub mod central_heuristics;
pub mod ml_predictions;
pub mod parser_metadata;

// Re-export main types
use std::collections::HashMap;

// parser_metadata types are already exported via interfaces::*
use anyhow::Result;
pub use central_heuristics::*;
pub use dependencies::*;
pub use errors::*;
pub use interfaces::*;
pub use languages::*;
pub use languages::adapters;
// Re-export ML prediction types (excluding duplicates)
pub use ml_predictions::*;
pub use optimizations::*;
pub use refactoring_suggestions::*;
use serde::{Deserialize, Serialize};

/// Version of the universal parser framework
pub const UNIVERSAL_PARSER_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Initialize the universal parser framework with default configuration
pub fn init() -> Result<UniversalDependencies> {
  UniversalDependencies::new()
}

/// Initialize the universal parser framework with custom configuration
pub fn init_with_config(config: UniversalParserFrameworkConfig) -> Result<UniversalDependencies> {
  UniversalDependencies::new_with_config(config)
}

/// Universal parser framework configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UniversalParserFrameworkConfig {
  /// Enable caching for analysis results
  pub enable_caching: bool,
  /// Cache size limit (number of entries)
  pub cache_size: usize,
  /// Enable parallel processing
  pub enable_parallel: bool,
  /// Maximum file size to analyze (bytes)
  pub max_file_size: u64,
  /// Analysis timeout per file (milliseconds)
  pub timeout_ms: u64,
  /// Enable memory optimization
  pub enable_memory_optimization: bool,
  /// Cache invalidation threshold (seconds)
  pub cache_ttl: u64,
  /// Enable content hashing for cache invalidation
  pub enable_content_hashing: bool,
  /// Maximum concurrent analyses
  pub max_concurrent: usize,
  /// Enable Language Server Protocol features
  pub enable_lsp_features: bool,
  /// Enable real-time analysis
  pub enable_real_time_analysis: bool,
  /// Enable auto-fix suggestions
  pub enable_auto_fix: bool,
  /// Enable live error detection
  pub enable_live_errors: bool,
  /// Enable interactive debugging
  pub enable_interactive_debugging: bool,
  /// Enable advanced analysis features
  pub enable_advanced_analysis: bool,
  /// Enable enterprise features (security, performance, etc.)
  pub enable_enterprise_features: bool,
}

impl Default for UniversalParserFrameworkConfig {
  fn default() -> Self {
    Self {
      enable_caching: true,
      cache_size: 1000,
      enable_parallel: true,
      max_file_size: 10 * 1024 * 1024, // 10MB
      timeout_ms: 30000,               // 30 seconds
      enable_memory_optimization: true,
      cache_ttl: 3600,                 // 1 hour
      enable_content_hashing: true,
      max_concurrent: 4,
      enable_lsp_features: true,
      enable_real_time_analysis: false,
      enable_auto_fix: false,
      enable_live_errors: true,
      enable_interactive_debugging: false,
      enable_advanced_analysis: true,
      enable_enterprise_features: false,
    }
  }
}

/// Analysis result that all parsers return
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
  /// File path that was analyzed
  pub file_path: String,
  /// Programming language detected
  pub language: ProgrammingLanguage,
  /// Standard metrics from tokei
  pub line_metrics: LineMetrics,
  /// Complexity metrics from Mozilla code analysis
  pub complexity_metrics: ComplexityMetrics,
  /// Halstead metrics
  pub halstead_metrics: HalsteadMetrics,
  /// Maintainability metrics
  pub maintainability_metrics: MaintainabilityMetrics,
  /// Language-specific extensions
  pub language_specific: HashMap<String, serde_json::Value>,
  /// Analysis timestamp
  pub timestamp: chrono::DateTime<chrono::Utc>,
  /// Analysis duration in milliseconds
  pub analysis_duration_ms: u64,
}

/// Comprehensive analysis result with enterprise-grade capabilities
/// Security vulnerability information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityVulnerability {
  pub severity: String,
  pub category: String,
  pub description: String,
  pub recommendation: String,
}

/// Performance optimization suggestion
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceOptimization {
  pub category: String,
  pub description: String,
  pub suggestion: String,
}

/// Framework detection results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkDetection {
  pub detected_frameworks: Vec<String>,
  pub confidence: f64,
}

/// Architecture pattern information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchitectureCodePattern {
  pub pattern_type: String,
  pub description: String,
  pub confidence: f64,
}

/// Dependency information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyInfo {
  pub dependencies: Vec<String>,
  pub dev_dependencies: Vec<String>,
  pub peer_dependencies: Vec<String>,
}

/// Error information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorInfo {
  pub errors: Vec<String>,
  pub warnings: Vec<String>,
  pub suggestions: Vec<String>,
}

/// Language configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageConfig {
  pub version: String,
  pub features: Vec<String>,
  pub strict_mode: bool,
}

/// This is the rich API that rust/go parsers expect
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RichAnalysisResult {
  /// Base analysis
  pub base: AnalysisResult,
  /// Security vulnerability analysis
  pub security_vulnerabilities: Vec<SecurityVulnerability>,
  /// Performance optimization suggestions
  pub performance_optimizations: Vec<PerformanceOptimization>,
  /// Framework detection results
  pub framework_detection: FrameworkDetection,
  /// Architecture pattern analysis
  pub architecture_patterns: Vec<ArchitectureCodePattern>,
  /// Dependency information
  pub dependency_info: DependencyInfo,
  /// Error handling analysis
  pub error_info: ErrorInfo,
  /// Language configuration
  pub language_config: LanguageConfig,
}

/// Standard line metrics from tokei
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LineMetrics {
  /// Total lines in file
  pub total_lines: usize,
  /// Lines of code (excluding comments and blanks)
  pub code_lines: usize,
  /// Comment lines
  pub comment_lines: usize,
  /// Blank lines
  pub blank_lines: usize,
}

/// Standard complexity metrics from Mozilla code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplexityMetrics {
  /// Cyclomatic complexity
  pub cyclomatic: f64,
  /// Cognitive complexity
  pub cognitive: f64,
  /// Number of exit points
  pub exit_points: usize,
  /// Nesting depth
  pub nesting_depth: usize,
}

/// Standard Halstead metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HalsteadMetrics {
  /// Total number of operators
  pub total_operators: u64,
  /// Total number of operands
  pub total_operands: u64,
  /// Unique operators
  pub unique_operators: u64,
  /// Unique operands
  pub unique_operands: u64,
  /// Program volume
  pub volume: f64,
  /// Program difficulty
  pub difficulty: f64,
  /// Programming effort
  pub effort: f64,
}

/// Standard maintainability metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaintainabilityMetrics {
  /// Maintainability index (0-100)
  pub index: f64,
  /// Technical debt ratio
  pub technical_debt_ratio: f64,
  /// Code duplication percentage
  pub duplication_percentage: f64,
}

#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn test_universal_parser_init() {
    let deps = init().expect("Failed to initialize universal parser");
    assert!(deps.tokei_analyzer.is_available());
    assert!(deps.complexity_analyzer.is_available());
  }

  #[tokio::test]
  async fn test_config_defaults() {
    let config = UniversalParserFrameworkConfig::default();
    assert!(config.enable_caching);
    assert_eq!(config.cache_size, 1000);
    assert!(config.enable_parallel);
  }

  #[test]
  fn test_universal_analysis_result_serialization() {
    let result = AnalysisResult {
      file_path: "test.rs".to_string(),
      language: ProgrammingLanguage::Rust,
      line_metrics: LineMetrics { total_lines: 100, code_lines: 80, comment_lines: 10, blank_lines: 10 },
      complexity_metrics: ComplexityMetrics { cyclomatic: 5.0, cognitive: 3.0, exit_points: 2, nesting_depth: 3 },
      halstead_metrics: HalsteadMetrics {
        total_operators: 50,
        total_operands: 30,
        unique_operators: 10,
        unique_operands: 15,
        volume: 200.0,
        difficulty: 3.33,
        effort: 666.0,
      },
      maintainability_metrics: MaintainabilityMetrics { index: 75.0, technical_debt_ratio: 0.1, duplication_percentage: 5.0 },
      language_specific: HashMap::new(),
      timestamp: chrono::Utc::now(),
      analysis_duration_ms: 150,
    };

    let serialized = serde_json::to_string(&result).expect("Failed to serialize");
    let deserialized: AnalysisResult = serde_json::from_str(&serialized).expect("Failed to deserialize");

    assert_eq!(result.file_path, deserialized.file_path);
    assert_eq!(result.language, deserialized.language);
  }
}
