//! Domain boundary analysis using petgraph

use std::collections::HashMap;

use anyhow::Result;
use petgraph::{
  algo::{is_cyclic_directed, kosaraju_scc},
  graph::{DiGraph, NodeIndex},
};

use crate::repository::types::*;

/// Domain boundary analyzer
pub struct DomainBoundaryAnalyzer {
  /// Domain interaction graph (should be acyclic)
  domain_graph: DiGraph<DomainNode, InteractionEdge>,
  /// Mapping from domain name to node index
  domain_index: HashMap<String, NodeIndex>,
}

/// Domain node in graph
#[derive(Debug, Clone)]
pub struct DomainNode {
  pub name: String,
  pub packages: Vec<PackageId>,
}

/// Interaction edge between domains
#[derive(Debug, Clone)]
pub struct InteractionEdge {
  pub interaction_type: InteractionType,
  pub strength: f64, // 0.0 = weak, 1.0 = strong coupling
}

impl DomainBoundaryAnalyzer {
  /// Create new analyzer from domains and dependency graph
  pub fn new(domains: &[Domain], dependency_graph: &DependencyGraph) -> Self {
    let mut domain_graph = DiGraph::new();
    let mut domain_index = HashMap::new();

    // Add all domains as nodes
    for domain in domains {
      let node = domain_graph.add_node(DomainNode { name: domain.name.clone(), packages: domain.packages.clone() });
      domain_index.insert(domain.name.clone(), node);
    }

    // Build edges from package dependencies
    Self::build_domain_edges(&mut domain_graph, &domain_index, domains, dependency_graph);

    Self { domain_graph, domain_index }
  }

  /// Build edges between domains based on package dependencies
  fn build_domain_edges(
    graph: &mut DiGraph<DomainNode, InteractionEdge>,
    domain_index: &HashMap<String, NodeIndex>,
    domains: &[Domain],
    dependency_graph: &DependencyGraph,
  ) {
    // Map package to domain
    let mut package_to_domain: HashMap<PackageId, String> = HashMap::new();
    for domain in domains {
      for package_id in &domain.packages {
        package_to_domain.insert(package_id.clone(), domain.name.clone());
      }
    }

    // For each dependency edge, if it crosses domains, add domain edge
    let mut domain_interactions: HashMap<(String, String), usize> = HashMap::new();

    for edge in &dependency_graph.edges {
      if let (Some(from_domain), Some(to_domain)) = (package_to_domain.get(&edge.from), package_to_domain.get(&edge.to)) {
        if from_domain != to_domain {
          // Cross-domain dependency
          let key = (from_domain.clone(), to_domain.clone());
          *domain_interactions.entry(key).or_insert(0) += 1;
        }
      }
    }

    // Add edges with coupling strength
    for ((from_domain, to_domain), count) in domain_interactions {
      if let (Some(&from_node), Some(&to_node)) = (domain_index.get(&from_domain), domain_index.get(&to_domain)) {
        // Normalize strength (1-3 deps = weak, 4-10 = medium, 10+ = strong)
        let strength = (count as f64 / 10.0).min(1.0);

        graph.add_edge(
          from_node,
          to_node,
          InteractionEdge {
            interaction_type: InteractionType::SharedLibrary, // TODO: Detect actual type
            strength,
          },
        );
      }
    }
  }

  /// Analyze all domain boundaries
  pub fn analyze_boundaries(&self) -> Result<Vec<DomainBoundary>> {
    let mut boundaries = Vec::new();

    for edge_idx in self.domain_graph.edge_indices() {
      let (from_idx, to_idx) = self.domain_graph.edge_endpoints(edge_idx).unwrap();
      let edge = &self.domain_graph[edge_idx];
      let from_domain = &self.domain_graph[from_idx];
      let to_domain = &self.domain_graph[to_idx];

      boundaries.push(DomainBoundary {
        domain_a: from_domain.name.clone(),
        domain_b: to_domain.name.clone(),
        interaction_type: edge.interaction_type.clone(),
        complexity: edge.strength,
      });
    }

    Ok(boundaries)
  }

  /// Detect domain cycles (architectural smell)
  pub fn detect_cycles(&self) -> Vec<Vec<String>> {
    let sccs = kosaraju_scc(&self.domain_graph);

    sccs
      .into_iter()
      .filter(|scc| scc.len() > 1) // Only actual cycles
      .map(|scc| {
        scc
          .into_iter()
          .map(|node_idx| self.domain_graph[node_idx].name.clone())
          .collect()
      })
      .collect()
  }

  /// Check if domain graph is acyclic (good architecture)
  pub fn is_acyclic(&self) -> bool {
    !is_cyclic_directed(&self.domain_graph)
  }

  /// Find isolated domains (no interactions)
  pub fn find_isolated_domains(&self) -> Vec<String> {
    let mut isolated = Vec::new();

    for node_idx in self.domain_graph.node_indices() {
      let has_incoming = self.domain_graph.neighbors_directed(node_idx, petgraph::Direction::Incoming).next().is_some();
      let has_outgoing = self.domain_graph.neighbors_directed(node_idx, petgraph::Direction::Outgoing).next().is_some();

      if !has_incoming && !has_outgoing {
        isolated.push(self.domain_graph[node_idx].name.clone());
      }
    }

    isolated
  }

  /// Compute domain coupling scores
  pub fn compute_coupling_scores(&self) -> HashMap<String, f64> {
    let mut scores = HashMap::new();

    for node_idx in self.domain_graph.node_indices() {
      let domain_name = &self.domain_graph[node_idx].name;

      // Count incoming and outgoing edges
      let incoming_count = self.domain_graph.neighbors_directed(node_idx, petgraph::Direction::Incoming).count();
      let outgoing_count = self.domain_graph.neighbors_directed(node_idx, petgraph::Direction::Outgoing).count();

      // Sum edge strengths
      let mut total_strength = 0.0;
      for edge_idx in self.domain_graph.edges(node_idx) {
        total_strength += edge_idx.weight().strength;
      }

      // Coupling score = (connections * average_strength)
      let connection_count = (incoming_count + outgoing_count) as f64;
      let coupling = if connection_count > 0.0 { total_strength / connection_count } else { 0.0 };

      scores.insert(domain_name.clone(), coupling);
    }

    scores
  }

  /// Find central domains (bottlenecks)
  pub fn find_central_domains(&self) -> Vec<(String, usize)> {
    let mut centrality: Vec<(String, usize)> = self
      .domain_graph
      .node_indices()
      .map(|node_idx| {
        let domain_name = self.domain_graph[node_idx].name.clone();
        let degree = self.domain_graph.edges(node_idx).count();
        (domain_name, degree)
      })
      .collect();

    centrality.sort_by(|a, b| b.1.cmp(&a.1));
    centrality
  }

  /// Suggest architectural improvements
  pub fn suggest_improvements(&self) -> Vec<String> {
    let mut suggestions = Vec::new();

    // Check for cycles
    let cycles = self.detect_cycles();
    if !cycles.is_empty() {
      suggestions.push(format!("⚠️  Found {} circular domain dependencies - consider breaking cycles: {:?}", cycles.len(), cycles));
    }

    // Check for isolated domains
    let isolated = self.find_isolated_domains();
    if !isolated.is_empty() {
      suggestions.push(format!("ℹ️  Found {} isolated domains (no interactions): {:?}", isolated.len(), isolated));
    }

    // Check for high coupling
    let coupling_scores = self.compute_coupling_scores();
    let high_coupling: Vec<_> = coupling_scores.iter().filter(|(_, &score)| score > 0.7).collect();

    if !high_coupling.is_empty() {
      suggestions.push(format!("⚠️  High coupling detected in {} domains - consider decoupling", high_coupling.len()));
    }

    // Check for central bottlenecks
    let central = self.find_central_domains();
    if let Some((domain, degree)) = central.first() {
      if *degree > 5 {
        suggestions.push(format!("⚠️  Domain '{}' is a central bottleneck ({} connections) - consider splitting", domain, degree));
      }
    }

    suggestions
  }

  /// Get domain graph as DOT for visualization
  pub fn to_dot(&self) -> String {
    use petgraph::dot::{Config, Dot};
    format!("{:?}", Dot::with_config(&self.domain_graph, &[Config::EdgeNoLabel]))
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_domain_boundary_analysis() {
    let domains = vec![
      Domain { name: "auth".to_string(), description: "Authentication".to_string(), packages: vec!["auth-service".to_string()], confidence: 0.9 },
      Domain { name: "payments".to_string(), description: "Payment processing".to_string(), packages: vec!["payment-service".to_string()], confidence: 0.9 },
    ];

    let dependency_graph = DependencyGraph {
      nodes: vec!["auth-service".to_string(), "payment-service".to_string()],
      edges: vec![Dependency { from: "payment-service".to_string(), to: "auth-service".to_string(), dependency_type: DependencyType::Direct }],
    };

    let analyzer = DomainBoundaryAnalyzer::new(&domains, &dependency_graph);
    let boundaries = analyzer.analyze_boundaries().unwrap();

    assert_eq!(boundaries.len(), 1);
    assert!(analyzer.is_acyclic());
  }

  #[test]
  fn test_cycle_detection() {
    let domains = vec![
      Domain { name: "a".to_string(), description: "Domain A".to_string(), packages: vec!["pkg-a".to_string()], confidence: 0.9 },
      Domain { name: "b".to_string(), description: "Domain B".to_string(), packages: vec!["pkg-b".to_string()], confidence: 0.9 },
    ];

    let dependency_graph = DependencyGraph {
      nodes: vec!["pkg-a".to_string(), "pkg-b".to_string()],
      edges: vec![
        Dependency { from: "pkg-a".to_string(), to: "pkg-b".to_string(), dependency_type: DependencyType::Direct },
        Dependency { from: "pkg-b".to_string(), to: "pkg-a".to_string(), dependency_type: DependencyType::Direct },
      ],
    };

    let analyzer = DomainBoundaryAnalyzer::new(&domains, &dependency_graph);
    let cycles = analyzer.detect_cycles();

    assert_eq!(cycles.len(), 1);
    assert!(!analyzer.is_acyclic());
  }
}
