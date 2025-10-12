//! Analysis Layer for Code Analysis
//!
//! This module provides PURE CODE ANALYSIS only (no architecture, no quality).
//! For architecture/framework analysis, use architecture_engine.
//! For quality/linting, use quality_engine.
//!
//! # Components (Code Analysis Only)
//!
//! - **metrics/**: Code metrics and statistics (LOC, complexity, etc.)
//! - **performance/**: Performance analysis and monitoring
//! - **security/**: Security vulnerability analysis
//! - **dependency/**: Dependency graph analysis
//! - **control_flow**: Control flow and complexity analysis
//! - **semantic/**: Semantic analysis and vector embeddings
//! - **graph/**: Code graph construction and analysis
//! - **dag/**: Directed Acyclic Graph for file relationships
//! - **multilang/**: Cross-language analysis

pub mod control_flow;
pub mod dag;
pub mod dependency;
pub mod graph;
pub mod metrics;
pub mod multilang;
pub mod performance;
pub mod security;
pub mod semantic;

// Re-export main types
pub use dag::*;
pub use dependency::*;
pub use graph::*;
pub use metrics::*;
pub use multilang::*;
pub use performance::*;
pub use security::*;
pub use semantic::*;
