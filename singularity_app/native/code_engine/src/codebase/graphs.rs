//! # Graph Analysis Module
//!
//! Consolidated graph capabilities for code analysis.
//! Integrates petgraph, DAG, and dependency analysis.

use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use anyhow::Result;
use petgraph::{Graph, Directed, NodeIndex, EdgeIndex};
use petgraph::graph::DiGraph;

/// Graph node representing code elements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphNode {
  /// Unique identifier
  pub id: String,
  /// Type of node: "file", "function", "class", "module", "variable"
  pub node_type: String,
  /// Name of the element
  pub name: String,
  /// File path where this element is defined
  pub file_path: String,
  /// Additional metadata
  pub metadata: HashMap<String, String>,
}

/// Graph edge representing relationships between code elements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
  /// Source node ID
  pub from: String,
  /// Target node ID
  pub to: String,
  /// Type of relationship: "calls", "imports", "inherits", "uses", "depends_on"
  pub edge_type: String,
  /// Weight/strength of the relationship
  pub weight: f32,
  /// Additional metadata
  pub metadata: HashMap<String, String>,
}

/// Code dependency graph using petgraph
#[derive(Debug, Clone)]
pub struct CodeGraph {
  /// The petgraph structure
  graph: DiGraph<GraphNode, GraphEdge>,
  /// Node ID to NodeIndex mapping
  node_lookup: HashMap<String, NodeIndex>,
  /// Edge lookup for quick access
  edge_lookup: HashMap<(String, String), EdgeIndex>,
}

impl CodeGraph {
  /// Create a new code graph
  pub fn new() -> Self {
    Self {
      graph: DiGraph::new(),
      node_lookup: HashMap::new(),
      edge_lookup: HashMap::new(),
    }
  }

  /// Add a node to the graph
  pub fn add_node(&mut self, node: GraphNode) -> NodeIndex {
    let node_id = node.id.clone();
    let node_index = self.graph.add_node(node);
    self.node_lookup.insert(node_id, node_index);
    node_index
  }

  /// Add an edge to the graph
  pub fn add_edge(&mut self, edge: GraphEdge) -> EdgeIndex {
    let from_id = edge.from.clone();
    let to_id = edge.to.clone();
    
    // Get node indices
    let from_index = self.node_lookup.get(&from_id)
      .expect("Source node not found");
    let to_index = self.node_lookup.get(&to_id)
      .expect("Target node not found");
    
    let edge_index = self.graph.add_edge(*from_index, *to_index, edge);
    self.edge_lookup.insert((from_id, to_id), edge_index);
    edge_index
  }

  /// Get a node by ID
  pub fn get_node(&self, id: &str) -> Option<&GraphNode> {
    self.node_lookup.get(id)
      .and_then(|index| self.graph.node_weight(*index))
  }

  /// Get all nodes of a specific type
  pub fn get_nodes_by_type(&self, node_type: &str) -> Vec<&GraphNode> {
    self.graph.node_weights()
      .filter(|node| node.node_type == node_type)
      .collect()
  }

  /// Get all nodes in a file
  pub fn get_file_nodes(&self, file_path: &str) -> Vec<&GraphNode> {
    self.graph.node_weights()
      .filter(|node| node.file_path == file_path)
      .collect()
  }

  /// Get neighbors of a node
  pub fn get_neighbors(&self, node_id: &str) -> Vec<&GraphNode> {
    if let Some(&node_index) = self.node_lookup.get(node_id) {
      self.graph.neighbors(node_index)
        .filter_map(|neighbor_index| self.graph.node_weight(neighbor_index))
        .collect()
    } else {
      Vec::new()
    }
  }

  /// Get incoming edges to a node
  pub fn get_incoming_edges(&self, node_id: &str) -> Vec<&GraphEdge> {
    if let Some(&node_index) = self.node_lookup.get(node_id) {
      self.graph.edges_directed(node_index, petgraph::Direction::Incoming)
        .map(|edge_ref| edge_ref.weight())
        .collect()
    } else {
      Vec::new()
    }
  }

  /// Get outgoing edges from a node
  pub fn get_outgoing_edges(&self, node_id: &str) -> Vec<&GraphEdge> {
    if let Some(&node_index) = self.node_lookup.get(node_id) {
      self.graph.edges_directed(node_index, petgraph::Direction::Outgoing)
        .map(|edge_ref| edge_ref.weight())
        .collect()
    } else {
      Vec::new()
    }
  }

  /// Calculate graph metrics
  pub fn get_metrics(&self) -> GraphMetrics {
    GraphMetrics {
      node_count: self.graph.node_count(),
      edge_count: self.graph.edge_count(),
      density: self.calculate_density(),
      average_degree: self.calculate_average_degree(),
      max_degree: self.calculate_max_degree(),
    }
  }

  /// Calculate graph density
  fn calculate_density(&self) -> f64 {
    let n = self.graph.node_count() as f64;
    if n <= 1.0 {
      0.0
    } else {
      let m = self.graph.edge_count() as f64;
      m / (n * (n - 1.0))
    }
  }

  /// Calculate average degree
  fn calculate_average_degree(&self) -> f64 {
    if self.graph.node_count() == 0 {
      0.0
    } else {
      let total_degree: usize = self.graph.node_indices()
        .map(|node_index| self.graph.neighbors(node_index).count())
        .sum();
      total_degree as f64 / self.graph.node_count() as f64
    }
  }

  /// Calculate maximum degree
  fn calculate_max_degree(&self) -> usize {
    self.graph.node_indices()
      .map(|node_index| self.graph.neighbors(node_index).count())
      .max()
      .unwrap_or(0)
  }

  /// Find cycles in the graph
  pub fn find_cycles(&self) -> Vec<Vec<String>> {
    // Simple cycle detection - in practice you'd use a proper algorithm
    // This is a placeholder implementation
    Vec::new()
  }

  /// Get topological sort of nodes
  pub fn topological_sort(&self) -> Vec<String> {
    // Simple topological sort - in practice you'd use proper algorithm
    // This is a placeholder implementation
    self.graph.node_indices()
      .filter_map(|index| self.graph.node_weight(index))
      .map(|node| node.id.clone())
      .collect()
  }
}

/// Graph metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphMetrics {
  /// Total number of nodes
  pub node_count: usize,
  /// Total number of edges
  pub edge_count: usize,
  /// Graph density (edges / possible edges)
  pub density: f64,
  /// Average degree of nodes
  pub average_degree: f64,
  /// Maximum degree of any node
  pub max_degree: usize,
}

/// DAG (Directed Acyclic Graph) for file relationships
#[derive(Debug, Clone)]
pub struct FileDAG {
  /// The underlying graph
  graph: CodeGraph,
  /// File-level relationships
  file_relationships: HashMap<String, Vec<String>>, // file -> dependent_files
}

impl FileDAG {
  /// Create a new file DAG
  pub fn new() -> Self {
    Self {
      graph: CodeGraph::new(),
      file_relationships: HashMap::new(),
    }
  }

  /// Add a file to the DAG
  pub fn add_file(&mut self, file_path: String, dependencies: Vec<String>) {
    // Create file node
    let file_node = GraphNode {
      id: file_path.clone(),
      node_type: "file".to_string(),
      name: file_path.clone(),
      file_path: file_path.clone(),
      metadata: HashMap::new(),
    };
    
    self.graph.add_node(file_node);
    
    // Add dependencies
    for dep in dependencies {
      let dep_node = GraphNode {
        id: dep.clone(),
        node_type: "file".to_string(),
        name: dep.clone(),
        file_path: dep.clone(),
        metadata: HashMap::new(),
      };
      
      self.graph.add_node(dep_node);
      
      // Add dependency edge
      let dep_edge = GraphEdge {
        from: file_path.clone(),
        to: dep.clone(),
        edge_type: "depends_on".to_string(),
        weight: 1.0,
        metadata: HashMap::new(),
      };
      
      self.graph.add_edge(dep_edge);
    }
    
    // Update file relationships
    self.file_relationships.insert(file_path, dependencies);
  }

  /// Get files that depend on a given file
  pub fn get_dependents(&self, file_path: &str) -> Vec<String> {
    self.graph.get_incoming_edges(file_path)
      .iter()
      .map(|edge| edge.from.clone())
      .collect()
  }

  /// Get files that a given file depends on
  pub fn get_dependencies(&self, file_path: &str) -> Vec<String> {
    self.graph.get_outgoing_edges(file_path)
      .iter()
      .map(|edge| edge.to.clone())
      .collect()
  }

  /// Get build order (topological sort)
  pub fn get_build_order(&self) -> Vec<String> {
    self.graph.topological_sort()
  }

  /// Check if adding a dependency would create a cycle
  pub fn would_create_cycle(&self, from: &str, to: &str) -> bool {
    // Simple cycle detection - in practice you'd use proper algorithm
    // This is a placeholder implementation
    false
  }

  /// Get DAG statistics
  pub fn get_stats(&self) -> DAGStats {
    let graph_metrics = self.graph.get_metrics();
    DAGStats {
      total_files: graph_metrics.node_count,
      total_dependencies: graph_metrics.edge_count,
      average_dependencies_per_file: graph_metrics.average_degree,
      max_dependencies: graph_metrics.max_degree,
      density: graph_metrics.density,
    }
  }
}

/// DAG statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DAGStats {
  /// Total number of files
  pub total_files: usize,
  /// Total number of dependencies
  pub total_dependencies: usize,
  /// Average dependencies per file
  pub average_dependencies_per_file: f64,
  /// Maximum dependencies for any file
  pub max_dependencies: usize,
  /// Dependency density
  pub density: f64,
}

impl Default for CodeGraph {
  fn default() -> Self {
    Self::new()
  }
}

impl Default for FileDAG {
  fn default() -> Self {
    Self::new()
  }
}