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
pub mod graph;    // Code dependency graphs and relationship modeling
pub mod vectors;  // Vector embeddings and operations
// pub mod embeddings; // DISABLED: Requires external embedding services (handled by Elixir)
pub mod analysis; // Code analysis, control flow, dependencies, and semantic features
pub mod api;      // API types
pub mod parsing;  // Code parsing
// paths module removed - NIF doesn't need file paths
// pub mod repository; // DISABLED: Has detection dependencies
pub mod types;    // Legacy types (being migrated)
pub mod codebase; // NEW: Single source of truth for all code metadata
// pub mod search;   // DISABLED: Semantic search requires database (handled by Elixir)

// Unified storage system
// storage module removed - NIF doesn't need persistent storage
// Legacy compatibility: map old storage path to new codebase::storage
pub use codebase::storage as storage;

// Re-export main types for easy access
// Domain types (new organization)
pub use domain::*;
pub use graph::{Graph, GraphHandle, GraphNode, GraphEdge, GraphType};  // Core graph types
// Note: graph::dag types (FileAnalysisResult, etc.) are available but not re-exported here
// They're used by nif_bindings when enabled
pub use vectors::*;

// NEW: Codebase types (single source of truth)
pub use codebase::*;

// NEW: Search types (semantic search with custom vectors)
// pub use search::*;  // DISABLED - search handled by Elixir

// Legacy re-exports for backward compatibility
pub use types::*;  // Export types first (these are the canonical definitions)

// Re-export analyzer types
// DISABLED: analyzer module disabled due to external dependencies
// pub use analyzer::{
//   ArchitecturalCodePattern, ComplexityDistribution, CrossLanguageAnalysis, FileMetrics, IntegrationCodePattern, ParsedFile, QualityConsistency, QualityGate,
//   QualityGateResults, TechnologyStack,
// };

// Re-export analysis types (code analysis only)
// DISABLED: analysis module disabled
// pub use analysis::{
//   performance, semantic, multilang, dependency, metrics, security,
// };

pub use parsing::*;
// pub use repository::{RepoAnalyzer, RepositoryAnalysis};  // DISABLED - module disabled
// Storage removed - NIF receives data from Elixir

// Main analyzer that orchestrates everything
// pub mod analyzer;  // DISABLED: Has too many external dependencies (prompt_engine, linting_engine, sparc_methodology)

// Re-export the main analyzer
// pub use analyzer::*;  // DISABLED - see above

// NIF bindings (feature-gated for Elixir integration)
#[cfg(feature = "nif")]
pub mod nif;

// nif_bindings - Elixir NIF bindings for analysis functionality
// Re-enabled after Phase 1-3 refactoring (commit: PHASE3):
// - Phase 1: Added SemanticFeatures type, complexity field, symbols field to CodeMetadata
// - Phase 2: Fixed all storage::graph imports to use crate::graph
// - Phase 3: Re-enabled analysis module and nif_bindings
#[cfg(feature = "nif")]
pub mod nif_bindings;
