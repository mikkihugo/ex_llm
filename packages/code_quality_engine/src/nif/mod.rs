//! NIF bindings for Elixir integration
//!
//! This module provides NIF-based integration between the Rust analysis-suite and Elixir.
//! It contains pure computation functions that can be called directly from Elixir.

use crate::analysis::multilang::{LanguageRuleType, RuleViolation};
use crate::analyzer::CodebaseAnalyzer;
use rustler::{Error, NifResult};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::Path;

/// Code analysis result structure
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.CodeAnalyzer.CodeAnalysisResult"]
pub struct CodeAnalysisResult {
    pub complexity_score: f64,
    pub maintainability_score: f64,
    pub security_issues: Vec<String>,
    pub performance_issues: Vec<String>,
    pub refactoring_suggestions: Vec<String>,
}

/// Quality metrics structure
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.CodeAnalyzer.QualityMetrics"]
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

fn map_extension_to_language(ext: &str) -> Option<&'static str> {
    match ext {
        "ex" | "exs" => Some("elixir"),
        "erl" => Some("erlang"),
        "gleam" => Some("gleam"),
        "rs" => Some("rust"),
        "ts" | "tsx" => Some("typescript"),
        "js" | "jsx" => Some("javascript"),
        "py" => Some("python"),
        "go" => Some("go"),
        "java" => Some("java"),
        "cpp" | "cc" | "cxx" => Some("cpp"),
        "c" => Some("c"),
        "cs" => Some("csharp"),
        "rb" => Some("ruby"),
        "php" => Some("php"),
        "swift" => Some("swift"),
        "kt" => Some("kotlin"),
        "scala" => Some("scala"),
        "json" => Some("json"),
        "yaml" | "yml" => Some("yaml"),
        "toml" => Some("toml"),
        "xml" => Some("xml"),
        "html" | "htm" => Some("html"),
        "css" => Some("css"),
        "sh" | "bash" => Some("bash"),
        "sql" => Some("sql"),
        "md" | "markdown" => Some("markdown"),
        "dockerfile" => Some("dockerfile"),
        _ => None,
    }
}

fn load_code_input(code_or_path: &str) -> std::io::Result<String> {
    let candidate = Path::new(code_or_path);
    if candidate.exists() && candidate.is_file() {
        fs::read_to_string(candidate)
    } else {
        Ok(code_or_path.to_string())
    }
}

fn dedup_preserve_order(messages: Vec<String>) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut deduped = Vec::with_capacity(messages.len());
    for message in messages {
        if seen.insert(message.clone()) {
            deduped.push(message);
        }
    }
    deduped
}

fn format_violation_message(violation: &RuleViolation) -> String {
    let severity = format!("{:?}", violation.rule.severity);
    match &violation.rule.suggested_fix {
        Some(fix) if !fix.is_empty() => format!(
            "{} [{}] at {}: {} — fix: {}",
            violation.rule.name, severity, violation.location, violation.details, fix
        ),
        _ => format!(
            "{} [{}] at {}: {}",
            violation.rule.name, severity, violation.location, violation.details
        ),
    }
}

fn classify_rule_violations(
    violations: &[RuleViolation],
) -> (Vec<String>, Vec<String>, Vec<String>) {
    let mut security = Vec::new();
    let mut performance = Vec::new();
    let mut refactoring = Vec::new();

    for violation in violations {
        let message = format_violation_message(violation);
        match violation.rule.rule_type {
            LanguageRuleType::SecurityRule => security.push(message.clone()),
            LanguageRuleType::PerformanceRule => performance.push(message.clone()),
            _ => {}
        }
        refactoring.push(message);
    }

    (
        dedup_preserve_order(security),
        dedup_preserve_order(performance),
        dedup_preserve_order(refactoring),
    )
}

/// NIF: Analyze code using existing analysis-suite (pure computation)
///
/// This performs code analysis on structured data passed from Elixir.
/// Note: `codebase_path` is for reference only - actual code data comes from Elixir.
/// Elixir reads files and passes the structured data to Rust for analysis.
///
/// Returns structured analysis results that Elixir can use.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn analyze_code_nif(
    code_or_path: String,
    language_hint: String,
) -> NifResult<CodeAnalysisResult> {
    let analyzer = CodebaseAnalyzer::new()
        .map_err(|e| Error::Term(Box::new(format!("Failed to create analyzer: {e}"))))?;

    let code = load_code_input(&code_or_path)
        .map_err(|e| Error::Term(Box::new(format!("Failed to load code input: {e}"))))?;

    let mut effective_language = language_hint.trim().to_string();
    if effective_language.is_empty() {
        if let Some(ext) = Path::new(&code_or_path)
            .extension()
            .and_then(|ext| ext.to_str())
        {
            if let Some(mapped) = map_extension_to_language(&ext.to_lowercase()) {
                effective_language = mapped.to_string();
            }
        }
    }

    if effective_language.is_empty() {
        return Err(Error::Term(Box::new(
            "Language hint required for legacy analyze_code_nif/2",
        )));
    }

    if !analyzer.is_language_supported(&effective_language) {
        return Err(Error::Term(Box::new(format!(
            "Unsupported language: {effective_language}"
        ))));
    }

    let language_analysis = analyzer
        .analyze_language(&code, &effective_language)
        .ok_or_else(|| {
            Error::Term(Box::new(format!(
                "Failed to analyze language: {effective_language}"
            )))
        })?;

    let rule_violations = analyzer.check_language_rules(&code, &effective_language);
    let (mut security_issues, mut performance_issues, mut refactoring_suggestions) =
        classify_rule_violations(&rule_violations);

    if language_analysis.complexity_score > 0.75 {
        refactoring_suggestions.push(format!(
            "Complexity score {:.2} is high; split large functions or reduce branching.",
            language_analysis.complexity_score
        ));
    }

    if language_analysis.quality_score < 0.65 {
        refactoring_suggestions.push(format!(
            "Quality score {:.2} suggests maintainability risk; increase tests/documentation.",
            language_analysis.quality_score
        ));
    }

    if security_issues.is_empty() {
        match language_analysis.language_id.as_str() {
            "rust" => security_issues
                .push("Validate unsafe blocks and document safety invariants.".to_string()),
            "javascript" | "typescript" => security_issues
                .push("Ensure user inputs are validated and avoid dynamic eval usage.".to_string()),
            "python" => security_issues.push(
                "Validate inputs and guard against SQL injection or unsafe deserialization."
                    .to_string(),
            ),
            "elixir" => security_issues
                .push("Use pattern matching and guards to validate external inputs.".to_string()),
            _ => {}
        }
    }

    if performance_issues.is_empty() && language_analysis.total_lines > 500 {
        performance_issues.push(format!(
            "File has {} lines; consider extracting modules to keep compilation fast.",
            language_analysis.total_lines
        ));
    }

    let mut maintainability_score = language_analysis.quality_score;
    if analyzer.has_rca_support(&language_analysis.language_id) {
        if let Ok(rca) = analyzer.get_rca_metrics(&code, &language_analysis.language_id) {
            if let Ok(mi) = rca.maintainability_index.parse::<f64>() {
                if mi > 0.0 {
                    maintainability_score = (mi / 100.0).clamp(0.0, 1.0);
                }
            }

            if let Ok(cc) = rca.cyclomatic_complexity.parse::<f64>() {
                if cc > 15.0 {
                    performance_issues.push(format!(
                        "Cyclomatic complexity {:.1} exceeds recommended threshold; refactor to reduce branching.",
                        cc
                    ));
                }
            }
        }
    }

    if performance_issues.is_empty() {
        performance_issues.push(format!(
            "Profile {} hotspots to confirm there are no bottlenecks.",
            language_analysis.language_name
        ));
    }

    if refactoring_suggestions.is_empty() {
        refactoring_suggestions.push(
            "Consider extracting reusable helpers and adding module-level documentation."
                .to_string(),
        );
    }

    let analysis = CodeAnalysisResult {
        complexity_score: language_analysis.complexity_score,
        maintainability_score,
        security_issues: dedup_preserve_order(security_issues),
        performance_issues: dedup_preserve_order(performance_issues),
        refactoring_suggestions: dedup_preserve_order(refactoring_suggestions),
    };

    Ok(analysis)
}

/// NIF: Calculate quality metrics (pure computation)
///
/// Calculates quality metrics using the CodebaseAnalyzer pure computation functions.
/// Takes structured code data from Elixir and returns computed metrics.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn calculate_quality_metrics_nif(
    code: Option<String>,
    language: String,
) -> NifResult<QualityMetrics> {
    let analyzer = CodebaseAnalyzer::new()
        .map_err(|e| Error::Term(Box::new(format!("Failed to create analyzer: {e}"))))?;

    let code_str = code.unwrap_or_default();

    let line_count = code_str.lines().count();
    let function_count = match language.as_str() {
        "elixir" => code_str.matches("def ").count() + code_str.matches("defp ").count(),
        "rust" => code_str.matches("fn ").count(),
        "javascript" | "typescript" => {
            code_str.matches("function ").count() + code_str.matches("=> ").count()
        }
        "python" => code_str.matches("def ").count(),
        "go" => code_str.matches("func ").count(),
        "java" | "csharp" => {
            code_str.matches(" void ").count() + code_str.matches(" class ").count()
        }
        _ => code_str.matches("fn ").count() + code_str.matches("def ").count(),
    };

    let class_count = match language.as_str() {
        "elixir" => code_str.matches("defmodule ").count(),
        "rust" => code_str.matches("struct ").count() + code_str.matches("enum ").count(),
        "javascript" | "typescript" => code_str.matches("class ").count(),
        "python" => code_str.matches("class ").count(),
        "java" | "csharp" => code_str.matches("class ").count(),
        _ => 0,
    };

    let complexity_metrics = analyzer
        .calculate_complexity_metrics(function_count, class_count, line_count)
        .map_err(|e| Error::Term(Box::new(format!("Complexity calculation failed: {e}"))))?;

    let mut cyclomatic = *complexity_metrics
        .get("cyclomatic_complexity")
        .unwrap_or(&0.0);
    let mut lines_of_code = line_count as u32;

    if !code_str.is_empty() && analyzer.has_rca_support(&language) {
        if let Ok(rca) = analyzer.get_rca_metrics(&code_str, &language) {
            if let Ok(cc) = rca.cyclomatic_complexity.parse::<f64>() {
                if cc > 0.0 {
                    cyclomatic = cc;
                }
            }
            if rca.source_lines_of_code > 0 {
                lines_of_code = rca.source_lines_of_code as u32;
            }
        }
    }

    let doc_coverage = if code_str.is_empty() {
        0.0
    } else {
        let doc_lines = match language.as_str() {
            "elixir" => code_str.matches("@doc").count() + code_str.matches("@moduledoc").count(),
            "rust" => code_str.matches("///").count() + code_str.matches("//!").count(),
            "javascript" | "typescript" => code_str.matches("/**").count(),
            "python" => code_str.matches("\"\"\"").count() / 2,
            "go" => code_str.matches("///").count(),
            _ => 0,
        };
        let total_defs = function_count + class_count;
        if total_defs > 0 {
            (doc_lines as f64 / total_defs as f64).min(1.0)
        } else {
            0.0
        }
    };

    let metrics = QualityMetrics {
        cyclomatic_complexity: cyclomatic as u32,
        lines_of_code,
        test_coverage: 0.0,
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
#[module = "Singularity.CodeAnalyzer.ParsedFile"]
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
        let symbols = ts
            .functions
            .iter()
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
        ast_json: serde_json::to_string(&analysis_result).unwrap_or_else(|_| "{}".to_string()),
        symbols,
        imports,
        exports,
    })
}

/// NIF: Get list of supported languages
#[rustler::nif]
pub fn supported_languages() -> NifResult<Vec<String>> {
    match CodebaseAnalyzer::new() {
        Ok(analyzer) => Ok(analyzer.supported_languages()),
        Err(e) => Err(Error::Term(Box::new(format!(
            "Failed to create analyzer: {e}"
        )))),
    }
}

#[rustler::nif]
pub fn rca_supported_languages() -> NifResult<Vec<String>> {
    match CodebaseAnalyzer::new() {
        Ok(analyzer) => Ok(analyzer.rca_supported_languages()),
        Err(e) => Err(Error::Term(Box::new(format!(
            "Failed to create analyzer: {e}"
        )))),
    }
}

#[rustler::nif]
pub fn ast_grep_supported_languages() -> NifResult<Vec<String>> {
    match CodebaseAnalyzer::new() {
        Ok(analyzer) => Ok(analyzer.ast_grep_supported_languages()),
        Err(e) => Err(Error::Term(Box::new(format!(
            "Failed to create analyzer: {e}"
        )))),
    }
}

#[rustler::nif]
pub fn has_rca_support(language_id: String) -> bool {
    match CodebaseAnalyzer::new() {
        Ok(analyzer) => analyzer.has_rca_support(&language_id),
        Err(_) => false,
    }
}

#[rustler::nif]
pub fn has_ast_grep_support(language_id: String) -> bool {
    match CodebaseAnalyzer::new() {
        Ok(analyzer) => analyzer.has_ast_grep_support(&language_id),
        Err(_) => false,
    }
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
    let path = Path::new(&file_path);

    // Detect language by file extension using the language registry
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|ext| ext.to_lowercase());

    let mut detection_method = "extension".to_string();
    let (language, confidence) = if let Some(ext) = ext {
        if let Some(lang) = map_extension_to_language(&ext) {
            (lang.to_string(), 0.99)
        } else {
            ("unknown".to_string(), 0.0)
        }
    } else if path
        .file_name()
        .and_then(|name| name.to_str())
        .map(|name| name.eq_ignore_ascii_case("dockerfile"))
        .unwrap_or(false)
    {
        detection_method = "filename".to_string();
        ("dockerfile".to_string(), 0.95)
    } else {
        ("unknown".to_string(), 0.0)
    };

    Ok(LanguageDetectionResult {
        language,
        confidence,
        detection_method,
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
pub fn detect_language_by_manifest_nif(
    manifest_path: String,
) -> NifResult<LanguageDetectionResult> {
    use std::path::Path;

    let path = Path::new(&manifest_path);
    let file_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");

    let (language, confidence, method) = match file_name {
        "Cargo.toml" => ("rust", 0.95, "manifest"),
        "package.json" => {
            // Check for tsconfig.json to distinguish TypeScript from JavaScript
            if path
                .parent()
                .map(|p| p.join("tsconfig.json").exists())
                .unwrap_or(false)
            {
                ("typescript", 0.95, "manifest+tsconfig")
            } else {
                ("javascript", 0.90, "manifest")
            }
        }
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
// NOTE: Rustler 0.34+ auto-detects exported functions
//       No need for explicit function list anymore
rustler::init!("Elixir.Singularity.CodeAnalyzer.Native");
