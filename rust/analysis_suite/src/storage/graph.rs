//! Code Semantic DAG for File Relationships
//!
//! Links files to vectors and creates intelligent relationships based on semantic similarity.
//! This module provides a sophisticated graph structure that models file relationships
//! using vector embeddings for semantic understanding and dependency tracking.
//!
//! # Features
//!
//! - **Semantic Similarity**: Uses vector embeddings to find semantically similar files
//! - **Dependency Tracking**: Models explicit and implicit dependencies between files
//! - **Complexity Analysis**: Tracks code complexity metrics for each file
//! - **Relationship Types**: Supports multiple relationship types (depends, imports, similar, etc.)
//! - **Concurrent Access**: Thread-safe operations with async/await support
//! - **Vector Integration**: Seamless integration with vector embeddings and ML models
//!
//! # Examples
//!
//! ## Basic Usage
//!
//! ```rust
//! use std::collections::HashMap;
//!
//! use analysis_suite::analysis::dag::{
//!   ComplexityMetrics, FileMetadata, FileNode, RelationshipType, SemanticFeatures, VectorDAG,
//! };
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!   // Create a new DAG
//!   let mut dag = VectorDAG::new();
//!
//!   // Create file nodes
//!   let user_service = FileNode {
//!     file_path: "src/services/user.rs".to_string(),
//!     vectors: vec!["user-management".to_string(), "authentication".to_string()],
//!     metadata: FileMetadata {
//!       size: 1024,
//!       lines: 50,
//!       language: "rust".to_string(),
//!       last_modified: 1234567890,
//!       file_type: "source".to_string(),
//!       complexity: ComplexityMetrics { cyclomatic: 5.0, cognitive: 3.0, maintainability: 0.8 },
//!     },
//!     semantic_features: SemanticFeatures {
//!       keywords: vec!["user".to_string(), "auth".to_string()],
//!       patterns: vec!["service".to_string()],
//!       concepts: vec!["authentication".to_string()],
//!     },
//!     dependencies: vec!["src/models/user.rs".to_string()],
//!     related_files: vec![],
//!   };
//!
//!   let user_model = FileNode {
//!     file_path: "src/models/user.rs".to_string(),
//!     vectors: vec!["user-model".to_string(), "data-structure".to_string()],
//!     metadata: FileMetadata {
//!       size: 512,
//!       lines: 25,
//!       language: "rust".to_string(),
//!       last_modified: 1234567890,
//!       file_type: "source".to_string(),
//!       complexity: ComplexityMetrics { cyclomatic: 2.0, cognitive: 1.0, maintainability: 0.9 },
//!     },
//!     semantic_features: SemanticFeatures {
//!       keywords: vec!["user".to_string(), "model".to_string()],
//!       patterns: vec!["struct".to_string()],
//!       concepts: vec!["data-model".to_string()],
//!     },
//!     dependencies: vec![],
//!     related_files: vec![],
//!   };
//!
//!   // Add files to DAG
//!   dag.add_file(user_service).await?;
//!   dag.add_file(user_model).await?;
//!
//!   // Add dependency relationship
//!   dag
//!     .add_relationship("src/services/user.rs", "src/models/user.rs", RelationshipType::DependsOn)
//!     .await?;
//!
//!   // Find similar files based on vectors
//!   let similar_files = dag.find_similar_files("src/services/user.rs", 0.8).await?;
//!   println!("Similar files: {:?}", similar_files);
//!
//!   // Get file relationships
//!   let relationships = dag.get_file_relationships("src/services/user.rs").await?;
//!   println!("Relationships: {:?}", relationships);
//!
//!   Ok(())
//! }
//! ```
//!
//! ## Advanced Usage with Vector Analysis
//!
//! ```rust
//! use analysis_suite::analysis::dag::{SemanticAnalysis, VectorDAG};
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!   let mut dag = VectorDAG::new();
//!
//!   // Analyze semantic similarity between files
//!   let analysis = SemanticAnalysis::new();
//!   let similarity_score =
//!     analysis.calculate_similarity("src/services/user.rs", "src/services/auth.rs", &dag).await?;
//!
//!   if similarity_score > 0.7 {
//!     dag
//!       .add_relationship(
//!         "src/services/user.rs",
//!         "src/services/auth.rs",
//!         RelationshipType::SemanticallySimilar,
//!       )
//!       .await?;
//!   }
//!
//!   // Get DAG statistics
//!   let stats = dag.get_stats().await?;
//!   println!("DAG Stats: {:?}", stats);
//!
//!   Ok(())
//! }
//! ```
//!
//! ## Performance Considerations
//!
//! - **Concurrent Access**: All operations are thread-safe and can be called concurrently
//! - **Memory Efficiency**: Uses efficient data structures for large codebases
//! - **Vector Caching**: Caches vector embeddings to avoid recomputation
//! - **Incremental Updates**: Supports incremental updates without full rebuilds
//!
//! @category graph-analysis @safe large-solution @mvp core @complexity high @since 1.0.0
//! @graph-nodes: [vector-dag, file-relationships, semantic-similarity, dependency-graph]
//! @graph-edges: [vector-dag->file-relationships, semantic-similarity->dependency-graph]
//! @vector-embedding: "vector enhanced DAG file relationships semantic similarity dependency graph analysis"

use serde::{Deserialize, Serialize};

/// File node in the vector-enhanced DAG
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileNode {
  /// File path
  pub file_path: String,
  /// All vector embeddings for this file
  pub vectors: Vec<String>,
  /// Code metadata
  pub metadata: CodeMetadata,
  /// Semantic features extracted
  pub semantic_features: SemanticFeatures,
  /// Dependencies extracted from code
  pub dependencies: Vec<String>,
  /// Related files based on vector similarity
  pub related_files: Vec<String>,

  // Parsed code storage
  /// Content hash (SHA256) for cache invalidation
  pub content_hash: Option<String>,
  /// When this file was last parsed
  pub parsed_at: Option<u64>,
  /// Parsed symbols (functions, structs, enums, traits)
  pub symbols: Option<CodeSymbols>,
}

// FileMetadata is now imported from domain::files
use crate::domain::files::CodeMetadata;

/// Complexity metrics for files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplexityMetrics {
  /// Cyclomatic complexity
  pub cyclomatic: f64,
  /// Cognitive complexity
  pub cognitive: f64,
  /// Maintainability index
  pub maintainability: f64,
  /// Function count
  pub function_count: usize,
  /// Class/trait count
  pub class_count: usize,

  // Mozilla metrics integration
  /// Halstead volume
  pub halstead_volume: f64,
  /// Halstead difficulty
  pub halstead_difficulty: f64,
  /// Halstead effort
  pub halstead_effort: f64,

  // Line counts
  /// Total lines
  pub total_lines: usize,
  /// Code lines
  pub code_lines: usize,
  /// Comment lines
  pub comment_lines: usize,
  /// Blank lines
  pub blank_lines: usize,
}

/// Semantic features for vector similarity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SemanticFeatures {
  /// Domain categories
  pub domains: Vec<String>,
  /// Architectural patterns
  pub patterns: Vec<String>,
  /// Technical features
  pub features: Vec<String>,
  /// Business context
  pub business_context: Vec<String>,
  /// Performance characteristics
  pub performance: Vec<String>,
  /// Security aspects
  pub security: Vec<String>,
}

/// Relationship edge between files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileRelationship {
  /// Relationship type
  pub relationship_type: RelationshipType,
  /// Similarity score (0.0 to 1.0)
  pub similarity_score: f64,
  /// Confidence level
  pub confidence: f64,
  /// Relationship strength
  pub strength: RelationshipStrength,
  /// Context of the relationship
  pub context: String,
}

/// Types of relationships between files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RelationshipType {
  /// Direct dependency (imports, includes)
  Dependency,
  /// Similar functionality
  Functional,
  /// Same domain/business area
  Domain,
  /// Architectural similarity
  Architectural,
  /// Data flow relationship
  DataFlow,
  /// Test relationship
  Test,
  /// Configuration relationship
  Configuration,
  /// Documentation relationship
  Documentation,
  /// Microservice communication
  MicroserviceCommunication,
  /// API dependency
  ApiDependency,
  /// Service discovery
  ServiceDiscovery,
  /// Message queue relationship
  MessageQueue,
  /// Database relationship
  DatabaseRelationship,
  /// Event streaming
  EventStreaming,
  /// Load balancer relationship
  LoadBalancer,
  /// Gateway relationship
  Gateway,
}

/// Strength of relationship
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RelationshipStrength {
  /// Very strong relationship (>0.8)
  VeryStrong,
  /// Strong relationship (0.6-0.8)
  Strong,
  /// Moderate relationship (0.4-0.6)
  Moderate,
  /// Weak relationship (0.2-0.4)
  Weak,
  /// Very weak relationship (<0.2)
  VeryWeak,
}

/// Parsed code symbols stored in DAG nodes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeSymbols {
  /// Functions
  pub functions: Vec<FunctionSymbol>,
  /// Structs/classes
  pub structs: Vec<StructSymbol>,
  /// Enums
  pub enums: Vec<EnumSymbol>,
  /// Traits/interfaces
  pub traits: Vec<TraitSymbol>,
  /// Imports
  pub imports: Vec<String>,
  /// Exports
  pub exports: Vec<String>,
}

/// Function symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionSymbol {
  pub name: String,
  pub start_line: usize,
  pub end_line: usize,
  pub parameters: Vec<String>,
  pub return_type: Option<String>,
  pub is_async: bool,
  pub is_public: bool,
}

/// Struct/class symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructSymbol {
  pub name: String,
  pub start_line: usize,
  pub fields: Vec<String>,
  pub is_public: bool,
}

/// Enum symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnumSymbol {
  pub name: String,
  pub start_line: usize,
  pub variants: Vec<String>,
  pub is_public: bool,
}

/// Trait/interface symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraitSymbol {
  pub name: String,
  pub start_line: usize,
  pub methods: Vec<String>,
  pub is_public: bool,
}

/// Code semantic DAG for file relationships
// Graph implementation has been moved to crate::graph module
// Re-export for backward compatibility
pub use crate::graph::{DAGStats, Graph, GraphHandle, VectorDAG};

// Old implementation removed - now lives in crate::graph::Graph
/*
 * Commented out - Graph implementation moved to crate::graph module
 *
// pub struct Graph {
//   /// The graph structure
//   graph: PetGraph<FileNode, FileRelationship, Directed>,
//   /// File path to node index mapping
//   file_to_node: HashMap<String, NodeIndex>,
//   /// Vector similarity cache
//   similarity_cache: HashMap<(String, String), f64>,
//   /// Relationship cache
//   relationship_cache: HashMap<(String, String), FileRelationship>,
// }
// 
// impl Graph {
//   /// Create a new vector-enhanced DAG
//   pub fn new() -> Self {
//     Self { graph: PetGraph::new(), file_to_node: HashMap::new(), similarity_cache: HashMap::new(), relationship_cache: HashMap::new() }
//   }
// 
//   /// Add a file node to the DAG
//   pub fn add_file(&mut self, file_path: String, vectors: Vec<String>, metadata: FileMetadata) -> NodeIndex {
//     let semantic_features = self.extract_semantic_features(&vectors);
//     let dependencies = self.extract_dependencies(&vectors);
// 
//     let file_node = FileNode {
//       file_path: file_path.clone(),
//       vectors,
//       metadata,
//       semantic_features,
//       dependencies,
//       related_files: Vec::new(),
//       content_hash: None,
//       parsed_at: None,
//       symbols: None,
//     };
// 
//     let node_index = self.graph.add_node(file_node);
//     self.file_to_node.insert(file_path, node_index);
//     node_index
//   }
// 
//   /// Extract semantic features from vectors
//   fn extract_semantic_features(&self, vectors: &[String]) -> SemanticFeatures {
//     let mut domains = Vec::new();
//     let mut patterns = Vec::new();
//     let mut features = Vec::new();
//     let mut business_context = Vec::new();
//     let mut performance = Vec::new();
//     let mut security = Vec::new();
// 
//     for vector in vectors {
//       if vector.contains("domain:") {
//         domains.push(vector.clone());
//       } else if vector.contains("pattern:") || vector.contains("behavior:") || vector.contains("structure:") {
//         patterns.push(vector.clone());
//       } else if vector.contains("functionality") || vector.contains("cognitive") || vector.contains("functional") {
//         features.push(vector.clone());
//       } else if vector.contains("business") || vector.contains("financial") || vector.contains("ecommerce") {
//         business_context.push(vector.clone());
//       } else if vector.contains("performance") || vector.contains("cached") || vector.contains("optimized") {
//         performance.push(vector.clone());
//       } else if vector.contains("security") || vector.contains("authenticated") || vector.contains("encrypted") {
//         security.push(vector.clone());
//       }
//     }
// 
//     SemanticFeatures { domains, patterns, features, business_context, performance, security }
//   }
// 
//   /// Extract dependencies from vectors
//   fn extract_dependencies(&self, vectors: &[String]) -> Vec<String> {
//     let mut dependencies = Vec::new();
// 
//     for vector in vectors {
//       if vector.contains("dependencies:") {
//         // Extract dependency names from vector
//         let parts: Vec<&str> = vector.split("dependencies:").collect();
//         if parts.len() > 1 {
//           let deps_str = parts[1].trim();
//           let deps: Vec<&str> = deps_str.split(',').collect();
//           for dep in deps {
//             dependencies.push(dep.trim().to_string());
//           }
//         }
//       }
//     }
// 
//     dependencies
//   }
// 
//   /// Calculate vector similarity between two files
//   pub fn calculate_similarity(&mut self, file1: &str, file2: &str) -> f64 {
//     // Check cache first
//     let cache_key = (file1.to_string(), file2.to_string());
//     if let Some(&similarity) = self.similarity_cache.get(&cache_key) {
//       return similarity;
//     }
// 
//     let similarity = if let (Some(node1), Some(node2)) = (self.file_to_node.get(file1), self.file_to_node.get(file2)) {
//       let file1_node = &self.graph[*node1];
//       let file2_node = &self.graph[*node2];
// 
//       self.calculate_vector_similarity(&file1_node.vectors, &file2_node.vectors)
//     } else {
//       0.0
//     };
// 
//     // Cache the result
//     self.similarity_cache.insert(cache_key, similarity);
//     similarity
//   }
// 
//   /// Calculate similarity between two vector sets
//   fn calculate_vector_similarity(&self, vectors1: &[String], vectors2: &[String]) -> f64 {
//     if vectors1.is_empty() || vectors2.is_empty() {
//       return 0.0;
//     }
// 
//     let mut total_similarity = 0.0;
//     let mut comparisons = 0;
// 
//     for v1 in vectors1 {
//       for v2 in vectors2 {
//         let similarity = self.calculate_string_similarity(v1, v2);
//         total_similarity += similarity;
//         comparisons += 1;
//       }
//     }
// 
//     if comparisons > 0 {
//       total_similarity / comparisons as f64
//     } else {
//       0.0
//     }
//   }
// 
//   /// Calculate string similarity using Jaccard index
//   fn calculate_string_similarity(&self, s1: &str, s2: &str) -> f64 {
//     let words1: HashSet<&str> = s1.split_whitespace().collect();
//     let words2: HashSet<&str> = s2.split_whitespace().collect();
// 
//     let intersection = words1.intersection(&words2).count();
//     let union = words1.union(&words2).count();
// 
//     if union > 0 {
//       intersection as f64 / union as f64
//     } else {
//       0.0
//     }
//   }
// 
//   /// Infer relationships between files based on vector similarity
//   pub fn infer_relationships(&mut self) {
//     let file_paths: Vec<String> = self.file_to_node.keys().cloned().collect();
// 
//     for i in 0..file_paths.len() {
//       for j in (i + 1)..file_paths.len() {
//         let file1 = &file_paths[i];
//         let file2 = &file_paths[j];
// 
//         let similarity = self.calculate_similarity(file1, file2);
// 
//         if similarity > 0.2 {
//           // Threshold for creating relationships
//           let relationship = self.create_relationship(file1, file2, similarity);
// 
//           if let (Some(node1), Some(node2)) = (self.file_to_node.get(file1), self.file_to_node.get(file2)) {
//             self.graph.add_edge(*node1, *node2, relationship.clone());
//             self.graph.add_edge(*node2, *node1, relationship);
//           }
//         }
//       }
//     }
//   }
// 
//   /// Create a relationship between two files
//   fn create_relationship(&self, file1: &str, file2: &str, similarity: f64) -> FileRelationship {
//     let relationship_type = self.determine_relationship_type(file1, file2, similarity);
//     let strength = self.determine_relationship_strength(similarity);
//     let confidence = self.calculate_confidence(file1, file2, similarity);
//     let context = self.generate_context(file1, file2, similarity);
// 
//     FileRelationship { relationship_type, similarity_score: similarity, confidence, strength, context }
//   }
// 
//   /// Determine relationship type based on file analysis
//   fn determine_relationship_type(&self, file1: &str, file2: &str, similarity: f64) -> RelationshipType {
//     // Analyze file paths and content to determine relationship type
//     if file1.contains("test") || file2.contains("test") {
//       RelationshipType::Test
//     } else if file1.contains("config") || file2.contains("config") {
//       RelationshipType::Configuration
//     } else if file1.contains("doc") || file2.contains("doc") {
//       RelationshipType::Documentation
//     } else if self.is_microservice_communication(file1, file2) {
//       RelationshipType::MicroserviceCommunication
//     } else if self.is_api_dependency(file1, file2) {
//       RelationshipType::ApiDependency
//     } else if self.is_service_discovery(file1, file2) {
//       RelationshipType::ServiceDiscovery
//     } else if self.is_message_queue(file1, file2) {
//       RelationshipType::MessageQueue
//     } else if self.is_database_relationship(file1, file2) {
//       RelationshipType::DatabaseRelationship
//     } else if self.is_event_streaming(file1, file2) {
//       RelationshipType::EventStreaming
//     } else if self.is_load_balancer(file1, file2) {
//       RelationshipType::LoadBalancer
//     } else if self.is_gateway(file1, file2) {
//       RelationshipType::Gateway
//     } else if similarity > 0.7 {
//       RelationshipType::Functional
//     } else if similarity > 0.5 {
//       RelationshipType::Domain
//     } else {
//       RelationshipType::Architectural
//     }
//   }
// 
//   /// Check if files represent microservice communication
//   fn is_microservice_communication(&self, file1: &str, file2: &str) -> bool {
//     let ms_patterns = ["service", "microservice", "api", "client", "server"];
//     ms_patterns.iter().any(|pattern| file1.contains(pattern) && file2.contains(pattern))
//   }
// 
//   /// Check if files represent API dependencies
//   fn is_api_dependency(&self, file1: &str, file2: &str) -> bool {
//     let api_patterns = ["api", "endpoint", "route", "controller"];
//     api_patterns.iter().any(|pattern| file1.contains(pattern) || file2.contains(pattern))
//   }
// 
//   /// Check if files represent service discovery
//   fn is_service_discovery(&self, file1: &str, file2: &str) -> bool {
//     let discovery_patterns = ["discovery", "registry", "consul", "etcd", "eureka"];
//     discovery_patterns.iter().any(|pattern| file1.contains(pattern) || file2.contains(pattern))
//   }
// 
//   /// Check if files represent message queue relationships
//   fn is_message_queue(&self, file1: &str, file2: &str) -> bool {
//     let mq_patterns = ["queue", "kafka", "rabbitmq", "redis", "pubsub", "message"];
//     mq_patterns.iter().any(|pattern| file1.contains(pattern) || file2.contains(pattern))
//   }
// 
//   /// Check if files represent database relationships
//   fn is_database_relationship(&self, file1: &str, file2: &str) -> bool {
//     let db_patterns = ["database", "db", "sql", "mongo", "postgres", "mysql", "repository"];
//     db_patterns.iter().any(|pattern| file1.contains(pattern) || file2.contains(pattern))
//   }
// 
//   /// Check if files represent event streaming
//   fn is_event_streaming(&self, file1: &str, file2: &str) -> bool {
//     let event_patterns = ["event", "stream", "kafka", "eventstore", "pipeline"];
//     event_patterns.iter().any(|pattern| file1.contains(pattern) || file2.contains(pattern))
//   }
// 
//   /// Check if files represent load balancer relationships
//   fn is_load_balancer(&self, file1: &str, file2: &str) -> bool {
//     let lb_patterns = ["loadbalancer", "nginx", "haproxy", "traefik", "proxy"];
//     lb_patterns.iter().any(|pattern| file1.contains(pattern) || file2.contains(pattern))
//   }
// 
//   /// Check if files represent gateway relationships
//   fn is_gateway(&self, file1: &str, file2: &str) -> bool {
//     let gateway_patterns = ["gateway", "zuul", "kong", "ambassador", "istio"];
//     gateway_patterns.iter().any(|pattern| file1.contains(pattern) || file2.contains(pattern))
//   }
// 
//   /// Determine relationship strength based on similarity score
//   fn determine_relationship_strength(&self, similarity: f64) -> RelationshipStrength {
//     match similarity {
//       s if s > 0.8 => RelationshipStrength::VeryStrong,
//       s if s > 0.6 => RelationshipStrength::Strong,
//       s if s > 0.4 => RelationshipStrength::Moderate,
//       s if s > 0.2 => RelationshipStrength::Weak,
//       _ => RelationshipStrength::VeryWeak,
//     }
//   }
// 
//   /// Calculate confidence in the relationship
//   fn calculate_confidence(&self, file1: &str, file2: &str, similarity: f64) -> f64 {
//     // Base confidence on similarity and file characteristics
//     let mut confidence = similarity;
// 
//     // Boost confidence for similar file types
//     if self.same_file_type(file1, file2) {
//       confidence += 0.1;
//     }
// 
//     // Boost confidence for similar directory structure
//     if self.same_directory_structure(file1, file2) {
//       confidence += 0.1;
//     }
// 
//     confidence.min(1.0)
//   }
// 
//   /// Check if files are of the same type
//   fn same_file_type(&self, file1: &str, file2: &str) -> bool {
//     let ext1 = file1.split('.').last().unwrap_or("");
//     let ext2 = file2.split('.').last().unwrap_or("");
//     ext1 == ext2
//   }
// 
//   /// Check if files have similar directory structure
//   fn same_directory_structure(&self, file1: &str, file2: &str) -> bool {
//     let dir1 = file1.split('/').nth_back(1).unwrap_or("");
//     let dir2 = file2.split('/').nth_back(1).unwrap_or("");
//     dir1 == dir2
//   }
// 
//   /// Generate context for the relationship
//   fn generate_context(&self, file1: &str, file2: &str, similarity: f64) -> String {
//     format!("Files {} and {} have {:.1}% similarity based on vector analysis", file1, file2, similarity * 100.0)
//   }
// 
//   /// Get related files for a given file
//   pub fn get_related_files(&self, file_path: &str) -> Vec<(String, f64)> {
//     if let Some(node_index) = self.file_to_node.get(file_path) {
//       let mut related = Vec::new();
// 
//       for edge in self.graph.edges_directed(*node_index, petgraph::Direction::Outgoing) {
//         let target_node = &self.graph[edge.target()];
//         let relationship = &edge.weight();
//         related.push((target_node.file_path.clone(), relationship.similarity_score));
//       }
// 
//       // Sort by similarity score
//       related.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
//       related
//     } else {
//       Vec::new()
//     }
//   }
// 
//   /// Get DAG statistics
//   pub fn get_stats(&self) -> DAGStats {
//     DAGStats {
//       total_files: self.graph.node_count(),
//       total_relationships: self.graph.edge_count(),
//       average_relationships_per_file: if self.graph.node_count() > 0 { self.graph.edge_count() as f64 / self.graph.node_count() as f64 } else { 0.0 },
//       cache_hits: self.similarity_cache.len(),
//     }
//   }
// 
//   /// Find files with similar vectors
//   pub fn find_similar_files(&self, file_path: &str, threshold: f64) -> Vec<(String, f64)> {
//     let mut similar_files = Vec::new();
// 
//     if let Some(node_index) = self.file_to_node.get(file_path) {
//       let source_node = &self.graph[*node_index];
// 
//       for (path, other_node_index) in &self.file_to_node {
//         if path != file_path {
//           let similarity = self.calculate_vector_similarity(&source_node.vectors, &self.graph[*other_node_index].vectors);
// 
//           if similarity >= threshold {
//             similar_files.push((path.clone(), similarity));
//           }
//         }
//       }
//     }
// 
//     // Sort by similarity score
//     similar_files.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
//     similar_files
//   }
// 
//   /// Optimize DAG traversal using vector embeddings
//   pub fn optimize_traversal(&self, start_file: &str, target_file: &str) -> Option<Vec<String>> {
//     if let (Some(start_node), Some(target_node)) = (self.file_to_node.get(start_file), self.file_to_node.get(target_file)) {
//       // Use Dijkstra's algorithm with vector similarity as weights
//       self.find_shortest_path(*start_node, *target_node)
//     } else {
//       None
//     }
//   }
// 
//   /// Find shortest path between two nodes
//   fn find_shortest_path(&self, start: NodeIndex, target: NodeIndex) -> Option<Vec<String>> {
//     use petgraph::algo::dijkstra;
// 
//     let distances = dijkstra(&self.graph, start, Some(target), |edge| {
//       // Use inverse similarity as weight (higher similarity = lower weight)
//       1.0 - edge.weight().similarity_score
//     });
// 
//     if let Some(_distance) = distances.get(&target) {
//       // Reconstruct path (simplified - in practice you'd want a more sophisticated path reconstruction)
//       Some(vec![self.graph[start].file_path.clone(), self.graph[target].file_path.clone()])
//     } else {
//       None
//     }
//   }
// }
// 
// /// Type alias for backward compatibility
// pub type VectorDAG = Graph;
// 
// /// Statistics for the vector-enhanced DAG
// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct DAGStats {
//   /// Total number of files
//   pub total_files: usize,
//   /// Total number of relationships
//   pub total_relationships: usize,
//   /// Average relationships per file
//   pub average_relationships_per_file: f64,
//   /// Number of cache hits
//   pub cache_hits: usize,
// }
// 
// /// Thread-safe handle for Graph
// pub type GraphHandle = Arc<RwLock<Graph>>;

impl Default for Graph {
  fn default() -> Self {
    Self::new()
  }
}
*/
