//! Code Quality Engine
//!
//! This crate provides comprehensive code quality analysis including
//! metrics, complexity analysis, maintainability scoring, and semantic search.
//!
//! ## Features
//!
//! - **Code Graph**: Understands code structure and dependencies
//! - **Semantic Analysis**: Provides semantic understanding of code
//! - **Quality Analysis**: Analyzes code quality and complexity
//! - **Metrics Collection**: Collects comprehensive code metrics
//! - **Pattern Detection**: Detects patterns and anti-patterns
//!
//! ## Integration with Elixir
//!
//! This Rust crate integrates with Elixir modules via Rustler NIFs.

pub mod analysis;
pub mod analyzer;
pub mod api;
pub mod centralcloud;
pub mod codebase;
pub mod domain;
pub mod feature;
pub mod graph;
#[cfg(feature = "nif")]
pub mod nif;
pub mod orchestrators;
pub mod parsing;
pub mod registry;
pub mod repository;
pub mod technology_detection;
pub mod testing;
pub mod types;
pub mod vectors;

// Re-export main types for easy access
pub use domain::ComplexityMetrics;
pub use graph::{CodeGraphBuilder, CodeInsightsEngine, Graph};
#[cfg(feature = "nif")]
pub use nif::{CodeAnalysisResult, QualityMetrics};
