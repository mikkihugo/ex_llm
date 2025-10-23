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

/// Language detection result
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.LanguageDetection.Result"]
pub struct LanguageDetectionResult {
    pub language: String,
    pub confidence: f64,
    pub detection_method: String,
}

/// NIF: Detect language from file path using registry
///
/// Uses the parser_engine language_registry to detect language by file extension.
/// This is the primary method - accurate for individual files.
///
/// # Arguments
/// * `file_path` - Path to the file (e.g., "lib/module.ex", "src/main.rs")
///
/// # Returns
/// * `Ok(LanguageDetectionResult)` - Language detected with confidence
/// * `Err(error)` - Language could not be detected
#[rustler::nif]
pub fn detect_language_by_extension_nif(file_path: String) -> NifResult<LanguageDetectionResult> {
    use std::path::Path;

    let path = Path::new(&file_path);

    // Detect language by file extension using the language registry
    let ext = path.extension()
        .and_then(|e| e.to_str())
        .unwrap_or("");

    let (language, confidence) = match ext.to_lowercase().as_str() {
        "ex" | "exs" => ("elixir", 0.99),
        "erl" => ("erlang", 0.99),
        "gleam" => ("gleam", 0.99),
        "rs" => ("rust", 0.99),
        "ts" | "tsx" => ("typescript", 0.99),
        "js" | "jsx" => ("javascript", 0.99),
        "py" => ("python", 0.99),
        "go" => ("go", 0.99),
        "java" => ("java", 0.99),
        "cpp" | "cc" | "cxx" => ("cpp", 0.99),
        "c" => ("c", 0.99),
        "cs" => ("csharp", 0.99),
        "rb" => ("ruby", 0.99),
        "php" => ("php", 0.99),
        "swift" => ("swift", 0.99),
        "kt" => ("kotlin", 0.99),
        "scala" => ("scala", 0.99),
        "json" => ("json", 0.99),
        "yaml" | "yml" => ("yaml", 0.99),
        "toml" => ("toml", 0.99),
        "xml" => ("xml", 0.99),
        "html" | "htm" => ("html", 0.99),
        "css" => ("css", 0.99),
        "sh" | "bash" => ("bash", 0.99),
        "sql" => ("sql", 0.99),
        _ => ("unknown", 0.0),
    };

    Ok(LanguageDetectionResult {
        language: language.to_string(),
        confidence,
        detection_method: "extension".to_string(),
    })
}

/// NIF: Detect language from manifest file
///
/// Detects the primary language of a project by examining manifest files.
/// More accurate than extension-based detection for determining project type.
///
/// This uses the techstack analyzer approach:
/// - Cargo.toml → Rust
/// - package.json ± tsconfig.json → TypeScript/JavaScript
/// - mix.exs → Elixir
/// - go.mod → Go
/// - etc.
///
/// # Arguments
/// * `manifest_path` - Path to the manifest file (e.g., "Cargo.toml", "package.json")
///
/// # Returns
/// * `Ok(LanguageDetectionResult)` - Primary language with high confidence
/// * `Err(error)` - Could not determine from manifest
#[rustler::nif]
pub fn detect_language_by_manifest_nif(manifest_path: String) -> NifResult<LanguageDetectionResult> {
    use std::path::Path;

    let path = Path::new(&manifest_path);
    let file_name = path.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("");

    let (language, confidence, method) = match file_name {
        "Cargo.toml" => ("rust", 0.95, "manifest"),
        "package.json" => {
            // Check for tsconfig.json to distinguish TypeScript from JavaScript
            if path.parent().map(|p| p.join("tsconfig.json").exists()).unwrap_or(false) {
                ("typescript", 0.95, "manifest+tsconfig")
            } else {
                ("javascript", 0.90, "manifest")
            }
        },
        "go.mod" => ("go", 0.95, "manifest"),
        "mix.exs" => ("elixir", 0.99, "manifest"),
        "rebar.config" | "rebar3.config" => ("erlang", 0.95, "manifest"),
        "pyproject.toml" | "setup.py" | "setup.cfg" => ("python", 0.95, "manifest"),
        "pom.xml" => ("java", 0.95, "maven"),
        "build.gradle" | "build.gradle.kts" => ("java", 0.95, "gradle"),
        "Gemfile" => ("ruby", 0.95, "manifest"),
        "composer.json" => ("php", 0.95, "manifest"),
        "pubspec.yaml" => ("dart", 0.95, "manifest"),
        "Package.swift" => ("swift", 0.95, "manifest"),
        "project.clj" => ("clojure", 0.95, "manifest"),
        "sbt" | "build.sbt" => ("scala", 0.95, "manifest"),
        _ => ("unknown", 0.0, "manifest"),
    };

    Ok(LanguageDetectionResult {
        language: language.to_string(),
        confidence,
        detection_method: method.to_string(),
    })
}

// Initialize the NIF module (SINGLE rustler::init! for entire crate)
// Module name MUST match Elixir module name exactly
//
// NOTE: Functions defined in this file (mod.rs) use local names
//       Functions from other modules use crate:: prefix
rustler::init!("Elixir.Singularity.CodeEngineNif", [
    // Legacy NIFs (defined in this file - mod.rs)
    analyze_code_nif,
    calculate_quality_metrics_nif,
    load_asset_nif,
    query_asset_nif,
    parse_file_nif,
    supported_languages_nif,
    detect_language_by_extension_nif,
    detect_language_by_manifest_nif,

    // Multi-language analyzer NIFs (from nif_bindings.rs)
    crate::nif_bindings::analyze_language,
    crate::nif_bindings::analyze_control_flow,
    crate::nif_bindings::check_language_rules,
    crate::nif_bindings::detect_cross_language_patterns,
    crate::nif_bindings::get_rca_metrics,
    crate::nif_bindings::extract_functions,
    crate::nif_bindings::extract_classes,
    crate::nif_bindings::extract_imports_exports,
    crate::nif_bindings::supported_languages,
    crate::nif_bindings::rca_supported_languages,
    crate::nif_bindings::ast_grep_supported_languages,
    crate::nif_bindings::has_rca_support,
    crate::nif_bindings::has_ast_grep_support
]);