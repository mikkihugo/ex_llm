//! Analysis metrics
//!
//! This module contains metrics for code complexity, quality, and performance.

use serde::{Deserialize, Serialize};

/// Complexity metrics for files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplexityMetrics {
  /// Cyclomatic complexity
  pub cyclomatic: f64,
  /// Cognitive complexity
  pub cognitive: f64,
  /// Maintainability index
  pub maintainability: f64,
  /// Function count
  pub function_count: usize,
  /// Class/trait count
  pub class_count: usize,

  // Mozilla metrics integration
  /// Halstead volume
  pub halstead_volume: f64,
  /// Halstead difficulty
  pub halstead_difficulty: f64,
  /// Halstead effort
  pub halstead_effort: f64,

  // Line counts
  /// Total lines
  pub total_lines: usize,
  /// Code lines
  pub code_lines: usize,
  /// Comment lines
  pub comment_lines: usize,
  /// Blank lines
  pub blank_lines: usize,
}

impl Default for ComplexityMetrics {
  fn default() -> Self {
    Self {
      cyclomatic: 0.0,
      cognitive: 0.0,
      maintainability: 100.0,
      function_count: 0,
      class_count: 0,
      halstead_volume: 0.0,
      halstead_difficulty: 0.0,
      halstead_effort: 0.0,
      total_lines: 0,
      code_lines: 0,
      comment_lines: 0,
      blank_lines: 0,
    }
  }
}
