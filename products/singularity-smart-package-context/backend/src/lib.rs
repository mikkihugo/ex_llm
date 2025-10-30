#![warn(missing_docs)]

//! # Singularity Smart Package Context Backend
//!
//! Unified backend for all 4 distribution channels (MCP, VS Code, CLI, API).
//!
//! ## Overview
//!
//! This module provides the **single unified backend** that all distribution channels wrap.
//! Each channel (MCP, VS Code, CLI, HTTP API) calls the same 5 core functions.
//!
//! ## The 5 Core Functions
//!
//! 1. **`get_package_info()`** - Get complete package metadata with quality score
//! 2. **`get_package_examples()`** - Get code examples from documentation
//! 3. **`get_package_patterns()`** - Get community consensus patterns for a package
//! 4. **`search_patterns()`** - Semantic search across all patterns
//! 5. **`analyze_file()`** - Analyze code and suggest improvements
//!
//! ## Design Principles
//!
//! - **One backend, many frontends** - Single implementation for all channels
//! - **Type-safe** - Strong Rust types prevent runtime errors
//! - **Async-first** - All I/O is async with Tokio
//! - **Comprehensive errors** - Detailed error types guide integration
//! - **Cached** - LRU cache reduces load on underlying services
//! - **Well-documented** - Every function has examples and error documentation
//!
//! ## Architecture
//!
//! The backend integrates three major systems:
//!
//! - **PackageIntelligence** - Rust NIF for metadata extraction + GitHub crawling
//! - **CentralCloud** - Elixir service for pattern aggregation + consensus
//! - **Embeddings** - Nx-based semantic search with pgvector
//!
//! ## See Also
//!
//! - [`SmartPackageContext`](crate::api::SmartPackageContext) - Main service
//! - [`types`](crate::types) - All data types (PackageInfo, PatternConsensus, etc.)
//! - [`error`](crate::error) - Error types and Result type
//! - README.md - Full documentation in backend directory

pub mod api;
pub mod cache;
pub mod error;
pub mod integrations;
pub mod types;

pub use api::SmartPackageContext;
pub use error::{Error, Result};
pub use types::*;

/// Library version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
