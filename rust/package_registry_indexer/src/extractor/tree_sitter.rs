//! Tree-sitter Extractor - Uses universal-parser framework
//!
//! This extractor uses the universal-parser framework which provides
//! tree-sitter parsers for all supported languages.

use super::{CodeExtractor, ExtractedCode};
use crate::storage::{FactSnippet, FactExample};
use anyhow::Result;
use std::path::Path;

#[cfg(feature = "tree-sitter-extraction")]
use universal_parser::{UniversalDependencies, AnalysisResult, ProgrammingLanguage};

/// Tree-sitter extractor using universal-parser
pub struct TreeSitterExtractor {
    #[cfg(feature = "tree-sitter-extraction")]
    deps: UniversalDependencies,
}

impl TreeSitterExtractor {
    pub fn new() -> Result<Self> {
        Ok(Self {
            #[cfg(feature = "tree-sitter-extraction")]
            deps: UniversalDependencies::new()?,
        })
    }

    fn detect_language(&self, path: &Path) -> &str {
        match path.extension().and_then(|e| e.to_str()) {
            Some("ts") | Some("tsx") => "typescript",
            Some("js") | Some("jsx") => "javascript",
            Some("rs") => "rust",
            Some("py") => "python",
            Some("go") => "go",
            Some("java") => "java",
            _ => "unknown",
        }
    }

    fn is_test_file(&self, path: &Path) -> bool {
        let path_str = path.to_string_lossy();
        path_str.contains("test")
    }

    #[cfg(feature = "tree-sitter-extraction")]
    fn analysis_to_snippets(&self, analysis: &AnalysisResult, file_path: &Path) -> Vec<FactSnippet> {
        let mut snippets = Vec::new();
        for symbol in &analysis.symbols {
            if symbol.visibility == "public" {
                snippets.push(FactSnippet {
                    title: format!("{}: {}", symbol.kind, symbol.name),
                    code: symbol.name.clone(),
                    description: symbol.documentation.clone().unwrap_or_default(),
                    language: self.detect_language(file_path).to_string(),
                    file_path: file_path.to_string_lossy().to_string(),
                    line_number: symbol.line as u32,
                });
            }
        }
        snippets
    }
}

#[async_trait::async_trait]
impl CodeExtractor for TreeSitterExtractor {
    async fn extract_snippets(&self, file_path: &Path, source: &str) -> Result<Vec<FactSnippet>> {
        #[cfg(feature = "tree-sitter-extraction")]
        {
            let lang = match self.detect_language(file_path) {
                "typescript" => ProgrammingLanguage::TypeScript,
                "rust" => ProgrammingLanguage::Rust,
                "python" => ProgrammingLanguage::Python,
                _ => return Ok(Vec::new()),
            };
            let analysis = self.deps.analyze_with_all_tools(source, lang).await?;
            Ok(self.analysis_to_snippets(&analysis, file_path))
        }
        #[cfg(not(feature = "tree-sitter-extraction"))]
        Ok(Vec::new())
    }

    async fn extract_examples(&self, _test_file: &Path, _source: &str) -> Result<Vec<FactExample>> {
        Ok(Vec::new())
    }

    async fn extract_from_directory(&self, dir: &Path) -> Result<ExtractedCode> {
        use walkdir::WalkDir;
        let mut result = ExtractedCode::default();
        for entry in WalkDir::new(dir).max_depth(5) {
            let entry = entry?;
            let path = entry.path();
            if !path.is_file() {
                continue;
            }
            let source = match tokio::fs::read_to_string(path).await {
                Ok(s) => s,
                Err(_) => continue,
            };
            let snippets = self.extract_snippets(path, &source).await?;
            result.snippets.extend(snippets);
        }
        Ok(result)
    }
}
