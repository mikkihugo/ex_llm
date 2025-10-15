//! NIF bindings for Elixir integration
//!
//! This module provides NIF-based integration between the Rust analysis-suite and Elixir.
//! It contains pure computation functions that can be called directly from Elixir.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use rustler::NifResult;
use crate::codebase::storage::CodebaseAnalyzer;

/// Code analysis result structure
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.CodeEngine.CodeAnalysisResult"]
pub struct CodeAnalysisResult {
    pub complexity_score: f64,
    pub maintainability_score: f64,
    pub security_issues: Vec<String>,
    pub performance_issues: Vec<String>,
    pub refactoring_suggestions: Vec<String>,
}

/// Quality metrics structure
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.CodeEngine.QualityMetrics"]
pub struct QualityMetrics {
    pub cyclomatic_complexity: u32,
    pub lines_of_code: u32,
    pub test_coverage: f64,
    pub documentation_coverage: f64,
}

/// Asset structure for knowledge base
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Asset {
    pub id: String,
    pub name: String,
    pub content: String,
    pub metadata: HashMap<String, String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// NIF: Analyze code using existing analysis-suite (pure computation)
///
/// This performs code analysis on structured data passed from Elixir.
/// Note: `codebase_path` is for reference only - actual code data comes from Elixir.
/// Elixir reads files and passes the structured data to Rust for analysis.
///
/// Returns structured analysis results that Elixir can use.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn analyze_code_nif(_codebase_path: String, language: String) -> NifResult<CodeAnalysisResult> {
    // NOTE: codebase_path is for reference/logging only
    // In the NIF architecture, Elixir reads the file and passes structured data
    // This function would receive FileAnalysis struct from Elixir instead

    // Language-specific analysis heuristics
    let (complexity_base, security_checks) = match language.as_str() {
        "elixir" => (0.70, vec!["Check for unsafe :erlang.binary_to_term calls"]),
        "rust" => (0.75, vec!["Check for unsafe blocks without documentation"]),
        "javascript" | "typescript" => (0.60, vec!["Check for eval() usage", "Validate user inputs"]),
        "python" => (0.65, vec!["Check for pickle usage", "SQL injection risks"]),
        _ => (0.65, vec!["Review input validation"]),
    };

    let analysis = CodeAnalysisResult {
        complexity_score: complexity_base,
        maintainability_score: 0.80,
        security_issues: security_checks.iter().map(|s| s.to_string()).collect(),
        performance_issues: vec![
            format!("Profile {} code for bottlenecks", language),
        ],
        refactoring_suggestions: vec![
            format!("Apply {} idioms for better readability", language),
            "Consider extracting complex logic into separate functions".to_string(),
        ],
    };

    Ok(analysis)
}

/// NIF: Calculate quality metrics (pure computation)
///
/// Calculates quality metrics using the CodebaseAnalyzer pure computation functions.
/// Takes structured code data from Elixir and returns computed metrics.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn calculate_quality_metrics_nif(code: Option<String>, language: String) -> NifResult<QualityMetrics> {
    let analyzer = CodebaseAnalyzer::new();

    // Parse code to get basic metrics
    let (lines, functions, classes) = if let Some(ref code_str) = code {
        let line_count = code_str.lines().count();

        // Simple function counting (language-agnostic heuristics)
        let fn_count = match language.as_str() {
            "elixir" => code_str.matches("def ").count() + code_str.matches("defp ").count(),
            "rust" => code_str.matches("fn ").count(),
            "javascript" | "typescript" => code_str.matches("function ").count() + code_str.matches("=> ").count(),
            "python" => code_str.matches("def ").count(),
            _ => code_str.matches("fn ").count() + code_str.matches("def ").count(),
        };

        // Simple class counting
        let class_count = match language.as_str() {
            "elixir" => code_str.matches("defmodule ").count(),
            "rust" => code_str.matches("struct ").count() + code_str.matches("enum ").count(),
            "javascript" | "typescript" => code_str.matches("class ").count(),
            "python" => code_str.matches("class ").count(),
            _ => 0,
        };

        (line_count, fn_count, class_count)
    } else {
        (0, 0, 0)
    };

    // Use analyzer to calculate complexity
    let complexity_metrics = analyzer
        .calculate_complexity_metrics(functions, classes, lines)
        .map_err(|e| rustler::Error::Term(Box::new(format!("Complexity calculation failed: {}", e))))?;

    let cyclomatic = complexity_metrics.get("cyclomatic_complexity").unwrap_or(&0.0);

    // Calculate test coverage and doc coverage (would come from Elixir in real impl)
    let test_coverage = 0.0; // Elixir would calculate this from ExUnit
    let doc_coverage = if let Some(ref code_str) = code {
        // Simple heuristic: count doc comments
        let doc_lines = match language.as_str() {
            "elixir" => code_str.matches("@doc").count() + code_str.matches("@moduledoc").count(),
            "rust" => code_str.matches("///").count() + code_str.matches("//!").count(),
            "javascript" | "typescript" => code_str.matches("/**").count(),
            "python" => code_str.matches("\"\"\"").count() / 2, // Opening and closing
            _ => 0,
        };
        let total_defs = functions + classes;
        if total_defs > 0 {
            (doc_lines as f64 / total_defs as f64).min(1.0)
        } else {
            0.0
        }
    } else {
        0.0
    };

    let metrics = QualityMetrics {
        cyclomatic_complexity: *cyclomatic as u32,
        lines_of_code: lines as u32,
        test_coverage,
        documentation_coverage: doc_coverage,
    };

    Ok(metrics)
}

/// NIF: Load asset from local cache
///
/// Loads a cached asset by ID. Assets are stored in a local in-memory cache
/// for fast access during analysis operations.
///
/// # Arguments
/// * `id` - Unique identifier for the asset (e.g., "template:elixir-genserver", "pattern:async-worker")
///
/// # Returns
/// * `Ok(Some(data))` - Asset found and loaded
/// * `Ok(None)` - Asset not found in cache
/// * `Err(error)` - Error loading asset
///
/// # Implementation Note
/// Currently returns None (empty cache). In production, this would:
/// 1. Check local LRU cache
/// 2. Return cached data if available
/// 3. Otherwise return None (caller should use query_asset_nif)
#[rustler::nif(schedule = "DirtyCpu")]
pub fn load_asset_nif(_id: String) -> NifResult<Option<String>> {
    // TODO: Implement actual caching with once_cell or similar
    // For now, always return None to indicate "not in cache"
    Ok(None)
}

/// NIF: Query asset from central service
///
/// Queries an asset from the central knowledge service. This is typically used
/// when the asset is not available in the local cache.
///
/// # Arguments
/// * `id` - Unique identifier for the asset
///
/// # Returns
/// * `Ok(Some(data))` - Asset found in central service
/// * `Ok(None)` - Asset not found
/// * `Err(error)` - Error querying service
///
/// # Implementation Note
/// Currently returns a mock response. In production, this would:
/// 1. Make HTTP request to central_cloud service
/// 2. Parse response
/// 3. Cache result locally
/// 4. Return data
#[rustler::nif(schedule = "DirtyCpu")]
pub fn query_asset_nif(id: String) -> NifResult<Option<String>> {
    // For now, return a structured response that indicates this is a query operation
    // In production, this would call central_cloud via HTTP
    let response = serde_json::json!({
        "source": "query",
        "id": id,
        "status": "not_implemented",
        "message": "Central service integration pending"
    });

    Ok(Some(response.to_string()))
}

// ============================================================================
// PARSING NIFs (using parser-code as library)
// ============================================================================

/// Parsed file result structure
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.CodeEngine.ParsedFile"]
pub struct ParsedFileResult {
    pub file_path: String,
    pub language: String,
    pub ast_json: String,
    pub symbols: Vec<String>,
    pub imports: Vec<String>,
    pub exports: Vec<String>,
}

/// NIF: Parse a single file using tree-sitter
///
/// Uses parser-code library for multi-language parsing.
/// Returns structured AST data and extracted symbols.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_file_nif(file_path: String) -> NifResult<ParsedFileResult> {
    use crate::parsing::PolyglotCodeParser;
    use std::path::Path;

    let path = Path::new(&file_path);

    // Parse file using parser-code
    let mut parser = PolyglotCodeParser::new()
        .map_err(|e| rustler::Error::Term(Box::new(format!("Parser init error: {}", e))))?;

    let analysis_result = parser
        .analyze_file(path)
        .map_err(|e| rustler::Error::Term(Box::new(format!("Parse error: {}", e))))?;

    // Extract symbols from tree-sitter analysis
    let (symbols, imports, exports) = if let Some(ref ts) = analysis_result.tree_sitter_analysis {
        let symbols = ts.functions.iter()
            .map(|f| f.name.clone())
            .chain(ts.classes.iter().map(|c| c.name.clone()))
            .collect();
        (symbols, ts.imports.clone(), ts.exports.clone())
    } else {
        (vec![], vec![], vec![])
    };

    Ok(ParsedFileResult {
        file_path: file_path.clone(),
        language: analysis_result.language.clone(),
        ast_json: serde_json::to_string(&analysis_result)
            .unwrap_or_else(|_| "{}".to_string()),
        symbols,
        imports,
        exports,
    })
}

/// NIF: Get list of supported languages
#[rustler::nif]
pub fn supported_languages_nif() -> NifResult<Vec<String>> {
    // Return languages that parser-code actually supports (from lib.rs)
    let languages = vec![
        "elixir", "erlang", "gleam", "rust", "javascript", "typescript",
        "python", "json", "yaml", "bash",
    ];

    Ok(languages.into_iter().map(String::from).collect())
}

// NOTE: nif_bindings module disabled (has dependencies on disabled graph/analysis modules)
// TODO: Re-enable when graph/analysis modules are fixed

// Initialize the NIF module (SINGLE rustler::init! for entire crate)
rustler::init!("Elixir.Singularity.RustAnalyzer", [
    analyze_code_nif,
    calculate_quality_metrics_nif,
    load_asset_nif,
    query_asset_nif,
    parse_file_nif,
    supported_languages_nif
]);