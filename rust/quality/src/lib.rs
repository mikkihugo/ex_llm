//! Quality analysis library for code quality metrics and patterns

use serde::{Deserialize, Serialize};

/// Quality metrics for code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityMetrics {
    pub complexity: f64,
    pub maintainability: f64,
    pub readability: f64,
    pub test_coverage: f64,
}

impl Default for QualityMetrics {
    fn default() -> Self {
        Self {
            complexity: 0.0,
            maintainability: 0.0,
            readability: 0.0,
            test_coverage: 0.0,
        }
    }
}