//! Language-agnostic metrics

use serde::{Deserialize, Serialize};

/// Language-specific metrics
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LanguageMetrics {
    pub lines_of_code: usize,
    pub functions_count: usize,
    pub imports_count: usize,
    pub comments_count: usize,
    pub classes_count: usize,
    pub enums_count: usize,
    pub docstrings_count: usize,
}
