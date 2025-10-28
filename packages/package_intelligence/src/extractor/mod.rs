//! Code Snippet Extractor - Delegates to source code parser
//!
//! This module provides a bridge between package_registry_indexer and
//! source code parser for extracting code snippets from downloaded packages.
//!
//! Architecture:
//! 1. package_registry_indexer downloads tarball (npm, cargo, etc.)
//! 2. Extractor calls source code parser to parse with tree-sitter
//! 3. Converts source code parser results to CodeSnippet format
//! 4. Returns snippets for storage

use crate::package_file_watcher::ProgrammingLanguage;
use crate::storage::{CodeSnippet, PackageExample};
use anyhow::Result;
use std::path::Path;
// use source_code_parser::{SourceCodeParser, ProgrammingLanguage};  // Temporarily disabled

/// Code extractor that delegates to source code parser (temporarily disabled)
pub struct SourceCodeExtractor {
  // parser: SourceCodeParser,  // Temporarily disabled
}

impl SourceCodeExtractor {
  /// Create new extractor
  pub fn new() -> Result<Self> {
    Ok(Self {
            // parser: SourceCodeParser::new()?,  // Temporarily disabled
        })
  }

  /// Extract code snippets from a source file using source code parser
  ///
  /// Process:
  /// 1. Call source code parser to parse file
  /// 2. Extract public exports (functions, classes, etc.)
  /// 3. Convert to CodeSnippet format
  pub async fn extract_snippets(
    &self,
    file_path: &Path,
    source: &str,
  ) -> Result<Vec<CodeSnippet>> {
    // Detect language from file extension
    let lang = detect_language(file_path)?;

    // Parse with source code parser
    // let analysis = self.parser.analyze_code(source, lang)?;  // Temporarily disabled
    // TODO: Implement analysis when source code parser is available

    // Convert public symbols to FactSnippets (temporarily disabled)
    let mut snippets = Vec::new();
    // TODO: Implement when source code parser is available
    // for symbol in analysis.symbols {
    //     if symbol.visibility == "public" || symbol.exported {
    //         snippets.push(CodeSnippet {
    //             title: symbol.name.clone(),
    //             code: source[symbol.byte_range.clone()].to_string(),
    //             language: format!("{:?}", lang).to_lowercase(),
    //             description: symbol.doc_comment.unwrap_or_default(),
    //             file_path: file_path.to_string_lossy().to_string(),
    //             line_number: symbol.line as u32,
    //         });
    //     }
    // }

    Ok(snippets)
  }

  /// Extract usage examples from documentation files
  pub async fn extract_examples(
    &self,
    doc_file: &Path,
    content: &str,
  ) -> Result<Vec<PackageExample>> {
    // Extract code blocks from markdown/docs
    // TODO: Parse markdown code fences
    let _ = (doc_file, content);
    Ok(Vec::new())
  }

  /// Extract snippets from entire directory (package)
  pub async fn extract_from_directory(
    &self,
    dir: &Path,
  ) -> Result<ExtractedCode> {
    use std::fs;
    use walkdir::WalkDir;

    let mut extracted = ExtractedCode::default();

    // Walk directory and parse source files
    for entry in WalkDir::new(dir)
      .follow_links(false)
      .into_iter()
      .filter_map(|e| e.ok())
      .filter(|e| e.file_type().is_file())
    {
      let path = entry.path();

      // Skip if not a source file
      if detect_language(path).is_err() {
        continue;
      }

      // Read and parse
      if let Ok(content) = fs::read_to_string(path) {
        if let Ok(snippets) = self.extract_snippets(path, &content).await {
          extracted.snippets.extend(snippets);
        }
      }
    }

    Ok(extracted)
  }
}

/// Detect programming language from file extension
fn detect_language(path: &Path) -> Result<ProgrammingLanguage> {
  match path.extension().and_then(|e| e.to_str()) {
    Some("rs") => Ok(ProgrammingLanguage::Rust),
    Some("ts") | Some("tsx") => Ok(ProgrammingLanguage::TypeScript),
    Some("js") | Some("jsx") => Ok(ProgrammingLanguage::JavaScript),
    Some("py") => Ok(ProgrammingLanguage::Python),
    Some("go") => Ok(ProgrammingLanguage::Go),
    Some("ex") | Some("exs") => Ok(ProgrammingLanguage::Elixir),
    _ => anyhow::bail!("Unsupported language"),
  }
}

/// Extracted code data from a package
#[derive(Debug, Clone, Default)]
pub struct ExtractedCode {
  pub snippets: Vec<CodeSnippet>,
  pub examples: Vec<PackageExample>,
  pub exports: Vec<String>, // List of exported symbols
}

/// Create extractor (unified interface)
pub fn create_extractor() -> Result<SourceCodeExtractor> {
  SourceCodeExtractor::new()
}
