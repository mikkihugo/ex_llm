//! Template management library for code generation patterns

use serde::{Deserialize, Serialize};

/// Code template for generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeTemplate {
    pub name: String,
    pub template_type: String,
    pub content: String,
    pub variables: Vec<String>,
}

impl Default for CodeTemplate {
    fn default() -> Self {
        Self {
            name: String::new(),
            template_type: String::new(),
            content: String::new(),
            variables: Vec::new(),
        }
    }
}