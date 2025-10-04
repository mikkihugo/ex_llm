//! Fact Storage Integration
//!
//! Converts framework detection results into FACT database entries
//! for intelligent caching and knowledge building.
//!
//! NOTE: Currently simplified - LLM enhancement integration will be
//! redesigned to use the main LLM engine properly.

use super::DetectionResult;
use serde_json::json;

/// Convert detection result to storable facts
///
/// This creates structured data that can be stored in the prompt-engine
/// fact system for later retrieval and LLM template augmentation.
pub fn to_fact_storage(result: &DetectionResult) -> Vec<serde_json::Value> {
  let mut facts = Vec::new();

  // Basic framework detection facts
  for framework in &result.frameworks {
    facts.push(json!({
        "fact_type": "TechStack",
        "technology": framework.name,
        "version": framework.version,
        "category": "Framework",
        "confidence": result.confidence_score,
        "timestamp": chrono::Utc::now().to_rfc3339(),
    }));
  }

  facts
}

/// Query helpers for retrieving stored facts
pub mod queries {
  use serde_json::Value;

  /// Generate a query for framework-specific tools
  pub fn get_framework_tools(framework_name: &str) -> Value {
    serde_json::json!({
        "query_type": "ToolRecommendation",
        "framework": framework_name,
    })
  }

  /// Generate a query for high-confidence recommendations
  pub fn get_high_confidence_tools(
    framework_name: &str,
    min_confidence: f32,
  ) -> Value {
    serde_json::json!({
        "query_type": "ToolRecommendation",
        "framework": framework_name,
        "min_confidence": min_confidence,
    })
  }

  /// Generate a query for deployment options
  pub fn get_deployment_options(framework_name: &str) -> Value {
    serde_json::json!({
        "query_type": "DevOpsRecommendation",
        "framework": framework_name,
        "category": "deployment",
    })
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use crate::framework_detector::{DetectionResult, FrameworkInfo};

  #[test]
  fn test_fact_conversion() {
    // Test that we can convert framework detection to facts
    let framework = FrameworkInfo {
      name: "Next.js".to_string(),
      version: Some("13.0.0".to_string()),
      confidence: 0.9,
      build_command: Some("next build".to_string()),
      output_directory: Some(".next".to_string()),
      dev_command: Some("next dev".to_string()),
      install_command: Some("npm install".to_string()),
      framework_type: "frontend".to_string(),
      detected_files: vec!["package.json".to_string()],
      dependencies: vec!["next".to_string()],
    };

    let result = DetectionResult {
      frameworks: vec![framework],
      primary_framework: None,
      build_tools: vec![],
      package_managers: vec!["npm".to_string()],
      total_confidence: 0.9,
    };

    let facts = to_fact_storage(&result);
    assert_eq!(facts.len(), 1);
    assert_eq!(facts[0]["fact_type"], "TechStack");
    assert_eq!(facts[0]["technology"], "Next.js");
  }
}
