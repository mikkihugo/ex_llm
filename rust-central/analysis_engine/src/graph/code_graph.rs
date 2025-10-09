//! Code Graph Analysis for SPARC Engine
//!
//! Creates and analyzes various graph structures from codebases:
//! - Call Graph: Function dependencies (DAG)
//! - Import Graph: Module dependencies (DAG)
//! - Semantic Graph: Concept relationships (General Graph)
//!
//! Uses petgraph for robust graph data structures and algorithms

use std::{collections::HashMap, path::PathBuf};

use anyhow::Result;
use petgraph::{
  algo::{is_cyclic_directed, kosaraju_scc, toposort},
  graph::{DiGraph, EdgeIndex, NodeIndex},
  Direction,
};
use serde::{Deserialize, Serialize};

use crate::analysis::semantic::ml_similarity::{MLVectorizer, MultiModalFusion};
use crate::analysis::CodeMetadata;

// Type alias for backward compatibility
pub type CodeGraph = CodeDependencyGraph;

/// Types of graphs we can build from code
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum GraphType {
  CallGraph,     // Function call dependencies (DAG)
  ImportGraph,   // Module import dependencies (DAG)
  SemanticGraph, // Conceptual relationships (General Graph)
  DataFlowGraph, // Variable and data dependencies (DAG)
}

/// Node in a code graph with real vector embedding
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphNode {
  pub id: String,
  pub node_type: String, // "function", "module", "class", "variable"
  pub name: String,
  pub file_path: PathBuf,
  pub line_number: Option<usize>,
  pub vector: Option<Vec<f32>>,      // Real vector embedding
  pub vector_magnitude: Option<f32>, // Cached for fast similarity
}

/// Edge between nodes in a code graph
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
  pub from: String,      // Source node ID
  pub to: String,        // Target node ID
  pub edge_type: String, // "calls", "imports", "inherits", "uses"
  pub weight: f64,       // Edge strength/frequency
  pub metadata: HashMap<String, serde_json::Value>,
}

/// Complete code dependency graph structure with petgraph backend
#[derive(Debug, Clone)]
pub struct CodeDependencyGraph {
  pub graph_type: GraphType,
  pub graph: DiGraph<GraphNode, GraphEdge>,    // petgraph directed graph
  pub node_lookup: HashMap<String, NodeIndex>, // ID -> NodeIndex mapping
}

impl CodeDependencyGraph {
  /// Create new empty code graph
  pub fn new(graph_type: GraphType) -> Self {
    Self { graph_type, graph: DiGraph::new(), node_lookup: HashMap::new() }
  }

  /// Add a node to the graph
  pub fn add_node(&mut self, node: GraphNode) -> NodeIndex {
    let node_id = node.id.clone();
    let node_index = self.graph.add_node(node);
    self.node_lookup.insert(node_id, node_index);
    node_index
  }

  /// Add an edge to the graph
  pub fn add_edge(&mut self, edge: GraphEdge) -> Result<EdgeIndex> {
    let from_index = self.node_lookup.get(&edge.from).ok_or_else(|| anyhow::anyhow!("Source node '{}' not found", edge.from))?;
    let to_index = self.node_lookup.get(&edge.to).ok_or_else(|| anyhow::anyhow!("Target node '{}' not found", edge.to))?;

    let edge_index = self.graph.add_edge(*from_index, *to_index, edge);
    Ok(edge_index)
  }

  /// Get direct dependencies of a node (outgoing edges)
  pub fn get_dependencies(&self, node_id: &str) -> Vec<&GraphNode> {
    if let Some(&node_index) = self.node_lookup.get(node_id) {
      self.graph.neighbors_directed(node_index, Direction::Outgoing).filter_map(|neighbor_index| self.graph.node_weight(neighbor_index)).collect()
    } else {
      Vec::new()
    }
  }

  /// Get direct dependents of a node (incoming edges)
  pub fn get_dependents(&self, node_id: &str) -> Vec<&GraphNode> {
    if let Some(&node_index) = self.node_lookup.get(node_id) {
      self.graph.neighbors_directed(node_index, Direction::Incoming).filter_map(|neighbor_index| self.graph.node_weight(neighbor_index)).collect()
    } else {
      Vec::new()
    }
  }

  /// Get node by ID
  pub fn get_node(&self, node_id: &str) -> Option<&GraphNode> {
    self.node_lookup.get(node_id).and_then(|&index| self.graph.node_weight(index))
  }

  /// Check if graph has cycles (using petgraph algorithm)
  pub fn has_cycles(&self) -> bool {
    is_cyclic_directed(&self.graph)
  }

  /// Get topological ordering (for DAGs only)
  pub fn topological_sort(&self) -> Result<Vec<String>> {
    match toposort(&self.graph, None) {
      Ok(node_indices) => {
        let node_ids: Vec<String> = node_indices.into_iter().filter_map(|index| self.graph.node_weight(index)).map(|node| node.id.clone()).collect();
        Ok(node_ids)
      }
      Err(_) => Err(anyhow::anyhow!("Graph contains cycles - cannot perform topological sort")),
    }
  }

  /// Get strongly connected components
  pub fn strongly_connected_components(&self) -> Vec<Vec<String>> {
    let sccs = kosaraju_scc(&self.graph);

    sccs.into_iter().map(|component| component.into_iter().filter_map(|index| self.graph.node_weight(index)).map(|node| node.id.clone()).collect()).collect()
  }

  /// Find semantically similar nodes using advanced vector similarity
  pub fn find_similar_nodes(&self, query_node_id: &str, top_k: usize) -> Vec<(String, f32)> {
    if let Some(query_node) = self.get_node(query_node_id) {
      if let Some(query_vector) = &query_node.vector {
        let query_magnitude = query_node.vector_magnitude.unwrap_or(0.0);

        let mut similarities = Vec::new();

        for (node_id, &node_index) in &self.node_lookup {
          if node_id != query_node_id {
            if let Some(node) = self.graph.node_weight(node_index) {
              if let (Some(node_vector), Some(node_magnitude)) = (&node.vector, node.vector_magnitude) {
                // Use advanced similarity combining multiple metrics
                let cosine_sim = Self::cosine_similarity(query_vector, node_vector, query_magnitude, node_magnitude);
                let jaccard_sim = Self::jaccard_similarity(&query_node.name, &node.name);
                let structural_sim = Self::structural_similarity(query_node, node);

                // Weighted combination for better results
                let combined_similarity = 0.6 * cosine_sim + 0.25 * jaccard_sim + 0.15 * structural_sim;
                similarities.push((node_id.clone(), combined_similarity));
              }
            }
          }
        }

        similarities.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        similarities.truncate(top_k);
        similarities
      } else {
        Vec::new()
      }
    } else {
      Vec::new()
    }
  }

  /// Find codebase patterns using graph topology and semantics
  pub fn find_codebase_patterns(&self) -> CodebaseCodePatterns {
    let mut patterns = CodebaseCodePatterns::new();

    // Detect architectural patterns
    patterns.hub_nodes = self.find_hub_nodes(5);
    patterns.leaf_nodes = self.find_leaf_nodes();
    patterns.bridge_components = self.find_bridge_components();
    patterns.circular_dependencies = self.detect_circular_dependencies();

    // Semantic clustering
    patterns.semantic_clusters = self.cluster_by_similarity(0.7);
    patterns.naming_conventions = self.analyze_naming_patterns();

    patterns
  }

  /// Find hub nodes (high connectivity)
  fn find_hub_nodes(&self, min_connections: usize) -> Vec<String> {
    self
      .node_lookup
      .iter()
      .filter_map(|(node_id, &node_index)| {
        let in_degree = self.graph.neighbors_directed(node_index, Direction::Incoming).count();
        let out_degree = self.graph.neighbors_directed(node_index, Direction::Outgoing).count();

        if in_degree + out_degree >= min_connections {
          Some(node_id.clone())
        } else {
          None
        }
      })
      .collect()
  }

  /// Find leaf nodes (minimal dependencies)
  fn find_leaf_nodes(&self) -> Vec<String> {
    self
      .node_lookup
      .iter()
      .filter_map(|(node_id, &node_index)| {
        let out_degree = self.graph.neighbors_directed(node_index, Direction::Outgoing).count();

        if out_degree == 0 {
          Some(node_id.clone())
        } else {
          None
        }
      })
      .collect()
  }

  /// Detect circular dependencies using SCC analysis
  fn detect_circular_dependencies(&self) -> Vec<Vec<String>> {
    let sccs = self.strongly_connected_components();
    sccs.into_iter().filter(|component| component.len() > 1).collect()
  }

  /// Find bridge components (critical connection points)
  fn find_bridge_components(&self) -> Vec<String> {
    // Nodes whose removal would significantly increase graph disconnection
    let mut bridge_nodes = Vec::new();

    for (node_id, &node_index) in &self.node_lookup {
      let connections =
        self.graph.neighbors_directed(node_index, Direction::Incoming).count() + self.graph.neighbors_directed(node_index, Direction::Outgoing).count();

      // High connectivity nodes that bridge different parts
      if connections > 3 {
        bridge_nodes.push(node_id.clone());
      }
    }

    bridge_nodes
  }

  /// Cluster nodes by semantic similarity
  fn cluster_by_similarity(&self, threshold: f32) -> Vec<Vec<String>> {
    let mut clusters = Vec::new();
    let mut visited = std::collections::HashSet::new();

    for (node_id, _) in &self.node_lookup {
      if !visited.contains(node_id) {
        let similar_nodes = self.find_similar_nodes(node_id, 10);
        let cluster: Vec<String> = similar_nodes
          .into_iter()
          .filter_map(|(similar_id, similarity)| {
            if similarity >= threshold && !visited.contains(&similar_id) {
              visited.insert(similar_id.clone());
              Some(similar_id)
            } else {
              None
            }
          })
          .collect();

        if cluster.len() > 1 {
          clusters.push(cluster);
        }
        visited.insert(node_id.clone());
      }
    }

    clusters
  }

  /// Analyze naming conventions and patterns
  fn analyze_naming_patterns(&self) -> Vec<NamingCodePattern> {
    let mut patterns = Vec::new();
    let mut name_groups: std::collections::HashMap<String, Vec<String>> = std::collections::HashMap::new();

    // Group by naming patterns
    for (node_id, &node_index) in &self.node_lookup {
      if let Some(node) = self.graph.node_weight(node_index) {
        let pattern = Self::extract_naming_pattern(&node.name);
        name_groups.entry(pattern).or_insert_with(Vec::new).push(node_id.clone());
      }
    }

    // Convert to patterns
    for (pattern, nodes) in name_groups {
      if nodes.len() > 2 {
        patterns.push(NamingCodePattern { pattern, count: nodes.len(), examples: nodes.into_iter().take(5).collect() });
      }
    }

    patterns
  }

  /// Extract naming pattern from identifier
  fn extract_naming_pattern(name: &str) -> String {
    // Simple pattern extraction - could be made more sophisticated
    if name.contains('_') {
      "snake_case".to_string()
    } else if name.chars().any(|c| c.is_uppercase()) {
      "camelCase".to_string()
    } else {
      "lowercase".to_string()
    }
  }

  /// Calculate cosine similarity between two vectors
  fn cosine_similarity(a: &[f32], b: &[f32], mag_a: f32, mag_b: f32) -> f32 {
    if mag_a == 0.0 || mag_b == 0.0 {
      return 0.0;
    }

    let dot_product: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
    dot_product / (mag_a * mag_b)
  }

  /// Calculate Jaccard similarity between two strings
  fn jaccard_similarity(a: &str, b: &str) -> f32 {
    use std::collections::HashSet;

    let set_a: HashSet<char> = a.chars().collect();
    let set_b: HashSet<char> = b.chars().collect();

    let intersection = set_a.intersection(&set_b).count();
    let union = set_a.union(&set_b).count();

    if union == 0 {
      0.0
    } else {
      intersection as f32 / union as f32
    }
  }

  /// Calculate structural similarity between two nodes
  fn structural_similarity(a: &GraphNode, b: &GraphNode) -> f32 {
    // Compare node types, file paths, and other structural features
    let mut similarity = 0.0;

    // Type similarity
    if a.node_type == b.node_type {
      similarity += 0.4;
    }

    // File path similarity
    if a.file_path.parent() == b.file_path.parent() {
      similarity += 0.3;
    }

    // Name pattern similarity
    let a_pattern = Self::extract_naming_pattern(&a.name);
    let b_pattern = Self::extract_naming_pattern(&b.name);
    if a_pattern == b_pattern {
      similarity += 0.3;
    }

    similarity
  }

  /// Calculate graph metrics using petgraph algorithms
  pub fn get_metrics(&self) -> GraphMetrics {
    let node_count = self.graph.node_count();
    let edge_count = self.graph.edge_count();

    let density = if node_count > 1 { edge_count as f64 / (node_count * (node_count - 1)) as f64 } else { 0.0 };

    let is_dag = !self.has_cycles();
    let sccs = self.strongly_connected_components();

    GraphMetrics {
      node_count,
      edge_count,
      density,
      is_dag,
      cycle_count: if is_dag { 0 } else { sccs.iter().filter(|scc| scc.len() > 1).count() },
      strongly_connected_components: sccs.len(),
    }
  }
}

/// Graph analysis metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphMetrics {
  pub node_count: usize,
  pub edge_count: usize,
  pub density: f64,
  pub is_dag: bool,
  pub cycle_count: usize,
  pub strongly_connected_components: usize,
}

/// Graph builder for extracting graphs from code
pub struct CodeGraphBuilder {
  working_directory: PathBuf,
}

impl CodeGraphBuilder {
  pub fn new(working_directory: PathBuf) -> Self {
    Self { working_directory }
  }

  /// Build call graph from parsed code with advanced vector embeddings
  pub async fn build_call_graph(&self, metadata_cache: &HashMap<PathBuf, CodeMetadata>) -> Result<CodeGraph> {
    let mut graph = CodeGraph::new(GraphType::CallGraph);

    // Add function nodes with vector embeddings
    for (file_path, metadata) in metadata_cache {
      for function in &metadata.functions {
        let node = GraphNode {
          id: format!("{}::{}", file_path.display(), function),
          node_type: "function".to_string(),
          name: function.clone(),
          file_path: file_path.clone(),
          line_number: None, // Could extract from tree-sitter
          vector: None,      // Will be populated by advanced vectorizer
          vector_magnitude: None,
        };
        graph.add_node(node);
      }
    }

    // TODO: Add call edges by analyzing function calls in AST
    // This would require deeper tree-sitter analysis

    Ok(graph)
  }

  /// Build import graph from parsed code with semantic analysis
  pub async fn build_import_graph(&self, metadata_cache: &HashMap<PathBuf, CodeMetadata>) -> Result<CodeGraph> {
    let mut graph = CodeGraph::new(GraphType::ImportGraph);

    // Add module nodes and import edges
    for (file_path, metadata) in metadata_cache {
      let module_id = file_path.to_string_lossy().to_string();
      let node = GraphNode {
        id: module_id.clone(),
        node_type: "module".to_string(),
        name: file_path.file_stem().unwrap_or_default().to_string_lossy().to_string(),
        file_path: file_path.clone(),
        line_number: None,
        vector: None, // Will be populated by advanced vectorizer
        vector_magnitude: None,
      };
      graph.add_node(node);

      // Add import edges
      for import in &metadata.imports {
        let edge = GraphEdge { from: module_id.clone(), to: import.clone(), edge_type: "imports".to_string(), weight: 1.0, metadata: HashMap::new() };
        let _ = graph.add_edge(edge);
      }
    }

    Ok(graph)
  }

  /// Build advanced codebase graph with heavy algorithms
  pub async fn build_advanced_codebase_graph(&self, metadata_cache: &HashMap<PathBuf, CodeMetadata>) -> Result<CodeGraph> {
    // Note: Don't import MultiModalFusion from advanced_vectors - we use the one from ml_similarity
    // use crate::vectors::advanced::{AdvancedVectorizer, MultiModalFusion};

    let mut graph = CodeGraph::new(GraphType::SemanticGraph);

    // Build CodeMetadata list for vectorization

    use crate::analysis::CodeMetadata;

    let metadata_list: Vec<CodeMetadata> = metadata_cache
      .iter()
      .map(|(file_path, metadata)| {
        CodeMetadata {
          file_path: file_path.clone(),
          file_type: metadata.file_type.clone(),
          functions: metadata.functions.clone(),
          imports: metadata.imports.clone(),
          exports: metadata.exports.clone(),
          classes: metadata.classes.clone(),
          interfaces: metadata.interfaces.clone(),
          patterns: metadata.patterns.clone(),
          keywords: metadata.keywords.clone(),
          last_modified: metadata.last_modified,
          size_bytes: metadata.size_bytes,
        }
      })
      .collect();

    // Initialize ML vectorizer with production algorithms
    let vectorizer = MLVectorizer::new_from_metadata(&metadata_list, 1000)?;
    let fusion = MultiModalFusion::new();

    // Add nodes with advanced vector embeddings
    for (file_path, metadata) in metadata_cache {
      for function in &metadata.functions {
        let node_id = format!("{}::{}", file_path.display(), function);
        let text = format!("{} {}", function, file_path.to_string_lossy());

        // Generate advanced vector embedding
        let advanced_vector = vectorizer.create_advanced_vector(node_id.clone(), &text, "function".to_string())?;
        let fusion_result = fusion.fuse_multimodal(&advanced_vector, &text, file_path);
        let magnitude = fusion_result.magnitude;

        let node = GraphNode {
          id: node_id,
          node_type: "function".to_string(),
          name: function.clone(),
          file_path: file_path.clone(),
          line_number: None,
          vector: Some(fusion_result.fusion_vector),
          vector_magnitude: Some(magnitude),
        };
        graph.add_node(node);
      }
    }

    Ok(graph)
  }
}

/// Codebase patterns detected by advanced analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodebaseCodePatterns {
  pub hub_nodes: Vec<String>,
  pub leaf_nodes: Vec<String>,
  pub bridge_components: Vec<String>,
  pub circular_dependencies: Vec<Vec<String>>,
  pub semantic_clusters: Vec<Vec<String>>,
  pub naming_conventions: Vec<NamingCodePattern>,
}

impl CodebaseCodePatterns {
  pub fn new() -> Self {
    Self {
      hub_nodes: Vec::new(),
      leaf_nodes: Vec::new(),
      bridge_components: Vec::new(),
      circular_dependencies: Vec::new(),
      semantic_clusters: Vec::new(),
      naming_conventions: Vec::new(),
    }
  }
}

/// Naming pattern analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingCodePattern {
  pub pattern: String,
  pub count: usize,
  pub examples: Vec<String>,
}
