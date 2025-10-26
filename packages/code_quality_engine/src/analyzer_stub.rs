//! Minimal CodebaseAnalyzer Stub
//!
//! This module provides a minimal stub implementation of CodebaseAnalyzer
//! for NIF pure computation without external dependencies.
//!
//! Since code_engine is now a pure computation NIF (no database, no external services),
//! the analyzer functionality should be called from Elixir with data passed as parameters.

use std::path::Path;
use anyhow::Result;

/// Minimal analyzer stub that does pure computation
#[derive(Debug, Clone)]
pub struct CodebaseAnalyzer {
    // Empty struct - all analysis is done via static functions with data passed in
}

impl CodebaseAnalyzer {
    /// Create a minimal analyzer (pure computation only)
    pub fn new() -> Result<Self> {
        Ok(Self {})
    }
}

impl Default for CodebaseAnalyzer {
    fn default() -> Self {
        Self {}
    }
}
