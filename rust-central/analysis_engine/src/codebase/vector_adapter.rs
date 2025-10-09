//! Vector Adapter - Bridge between parser output and CodeVector storage
//!
//! Parsers generate AST/metadata (functions, classes, etc)
//! This adapter converts that into CodeVector format for storage

use crate::codebase::metadata::{CodebaseMetadata, FileAnalysis};
use crate::codebase::vectors::CodeVector;
use anyhow::Result;
use std::collections::HashMap;

/// Adapter to convert parser output to CodeVector format
pub struct VectorAdapter;

impl VectorAdapter {
  /// Generate CodeVectors from file analysis
  ///
  /// Parsers output: functions, classes, complexity metrics
  /// This converts to: CodeVector with text representations for embedding
  pub fn from_file_analysis(analysis: &FileAnalysis) -> Vec<CodeVectorInput> {
    let mut inputs = Vec::new();
    let path = &analysis.path;
    let metadata = &analysis.metadata;

    // 1. File-level vector
    inputs.push(CodeVectorInput {
      id: format!("file:{}", path),
      text: Self::file_to_text(path, metadata),
      code_type: "file".to_string(),
      file_path: path.clone(),
      metadata: Self::file_metadata(metadata),
    });

    // 2. Function-level vectors (from parser output)
    for i in 0..metadata.function_count {
      inputs.push(CodeVectorInput {
        id: format!("{}:fn:{}", path, i),
        text: format!("function in {} with complexity {}", path, metadata.cyclomatic_complexity),
        code_type: "function".to_string(),
        file_path: path.clone(),
        metadata: HashMap::new(),
      });
    }

    // 3. Class-level vectors (from parser output)
    for i in 0..metadata.class_count {
      inputs.push(CodeVectorInput {
        id: format!("{}:class:{}", path, i),
        text: format!("class in {} language {}", path, metadata.language),
        code_type: "class".to_string(),
        file_path: path.clone(),
        metadata: HashMap::new(),
      });
    }

    inputs
  }

  /// Convert file metadata to text representation for embedding
  fn file_to_text(path: &str, metadata: &CodebaseMetadata) -> String {
    format!(
      "{} {} language with {} functions {} classes complexity {} maintainability {}",
      path,
      metadata.language,
      metadata.function_count,
      metadata.class_count,
      metadata.cyclomatic_complexity,
      metadata.maintainability_index
    )
  }

  /// Extract metadata for vector storage
  fn file_metadata(metadata: &CodebaseMetadata) -> HashMap<String, String> {
    let mut map = HashMap::new();
    map.insert("language".to_string(), metadata.language.clone());
    map.insert("complexity".to_string(), metadata.cyclomatic_complexity.to_string());
    map.insert("maintainability".to_string(), metadata.maintainability_index.to_string());
    map.insert("function_count".to_string(), metadata.function_count.to_string());
    map.insert("class_count".to_string(), metadata.class_count.to_string());
    map
  }

  /// Convert embedding result to CodeVector
  pub fn to_code_vector(input: CodeVectorInput, embedding: Vec<f32>) -> CodeVector {
    CodeVector::new(
      input.id,
      embedding,
      input.code_type,
      input.file_path,
    ).with_metadata(input.metadata)
  }
}

/// Input for vector generation (text to be embedded)
#[derive(Debug, Clone)]
pub struct CodeVectorInput {
  pub id: String,
  pub text: String,           // Text representation for embedding
  pub code_type: String,
  pub file_path: String,
  pub metadata: HashMap<String, String>,
}

impl CodeVector {
  /// Add metadata to existing CodeVector
  pub fn with_metadata(mut self, metadata: HashMap<String, String>) -> Self {
    self.metadata = metadata;
    self
  }
}

