//! Code Analysis Library
//!
//! A pure codebase analysis library that provides intelligent code understanding,
//! quality analysis, metrics collection, pattern detection, intelligent naming,
//! and semantic search capabilities without LLM dependencies.
//!
//! # Features
//!
//! - **Code Analysis**: Quality metrics, complexity analysis, maintainability scoring
//! - **Pattern Detection**: Design patterns, anti-patterns, code smells
//! - **Metrics Collection**: LOC, function counts, performance metrics
//! - **Intelligent Naming**: Context-aware naming suggestions with learning
//! - **Graph Analysis**: Code dependency analysis and structure understanding
//! - **Semantic Analysis**: Vector embeddings and similarity analysis
//! - **DAG Analysis**: File relationships and dependency modeling
//! - **Multi-language Support**: Cross-language analysis capabilities
//! - **Architecture Analysis**: Architectural pattern detection
//! - **Evolution Tracking**: Code evolution and naming history
//! - **Semantic Search**: Business-aware, architecture-aware, and security-aware code search
//!
//! # Usage
//!
//! ```rust
//! use code_analysis::codebase::*;
//!
//! // Create a codebase analyzer
//! let analyzer = CodebaseAnalyzer::new();
//!
//! // Analyze a project
//! let analysis = analyzer.analyze_project("/path/to/project").await?;
//!
//! // Get quality metrics
//! let quality = analysis.quality;
//! let complexity = quality.complexity_score;
//!
//! // Perform semantic search
//! let search_engine = SemanticSearchEngine::new();
//! let search_results = search_engine.search(
//!   "payment processing with Stripe",
//!   SearchOptions::default()
//! ).await?;
//! ```
//!
//! # NIF Support
//!
//! When compiled with the `nif` feature, this crate provides Elixir NIF bindings:
//!
//! ```elixir
//! # In Elixir
//! {:ok, metrics} = CodeAnalysis.analyze_quality("/path/to/code")
//! {:ok, results} = CodeAnalysis.semantic_search("payment processing", "/path")
//! ```
//!
//! # Architecture
//!
//! - **Storage Layer**: Pure data storage (files, ASTs, metadata)
//! - **Repository Layer**: Repository structure analysis (workspace, packages, infrastructure)
//! - **Analysis Layer**: Analysis logic (quality, patterns, naming)
//! - **Search Layer**: Semantic search with business, architecture, and security awareness
//! - **Types Layer**: Shared types and traits
//! - **NIF Layer**: Optional Elixir bindings (feature-gated)

// Core modules
pub mod domain;        // Domain types (symbols, files, metrics, relationships)
pub mod graph;         // Code dependency graphs and relationship modeling
pub mod vectors;       // Vector embeddings and operations
pub mod analysis;      // Code analysis, control flow, dependencies, and semantic features
pub mod api;           // API types
pub mod parsing;       // Code parsing
pub mod types;         // Shared types and traits
pub mod codebase;      // Codebase storage and metadata
pub mod centralcloud;  // CentralCloud integration via NATS (CVEs, patterns, rules)

// Re-export storage for backward compatibility
pub use codebase::storage as storage;

// Re-export main types for easy access (be explicit to avoid conflicts)
// Domain exports (files, symbols, relationships, and domain metrics)
pub use domain::files::*;
pub use domain::symbols::*;
pub use domain::relationships::*;
pub use domain::metrics as domain_metrics;  // Qualified re-export to avoid conflict with analysis::metrics

pub use graph::{Graph, GraphHandle, GraphNode, GraphEdge, GraphType};
pub use vectors::*;
pub use codebase::*;
pub use types::*;
pub use parsing::*;

// Main analyzer that orchestrates everything
pub mod analyzer;
pub use analyzer::CodebaseAnalyzer;

// NIF bindings (feature-gated for Elixir integration)
#[cfg(feature = "nif")]
pub mod nif;

#[cfg(feature = "nif")]
pub mod nif_bindings;

