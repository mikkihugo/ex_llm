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

// Core modules - reorganized for domain-driven design
pub mod domain;   // Domain types (symbols, files, metrics, relationships)
pub mod graph;    // Graph algorithms and structures
pub mod vectors;  // Vector embeddings and operations
pub mod embeddings; // NEW: Hybrid TF-IDF + Transformer code embeddings
pub mod analysis; // Analysis logic and algorithms
pub mod api;      // API types
pub mod parsing;  // Code parsing
pub mod paths;    // Path utilities
pub mod repository; // Repository analysis
pub mod types;    // Legacy types (being migrated)
pub mod codebase; // NEW: Single source of truth for all code metadata
pub mod search;   // Semantic search with custom vectors

// Unified storage system
pub mod storage;

// Re-export main types for easy access
// Domain types (new organization)
pub use domain::*;
pub use graph::*;
pub use vectors::*;

// NEW: Codebase types (single source of truth)
pub use codebase::*;

// NEW: Search types (semantic search with custom vectors)
pub use search::*;

// Legacy re-exports for backward compatibility
pub use types::*;  // Export types first (these are the canonical definitions)

// Re-export analyzer types
pub use analyzer::{
  ArchitecturalCodePattern, ComplexityDistribution, CrossLanguageAnalysis, FileMetrics, IntegrationCodePattern, ParsedFile, QualityConsistency, QualityGate,
  QualityGateResults, TechnologyStack,
};

// Re-export analysis types that don't conflict
pub use analysis::{
  performance, quality_analyzer, semantic, patterns, architecture, evolution, multilang, refactoring,
};

pub use parsing::*;
pub use paths::SPARCPaths;
pub use repository::{RepoAnalyzer, RepositoryAnalysis};
pub use storage::*;

// Main analyzer that orchestrates everything
pub mod analyzer;

// Re-export the main analyzer
pub use analyzer::*;

// NIF bindings (feature-gated for Elixir integration)
#[cfg(feature = "nif")]
pub mod nif;
