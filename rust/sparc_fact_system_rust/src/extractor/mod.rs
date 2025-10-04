//! Code Snippet Extractor
//!
//! Temporarily uses analysis-suite parsers to extract useful snippets,
//! then discards the full analysis. Only stores extracted results.
//!
//! Architecture:
//! 1. Parse code with tree-sitter (from analysis-suite)
//! 2. Extract snippets, examples, patterns
//! 3. Discard AST and analysis data
//! 4. Return only useful extracted data

use crate::storage::{FactSnippet, FactExample};
use anyhow::Result;
use std::path::Path;

#[cfg(feature = "tree-sitter-extraction")]
pub mod tree_sitter;

#[cfg(not(feature = "tree-sitter-extraction"))]
pub mod fallback;

/// Code extractor trait
#[async_trait::async_trait]
pub trait CodeExtractor: Send + Sync {
    /// Extract code snippets from a source file
    ///
    /// Process:
    /// 1. Parse with appropriate parser
    /// 2. Extract useful code snippets (exported functions, classes, etc.)
    /// 3. Discard AST
    /// 4. Return only snippets
    async fn extract_snippets(
        &self,
        file_path: &Path,
        source: &str,
    ) -> Result<Vec<FactSnippet>>;

    /// Extract usage examples from test files
    async fn extract_examples(
        &self,
        test_file: &Path,
        source: &str,
    ) -> Result<Vec<FactExample>>;

    /// Extract snippets from entire directory
    async fn extract_from_directory(
        &self,
        dir: &Path,
    ) -> Result<ExtractedCode>;
}

/// Extracted code data (what we keep)
#[derive(Debug, Clone, Default)]
pub struct ExtractedCode {
    pub snippets: Vec<FactSnippet>,
    pub examples: Vec<FactExample>,
    pub exports: Vec<String>,  // List of exported symbols
}

/// Create appropriate extractor based on features
pub fn create_extractor() -> Result<Box<dyn CodeExtractor>> {
    #[cfg(feature = "tree-sitter-extraction")]
    {
        Ok(Box::new(tree_sitter::TreeSitterExtractor::new()?))
    }

    #[cfg(not(feature = "tree-sitter-extraction"))]
    {
        Ok(Box::new(fallback::FallbackExtractor::new()))
    }
}
