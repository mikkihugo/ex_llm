//! Metadata Store for Codebase Analysis
//!
//! This module provides metadata storage capabilities for codebase analysis.
//! It stores file metadata, relationships, and analysis results.

use std::{collections::HashMap, path::PathBuf};

use serde::{Deserialize, Serialize};

/// Metadata store for codebase analysis
#[derive(Debug, Clone, Default)]
pub struct MetadataStorage {
  /// File relationships indexed by file path
  pub relationships: HashMap<PathBuf, Vec<FileRelationship>>,
  /// Analysis results indexed by file path
  pub analysis_results: HashMap<PathBuf, AnalysisResult>,
  /// Project metadata
  pub project_metadata: ProjectMetadata,
}

/// File relationship
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileRelationship {
  /// Target file path
  pub target: PathBuf,
  /// Relationship type
  pub relationship_type: RelationshipType,
  /// Strength of relationship (0.0 to 1.0)
  pub strength: f64,
}

/// Relationship type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RelationshipType {
  /// Import/dependency relationship
  Import,
  /// Inheritance relationship
  Inheritance,
  /// Composition relationship
  Composition,
  /// Function call relationship
  FunctionCall,
  /// Data flow relationship
  DataFlow,
  /// Semantic similarity
  SemanticSimilarity,
}

/// Analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
  /// File path
  pub path: PathBuf,
  /// Quality score (0.0 to 1.0)
  pub quality_score: f64,
  /// Complexity score (0.0 to 1.0)
  pub complexity_score: f64,
  /// Maintainability score (0.0 to 1.0)
  pub maintainability_score: f64,
  /// Analysis timestamp
  pub analyzed_at: u64,
}

/// Project metadata
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ProjectMetadata {
  /// Project name
  #[serde(default)]
  pub name: String,
  /// Project language
  #[serde(default)]
  pub language: String,
  /// Total files
  #[serde(default)]
  pub total_files: usize,
  /// Total lines of code
  #[serde(default)]
  pub total_lines: usize,
  /// Project creation timestamp
  #[serde(default)]
  pub created_at: u64,
  /// Last analysis timestamp
  #[serde(default)]
  pub last_analyzed_at: u64,
}

impl MetadataStorage {
  /// Create a new metadata store
  pub fn new() -> Self {
    Self {
      relationships: HashMap::new(),
      analysis_results: HashMap::new(),
      project_metadata: ProjectMetadata {
        name: String::new(),
        language: String::new(),
        total_files: 0,
        total_lines: 0,
        created_at: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
        last_analyzed_at: 0,
      },
    }
  }

  /// Add a file relationship
  pub fn add_relationship(&mut self, source: PathBuf, target: PathBuf, relationship_type: RelationshipType, strength: f64) {
    let relationship = FileRelationship { target, relationship_type, strength };

    self.relationships.entry(source).or_insert_with(Vec::new).push(relationship);
  }

  /// Add analysis result
  pub fn add_analysis_result(&mut self, path: PathBuf, quality_score: f64, complexity_score: f64, maintainability_score: f64) {
    let result = AnalysisResult {
      path: path.clone(),
      quality_score,
      complexity_score,
      maintainability_score,
      analyzed_at: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
    };

    self.analysis_results.insert(path, result);
  }

  /// Get relationships for a file
  pub fn get_relationships(&self, path: &PathBuf) -> Option<&Vec<FileRelationship>> {
    self.relationships.get(path)
  }

  /// Get analysis result for a file
  pub fn get_analysis_result(&self, path: &PathBuf) -> Option<&AnalysisResult> {
    self.analysis_results.get(path)
  }

  /// Update project metadata
  pub fn update_project_metadata(&mut self, name: String, language: String, total_files: usize, total_lines: usize) {
    self.project_metadata.name = name;
    self.project_metadata.language = language;
    self.project_metadata.total_files = total_files;
    self.project_metadata.total_lines = total_lines;
    self.project_metadata.last_analyzed_at = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs();
  }
}
