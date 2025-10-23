//! Analysis Result Types
//!
//! Structures for representing analysis results from various code analysis operations.
//! These types encapsulate the output of parsers and analyzers.

use std::collections::HashMap;
use serde::{Deserialize, Serialize};

use crate::domain::files::CodeMetadata;

/// File analysis result containing vectors, metadata, and relationships
///
/// Represents the complete analysis of a single file including semantic vectors,
/// computed metadata, and discovered relationships to other files.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileAnalysisResult {
  /// File path
  pub file_path: String,
  /// Vector embeddings extracted from the file
  pub vectors: Vec<String>,
  /// Comprehensive metadata about the file
  pub metadata: CodeMetadata,
  /// Related files based on similarity
  pub related_files: Vec<(String, f64)>,
  /// Similarity scores between this file and others
  pub similarity_scores: HashMap<String, f64>,
}

/// Documentation metadata extracted from code
///
/// Captures documentation-related information including vector embeddings
/// of documentation strings and comments.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentationMetadata {
  /// Vector embeddings of documentation content
  pub vector_embeddings: Vec<String>,
}

/// Rust-specific analysis result
///
/// Result type for Rust file analysis including complexity metrics,
/// structural elements, and documentation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RustAnalysisResult {
  /// Complexity metrics by function/method
  pub complexity_metrics: HashMap<String, f64>,
  /// List of functions found
  pub functions: Vec<String>,
  /// List of structs found
  pub structs: Vec<String>,
  /// Documentation metadata
  pub documentation_metadata: DocumentationMetadata,
}

/// Python-specific analysis result
///
/// Result type for Python file analysis including complexity metrics,
/// structural elements, and documentation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PythonAnalysisResult {
  /// Complexity metrics by function/method
  pub complexity_metrics: HashMap<String, f64>,
  /// List of functions found
  pub functions: Vec<String>,
  /// List of classes found
  pub classes: Vec<String>,
  /// Documentation metadata
  pub documentation_metadata: DocumentationMetadata,
}

/// Pattern detection result for code patterns
///
/// Represents a pattern detected in code with its location and characteristics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternDetectionResult {
  /// Pattern name
  pub pattern_name: String,
  /// Pattern type (design, anti, smell, etc.)
  pub pattern_type: String,
  /// Files where pattern is detected
  pub detected_in_files: Vec<String>,
  /// Confidence score (0.0 to 1.0)
  pub confidence: f64,
  /// Detailed description
  pub description: String,
}

/// Code database for pattern storage and querying
///
/// Stores and manages code patterns, their characteristics, and relationships.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CodePatternDatabase {
  /// Patterns indexed by name
  pub patterns: HashMap<String, PatternDetectionResult>,
  /// Pattern relationships
  pub pattern_relationships: HashMap<String, Vec<String>>,
  /// File to patterns mapping
  pub file_patterns: HashMap<String, Vec<String>>,
}

impl CodePatternDatabase {
  /// Create a new empty pattern database
  pub fn new() -> Self {
    Self {
      patterns: HashMap::new(),
      pattern_relationships: HashMap::new(),
      file_patterns: HashMap::new(),
    }
  }

  /// Add a pattern to the database
  pub fn add_pattern(&mut self, pattern: PatternDetectionResult) {
    self.patterns.insert(pattern.pattern_name.clone(), pattern);
  }

  /// Query patterns by type
  pub fn query_by_type(&self, pattern_type: &str) -> Vec<&PatternDetectionResult> {
    self.patterns
      .values()
      .filter(|p| p.pattern_type == pattern_type)
      .collect()
  }

  /// Get all patterns detected in a file
  pub fn get_file_patterns(&self, file_path: &str) -> Vec<&PatternDetectionResult> {
    self.file_patterns
      .get(file_path)
      .map(|pattern_names| {
        pattern_names
          .iter()
          .filter_map(|name| self.patterns.get(name))
          .collect()
      })
      .unwrap_or_default()
  }
}
