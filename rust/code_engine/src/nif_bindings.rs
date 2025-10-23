//! NIF bindings for Elixir integration
//!
//! Exposes code_engine functions to Elixir via Rustler NIFs
//! NO I/O - pure computation only!
//!
//! **ENABLED**: Re-enabled after Phase 1-3 refactoring
//! - Phase 1: Added missing type definitions (SemanticFeatures, complexity field, symbols field)
//! - Phase 2: Fixed all storage::graph imports to use crate::graph
//! - Phase 3: Uncommented analysis and nif_bindings modules

use rustler::{Encoder, Env, NifStruct, Term};
use serde::{Deserialize, Serialize};

use crate::analysis::control_flow::{
    analyze_function_flow, ControlFlowAnalysis, DeadEnd, DeadEndReason, UnreachableCode,
    FlowCompleteness,
};
use crate::graph::{CodeDependencyGraph, GraphType};

/// Result returned to Elixir (maps to Elixir struct)
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.RustAnalyzer.ControlFlowResult"]
pub struct ControlFlowResult {
    pub dead_ends: Vec<DeadEndInfo>,
    pub unreachable_code: Vec<UnreachableCodeInfo>,
    pub completeness_score: f64,
    pub total_paths: usize,
    pub complete_paths: usize,
    pub incomplete_paths: usize,
    pub has_issues: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.RustAnalyzer.DeadEnd"]
pub struct DeadEndInfo {
    pub node_id: String,
    pub function_name: String,
    pub line_number: usize,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.RustAnalyzer.UnreachableCode"]
pub struct UnreachableCodeInfo {
    pub node_id: String,
    pub line_number: usize,
    pub reason: String,
}

/// Analyze control flow for a file
///
/// This is a pure computation NIF - NO I/O!
/// Returns results to Elixir, which stores in PostgreSQL
#[rustler::nif]
pub fn analyze_control_flow(file_path: String) -> Result<ControlFlowResult, String> {
    // For now, create a simple graph to demonstrate
    // In production, this would parse the file and build a real CFG

    // TODO: Integrate with existing tree-sitter parsing
    // TODO: Build actual CFG from AST

    // Placeholder: Create example graph
    let graph = create_example_graph(&file_path)?;

    // Analyze using our control_flow module
    let analysis = analyze_function_flow(graph)
        .map_err(|e| format!("Analysis failed: {}", e))?;

    // Convert to Elixir-friendly format
    Ok(convert_analysis_to_result(analysis))
}

/// Helper: Create example graph (replace with real parsing)
fn create_example_graph(file_path: &str) -> Result<CodeDependencyGraph, String> {
    // This is a placeholder - in production, parse the file
    use crate::graph::{GraphNode, GraphEdge};
    use std::path::PathBuf;
    use std::collections::HashMap;

    let mut graph = CodeDependencyGraph::new(GraphType::DataFlowGraph);

    // Example: Create simple CFG
    let entry = GraphNode {
        id: "entry".to_string(),
        node_type: "entry".to_string(),
        name: "start".to_string(),
        file_path: PathBuf::from(file_path),
        line_number: Some(1),
        vector: None,
        vector_magnitude: None,
    };

    let validate = GraphNode {
        id: "validate".to_string(),
        node_type: "function_call".to_string(),
        name: "validate_user".to_string(),
        file_path: PathBuf::from(file_path),
        line_number: Some(5),
        vector: None,
        vector_magnitude: None,
    };

    let process = GraphNode {
        id: "process".to_string(),
        node_type: "function_call".to_string(),
        name: "process_data".to_string(),
        file_path: PathBuf::from(file_path),
        line_number: Some(10),
        vector: None,
        vector_magnitude: None,
    };

    let return_node = GraphNode {
        id: "return_ok".to_string(),
        node_type: "return".to_string(),
        name: "return :ok".to_string(),
        file_path: PathBuf::from(file_path),
        line_number: Some(15),
        vector: None,
        vector_magnitude: None,
    };

    graph.add_node(entry);
    graph.add_node(validate);
    graph.add_node(process);
    graph.add_node(return_node);

    // Add edges
    graph.add_edge(GraphEdge {
        from: "entry".to_string(),
        to: "validate".to_string(),
        edge_type: "calls".to_string(),
        weight: 1.0,
        metadata: HashMap::new(),
    }).map_err(|e| e.to_string())?;

    graph.add_edge(GraphEdge {
        from: "validate".to_string(),
        to: "process".to_string(),
        edge_type: "calls".to_string(),
        weight: 1.0,
        metadata: HashMap::new(),
    }).map_err(|e| e.to_string())?;

    graph.add_edge(GraphEdge {
        from: "process".to_string(),
        to: "return_ok".to_string(),
        edge_type: "calls".to_string(),
        weight: 1.0,
        metadata: HashMap::new(),
    }).map_err(|e| e.to_string())?;

    Ok(graph)
}

/// Convert analysis result to Elixir-friendly format
fn convert_analysis_to_result(analysis: ControlFlowAnalysis) -> ControlFlowResult {
    let dead_ends = analysis.dead_ends
        .into_iter()
        .map(|de| DeadEndInfo {
            node_id: de.node_id,
            function_name: de.function_name,
            line_number: de.line_number,
            reason: format!("{:?}", de.reason),
        })
        .collect();

    let unreachable_code = analysis.unreachable_code
        .into_iter()
        .map(|uc| UnreachableCodeInfo {
            node_id: uc.node_id,
            line_number: uc.line_number,
            reason: uc.reason,
        })
        .collect();

    ControlFlowResult {
        dead_ends,
        unreachable_code,
        completeness_score: analysis.completeness.completeness_score,
        total_paths: analysis.completeness.total_paths,
        complete_paths: analysis.completeness.complete_paths,
        incomplete_paths: analysis.completeness.incomplete_paths,
        has_issues: analysis.has_issues,
    }
}

// NOTE: rustler::init! moved to src/nif/mod.rs to avoid duplicate nif_init symbol
// This file only exports the NIF function - initialization happens in nif/mod.rs
