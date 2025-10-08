//! Control Flow Analysis - Dead End Detection & Completeness Checking
//!
//! EXTENDS existing CodeDependencyGraph with CFG-specific analysis

use anyhow::Result;
use std::collections::HashSet;

use crate::graph::{CodeDependencyGraph, GraphNode, GraphEdge, GraphType};
use petgraph::{Direction, visit::{Dfs, EdgeRef}};

/// Control Flow Graph - extends existing graph infrastructure
pub struct ControlFlowGraph {
    pub graph: CodeDependencyGraph,
    pub entry_nodes: Vec<String>,
    pub exit_nodes: Vec<String>,
}

/// Dead end in control flow (code path that never returns/completes)
#[derive(Debug, Clone)]
pub struct DeadEnd {
    pub node_id: String,
    pub function_name: String,
    pub line_number: usize,
    pub reason: DeadEndReason,
}

#[derive(Debug, Clone)]
pub enum DeadEndReason {
    MayRaiseWithoutHandler,
    NoReturnPath,
    InfiniteLoop,
}

/// Unreachable code that can never execute
#[derive(Debug, Clone)]
pub struct UnreachableCode {
    pub node_id: String,
    pub line_number: usize,
    pub reason: String,
}

/// Flow completeness analysis result
#[derive(Debug, Clone)]
pub struct FlowCompleteness {
    pub total_paths: usize,
    pub complete_paths: usize,
    pub incomplete_paths: usize,
    pub completeness_score: f64, // 0.0 to 1.0
}

impl ControlFlowGraph {
    /// Create new CFG from existing CodeDependencyGraph
    pub fn from_dependency_graph(graph: CodeDependencyGraph) -> Self {
        let entry_nodes = Self::find_entry_nodes(&graph);
        let exit_nodes = Self::find_exit_nodes(&graph);

        Self {
            graph,
            entry_nodes,
            exit_nodes,
        }
    }

    /// Find entry points (nodes with no incoming edges)
    fn find_entry_nodes(graph: &CodeDependencyGraph) -> Vec<String> {
        graph.graph
            .node_indices()
            .filter(|&idx| {
                graph.graph.edges_directed(idx, Direction::Incoming).count() == 0
            })
            .map(|idx| graph.graph[idx].id.clone())
            .collect()
    }

    /// Find exit points (return statements, final expressions)
    fn find_exit_nodes(graph: &CodeDependencyGraph) -> Vec<String> {
        graph.graph
            .node_indices()
            .filter(|&idx| {
                let node = &graph.graph[idx];
                node.node_type == "return" || node.node_type == "exit"
            })
            .map(|idx| graph.graph[idx].id.clone())
            .collect()
    }

    /// Detect dead ends (MAIN FEATURE!)
    pub fn find_dead_ends(&self) -> Vec<DeadEnd> {
        let mut dead_ends = Vec::new();

        for node_idx in self.graph.graph.node_indices() {
            let node = &self.graph.graph[node_idx];

            // Skip exit nodes (they're supposed to end!)
            if node.node_type == "return" || node.node_type == "exit" {
                continue;
            }

            let outgoing_edges: Vec<_> = self.graph.graph
                .edges_directed(node_idx, Direction::Outgoing)
                .collect();

            // No outgoing edges = dead end!
            if outgoing_edges.is_empty() {
                let reason = if node.node_type == "function_call" {
                    DeadEndReason::MayRaiseWithoutHandler
                } else if node.node_type == "loop" {
                    DeadEndReason::InfiniteLoop
                } else {
                    DeadEndReason::NoReturnPath
                };

                dead_ends.push(DeadEnd {
                    node_id: node.id.clone(),
                    function_name: self.extract_function_name(node),
                    line_number: node.line_number.unwrap_or(0),
                    reason,
                });
            }
        }

        dead_ends
    }

    /// Find unreachable code
    pub fn find_unreachable_code(&self) -> Vec<UnreachableCode> {
        let mut unreachable = Vec::new();

        // Find all reachable nodes via DFS from entry points
        let reachable = self.find_reachable_nodes();

        // Any node NOT in reachable set is unreachable
        for node_idx in self.graph.graph.node_indices() {
            let node = &self.graph.graph[node_idx];

            if !reachable.contains(&node.id) {
                unreachable.push(UnreachableCode {
                    node_id: node.id.clone(),
                    line_number: node.line_number.unwrap_or(0),
                    reason: format!("Code cannot be reached from entry points"),
                });
            }
        }

        unreachable
    }

    /// Find all nodes reachable from entry points
    fn find_reachable_nodes(&self) -> HashSet<String> {
        let mut reachable = HashSet::new();

        for entry_id in &self.entry_nodes {
            if let Some(&entry_idx) = self.graph.node_lookup.get(entry_id) {
                // DFS from this entry point
                let mut dfs = Dfs::new(&self.graph.graph, entry_idx);

                while let Some(node_idx) = dfs.next(&self.graph.graph) {
                    let node = &self.graph.graph[node_idx];
                    reachable.insert(node.id.clone());
                }
            }
        }

        reachable
    }

    /// Calculate flow completeness
    pub fn calculate_completeness(&self) -> FlowCompleteness {
        let total_paths = self.count_all_paths();
        let complete_paths = self.count_complete_paths();
        let incomplete_paths = total_paths - complete_paths;

        let completeness_score = if total_paths > 0 {
            complete_paths as f64 / total_paths as f64
        } else {
            1.0
        };

        FlowCompleteness {
            total_paths,
            complete_paths,
            incomplete_paths,
            completeness_score,
        }
    }

    /// Count all possible execution paths
    fn count_all_paths(&self) -> usize {
        let mut total = 0;

        for entry_id in &self.entry_nodes {
            if let Some(&entry_idx) = self.graph.node_lookup.get(entry_id) {
                total += self.count_paths_from(entry_idx, &mut HashSet::new());
            }
        }

        total.max(1) // At least 1 path
    }

    /// Count complete paths (that reach an exit)
    fn count_complete_paths(&self) -> usize {
        let mut complete = 0;

        for entry_id in &self.entry_nodes {
            if let Some(&entry_idx) = self.graph.node_lookup.get(entry_id) {
                complete += self.count_complete_paths_from(entry_idx, &mut HashSet::new());
            }
        }

        complete
    }

    fn count_paths_from(&self, node_idx: petgraph::graph::NodeIndex, visited: &mut HashSet<String>) -> usize {
        let node = &self.graph.graph[node_idx];

        // Prevent infinite loops
        if visited.contains(&node.id) {
            return 0;
        }
        visited.insert(node.id.clone());

        let outgoing: Vec<_> = self.graph.graph
            .edges_directed(node_idx, Direction::Outgoing)
            .collect();

        if outgoing.is_empty() {
            // Leaf node
            visited.remove(&node.id);
            return 1;
        }

        let mut total = 0;
        for edge in outgoing {
            total += self.count_paths_from(edge.target(), visited);
        }

        visited.remove(&node.id);
        total
    }

    fn count_complete_paths_from(&self, node_idx: petgraph::graph::NodeIndex, visited: &mut HashSet<String>) -> usize {
        let node = &self.graph.graph[node_idx];

        if visited.contains(&node.id) {
            return 0;
        }
        visited.insert(node.id.clone());

        // Is this an exit node?
        if self.exit_nodes.contains(&node.id) {
            visited.remove(&node.id);
            return 1;
        }

        let outgoing: Vec<_> = self.graph.graph
            .edges_directed(node_idx, Direction::Outgoing)
            .collect();

        if outgoing.is_empty() {
            // Dead end, not a complete path
            visited.remove(&node.id);
            return 0;
        }

        let mut total = 0;
        for edge in outgoing {
            total += self.count_complete_paths_from(edge.target(), visited);
        }

        visited.remove(&node.id);
        total
    }

    fn extract_function_name(&self, node: &GraphNode) -> String {
        // Try to extract function name from node metadata
        node.name.clone()
    }
}

/// Analyze a function for control flow issues
pub fn analyze_function_flow(graph: CodeDependencyGraph) -> Result<ControlFlowAnalysis> {
    let cfg = ControlFlowGraph::from_dependency_graph(graph);

    let dead_ends = cfg.find_dead_ends();
    let unreachable = cfg.find_unreachable_code();
    let completeness = cfg.calculate_completeness();
    let has_issues = !dead_ends.is_empty() || !unreachable.is_empty() || completeness.completeness_score < 1.0;

    Ok(ControlFlowAnalysis {
        dead_ends,
        unreachable_code: unreachable,
        completeness,
        has_issues,
    })
}

/// Complete flow analysis result
#[derive(Debug, Clone)]
pub struct ControlFlowAnalysis {
    pub dead_ends: Vec<DeadEnd>,
    pub unreachable_code: Vec<UnreachableCode>,
    pub completeness: FlowCompleteness,
    pub has_issues: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dead_end_detection() {
        let mut graph = CodeDependencyGraph::new(GraphType::DataFlowGraph);

        // Add nodes
        let entry = GraphNode {
            id: "entry".to_string(),
            node_type: "entry".to_string(),
            name: "start".to_string(),
            file_path: "test.ex".into(),
            line_number: Some(1),
            vector: None,
            vector_magnitude: None,
        };

        let call = GraphNode {
            id: "validate".to_string(),
            node_type: "function_call".to_string(),
            name: "validate_user".to_string(),
            file_path: "test.ex".into(),
            line_number: Some(2),
            vector: None,
            vector_magnitude: None,
        };

        graph.add_node(entry);
        graph.add_node(call.clone());

        // Add edge from entry to call
        graph.add_edge(GraphEdge {
            from: "entry".to_string(),
            to: "validate".to_string(),
            edge_type: "calls".to_string(),
            weight: 1.0,
            metadata: Default::default(),
        }).unwrap();

        // Analyze
        let cfg = ControlFlowGraph::from_dependency_graph(graph);
        let dead_ends = cfg.find_dead_ends();

        // Should find dead end at validate (no outgoing edges)
        assert_eq!(dead_ends.len(), 1);
        assert_eq!(dead_ends[0].node_id, "validate");
    }
}
