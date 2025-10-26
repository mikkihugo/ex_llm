//! Central Heuristics Module - Universal scoring across all languages
//!
//! Provides central heuristic scoring that works for all programming languages:
//! - File size scoring (universal)
//! - `PageRank` centrality analysis (graph-based)
//! - Overall importance calculation (combines all scores)

use std::{collections::HashMap, path::Path};

use petgraph::{algo::page_rank, graph::NodeIndex, Directed, Graph};
use serde::{Deserialize, Serialize};

/// Central heuristic scoring configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CentralHeuristicConfig {
  /// Enable central heuristic scoring
  pub enabled: bool,
  /// Weight for file size scoring
  pub file_size_weight: f64,
  /// Weight for centrality scoring (`PageRank`)
  pub centrality_weight: f64,
  /// Weight for language-specific complexity (from parsers)
  pub complexity_weight: f64,
  /// Weight for language-specific dependencies (from parsers)
  pub dependency_weight: f64,
}

impl Default for CentralHeuristicConfig {
  fn default() -> Self {
    Self { enabled: true, file_size_weight: 0.2, centrality_weight: 0.3, complexity_weight: 0.3, dependency_weight: 0.2 }
  }
}

/// Central `PageRank` system for all languages
pub struct CentralPageRankSystem {
  graph: Graph<String, f64, Directed>,
  node_map: HashMap<String, NodeIndex>,
}

impl Default for CentralPageRankSystem {
  fn default() -> Self {
    Self::new()
  }
}

impl CentralPageRankSystem {
  #[must_use]
  pub fn new() -> Self {
    Self { graph: Graph::new(), node_map: HashMap::new() }
  }

  pub fn add_file(&mut self, file_path: &str) -> NodeIndex {
    if let Some(&node) = self.node_map.get(file_path) {
      node
    } else {
      let node = self.graph.add_node(file_path.to_string());
      self.node_map.insert(file_path.to_string(), node);
      node
    }
  }

  pub fn add_dependency(&mut self, from: &str, to: &str, weight: f64) {
    let from_node = self.add_file(from);
    let to_node = self.add_file(to);
    self.graph.add_edge(from_node, to_node, weight);
  }

  #[must_use]
  pub fn calculate_pagerank(&self) -> HashMap<String, f64> {
    let scores = page_rank(&self.graph, 0.85, 100);
    let mut result = HashMap::new();

    // page_rank returns Vec<f64> indexed by node index
    for (node_idx, score) in scores.iter().enumerate() {
      if let Some(file_path) = self.graph.node_weight(NodeIndex::new(node_idx)) {
        result.insert(file_path.clone(), *score);
      }
    }

    result
  }

  #[must_use]
  pub fn get_file_score(&self, file_path: &str) -> f64 {
    let scores = self.calculate_pagerank();
    scores.get(file_path).copied().unwrap_or(0.0)
  }
}

/// Central file importance score (combines central + language-specific)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CentralFileImportanceScore {
  /// Overall importance score (0.0 - 1.0)
  pub overall_score: f64,
  /// Central file size score
  pub file_size_score: f64,
  /// Central centrality score (`PageRank`)
  pub centrality_score: f64,
  /// Language-specific complexity score (from parser)
  pub complexity_score: f64,
  /// Language-specific dependency score (from parser)
  pub dependency_score: f64,
  /// File path
  pub file_path: String,
}

/// Central heuristic analyzer
pub struct CentralHeuristicAnalyzer {
  config: CentralHeuristicConfig,
  pagerank: CentralPageRankSystem,
}

impl CentralHeuristicAnalyzer {
  /// Create new central heuristic analyzer
  #[must_use]
  pub fn new(config: CentralHeuristicConfig) -> Self {
    Self { config, pagerank: CentralPageRankSystem::new() }
  }

  /// Calculate central file size score (universal across languages)
  #[must_use]
  pub fn calculate_file_size_score(&self, content: &str) -> f64 {
    let lines = content.lines().count();
    let chars = content.len();

    // Normalize based on typical file sizes
    #[allow(clippy::cast_precision_loss)]
    let line_score = (lines as f64 / 1_000.0).min(1.0);
    #[allow(clippy::cast_precision_loss)]
    let char_score = (chars as f64 / 100_000.0).min(1.0);

    // Weighted combination
    line_score.mul_add(0.6, char_score * 0.4).min(1.0)
  }

  /// Calculate central centrality score using `PageRank`
  #[must_use]
  pub fn calculate_centrality_score(&self, file_path: &Path) -> f64 {
    let path_str = &file_path.to_string_lossy();
    self.pagerank.get_file_score(path_str)
  }

  /// Calculate overall importance score combining all metrics
  #[must_use]
  pub fn calculate_overall_score(&self, file_path: &Path, content: &str, complexity_score: f64, dependency_score: f64) -> CentralFileImportanceScore {
    let file_size_score = self.calculate_file_size_score(content);
    let centrality_score = self.calculate_centrality_score(file_path);

    // Weighted combination of all scores
    let overall_score = file_size_score.mul_add(
      self.config.file_size_weight,
      centrality_score
        .mul_add(self.config.centrality_weight, complexity_score.mul_add(self.config.complexity_weight, dependency_score * self.config.dependency_weight)),
    );

    CentralFileImportanceScore {
      overall_score: overall_score.min(1.0),
      file_size_score,
      centrality_score,
      complexity_score,
      dependency_score,
      file_path: file_path.to_string_lossy().to_string(),
    }
  }

  /// Add file to `PageRank` graph
  pub fn add_file_to_graph(&mut self, file_path: &str) {
    self.pagerank.add_file(file_path);
  }

  /// Add dependency to `PageRank` graph
  pub fn add_dependency_to_graph(&mut self, from: &str, to: &str, weight: f64) {
    self.pagerank.add_dependency(from, to, weight);
  }

  /// Get `PageRank` system for external access
  #[must_use]
  pub const fn get_pagerank(&self) -> &CentralPageRankSystem {
    &self.pagerank
  }
}

impl Default for CentralHeuristicAnalyzer {
  fn default() -> Self {
    Self::new(CentralHeuristicConfig::default())
  }
}
