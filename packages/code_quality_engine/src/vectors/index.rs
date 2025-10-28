//! Vector indexing and search
//!
//! This module provides vector indexing capabilities for fast similarity search.

use serde::{Deserialize, Serialize};

/// Vector index for similarity search
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VectorIndex {
    /// Index name
    pub name: String,
    /// Dimension of vectors
    pub dimension: usize,
}
