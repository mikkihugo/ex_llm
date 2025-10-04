//! Fallback Extractor - When tree-sitter not available
//!
//! Returns empty results when tree-sitter-extraction feature is disabled.

use super::{CodeExtractor, ExtractedCode};
use crate::storage::{FactSnippet, FactExample};
use anyhow::Result;
use std::path::Path;

/// Fallback extractor - returns empty results
pub struct FallbackExtractor;

impl FallbackExtractor {
    pub fn new() -> Self {
        Self
    }
}

#[async_trait::async_trait]
impl CodeExtractor for FallbackExtractor {
    async fn extract_snippets(&self, _file_path: &Path, _source: &str) -> Result<Vec<FactSnippet>> {
        Ok(Vec::new())
    }

    async fn extract_examples(&self, _test_file: &Path, _source: &str) -> Result<Vec<FactExample>> {
        Ok(Vec::new())
    }

    async fn extract_from_directory(&self, _dir: &Path) -> Result<ExtractedCode> {
        Ok(ExtractedCode::default())
    }
}
