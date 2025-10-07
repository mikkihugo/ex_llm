//! Singularity Unified Analysis Engine
//!
//! A single codebase that can run as either:
//! - NIF (Native Implemented Function) - Direct in Elixir
//! - Server (NATS Service) - Distributed via NATS
//!
//! Uses feature flags to gate functionality:
//! - `nif` - Enable NIF functions
//! - `server` - Enable NATS service
//! - `both` - Enable both (default)

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;

// Import all the analysis modules
use analysis_suite::{
    analyzer::Analyzer,
    codebase::CodebaseAnalyzer,
    quality::QualityAnalyzer,
    security::SecurityAnalyzer,
    architecture::ArchitectureAnalyzer,
};
use tech_detector::TechDetector;
use source_code_parser::{
    languages::LanguageDetector,
    dependencies::DependencyParser,
    parsing::CodeParser,
};
use embedding_engine::{
    EmbeddingEngine,
    models::EmbeddingModel,
    tokenizers::Tokenizer,
};

// Re-export based on features
#[cfg(feature = "nif")]
mod nif;
#[cfg(feature = "nif")]
pub use nif::*;

#[cfg(feature = "server")]
mod server;
#[cfg(feature = "server")]
pub use server::*;

// Common modules
pub mod types;
pub mod parsers;
pub mod features;

// Re-export the unified analysis engine
pub use parsers::UnifiedParsers;
pub use features::{FeatureAwareEngine, FeatureConfig, Feature, create_nif_config, create_server_config};

// Re-export types
pub use types::*;
