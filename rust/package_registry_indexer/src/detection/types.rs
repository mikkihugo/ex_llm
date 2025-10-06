//! Core types for framework detection system.
//!
//! Defines the fundamental data structures and enums used across
//! the detection system.

// === 1. STANDARD LIBRARY ===
use std::collections::HashMap;

// === 2. EXTERNAL CRATES ===
use serde::{Deserialize, Serialize};
use thiserror::Error;

// === 3. FOUNDATION (primecode_*) ===
// (none in this file)

// === 4. INTERNAL CRATE ===
// (none in this file)

/// Errors that can occur during framework detection
#[derive(Debug, Error)]
pub enum FrameworkDetectionError {
  #[error("Node.js runtime error: {0}")]
  NodeError(String),

  #[error("JSON parsing error: {0}")]
  JsonError(#[from] serde_json::Error),

  #[error("Path error: {0}")]
  PathError(String),

  #[error("Command execution error: {0}")]
  CommandError(String),

  #[error("IO error: {0}")]
  IoError(#[from] std::io::Error),

  #[error("Storage error: {0}")]
  StorageError(String),

  #[error("LLM error: {0}")]
  LLMError(String),
}

/// Information about a detected framework
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkInfo {
  pub name: String,
  pub version: Option<String>,
  pub confidence: f32,
  pub build_command: Option<String>,
  pub output_directory: Option<String>,
  pub dev_command: Option<String>,
  pub install_command: Option<String>,
  pub framework_type: String,
  pub detected_files: Vec<String>,
  pub dependencies: Vec<String>,
  pub detection_method: DetectionMethod,
  pub metadata: HashMap<String, serde_json::Value>,
}

/// Methods used to detect frameworks
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DetectionMethod {
  NpmDependencies,
  NodeApi,
  LLMAnalysis,
  FileCodePattern,
  Combined,
}

/// Result of framework detection process
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionResult {
  pub frameworks: Vec<FrameworkInfo>,
  pub primary_framework: Option<FrameworkInfo>,
  pub build_tools: Vec<String>,
  pub package_managers: Vec<String>,
  pub detected_at: chrono::DateTime<chrono::Utc>,
  pub project_path: String,
  pub confidence_score: f32,
  pub detection_methods_used: Vec<DetectionMethod>,
  pub recommendations: Option<FrameworkRecommendations>,
}

/// Enhanced detection result with additional metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnhancedDetectionResult {
  pub base_result: DetectionResult,
  pub fact_system_knowledge: Vec<String>,
  pub learning_data: HashMap<String, serde_json::Value>,
  pub performance_metrics: DetectionMetrics,
}

/// Framework recommendations based on detection
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkRecommendations {
  pub recommended_frameworks: Vec<FrameworkInfo>,
  pub migration_suggestions: Vec<String>,
  pub best_practices: Vec<String>,
  pub common_patterns: Vec<String>,
  pub performance_tips: Vec<String>,
  pub security_considerations: Vec<String>,
}

/// Performance metrics for detection process
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionMetrics {
  pub detection_time_ms: u64,
  pub methods_used: Vec<DetectionMethod>,
  pub confidence_scores: HashMap<String, f32>,
  pub cache_hits: u32,
  pub cache_misses: u32,
}

/// Framework signature for pattern matching
#[derive(Debug, Clone)]
pub struct FrameworkSignature {
  pub name: &'static str,
  pub package_names: Vec<&'static str>,
  pub file_patterns: Vec<&'static str>,
  pub directory_patterns: Vec<&'static str>,
  pub config_files: Vec<&'static str>,
  pub build_commands: Vec<&'static str>,
  pub dev_commands: Vec<&'static str>,
  pub output_dirs: Vec<&'static str>,
  pub framework_type: &'static str,
  pub confidence_weight: f32,
}

/// LLM provider types
#[derive(Debug, Clone)]
pub enum LLMProvider {
  Claude,
}

/// LLM interface for framework analysis
pub struct ToolchainLlmInterface {
  provider: LLMProvider,
}

impl ToolchainLlmInterface {
  /// Create new LLM interface
  pub fn new(provider: LLMProvider) -> Self {
    Self { provider }
  }

  /// Generate content using LLM
  pub async fn generate_content(
    &self,
    _prompt: &str,
  ) -> Result<String, FrameworkDetectionError> {
    Err(FrameworkDetectionError::LLMError(
      "LLM not implemented yet".to_string(),
    ))
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use std::collections::HashMap;

  #[test]
  fn test_framework_info_creation() {
    let mut metadata = HashMap::new();
    metadata.insert("test_key".to_string(), serde_json::json!("test_value"));

    let framework = FrameworkInfo {
      name: "react".to_string(),
      version: Some("18.0.0".to_string()),
      confidence: 0.95,
      build_command: Some("npm run build".to_string()),
      output_directory: Some("build".to_string()),
      dev_command: Some("npm start".to_string()),
      install_command: Some("npm install".to_string()),
      framework_type: "frontend".to_string(),
      detected_files: vec!["package.json".to_string()],
      dependencies: vec!["react".to_string(), "react-dom".to_string()],
      detection_method: DetectionMethod::NpmDependencies,
      metadata,
    };

    assert_eq!(framework.name, "react");
    assert_eq!(framework.confidence, 0.95);
    assert_eq!(framework.detection_method, DetectionMethod::NpmDependencies);
  }

  #[test]
  fn test_detection_result_creation() {
    let framework = FrameworkInfo {
      name: "vue".to_string(),
      version: Some("3.0.0".to_string()),
      confidence: 0.9,
      build_command: Some("npm run build".to_string()),
      output_directory: Some("dist".to_string()),
      dev_command: Some("npm run serve".to_string()),
      install_command: Some("npm install".to_string()),
      framework_type: "frontend".to_string(),
      detected_files: vec!["package.json".to_string()],
      dependencies: vec!["vue".to_string()],
      detection_method: DetectionMethod::FileCodePattern,
      metadata: HashMap::new(),
    };

    let result = DetectionResult {
      frameworks: vec![framework.clone()],
      primary_framework: Some(framework),
      build_tools: vec!["webpack".to_string()],
      package_managers: vec!["npm".to_string()],
      detected_at: chrono::Utc::now(),
      project_path: "/test/project".to_string(),
      confidence_score: 0.9,
      detection_methods_used: vec![DetectionMethod::FileCodePattern],
      recommendations: None,
    };

    assert_eq!(result.frameworks.len(), 1);
    assert!(result.primary_framework.is_some());
    assert_eq!(result.confidence_score, 0.9);
  }

  #[test]
  fn test_framework_signature_creation() {
    let signature = FrameworkSignature {
      name: "react",
      package_names: vec!["react", "react-dom"],
      file_patterns: vec!["*.jsx", "*.tsx"],
      directory_patterns: vec!["src/", "components/"],
      config_files: vec!["package.json"],
      build_commands: vec!["npm run build"],
      dev_commands: vec!["npm start"],
      output_dirs: vec!["build/"],
      framework_type: "frontend",
      confidence_weight: 0.9,
    };

    assert_eq!(signature.name, "react");
    assert_eq!(signature.package_names.len(), 2);
    assert_eq!(signature.confidence_weight, 0.9);
  }

  #[test]
  fn test_llm_provider_creation() {
    let provider = LLMProvider::Claude;
    let interface = ToolchainLlmInterface::new(provider);

    // Test that interface was created successfully
    assert!(matches!(interface.provider, LLMProvider::Claude));
  }

  #[tokio::test]
  async fn test_llm_interface_error() {
    let interface = ToolchainLlmInterface::new(LLMProvider::Claude);
    let result = interface.generate_content("test prompt").await;

    assert!(result.is_err());
    match result.unwrap_err() {
      FrameworkDetectionError::LLMError(msg) => {
        assert_eq!(msg, "LLM not implemented yet");
      }
      _ => panic!("Expected LLMError"),
    }
  }

  #[test]
  fn test_detection_methods() {
    let methods = vec![
      DetectionMethod::NpmDependencies,
      DetectionMethod::NodeApi,
      DetectionMethod::LLMAnalysis,
      DetectionMethod::FileCodePattern,
      DetectionMethod::Combined,
    ];

    for method in methods {
      // Test that each method can be serialized/deserialized
      let serialized =
        serde_json::to_string(&method).expect("Failed to serialize");
      let deserialized: DetectionMethod =
        serde_json::from_str(&serialized).expect("Failed to deserialize");
      assert_eq!(method, deserialized);
    }
  }

  #[test]
  fn test_framework_recommendations() {
    let recommendations = FrameworkRecommendations {
      recommended_frameworks: vec![],
      migration_suggestions: vec!["Use TypeScript".to_string()],
      best_practices: vec!["Use hooks".to_string()],
      common_patterns: vec!["Component composition".to_string()],
      performance_tips: vec!["Use React.memo".to_string()],
      security_considerations: vec!["Validate inputs".to_string()],
    };

    assert_eq!(recommendations.migration_suggestions.len(), 1);
    assert_eq!(recommendations.best_practices.len(), 1);
    assert_eq!(recommendations.common_patterns.len(), 1);
    assert_eq!(recommendations.performance_tips.len(), 1);
    assert_eq!(recommendations.security_considerations.len(), 1);
  }

  #[test]
  fn test_detection_metrics() {
    let mut confidence_scores = HashMap::new();
    confidence_scores.insert("react".to_string(), 0.9);
    confidence_scores.insert("typescript".to_string(), 0.8);

    let metrics = DetectionMetrics {
      detection_time_ms: 150,
      methods_used: vec![DetectionMethod::NpmDependencies],
      confidence_scores,
      cache_hits: 5,
      cache_misses: 2,
    };

    assert_eq!(metrics.detection_time_ms, 150);
    assert_eq!(metrics.methods_used.len(), 1);
    assert_eq!(metrics.confidence_scores.len(), 2);
    assert_eq!(metrics.cache_hits, 5);
    assert_eq!(metrics.cache_misses, 2);
  }
}
