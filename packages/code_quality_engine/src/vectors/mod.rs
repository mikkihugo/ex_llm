//! Vector embeddings and similarity operations
//!
//! This module consolidates all vector-related functionality:
//! - embeddings: Semantic vector embeddings
//! - index: Vector indexing and search
//! - advanced: Advanced ML-based vectors
//! - tokenizers: Custom tokenizers for vector generation
//! - statistical: Statistical vector operations
//! - retrieval: Vector retrieval and similarity search

pub mod advanced;
pub mod embeddings;
pub mod index;
pub mod tokenizers;

// Re-export main types
pub use advanced::*;
pub use embeddings::*; // Primary SemanticVector definition
pub use index::*;
pub use tokenizers::*;

// Note: retrieval.rs and statistical.rs removed - use codebase::vectors instead
