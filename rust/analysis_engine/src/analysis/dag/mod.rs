//! Directed Acyclic Graph (DAG) for File Relationships
//!
//! Provides DAG-based modeling of file relationships, dependencies, and
//! semantic similarity for intelligent code analysis and naming suggestions.
//!
//! # AI Coder Benefits
//!
//! - **File Relationships**: Models how files relate to each other
//! - **Dependency Tracking**: Tracks dependencies between files
//! - **Semantic Similarity**: Uses vector embeddings for similarity
//! - **Intelligent Naming**: Provides context for naming suggestions
//!
//! # Components
//!
//! - **storage/graph.rs**: Core DAG implementation with vector embeddings (moved from analysis/dag/)
//! - **vector_integration.rs**: Integration service for DAG operations
//!
//! # Examples
//!
//! ```rust
//! use std::collections::HashMap;
//!
//! use analysis_suite::storage::{Graph, FileMetadata};
//!
//! // Create a new DAG
//! let mut graph = Graph::new();
//!
//! // Graph is now part of storage layer (in-memory cache)
//! ```

pub mod vector_integration;

// Re-export graph types from storage
pub use crate::storage::graph::*;
pub use vector_integration::*;
