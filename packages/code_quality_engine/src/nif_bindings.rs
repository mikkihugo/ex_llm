//! NIF bindings for Elixir integration
//!
//! Exposes code_engine functions to Elixir via Rustler NIFs
//! NO I/O - pure computation only!
//!
//! **ENABLED**: Re-enabled after Phase 1-3 refactoring
//! - Phase 1: Added missing type definitions (SemanticFeatures, complexity field, symbols field)
//! - Phase 2: Fixed all storage::graph imports to use crate::graph
//! - Phase 3: Uncommented analysis and nif_bindings modules

use rustler::NifStruct;
use serde::{Deserialize, Serialize};

use crate::analysis::control_flow::{analyze_function_flow, ControlFlowAnalysis};
use crate::graph::{CodeDependencyGraph, GraphType};

/// Function metadata result for cross-language analysis
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.FunctionMetadata"]
pub struct FunctionMetadataResult {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub parameters: Vec<String>,
    pub return_type: Option<String>,
    pub is_async: bool,
    pub is_generator: bool,
    pub docstring: Option<String>,
}

/// Class metadata result for cross-language analysis
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.ClassMetadata"]
pub struct ClassMetadataResult {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub methods: Vec<String>,
    pub fields: Vec<String>,
    pub inheritance: Vec<String>,
    pub visibility: String,
}

/// Result returned to Elixir (maps to Elixir struct)
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.ControlFlowResult"]
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
#[module = "Singularity.CodeAnalyzer.DeadEnd"]
pub struct DeadEndInfo {
    pub node_id: String,
    pub function_name: String,
    pub line_number: usize,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.UnreachableCode"]
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
    let analysis = analyze_function_flow(graph).map_err(|e| format!("Analysis failed: {}", e))?;

    // Convert to Elixir-friendly format
    Ok(convert_analysis_to_result(analysis))
}

/// Helper: Create example graph (replace with real parsing)
fn create_example_graph(file_path: &str) -> Result<CodeDependencyGraph, String> {
    // This is a placeholder - in production, parse the file
    use crate::graph::{GraphEdge, GraphNode};
    use std::collections::HashMap;
    use std::path::PathBuf;

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
    graph
        .add_edge(GraphEdge {
            from: "entry".to_string(),
            to: "validate".to_string(),
            edge_type: "calls".to_string(),
            weight: 1.0,
            metadata: HashMap::new(),
        })
        .map_err(|e| e.to_string())?;

    graph
        .add_edge(GraphEdge {
            from: "validate".to_string(),
            to: "process".to_string(),
            edge_type: "calls".to_string(),
            weight: 1.0,
            metadata: HashMap::new(),
        })
        .map_err(|e| e.to_string())?;

    graph
        .add_edge(GraphEdge {
            from: "process".to_string(),
            to: "return_ok".to_string(),
            edge_type: "calls".to_string(),
            weight: 1.0,
            metadata: HashMap::new(),
        })
        .map_err(|e| e.to_string())?;

    Ok(graph)
}

/// Convert analysis result to Elixir-friendly format
fn convert_analysis_to_result(analysis: ControlFlowAnalysis) -> ControlFlowResult {
    let dead_ends = analysis
        .dead_ends
        .into_iter()
        .map(|de| DeadEndInfo {
            node_id: de.node_id,
            function_name: de.function_name,
            line_number: de.line_number,
            reason: format!("{:?}", de.reason),
        })
        .collect();

    let unreachable_code = analysis
        .unreachable_code
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

// ===========================
// Multi-Language Analyzer NIF Bindings
// ===========================

/// Language analysis result (maps to Elixir struct)
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.LanguageAnalysis"]
pub struct LanguageAnalysisResult {
    pub language_id: String,
    pub language_name: String,
    pub family: Option<String>,
    pub complexity_score: f64,
    pub quality_score: f64,
    pub rca_supported: bool,
    pub ast_grep_supported: bool,
}

/// Language rule violation result
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.RuleViolation"]
pub struct RuleViolationResult {
    pub rule_id: String,
    pub rule_name: String,
    pub severity: String,
    pub location: String,
    pub details: String,
}

/// Cross-language pattern result
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.CrossLanguagePattern"]
pub struct CrossLanguagePatternResult {
    pub id: String,
    pub name: String,
    pub pattern_type: String,
    pub source_language: String,
    pub target_language: String,
    pub confidence: f64,
    pub characteristics: Vec<String>,
}

/// RCA metrics result
#[derive(Debug, Clone, Serialize, Deserialize, NifStruct)]
#[module = "Singularity.CodeAnalyzer.RcaMetrics"]
pub struct RcaMetricsResult {
    pub cyclomatic_complexity: String,
    pub halstead_metrics: String,
    pub maintainability_index: String,
    pub source_lines_of_code: u64,
    pub logical_lines_of_code: u64,
    pub comment_lines_of_code: u64,
    pub blank_lines: u64,
}

/// Analyze a single language file
///
/// Pure computation NIF - NO I/O!
/// Returns language analysis with registry metadata
#[rustler::nif]
pub fn analyze_language(
    code: String,
    language_hint: String,
) -> Result<LanguageAnalysisResult, String> {
    use crate::analyzer::CodebaseAnalyzer;

    let analyzer =
        CodebaseAnalyzer::new().map_err(|e| format!("Failed to create analyzer: {}", e))?;

    match analyzer.analyze_language(&code, &language_hint) {
        Some(analysis) => Ok(LanguageAnalysisResult {
            language_id: analysis.language_id,
            language_name: analysis.language_name,
            family: analysis.family,
            complexity_score: analysis.complexity_score,
            quality_score: analysis.quality_score,
            rca_supported: analysis.rca_supported,
            ast_grep_supported: analysis.ast_grep_supported,
        }),
        None => Err(format!("Unsupported language: {}", language_hint)),
    }
}

/// Check code against language-specific rules
///
/// Pure computation NIF - NO I/O!
/// Returns list of rule violations
#[rustler::nif]
pub fn check_language_rules(
    code: String,
    language_hint: String,
) -> Result<Vec<RuleViolationResult>, String> {
    use crate::analyzer::CodebaseAnalyzer;

    let analyzer =
        CodebaseAnalyzer::new().map_err(|e| format!("Failed to create analyzer: {}", e))?;

    let violations = analyzer.check_language_rules(&code, &language_hint);

    Ok(violations
        .into_iter()
        .map(|v| RuleViolationResult {
            rule_id: v.rule.id,
            rule_name: v.rule.name,
            severity: format!("{:?}", v.rule.severity),
            location: v.location,
            details: v.details,
        })
        .collect())
}

/// Detect cross-language patterns in polyglot codebases
///
/// Pure computation NIF - NO I/O!
/// Analyzes multiple files to find patterns spanning language boundaries
#[rustler::nif]
pub fn detect_cross_language_patterns(
    files: Vec<(String, String)>,
) -> Result<Vec<CrossLanguagePatternResult>, String> {
    use crate::analyzer::CodebaseAnalyzer;

    let analyzer =
        CodebaseAnalyzer::new().map_err(|e| format!("Failed to create analyzer: {}", e))?;

    let patterns = analyzer.detect_cross_language_patterns(&files);

    Ok(patterns
        .into_iter()
        .map(|p| CrossLanguagePatternResult {
            id: p.id,
            name: p.name,
            pattern_type: format!("{:?}", p.pattern_type),
            source_language: p.source_language,
            target_language: p.target_language,
            confidence: p.confidence,
            characteristics: p.characteristics,
        })
        .collect())
}

/// Get RCA metrics for code
///
/// Pure computation NIF - NO I/O!
/// Returns detailed complexity metrics (CC, Halstead, MI, SLOC, etc.)
#[rustler::nif]
pub fn get_rca_metrics(code: String, language_hint: String) -> Result<RcaMetricsResult, String> {
    use crate::analyzer::CodebaseAnalyzer;

    let analyzer =
        CodebaseAnalyzer::new().map_err(|e| format!("Failed to create analyzer: {}", e))?;

    let metrics = analyzer.get_rca_metrics(&code, &language_hint)?;

    Ok(RcaMetricsResult {
        cyclomatic_complexity: metrics.cyclomatic_complexity,
        halstead_metrics: metrics.halstead_metrics,
        maintainability_index: metrics.maintainability_index,
        source_lines_of_code: metrics.source_lines_of_code,
        logical_lines_of_code: metrics.logical_lines_of_code,
        comment_lines_of_code: metrics.comment_lines_of_code,
        blank_lines: metrics.blank_lines,
    })
}

/// Extract function metadata from code using AST
///
/// Pure computation NIF - NO I/O!
/// Uses Tree-sitter to extract function signatures, parameters, etc.
#[rustler::nif]
pub fn extract_functions(
    code: String,
    language_hint: String,
) -> Result<Vec<FunctionMetadataResult>, String> {
    use crate::analyzer::CodebaseAnalyzer;

    let analyzer =
        CodebaseAnalyzer::new().map_err(|e| format!("Failed to create analyzer: {}", e))?;

    let functions = analyzer.extract_functions(&code, &language_hint)?;

    Ok(functions
        .into_iter()
        .map(|f| FunctionMetadataResult {
            name: f.name,
            line_start: f.line_start,
            line_end: f.line_end,
            parameters: f.parameters,
            return_type: f.return_type,
            is_async: f.is_async,
            is_generator: f.is_generator,
            docstring: f.docstring,
        })
        .collect())
}

/// Extract class metadata from code using AST
///
/// Pure computation NIF - NO I/O!
/// Uses Tree-sitter to extract class structure
#[rustler::nif]
pub fn extract_classes(
    code: String,
    language_hint: String,
) -> Result<Vec<ClassMetadataResult>, String> {
    use crate::analyzer::CodebaseAnalyzer;

    let analyzer =
        CodebaseAnalyzer::new().map_err(|e| format!("Failed to create analyzer: {}", e))?;

    let classes = analyzer.extract_classes(&code, &language_hint)?;

    Ok(classes
        .into_iter()
        .map(|c| ClassMetadataResult {
            name: c.name,
            line_start: c.line_start,
            line_end: c.line_end,
            methods: c.methods.into_iter().map(|m| m.name).collect(),
            fields: c.fields,
                inheritance: Vec::new(),
                visibility: "unknown".to_string(),
        })
        .collect())
}

/// Extract imports and exports from code
///
/// Pure computation NIF - NO I/O!
/// Uses AST-based detection for accurate dependency extraction
#[rustler::nif]
pub fn extract_imports_exports(
    code: String,
    language_hint: String,
) -> Result<(Vec<String>, Vec<String>), String> {
    use crate::analyzer::CodebaseAnalyzer;

    let analyzer =
        CodebaseAnalyzer::new().map_err(|e| format!("Failed to create analyzer: {}", e))?;

    analyzer.extract_imports_exports(&code, &language_hint)
}

// Note: supported_languages, rca_supported_languages, has_rca_support,
// and has_ast_grep_support are exported from nif/mod.rs to avoid duplicates.

// NOTE: rustler::init! moved to src/nif/mod.rs to avoid duplicate nif_init symbol
// This file only exports the NIF function - initialization happens in nif/mod.rs

/*
Removed legacy #[allow(dead_code)] and unimplemented NIF stubs.
Production code must provide real implementations or handle NIF loading errors gracefully.
*/
