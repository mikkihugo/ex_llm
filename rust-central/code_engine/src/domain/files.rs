//! File-level metadata and relationships
//!
//! This module contains types for file nodes, metadata, and relationships
//! in the code graph.

use serde::{Deserialize, Serialize};

use super::{metrics::ComplexityMetrics, symbols::CodeSymbols};

/// File node in the vector-enhanced DAG
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileNode {
  /// File path
  pub file_path: String,
  /// All vector embeddings for this file
  pub vectors: Vec<String>,
  /// Comprehensive code metadata (includes all semantic features)
  pub metadata: CodeMetadata,
  /// Dependencies extracted from code (also in metadata.dependencies)
  pub dependencies: Vec<String>,
  /// Related files based on vector similarity (also in metadata.related_files)
  pub related_files: Vec<String>,

  // Parsed code storage
  /// Content hash (SHA256) for cache invalidation
  pub content_hash: Option<String>,
  /// When this file was last parsed
  pub parsed_at: Option<u64>,
  /// Parsed symbols (functions, structs, enums, traits)
  pub symbols: Option<CodeSymbols>,
}

/// THE ONE AND ONLY structure for all code analysis data
/// Replaces: FileMetadata, SemanticFeatures, AnalysisResult, Metrics, Stats, etc.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeMetadata {
  // === BASIC FILE INFO ===
  /// File size in bytes
  pub size: u64,
  /// Number of lines
  pub lines: usize,
  /// Language type
  pub language: String,
  /// Last modified timestamp
  pub last_modified: u64,
  /// File type (source, test, config, etc.)
  pub file_type: String,
  
  // === COMPLEXITY METRICS ===
  /// Cyclomatic complexity
  pub cyclomatic_complexity: f64,
  /// Cognitive complexity
  pub cognitive_complexity: f64,
  /// Maintainability index
  pub maintainability_index: f64,
  /// Nesting depth
  pub nesting_depth: u64,
  
  // === CODE METRICS ===
  /// Function count
  pub function_count: u64,
  /// Class count
  pub class_count: u64,
  /// Struct count
  pub struct_count: u64,
  /// Enum count
  pub enum_count: u64,
  /// Trait count
  pub trait_count: u64,
  /// Interface count
  pub interface_count: u64,
  
  // === LINE METRICS ===
  /// Total lines
  pub total_lines: u64,
  /// Code lines
  pub code_lines: u64,
  /// Comment lines
  pub comment_lines: u64,
  /// Blank lines
  pub blank_lines: u64,
  
  // === HALSTEAD METRICS ===
  /// Vocabulary size
  pub halstead_vocabulary: u64,
  /// Program length
  pub halstead_length: u64,
  /// Program volume
  pub halstead_volume: f64,
  /// Program difficulty
  pub halstead_difficulty: f64,
  /// Program effort
  pub halstead_effort: f64,
  
  // === PAGERANK & GRAPH METRICS ===
  /// PageRank score
  pub pagerank_score: f64,
  /// Graph centrality
  pub centrality_score: f64,
  /// Number of dependencies
  pub dependency_count: usize,
  /// Number of dependents
  pub dependent_count: usize,
  
  // === PERFORMANCE METRICS ===
  /// Technical debt ratio
  pub technical_debt_ratio: f64,
  /// Code smells count
  pub code_smells_count: usize,
  /// Duplication percentage
  pub duplication_percentage: f64,
  
  // === SECURITY METRICS ===
  /// Security score (0-100)
  pub security_score: f64,
  /// Vulnerability count
  pub vulnerability_count: usize,
  
  // === QUALITY METRICS ===
  /// Overall quality score (0-100)
  pub quality_score: f64,
  /// Test coverage percentage
  pub test_coverage: f64,
  /// Documentation coverage
  pub documentation_coverage: f64,
  
  // === SEMANTIC FEATURES ===
  /// Domain categories
  pub domains: Vec<String>,
  /// Architectural patterns
  pub patterns: Vec<String>,
  /// Technical features
  pub features: Vec<String>,
  /// Business context
  pub business_context: Vec<String>,
  /// Performance characteristics
  pub performance_characteristics: Vec<String>,
  /// Security characteristics
  pub security_characteristics: Vec<String>,
  
  // === DEPENDENCIES & RELATIONSHIPS ===
  /// Direct dependencies
  pub dependencies: Vec<String>,
  /// Related files
  pub related_files: Vec<String>,
  /// Import statements
  pub imports: Vec<String>,
  /// Export statements
  pub exports: Vec<String>,
}

impl Default for CodeMetadata {
  fn default() -> Self {
    Self {
      // Basic file info
      size: 0,
      lines: 0,
      language: "unknown".to_string(),
      last_modified: 0,
      file_type: "source".to_string(),
      
      // Complexity metrics
      cyclomatic_complexity: 0.0,
      cognitive_complexity: 0.0,
      maintainability_index: 0.0,
      nesting_depth: 0,
      
      // Code metrics
      function_count: 0,
      class_count: 0,
      struct_count: 0,
      enum_count: 0,
      trait_count: 0,
      interface_count: 0,
      
      // Line metrics
      total_lines: 0,
      code_lines: 0,
      comment_lines: 0,
      blank_lines: 0,
      
      // Halstead metrics
      halstead_vocabulary: 0,
      halstead_length: 0,
      halstead_volume: 0.0,
      halstead_difficulty: 0.0,
      halstead_effort: 0.0,
      
      // PageRank & graph metrics
      pagerank_score: 0.0,
      centrality_score: 0.0,
      dependency_count: 0,
      dependent_count: 0,
      
      // Performance metrics
      technical_debt_ratio: 0.0,
      code_smells_count: 0,
      duplication_percentage: 0.0,
      
      // Security metrics
      security_score: 0.0,
      vulnerability_count: 0,
      
      // Quality metrics
      quality_score: 0.0,
      test_coverage: 0.0,
      documentation_coverage: 0.0,
      
      // Semantic features
      domains: Vec::new(),
      patterns: Vec::new(),
      features: Vec::new(),
      business_context: Vec::new(),
      performance_characteristics: Vec::new(),
      security_characteristics: Vec::new(),
      
      // Dependencies & relationships
      dependencies: Vec::new(),
      related_files: Vec::new(),
      imports: Vec::new(),
      exports: Vec::new(),
    }
  }
}

// SemanticFeatures removed - all semantic data is now in CodeMetadata!
// Use CodeMetadata.domains, CodeMetadata.patterns, etc. instead

/// File relationship in the DAG
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileRelationship {
  /// Relationship type
  pub relationship_type: crate::domain::relationships::RelationshipType,
  /// Similarity score (0.0 to 1.0)
  pub similarity_score: f64,
  /// Confidence level
  pub confidence: f64,
  /// Relationship strength
  pub strength: crate::domain::relationships::RelationshipStrength,
  /// Context of the relationship
  pub context: String,
}
