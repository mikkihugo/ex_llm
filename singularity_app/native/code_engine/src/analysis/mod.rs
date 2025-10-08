//! Analysis Layer for Codebase Analysis
//!
//! This module provides analysis logic for codebase understanding.
//! It contains all the analysis algorithms and business logic,
//! using the storage layer for data access.
//!
//! # Components
//!
//! - **quality/**: Code quality analysis and scoring
//! - **metrics/**: Code metrics and statistics collection
//! - **performance/**: Performance analysis and monitoring
//! - **refactoring/**: Refactoring analysis and suggestions
//! - **patterns/**: CodePattern and anti-pattern detection
//! - **evolution/**: Code evolution and history tracking
//! - **multilang/**: Cross-language analysis
//! - **architecture/**: Architectural pattern analysis
//! - **semantic/**: Semantic analysis and vector embeddings
//! - **graph/**: Code graph construction and analysis
//! - **dag/**: Directed Acyclic Graph for file relationships

// pub mod architecture; // TODO: implement
pub mod dag;
pub mod dependency;
// pub mod evolution; // TODO: implement
// pub mod framework; // TODO: implement
pub mod graph;
pub mod metrics;
pub mod multilang;
pub mod orchestrator;
// pub mod patterns; // TODO: implement
pub mod performance;
pub mod quality;
pub mod quality_analyzer;
// pub mod refactoring; // TODO: implement
pub mod security;
pub mod semantic;

// Re-export main types
pub use architecture::*;
pub use dag::*;
pub use dependency::*;
pub use evolution::*;
pub use framework::*;
pub use graph::*;
pub use metrics::*;
pub use multilang::*;
pub use orchestrator::*;
pub use patterns::*;
pub use performance::*;
pub use quality::*;
pub use quality_analyzer::*;
pub use refactoring::*;
pub use security::*;
pub use semantic::*;

// Note: retrieval_vectors.rs and statistical_vectors.rs removed - use codebase::vectors instead
