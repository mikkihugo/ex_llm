//! Language-agnostic metrics

use serde::{Deserialize, Serialize};

/// Language-specific metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageMetrics {
    pub language: String,
    pub lines_of_code: u32,
    pub lines_of_comments: u32,
    pub lines_of_blank: u32,
    pub total_lines: u32,
    pub functions: u32,
    pub classes: u32,
    pub imports: u32,
    pub complexity: ComplexityMetrics,
    pub quality: QualityMetrics,
}

/// Complexity metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplexityMetrics {
    pub cyclomatic_complexity: u32,
    pub cognitive_complexity: u32,
    pub nesting_depth: u32,
    pub max_function_length: u32,
    pub max_class_length: u32,
}

/// Quality metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityMetrics {
    pub test_coverage: f64,
    pub documentation_coverage: f64,
    pub maintainability_index: f64,
    pub technical_debt: f64,
    pub code_smells: u32,
    pub bugs: u32,
    pub vulnerabilities: u32,
}