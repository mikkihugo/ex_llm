//! Dependency Graph Analysis with CentralCloud Integration
//!
//! Builds dependency graphs from code and enriches nodes with health data from CentralCloud.
//!
//! ## CentralCloud Integration
//!
//! - Queries "intelligence_hub.dependency_health.query" for health annotations
//! - Publishes graph metrics to "intelligence_hub.graph.stats"
//! - No local databases - all health data from CentralCloud

use crate::centralcloud::{extract_data, publish_detection, query_centralcloud};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;

/// Dependency graph analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyGraphAnalysis {
    pub graph: DependencyGraph,
    pub metrics: GraphMetrics,
    pub cycles: Vec<CircularDependency>,
    pub recommendations: Vec<GraphRecommendation>,
    pub metadata: GraphMetadata,
}

/// Dependency graph
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyGraph {
    pub nodes: Vec<DependencyNode>,
    pub edges: Vec<DependencyEdge>,
    pub root_nodes: Vec<String>,
    pub leaf_nodes: Vec<String>,
    pub strongly_connected_components: Vec<Vec<String>>,
}

/// Dependency node with health annotations from CentralCloud
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyNode {
    pub id: String,
    pub name: String,
    pub node_type: DependencyNodeType,
    pub version: Option<String>,
    pub location: String,
    pub metadata: NodeMetadata,
    pub in_degree: u32,
    pub out_degree: u32,
    pub centrality: CentralityMetrics,
}

/// Dependency node types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DependencyNodeType {
    Package,
    Module,
    Class,
    Function,
    File,
    Service,
    Component,
    Library,
    Framework,
    External,
}

/// Node metadata enriched with CentralCloud health data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeMetadata {
    pub size: u64,
    pub complexity: f64,
    pub maintainability: f64,
    pub testability: f64,
    pub security_score: f64,
    pub performance_score: f64,
    pub last_modified: Option<chrono::DateTime<chrono::Utc>>,
    pub author: Option<String>,
    pub description: Option<String>,
}

/// Centrality metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CentralityMetrics {
    pub degree_centrality: f64,
    pub betweenness_centrality: f64,
    pub closeness_centrality: f64,
    pub eigenvector_centrality: f64,
    pub pagerank: f64,
}

/// Dependency edge
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyEdge {
    pub id: String,
    pub from_node: String,
    pub to_node: String,
    pub edge_type: DependencyEdgeType,
    pub weight: f64,
    pub metadata: EdgeMetadata,
}

/// Dependency edge types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DependencyEdgeType {
    Import,
    Inheritance,
    Composition,
    Aggregation,
    Association,
    Dependency,
    Call,
    Reference,
    Include,
    Require,
    Use,
    Extend,
    Implement,
}

/// Edge metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EdgeMetadata {
    pub frequency: u32,
    pub strength: f64,
    pub direction: EdgeDirection,
    pub context: Option<String>,
    pub line_number: Option<u32>,
    pub function_name: Option<String>,
}

/// Edge direction
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EdgeDirection {
    Forward,
    Backward,
    Bidirectional,
}

/// Graph metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphMetrics {
    pub node_count: u32,
    pub edge_count: u32,
    pub density: f64,
    pub average_degree: f64,
    pub max_degree: u32,
    pub min_degree: u32,
    pub diameter: u32,
    pub radius: u32,
    pub clustering_coefficient: f64,
    pub modularity: f64,
    pub connectivity: f64,
    pub robustness: f64,
}

/// Circular dependency
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CircularDependency {
    pub id: String,
    pub cycle_nodes: Vec<String>,
    pub cycle_length: u32,
    pub severity: CircularDependencySeverity,
    pub impact: CircularDependencyImpact,
    pub description: String,
    pub remediation: String,
}

/// Circular dependency severity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CircularDependencySeverity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

/// Circular dependency impact
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CircularDependencyImpact {
    pub build_impact: f64,
    pub test_impact: f64,
    pub maintenance_impact: f64,
    pub performance_impact: f64,
    pub scalability_impact: f64,
}

/// Graph recommendation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphRecommendation {
    pub priority: RecommendationPriority,
    pub category: GraphCategory,
    pub title: String,
    pub description: String,
    pub implementation: String,
    pub expected_benefit: f64,
    pub effort_required: EffortEstimate,
}

/// Recommendation priority
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationPriority {
    Critical,
    High,
    Medium,
    Low,
}

/// Graph categories
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GraphCategory {
    Structure,
    Performance,
    Maintainability,
    Testability,
    Security,
    Scalability,
    Modularity,
    Coupling,
    Cohesion,
}

/// Effort estimate
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EffortEstimate {
    Low,
    Medium,
    High,
    VeryHigh,
}

/// Graph metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphMetadata {
    pub analysis_time: chrono::DateTime<chrono::Utc>,
    pub files_analyzed: usize,
    pub nodes_created: usize,
    pub edges_created: usize,
    pub cycles_found: usize,
    pub analysis_duration_ms: u64,
    pub detector_version: String,
}

/// Dependency graph analyzer - CentralCloud integration (no local databases)
pub struct DependencyGraphAnalyzer {
    // No local databases - query CentralCloud on-demand
}

impl DependencyGraphAnalyzer {
    pub fn new() -> Self {
        Self {}
    }

    /// Initialize (no-op for CentralCloud mode)
    pub async fn initialize(&mut self) -> Result<()> {
        // No initialization needed - queries CentralCloud on-demand
        Ok(())
    }

    /// Analyze dependency graph with CentralCloud health annotations
    pub async fn analyze(&self, content: &str, file_path: &str) -> Result<DependencyGraphAnalysis> {
        let start_time = std::time::Instant::now();

        // 1. Build dependency graph from content (use content!)
        let mut graph = self.build_dependency_graph(content, file_path).await?;

        // 2. Enrich nodes with CentralCloud health data
        self.enrich_with_health_data(&mut graph).await?;

        // 3. Calculate graph metrics (use graph!)
        let metrics = self.calculate_graph_metrics(&graph);

        // 4. Detect circular dependencies (use graph!)
        let cycles = self.detect_circular_dependencies(&graph);

        // 5. Generate recommendations (use all!)
        let recommendations = self.generate_recommendations(&graph, &metrics, &cycles);

        // 6. Publish graph metrics to CentralCloud
        self.publish_graph_stats(&graph, &metrics, &cycles).await;

        let analysis_duration = start_time.elapsed().as_millis() as u64;
        let nodes_count = graph.nodes.len();
        let edges_count = graph.edges.len();
        let cycles_count = cycles.len();

        Ok(DependencyGraphAnalysis {
            graph,
            metrics,
            cycles,
            recommendations,
            metadata: GraphMetadata {
                analysis_time: chrono::Utc::now(),
                files_analyzed: 1,
                nodes_created: nodes_count,
                edges_created: edges_count,
                cycles_found: cycles_count,
                analysis_duration_ms: analysis_duration,
                detector_version: "1.0.0".to_string(),
            },
        })
    }

    /// Build dependency graph from code content
    async fn build_dependency_graph(
        &self,
        content: &str,
        file_path: &str,
    ) -> Result<DependencyGraph> {
        let mut nodes = Vec::new();
        let mut edges = Vec::new();

        // Extract dependencies from content (simplified - real impl would parse AST)
        let dependencies = self.extract_dependencies_from_content(content, file_path);

        // Create nodes from dependencies
        for (idx, dep) in dependencies.iter().enumerate() {
            nodes.push(DependencyNode {
                id: format!("dep_{}", idx),
                name: dep.clone(),
                node_type: DependencyNodeType::Package,
                version: None,
                location: file_path.to_string(),
                metadata: NodeMetadata {
                    size: 0,
                    complexity: 0.0,
                    maintainability: 0.0,
                    testability: 0.0,
                    security_score: 0.0,
                    performance_score: 0.0,
                    last_modified: None,
                    author: None,
                    description: None,
                },
                in_degree: 0,
                out_degree: 1,
                centrality: CentralityMetrics {
                    degree_centrality: 0.0,
                    betweenness_centrality: 0.0,
                    closeness_centrality: 0.0,
                    eigenvector_centrality: 0.0,
                    pagerank: 0.0,
                },
            });

            edges.push(DependencyEdge {
                id: format!("edge_{}", idx),
                from_node: file_path.to_string(),
                to_node: format!("dep_{}", idx),
                edge_type: DependencyEdgeType::Import,
                weight: 1.0,
                metadata: EdgeMetadata {
                    frequency: 1,
                    strength: 1.0,
                    direction: EdgeDirection::Forward,
                    context: None,
                    line_number: None,
                    function_name: None,
                },
            });
        }

        // Identify root and leaf nodes
        let root_nodes: Vec<String> = nodes
            .iter()
            .filter(|n| n.in_degree == 0)
            .map(|n| n.id.clone())
            .collect();
        let leaf_nodes: Vec<String> = nodes
            .iter()
            .filter(|n| n.out_degree == 0)
            .map(|n| n.id.clone())
            .collect();

        Ok(DependencyGraph {
            nodes,
            edges,
            root_nodes,
            leaf_nodes,
            strongly_connected_components: Vec::new(),
        })
    }

    /// Extract dependency names from content (simplified parser)
    fn extract_dependencies_from_content(&self, content: &str, _file_path: &str) -> Vec<String> {
        let mut dependencies = Vec::new();

        // Simple heuristic: look for import/use/require statements
        for line in content.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("import ")
                || trimmed.starts_with("use ")
                || trimmed.starts_with("require ")
            {
                if let Some(dep_name) = Self::extract_dep_name(trimmed) {
                    dependencies.push(dep_name);
                }
            }
        }

        dependencies
    }

    /// Extract dependency name from import statement
    fn extract_dep_name(line: &str) -> Option<String> {
        // Simplified: extract first word after import/use/require
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() > 1 {
            Some(
                parts[1]
                    .trim_matches(|c| c == ';' || c == ',' || c == '\'' || c == '"')
                    .to_string(),
            )
        } else {
            None
        }
    }

    /// Enrich dependency nodes with health data from CentralCloud
    async fn enrich_with_health_data(&self, graph: &mut DependencyGraph) -> Result<()> {
        if graph.nodes.is_empty() {
            return Ok(());
        }

        // Prepare request for CentralCloud
        let dependencies: Vec<serde_json::Value> = graph
            .nodes
            .iter()
            .map(|node| {
                json!({
                    "name": node.name,
                    "version": node.version,
                })
            })
            .collect();

        let request = json!({
            "dependencies": dependencies,
            "include_health_score": true,
            "include_security_score": true,
        });

        // Query CentralCloud for health data
        let response =
            query_centralcloud("intelligence_hub.dependency_health.query", &request, 5000)?;

        let health_data: Vec<serde_json::Value> = extract_data(&response, "health_data");

        // Enrich nodes with health data
        for (node, health) in graph.nodes.iter_mut().zip(health_data.iter()) {
            if let Some(maintainability) =
                health.get("maintainability_score").and_then(|v| v.as_f64())
            {
                node.metadata.maintainability = maintainability;
            }
            if let Some(security) = health.get("security_score").and_then(|v| v.as_f64()) {
                node.metadata.security_score = security;
            }
            if let Some(performance) = health.get("performance_score").and_then(|v| v.as_f64()) {
                node.metadata.performance_score = performance;
            }
        }

        Ok(())
    }

    /// Calculate graph metrics using graph structure
    fn calculate_graph_metrics(&self, graph: &DependencyGraph) -> GraphMetrics {
        let node_count = graph.nodes.len() as u32;
        let edge_count = graph.edges.len() as u32;

        let density = if node_count > 1 {
            (edge_count as f64) / ((node_count * (node_count - 1)) as f64)
        } else {
            0.0
        };

        let degrees: Vec<u32> = graph
            .nodes
            .iter()
            .map(|n| n.in_degree + n.out_degree)
            .collect();

        let average_degree = if node_count > 0 {
            degrees.iter().sum::<u32>() as f64 / node_count as f64
        } else {
            0.0
        };

        let max_degree = degrees.iter().max().copied().unwrap_or(0);
        let min_degree = degrees.iter().min().copied().unwrap_or(0);

        // Simplified metrics (real impl would use graph algorithms)
        let diameter = node_count.saturating_sub(1);
        let radius = diameter / 2;
        let clustering_coefficient = if node_count > 2 { density } else { 0.0 };
        let modularity = 1.0 - density;
        let connectivity = if node_count > 0 {
            edge_count as f64 / node_count as f64
        } else {
            0.0
        };
        let robustness =
            1.0 - (graph.strongly_connected_components.len() as f64 / node_count.max(1) as f64);

        GraphMetrics {
            node_count,
            edge_count,
            density,
            average_degree,
            max_degree,
            min_degree,
            diameter,
            radius,
            clustering_coefficient,
            modularity,
            connectivity,
            robustness,
        }
    }

    /// Detect circular dependencies using strongly connected components
    fn detect_circular_dependencies(&self, graph: &DependencyGraph) -> Vec<CircularDependency> {
        let mut cycles = Vec::new();

        // Use strongly connected components from graph
        for (idx, component) in graph.strongly_connected_components.iter().enumerate() {
            if component.len() > 1 {
                let severity = match component.len() {
                    2..=3 => CircularDependencySeverity::Low,
                    4..=6 => CircularDependencySeverity::Medium,
                    7..=10 => CircularDependencySeverity::High,
                    _ => CircularDependencySeverity::Critical,
                };

                cycles.push(CircularDependency {
                    id: format!("cycle_{}", idx),
                    cycle_nodes: component.clone(),
                    cycle_length: component.len() as u32,
                    severity,
                    impact: CircularDependencyImpact {
                        build_impact: 0.7,
                        test_impact: 0.6,
                        maintenance_impact: 0.8,
                        performance_impact: 0.4,
                        scalability_impact: 0.5,
                    },
                    description: format!("Circular dependency involving {} nodes", component.len()),
                    remediation: "Refactor to break the circular dependency using dependency inversion or interfaces".to_string(),
                });
            }
        }

        cycles
    }

    /// Generate recommendations based on graph analysis
    fn generate_recommendations(
        &self,
        graph: &DependencyGraph,
        metrics: &GraphMetrics,
        cycles: &[CircularDependency],
    ) -> Vec<GraphRecommendation> {
        let mut recommendations = Vec::new();

        // Recommendations for circular dependencies
        for cycle in cycles {
            let priority = match cycle.severity {
                CircularDependencySeverity::Critical => RecommendationPriority::Critical,
                CircularDependencySeverity::High => RecommendationPriority::High,
                CircularDependencySeverity::Medium => RecommendationPriority::Medium,
                _ => RecommendationPriority::Low,
            };

            recommendations.push(GraphRecommendation {
                priority,
                category: GraphCategory::Structure,
                title: "Break Circular Dependency".to_string(),
                description: cycle.description.clone(),
                implementation: cycle.remediation.clone(),
                expected_benefit: 0.8,
                effort_required: EffortEstimate::High,
            });
        }

        // Recommendations for high coupling
        if metrics.density > 0.5 {
            recommendations.push(GraphRecommendation {
                priority: RecommendationPriority::High,
                category: GraphCategory::Coupling,
                title: "Reduce Coupling".to_string(),
                description: format!("High coupling detected (density: {:.2})", metrics.density),
                implementation: "Refactor to reduce dependencies between modules using interfaces or dependency injection".to_string(),
                expected_benefit: 0.6,
                effort_required: EffortEstimate::Medium,
            });
        }

        // Recommendations for low modularity
        if metrics.modularity < 0.3 {
            recommendations.push(GraphRecommendation {
                priority: RecommendationPriority::Medium,
                category: GraphCategory::Modularity,
                title: "Improve Modularity".to_string(),
                description: format!("Low modularity detected ({:.2})", metrics.modularity),
                implementation: "Reorganize code into more cohesive modules with clear boundaries"
                    .to_string(),
                expected_benefit: 0.5,
                effort_required: EffortEstimate::High,
            });
        }

        // Recommendations for unhealthy dependencies
        let unhealthy_nodes: Vec<&DependencyNode> = graph
            .nodes
            .iter()
            .filter(|n| n.metadata.security_score < 0.5 || n.metadata.maintainability < 0.5)
            .collect();

        if !unhealthy_nodes.is_empty() {
            recommendations.push(GraphRecommendation {
                priority: RecommendationPriority::High,
                category: GraphCategory::Security,
                title: "Address Unhealthy Dependencies".to_string(),
                description: format!(
                    "{} dependencies have low health scores",
                    unhealthy_nodes.len()
                ),
                implementation:
                    "Review and update dependencies with low security or maintainability scores"
                        .to_string(),
                expected_benefit: 0.7,
                effort_required: EffortEstimate::Medium,
            });
        }

        recommendations
    }

    /// Publish graph statistics to CentralCloud for collective learning
    async fn publish_graph_stats(
        &self,
        graph: &DependencyGraph,
        metrics: &GraphMetrics,
        cycles: &[CircularDependency],
    ) {
        let stats = json!({
            "type": "dependency_graph_analysis",
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "metrics": {
                "node_count": metrics.node_count,
                "edge_count": metrics.edge_count,
                "density": metrics.density,
                "average_degree": metrics.average_degree,
                "cycles_found": cycles.len(),
            },
            "graph_summary": {
                "total_nodes": graph.nodes.len(),
                "total_edges": graph.edges.len(),
                "root_nodes": graph.root_nodes.len(),
                "leaf_nodes": graph.leaf_nodes.len(),
            }
        });

        // Fire-and-forget publish
        publish_detection("intelligence_hub.graph.stats", &stats).ok();
    }
}

impl Default for DependencyGraphAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}
