//! Semantic search and embedding library

use serde::{Deserialize, Serialize};

/// Vector embedding for semantic search
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Embedding {
    pub vector: Vec<f32>,
    pub dimension: usize,
    pub metadata: Option<String>,
}

impl Default for Embedding {
    fn default() -> Self {
        Self {
            vector: Vec::new(),
            dimension: 0,
            metadata: None,
        }
    }
}

/// Semantic search result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub content: String,
    pub similarity: f32,
    pub metadata: Option<String>,
}

impl Default for SearchResult {
    fn default() -> Self {
        Self {
            content: String::new(),
            similarity: 0.0,
            metadata: None,
        }
    }
}