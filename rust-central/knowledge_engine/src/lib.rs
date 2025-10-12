//! Knowledge management library for patterns and templates

use serde::{Deserialize, Serialize};

/// Knowledge pattern for code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KnowledgePattern {
    pub name: String,
    pub pattern_type: String,
    pub confidence: f64,
}

impl Default for KnowledgePattern {
    fn default() -> Self {
        Self {
            name: String::new(),
            pattern_type: String::new(),
            confidence: 0.0,
        }
    }
}