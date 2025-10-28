//! PageRank Analysis for Code Graphs
//!
//! Provides PageRank centrality scoring for code dependency analysis.
//! Part of the analysis-suite graph analysis module.

use std::{collections::HashMap, path::Path};

use anyhow::Result;
use serde::{Deserialize, Serialize};
use tracing::{debug, info, warn};

/// Central PageRank analyzer for code graphs
#[derive(Debug)]
pub struct CentralPageRank {
    /// Graph adjacency matrix
    graph: HashMap<String, Vec<String>>,
    /// Current PageRank scores
    scores: HashMap<String, f64>,
    /// Configuration
    config: PageRankConfig,
    /// Cache for performance (using RefCell for interior mutability)
    cache: std::cell::RefCell<HashMap<String, f64>>,
}

/// PageRank configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PageRankConfig {
    /// Damping factor (typically 0.85)
    pub damping_factor: f64,
    /// Maximum iterations
    pub max_iterations: usize,
    /// Convergence threshold
    pub convergence_threshold: f64,
    /// Enable caching
    pub enable_caching: bool,
}

impl Default for PageRankConfig {
    fn default() -> Self {
        Self {
            damping_factor: 0.85,
            max_iterations: 100,
            convergence_threshold: 1e-6,
            enable_caching: true,
        }
    }
}

/// PageRank analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PageRankResult {
    /// Node identifier
    pub node_id: String,
    /// PageRank score (0.0 - 1.0)
    pub score: f64,
    /// Normalized score for easier comparison
    pub normalized_score: f64,
    /// Rank position (1 = highest)
    pub rank: usize,
}

/// Graph metrics for analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PageRankMetrics {
    /// Total nodes in graph
    pub total_nodes: usize,
    /// Total edges in graph
    pub total_edges: usize,
    /// Average degree
    pub average_degree: f64,
    /// Graph density
    pub density: f64,
    /// Number of iterations to converge
    pub iterations_to_converge: usize,
    /// Convergence achieved
    pub converged: bool,
}

impl CentralPageRank {
    /// Create a new PageRank analyzer
    pub fn new(config: PageRankConfig) -> Self {
        Self {
            graph: HashMap::new(),
            scores: HashMap::new(),
            config,
            cache: std::cell::RefCell::new(HashMap::new()),
        }
    }

    /// Create with default configuration
    pub fn default() -> Self {
        Self::new(PageRankConfig::default())
    }

    /// Add a node to the graph
    pub fn add_node(&mut self, node_id: String) {
        if !self.graph.contains_key(&node_id) {
            self.graph.insert(node_id.clone(), Vec::new());
            self.scores.insert(node_id, 1.0);
            self.invalidate_cache();
        }
    }

    /// Add an edge between two nodes
    pub fn add_edge(&mut self, from: String, to: String) {
        // Ensure both nodes exist
        self.add_node(from.clone());
        self.add_node(to.clone());

        // Add edge
        if let Some(edges) = self.graph.get_mut(&from) {
            if !edges.contains(&to) {
                edges.push(to);
                self.invalidate_cache();
            }
        }
    }

    /// Build graph from code dependencies
    pub fn build_from_dependencies(&mut self, dependencies: &HashMap<String, Vec<String>>) {
        info!("Building PageRank graph from {} nodes", dependencies.len());

        for (file, deps) in dependencies {
            self.add_node(file.clone());
            for dep in deps {
                self.add_edge(file.clone(), dep.clone());
            }
        }

        debug!(
            "Graph built: {} nodes, {} total edges",
            self.graph.len(),
            self.graph.values().map(|v| v.len()).sum::<usize>()
        );
    }

    /// Calculate PageRank scores for all nodes
    pub fn calculate_pagerank(&mut self) -> Result<PageRankMetrics> {
        if self.graph.is_empty() {
            warn!("Cannot calculate PageRank on empty graph");
            return Ok(PageRankMetrics {
                total_nodes: 0,
                total_edges: 0,
                average_degree: 0.0,
                density: 0.0,
                iterations_to_converge: 0,
                converged: false,
            });
        }

        let node_count = self.graph.len();
        let total_edges = self.graph.values().map(|v| v.len()).sum::<usize>();
        let initial_score = 1.0 / node_count as f64;

        // Initialize scores
        for node in self.graph.keys() {
            self.scores.insert(node.clone(), initial_score);
        }

        let mut iteration = 0;
        let mut converged = false;

        info!(
            "Starting PageRank calculation: {} nodes, {} edges",
            node_count, total_edges
        );

        // PageRank iteration
        while iteration < self.config.max_iterations && !converged {
            let mut new_scores = HashMap::new();
            let mut max_change: f64 = 0.0;

            // Calculate new scores
            for node in self.graph.keys() {
                let mut score = (1.0 - self.config.damping_factor) / node_count as f64;

                // Sum contributions from incoming links
                for (source, targets) in &self.graph {
                    if targets.contains(node) {
                        let source_score = self.scores.get(source).unwrap_or(&initial_score);
                        let out_degree = targets.len() as f64;
                        if out_degree > 0.0 {
                            score += self.config.damping_factor * (source_score / out_degree);
                        }
                    }
                }

                // Handle dangling nodes (nodes with no outgoing links)
                if self.graph.get(node).map(|v| v.is_empty()).unwrap_or(true) {
                    score += self.config.damping_factor * initial_score;
                }

                let old_score = self.scores.get(node).unwrap_or(&initial_score);
                max_change = max_change.max((score - old_score).abs());

                new_scores.insert(node.clone(), score);
            }

            self.scores = new_scores;
            iteration += 1;

            // Check convergence
            if max_change < self.config.convergence_threshold {
                converged = true;
                info!("PageRank converged after {} iterations", iteration);
            }
        }

        if !converged {
            warn!("PageRank did not converge after {} iterations", iteration);
        }

        // Normalize scores to 0-1 range
        self.normalize_scores();

        Ok(PageRankMetrics {
            total_nodes: node_count,
            total_edges,
            average_degree: total_edges as f64 / node_count as f64,
            density: total_edges as f64 / (node_count * (node_count - 1)) as f64,
            iterations_to_converge: iteration,
            converged,
        })
    }

    /// Get PageRank score for a specific node
    pub fn get_score(&self, node_id: &str) -> f64 {
        // Check cache first
        if self.config.enable_caching {
            if let Some(cached_score) = self.cache.borrow().get(node_id) {
                return *cached_score;
            }
        }

        let score = self.scores.get(node_id).unwrap_or(&0.0);

        // Cache the result
        if self.config.enable_caching {
            self.cache.borrow_mut().insert(node_id.to_string(), *score);
        }

        *score
    }

    /// Get PageRank score for a file path
    pub fn get_file_score<P: AsRef<Path>>(&self, file_path: P) -> f64 {
        let path_str = file_path.as_ref().to_string_lossy().to_string();
        self.get_score(&path_str)
    }

    /// Get top N nodes by PageRank score
    pub fn get_top_nodes(&self, n: usize) -> Vec<PageRankResult> {
        let mut results: Vec<_> = self
            .scores
            .iter()
            .map(|(node_id, score)| (node_id.clone(), *score))
            .collect();

        results.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        let max_score = results.first().map(|(_, score)| *score).unwrap_or(1.0);

        results
            .into_iter()
            .take(n)
            .enumerate()
            .map(|(rank, (node_id, score))| PageRankResult {
                node_id,
                score,
                normalized_score: if max_score > 0.0 {
                    score / max_score
                } else {
                    0.0
                },
                rank: rank + 1,
            })
            .collect()
    }

    /// Get all PageRank results sorted by score
    pub fn get_all_results(&self) -> Vec<PageRankResult> {
        self.get_top_nodes(self.scores.len())
    }

    /// Clear the graph and scores
    pub fn clear(&mut self) {
        self.graph.clear();
        self.scores.clear();
        self.invalidate_cache();
    }

    /// Get graph statistics
    pub fn get_stats(&self) -> HashMap<String, f64> {
        let mut stats = HashMap::new();

        stats.insert("nodes".to_string(), self.graph.len() as f64);
        stats.insert(
            "edges".to_string(),
            self.graph.values().map(|v| v.len()).sum::<usize>() as f64,
        );

        if !self.scores.is_empty() {
            let scores: Vec<f64> = self.scores.values().cloned().collect();
            stats.insert(
                "max_score".to_string(),
                scores.iter().fold(0.0, |a, &b| a.max(b)),
            );
            stats.insert(
                "min_score".to_string(),
                scores.iter().fold(1.0, |a, &b| a.min(b)),
            );
            stats.insert(
                "avg_score".to_string(),
                scores.iter().sum::<f64>() / scores.len() as f64,
            );
        }

        stats
    }

    /// Export graph to DOT format for visualization
    pub fn export_dot(&self) -> String {
        let mut dot = String::from("digraph PageRank {\n");
        dot.push_str("  rankdir=TB;\n");
        dot.push_str("  node [shape=ellipse];\n");

        // Add nodes with scores
        for (node, score) in &self.scores {
            let intensity = (score * 10.0).min(1.0);
            dot.push_str(&format!(
                "  \"{}\" [label=\"{}\\n{:.4}\", color=\"{:.2} 1.0 1.0\"];\n",
                node, node, score, intensity
            ));
        }

        // Add edges
        for (from, targets) in &self.graph {
            for to in targets {
                dot.push_str(&format!("  \"{}\" -> \"{}\";\n", from, to));
            }
        }

        dot.push_str("}\n");
        dot
    }

    /// Private helper methods
    fn normalize_scores(&mut self) {
        if self.scores.is_empty() {
            return;
        }

        let max_score: f64 = self.scores.values().fold(0.0_f64, |a, &b| a.max(b));

        if max_score > 0.0 {
            for score in self.scores.values_mut() {
                *score /= max_score;
            }
        }
    }

    fn invalidate_cache(&mut self) {
        if self.config.enable_caching {
            self.cache.borrow_mut().clear();
        }
    }
}

/// Integration trait for parsers to use central PageRank
pub trait PageRankIntegration {
    /// Calculate centrality score for a file using central PageRank
    async fn calculate_centrality_score(
        &self,
        file_path: &Path,
        pagerank: &CentralPageRank,
    ) -> Result<f64> {
        Ok(pagerank.get_file_score(file_path))
    }

    /// Get file importance ranking
    async fn get_file_importance_rank(
        &self,
        file_path: &Path,
        pagerank: &CentralPageRank,
    ) -> Result<Option<usize>> {
        let path_str = file_path.to_string_lossy().to_string();
        let results = pagerank.get_all_results();

        Ok(results
            .iter()
            .find(|result| result.node_id == path_str)
            .map(|result| result.rank))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pagerank_basic() {
        let mut pagerank = CentralPageRank::default();

        // Create a simple graph: A -> B -> C, A -> C
        pagerank.add_edge("A".to_string(), "B".to_string());
        pagerank.add_edge("B".to_string(), "C".to_string());
        pagerank.add_edge("A".to_string(), "C".to_string());

        let metrics = pagerank.calculate_pagerank().unwrap();
        assert!(metrics.converged);
        assert_eq!(metrics.total_nodes, 3);
        assert_eq!(metrics.total_edges, 3);

        // C should have the highest score (receives links from both A and B)
        let c_score = pagerank.get_score("C");
        let a_score = pagerank.get_score("A");
        let b_score = pagerank.get_score("B");

        assert!(c_score > a_score);
        assert!(c_score > b_score);
    }

    #[test]
    fn test_pagerank_top_nodes() {
        let mut pagerank = CentralPageRank::default();

        // Create a star graph with center node
        pagerank.add_edge("node1".to_string(), "center".to_string());
        pagerank.add_edge("node2".to_string(), "center".to_string());
        pagerank.add_edge("node3".to_string(), "center".to_string());

        pagerank.calculate_pagerank().unwrap();
        let top_nodes = pagerank.get_top_nodes(2);

        assert_eq!(top_nodes.len(), 2);
        assert_eq!(top_nodes[0].node_id, "center");
        assert_eq!(top_nodes[0].rank, 1);
    }

    #[test]
    fn test_pagerank_dependencies() {
        let mut pagerank = CentralPageRank::default();

        let mut deps = HashMap::new();
        deps.insert(
            "main.rs".to_string(),
            vec!["lib.rs".to_string(), "utils.rs".to_string()],
        );
        deps.insert("lib.rs".to_string(), vec!["utils.rs".to_string()]);
        deps.insert("utils.rs".to_string(), vec![]);

        pagerank.build_from_dependencies(&deps);
        let metrics = pagerank.calculate_pagerank().unwrap();

        assert_eq!(metrics.total_nodes, 3);

        // utils.rs should have highest score (most incoming dependencies)
        let utils_score = pagerank.get_file_score("utils.rs");
        let lib_score = pagerank.get_file_score("lib.rs");
        let main_score = pagerank.get_file_score("main.rs");

        assert!(utils_score >= lib_score);
        assert!(utils_score >= main_score);
    }
}
