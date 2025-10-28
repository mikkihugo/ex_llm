//! Semantic vector embeddings
//!
//! This module provides core semantic vector types and operations
//! for code similarity and analysis.

use serde::{Deserialize, Serialize};

/// Semantic vector for code representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SemanticVector {
    /// Vector embedding
    pub embedding: Vec<f32>,
    /// Source text this vector represents
    pub source: String,
    /// Metadata
    pub metadata: Option<String>,
}
