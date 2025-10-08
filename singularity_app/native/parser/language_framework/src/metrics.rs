//! Language-agnostic metrics

use serde::{Deserialize, Serialize};

/// Language-specific metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageMetrics {
    pub lines_of_code: usize,
    pub functions_count: usize,
    pub imports_count: usize,
    pub comments_count: usize,
}