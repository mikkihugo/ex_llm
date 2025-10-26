//! Main Codebase Analyzer
//!
//! Orchestrates multi-language code analysis by coordinating:
//! - LanguageAnalyzer: Semantic tokenization & complexity/quality metrics
//! - LanguageSpecificRulesAnalyzer: Language-specific style & best practice rules
//! - CrossLanguagePatternDetector: Polyglot pattern detection
//! - CodeGraphBuilder: Call graph and import graph analysis
//!
//! Pure computation layer (no storage, no sessions, no caching).
//! All data passed via parameters, all results returned to caller.


use anyhow::Result;

use crate::analysis::multilang::{
  LanguageAnalyzer, LanguageSpecificRulesAnalyzer, CrossLanguageCodePatternsDetector,
  LanguageAnalysis, RuleViolation, CrossLanguageCodePattern,
};
use crate::analysis::graph::CodeGraphBuilder;
use crate::analysis::semantic::search_index::CodeMetadata;

// Import parser types
use parser_core::{AnalysisResult, FunctionInfo, ClassInfo, RcaMetrics};

/// Main codebase analyzer that orchestrates all analysis systems
///
/// **Pure Analysis Library** - No cross-project caching, no sessions, no engine state.
/// Those belong in sparc-engine orchestration layer.
///
/// ## Multi-Language Analysis Capabilities
///
/// This analyzer integrates all multilang analysis modules to provide comprehensive
/// polyglot codebase understanding:
///
/// ### 1. Language Registry Integration
/// Uses centralized `parser_core::language_registry::LanguageRegistry` to:
/// - Detect language families (BEAM, Systems, Web, Scripting)
/// - Track tool support (AST-Grep, RCA analysis capabilities)
/// - Enable flexible language name matching (ID, alias, extension)
/// - Automatically scale to new languages without code changes
///
/// ### 2. Language-Specific Analysis
/// - `analyze_language()` - Semantic tokenization with complexity/quality metrics
/// - `check_language_rules()` - Family-based coding rules (snake_case, PascalCase, etc.)
/// - `supported_languages()` - List all 18+ supported languages
/// - `languages_by_family()` - Group languages by family
/// - `is_language_supported()` - Check language support
///
/// ### 3. Cross-Language Pattern Detection
/// - `detect_cross_language_patterns()` - 8 pattern types:
///   - API Integration (REST/HTTP: reqwest, requests, fetch)
///   - Error Handling (try/catch vs Result/Option)
///   - Logging (log::, logging., console., etc.)
///   - Messaging (NATS, Kafka, RabbitMQ)
///   - Testing, Configuration, Data Flow, Async patterns
/// - Confidence scoring (0.0-1.0) for all detections
/// - Language-aware pattern detection strategies
///
/// ### 4. Code Structure Analysis
/// - `build_call_graph()` - Function call dependencies using import analysis
/// - `build_import_graph()` - Module dependency structure
/// - Call edge detection with confidence scoring
/// - Circular dependency detection
///
/// ### 5. Parser Integration Points
/// Uses singularity-code-analysis + parser_core to provide metrics for each language:
/// - **Complexity (CC)**: Cyclomatic complexity from control flow
/// - **Line Metrics**: SLOC, PLOC, LLOC, CLOC, BLANK
/// - **Function Analysis**: NOM (number of methods), NARGS (arguments), NEXITS (exit points)
/// - **Maintainability (MI)**: Composite score for code quality
/// - **Halstead Metrics**: Effort, vocabulary, time to implement
///
/// These metrics can enhance call graph edge weighting and complexity scoring.
///
/// ## Design Pattern: Pure Computation
///
/// - All analysis is stateless and deterministic
/// - No cross-project caching or session state
/// - All data passed via parameters
/// - All results returned to caller
/// - External data stored in Elixir (PostgreSQL) via NATS
pub struct CodebaseAnalyzer;

impl CodebaseAnalyzer {
  /// Create a new codebase analyzer (pure computation, no storage)
  pub fn new() -> Result<Self> {
    // Pure computation - no storage needed
    // Data is passed in via NIF parameters
    // Language registry and parser_core accessed as library, not as owned state
    Ok(Self)
  }


  // ===========================
  // Multi-Language Analysis Methods
  // ===========================

  /// Analyze a single language file using language registry awareness
  ///
  /// Uses the centralized language registry to:
  /// - Detect language capabilities (AST-Grep, RCA support)
  /// - Perform semantic tokenization
  /// - Calculate complexity and quality scores
  /// - Extract common patterns
  ///
  /// # Arguments
  /// * `code` - Source code to analyze
  /// * `language_hint` - Language ID, alias, or file extension
  ///
  /// # Returns
  /// Complete language analysis with registry-derived metadata
  pub fn analyze_language(&self, code: &str, language_hint: &str) -> Option<LanguageAnalysis> {
    let analyzer = LanguageAnalyzer::new();
    analyzer.analyze_language(code, language_hint)
  }

  /// Check code against language-specific rules and best practices
  ///
  /// Applies family-based rules that automatically adapt to the language:
  /// - BEAM languages: snake_case naming, module organization
  /// - Systems languages: PascalCase types, Result<T>/Option<T> patterns
  /// - Web languages: camelCase naming, async/await patterns
  /// - Scripting languages: snake_case, type hints
  ///
  /// # Arguments
  /// * `code` - Source code to check
  /// * `language_hint` - Language ID, alias, or file extension
  ///
  /// # Returns
  /// Vector of rule violations (empty if code is compliant)
  pub fn check_language_rules(&self, code: &str, language_hint: &str) -> Vec<RuleViolation> {
    let rule_analyzer = LanguageSpecificRulesAnalyzer::new();
    let tokenizer = crate::analysis::semantic::custom_tokenizers::SemanticTokenizer::new(language_hint);
    let tokens = tokenizer.tokenize(code).unwrap_or_default();
    rule_analyzer.analyze_rules(code, language_hint, &tokens)
  }

  /// Detect cross-language patterns in polyglot codebases
  ///
  /// Analyzes multiple files to find patterns that span language boundaries:
  /// - API Integration: REST/HTTP patterns (reqwest, requests, fetch)
  /// - Error Handling: try/catch vs Result/Option patterns
  /// - Logging: Structured logging across languages
  /// - Messaging: NATS, Kafka, or queue patterns
  /// - Testing: Common test patterns across boundaries
  ///
  /// # Arguments
  /// * `files` - Vector of (language_hint, code) tuples
  ///
  /// # Returns
  /// Detected cross-language patterns with confidence scores
  pub fn detect_cross_language_patterns(&self, files: &[(String, String)]) -> Vec<CrossLanguageCodePattern> {
    let detector = CrossLanguageCodePatternsDetector::new();

    // Convert to token sequences using semantic tokenizers
    let tokens_by_file: Vec<Vec<crate::analysis::semantic::custom_tokenizers::DataToken>> = files
      .iter()
      .map(|(hint, code)| {
        let tokenizer = crate::analysis::semantic::custom_tokenizers::SemanticTokenizer::new(hint);
        tokenizer.tokenize(code).unwrap_or_default()
      })
      .collect();

    detector.detect_patterns(files, &tokens_by_file)
  }

  /// Analyze language support in the codebase
  ///
  /// Returns information about all supported languages:
  /// - Language IDs and names
  /// - Language families (BEAM, Systems, Web, etc.)
  /// - Tool support (RCA, AST-Grep)
  /// - Aliases for flexible matching
  ///
  /// # Returns
  /// List of all supported language IDs
  pub fn supported_languages(&self) -> Vec<String> {
    let analyzer = LanguageAnalyzer::new();
    analyzer.supported_languages()
  }

  /// Get languages grouped by family
  ///
  /// Useful for understanding language relationships and
  /// determining which family-level rules apply.
  ///
  /// # Arguments
  /// * `family` - Language family (e.g., "BEAM", "Systems", "Web")
  ///
  /// # Returns
  /// Language IDs belonging to the specified family
  pub fn languages_by_family(&self, family: &str) -> Vec<String> {
    let analyzer = LanguageAnalyzer::new();
    analyzer.languages_by_family(family)
  }

  /// Check if a language is supported by the analysis system
  ///
  /// # Arguments
  /// * `language_id` - Language ID, alias, or file extension
  ///
  /// # Returns
  /// True if language is recognized and supported
  pub fn is_language_supported(&self, language_id: &str) -> bool {
    let analyzer = LanguageAnalyzer::new();
    analyzer.is_supported(language_id)
  }

  /// Build and analyze call graphs from code metadata
  ///
  /// Creates a directed graph of function calls with:
  /// - Import-based call edge detection
  /// - Function dependency analysis
  /// - Call graph traversal APIs
  ///
  /// # Arguments
  /// * `working_directory` - The working directory for the project
  /// * `metadata_cache` - HashMap of code metadata (file path -> metadata)
  ///
  /// # Returns
  /// Built call graph ready for analysis
  pub async fn build_call_graph(
    &self,
    working_directory: std::path::PathBuf,
    metadata_cache: &std::collections::HashMap<std::path::PathBuf, CodeMetadata>
  ) -> Result<crate::analysis::graph::code_graph::CodeGraph, String> {
    let graph_builder = CodeGraphBuilder::new(working_directory);
    graph_builder.build_call_graph(metadata_cache)
      .await
      .map_err(|e| format!("Failed to build call graph: {}", e))
  }

  /// Build import graph from code dependencies
  ///
  /// Creates a directed graph showing module/file imports:
  /// - Import relationships between files
  /// - Circular dependency detection
  /// - Module structure visualization
  ///
  /// # Arguments
  /// * `working_directory` - The working directory for the project
  /// * `metadata_cache` - HashMap of code metadata (file path -> metadata)
  ///
  /// # Returns
  /// Built import graph
  pub async fn build_import_graph(
    &self,
    working_directory: std::path::PathBuf,
    metadata_cache: &std::collections::HashMap<std::path::PathBuf, CodeMetadata>
  ) -> Result<crate::analysis::graph::code_graph::CodeGraph, String> {
    let graph_builder = CodeGraphBuilder::new(working_directory);
    graph_builder.build_import_graph(metadata_cache)
      .await
      .map_err(|e| format!("Failed to build import graph: {}", e))
  }

  // ===========================
  // Enhanced Parser Integration Methods
  // ===========================

  /// Analyze multiple files using RCA metrics and batch processing
  ///
  /// Uses parser_core's batch analysis for better performance:
  /// - RCA complexity metrics (Cyclomatic Complexity, Halstead, MI)
  /// - AST extraction (functions, classes, imports, exports)
  /// - Tree-sitter parsing for supported languages
  /// - Dependency analysis for external packages
  ///
  /// # Arguments
  /// * `file_paths` - Vector of file paths to analyze
  ///
  /// # Returns
  /// Vector of analysis results with full parser metrics
  pub fn analyze_files_with_parser(&self, file_paths: &[&std::path::Path]) -> Result<Vec<AnalysisResult>, String> {
    // Create a new parser instance from parser_core
    // Parser is accessed as a library dependency, not owned state
    let mut parser = parser_core::PolyglotCodeParser::new()
      .map_err(|e| format!("Failed to create parser: {}", e))?;

    let mut results = Vec::new();
    for file_path in file_paths {
      match parser.analyze_file(file_path) {
        Ok(analysis) => results.push(analysis),
        Err(e) => return Err(format!("Parser analysis failed for {:?}: {}", file_path, e)),
      }
    }
    Ok(results)
  }

  /// Extract function metadata from code using AST
  ///
  /// Leverages Tree-sitter to extract detailed function information:
  /// - Function signatures with parameter types
  /// - Return types and decorators
  /// - Async and generator functions
  /// - Documentation/docstrings
  /// - Line ranges and complexity
  ///
  /// # Arguments
  /// * `code` - Source code to analyze
  /// * `language_hint` - Language ID or file extension
  ///
  /// # Returns
  /// Vector of function metadata extracted from AST
  pub fn extract_functions(&self, code: &str, language_hint: &str) -> Result<Vec<FunctionInfo>, String> {
    // Uses tree-sitter directly via parser_core
    use std::io::Write;

    // Use language hint to determine file extension for parser
    let extension = parser_core::language_registry::get_language(language_hint)
      .or_else(|| parser_core::language_registry::get_language_by_alias(language_hint))
      .and_then(|lang| lang.extensions.first().cloned())
      .unwrap_or_else(|| "txt".to_string());

    // Write to temp file with appropriate extension
    let mut temp_file = tempfile::Builder::new()
      .suffix(&format!(".{}", extension))
      .tempfile()
      .map_err(|e| format!("Failed to create temp file: {}", e))?;
    temp_file.write_all(code.as_bytes())
      .map_err(|e| format!("Failed to write temp file: {}", e))?;

    let mut parser = parser_core::PolyglotCodeParser::new()
      .map_err(|e| format!("Failed to create parser: {}", e))?;
    match parser.analyze_file(temp_file.path()) {
      Ok(result) => {
        if let Some(ast) = result.tree_sitter_analysis {
          Ok(ast.functions)
        } else {
          Ok(Vec::new())
        }
      }
      Err(e) => Err(format!("AST extraction failed: {}", e)),
    }
  }

  /// Extract class/struct metadata from code using AST
  ///
  /// Leverages Tree-sitter to extract class information:
  /// - Class/struct names and hierarchy
  /// - Methods and fields
  /// - Visibility and modifiers
  /// - Line ranges
  ///
  /// # Arguments
  /// * `code` - Source code to analyze
  /// * `language_hint` - Language ID or file extension
  ///
  /// # Returns
  /// Vector of class metadata extracted from AST
  pub fn extract_classes(&self, code: &str, language_hint: &str) -> Result<Vec<ClassInfo>, String> {
    use std::io::Write;

    // Use language hint to determine file extension for parser
    let extension = parser_core::language_registry::get_language(language_hint)
      .or_else(|| parser_core::language_registry::get_language_by_alias(language_hint))
      .and_then(|lang| lang.extensions.first().cloned())
      .unwrap_or_else(|| "txt".to_string());

    // Write to temp file with appropriate extension
    let mut temp_file = tempfile::Builder::new()
      .suffix(&format!(".{}", extension))
      .tempfile()
      .map_err(|e| format!("Failed to create temp file: {}", e))?;
    temp_file.write_all(code.as_bytes())
      .map_err(|e| format!("Failed to write temp file: {}", e))?;

    let mut parser = parser_core::PolyglotCodeParser::new()
      .map_err(|e| format!("Failed to create parser: {}", e))?;
    match parser.analyze_file(temp_file.path()) {
      Ok(result) => {
        if let Some(ast) = result.tree_sitter_analysis {
          Ok(ast.classes)
        } else {
          Ok(Vec::new())
        }
      }
      Err(e) => Err(format!("Class extraction failed: {}", e)),
    }
  }

  /// Get RCA (Rust Code Analysis) metrics for code
  ///
  /// Extracts detailed code quality metrics:
  /// - Cyclomatic Complexity (CC)
  /// - Halstead metrics (effort, vocabulary, bugs)
  /// - Maintainability Index (MI)
  /// - Line metrics (SLOC, PLOC, LLOC, CLOC, BLANK)
  ///
  /// # Arguments
  /// * `code` - Source code to analyze
  /// * `language_hint` - Language ID or file extension
  ///
  /// # Returns
  /// RCA metrics for the code
  pub fn get_rca_metrics(&self, code: &str, language_hint: &str) -> Result<RcaMetrics, String> {
    use std::io::Write;

    // Use language hint to determine file extension for parser
    let extension = parser_core::language_registry::get_language(language_hint)
      .or_else(|| parser_core::language_registry::get_language_by_alias(language_hint))
      .and_then(|lang| lang.extensions.first().cloned())
      .unwrap_or_else(|| "txt".to_string());

    // Write to temp file with appropriate extension
    let mut temp_file = tempfile::Builder::new()
      .suffix(&format!(".{}", extension))
      .tempfile()
      .map_err(|e| format!("Failed to create temp file: {}", e))?;
    temp_file.write_all(code.as_bytes())
      .map_err(|e| format!("Failed to write temp file: {}", e))?;

    let mut parser = parser_core::PolyglotCodeParser::new()
      .map_err(|e| format!("Failed to create parser: {}", e))?;
    match parser.analyze_file(temp_file.path()) {
      Ok(result) => {
        if let Some(rca) = result.rca_metrics {
          Ok(rca)
        } else {
          Ok(RcaMetrics::default())
        }
      }
      Err(e) => Err(format!("RCA metrics extraction failed: {}", e)),
    }
  }

  /// Extract imports and exports from code
  ///
  /// Uses AST to detect module dependencies:
  /// - Import statements
  /// - Export declarations
  /// - Dependency relationships
  /// - Cross-file references
  ///
  /// # Arguments
  /// * `code` - Source code to analyze
  /// * `language_hint` - Language ID or file extension
  ///
  /// # Returns
  /// Tuple of (imports, exports)
  pub fn extract_imports_exports(&self, code: &str, language_hint: &str) -> Result<(Vec<String>, Vec<String>), String> {
    use std::io::Write;

    // Use language hint to determine file extension for parser
    let extension = parser_core::language_registry::get_language(language_hint)
      .or_else(|| parser_core::language_registry::get_language_by_alias(language_hint))
      .and_then(|lang| lang.extensions.first().cloned())
      .unwrap_or_else(|| "txt".to_string());

    // Write to temp file with appropriate extension
    let mut temp_file = tempfile::Builder::new()
      .suffix(&format!(".{}", extension))
      .tempfile()
      .map_err(|e| format!("Failed to create temp file: {}", e))?;
    temp_file.write_all(code.as_bytes())
      .map_err(|e| format!("Failed to write temp file: {}", e))?;

    let mut parser = parser_core::PolyglotCodeParser::new()
      .map_err(|e| format!("Failed to create parser: {}", e))?;
    match parser.analyze_file(temp_file.path()) {
      Ok(result) => {
        if let Some(ast) = result.tree_sitter_analysis {
          Ok((ast.imports, ast.exports))
        } else {
          Ok((Vec::new(), Vec::new()))
        }
      }
      Err(e) => Err(format!("Import/export extraction failed: {}", e)),
    }
  }

  /// Get RCA-supported languages for metrics analysis
  ///
  /// Returns languages where RCA metrics are available.
  /// Use this to determine if complexity metrics can be computed.
  ///
  /// # Returns
  /// List of language IDs with RCA support
  pub fn rca_supported_languages(&self) -> Vec<String> {
    use parser_core::language_registry::rca_supported_languages;
    rca_supported_languages()
      .iter()
      .map(|lang| lang.id.clone())
      .collect()
  }

  /// Get AST-Grep supported languages for pattern matching
  ///
  /// Returns languages where AST-Grep pattern matching is available.
  /// Use this for structural code analysis.
  ///
  /// # Returns
  /// List of language IDs with AST-Grep support
  pub fn ast_grep_supported_languages(&self) -> Vec<String> {
    use parser_core::language_registry::ast_grep_supported_languages;
    ast_grep_supported_languages()
      .iter()
      .map(|lang| lang.id.clone())
      .collect()
  }

  /// Check if language supports RCA metrics
  ///
  /// # Arguments
  /// * `language_id` - Language to check
  ///
  /// # Returns
  /// True if RCA metrics are available for this language
  pub fn has_rca_support(&self, language_id: &str) -> bool {
    if let Some(lang) = parser_core::language_registry::get_language(language_id)
      .or_else(|| parser_core::language_registry::get_language_by_alias(language_id))
    {
      lang.rca_supported
    } else {
      false
    }
  }

  /// Check if language supports AST-Grep analysis
  ///
  /// # Arguments
  /// * `language_id` - Language to check
  ///
  /// # Returns
  /// True if AST-Grep analysis is available for this language
  pub fn has_ast_grep_support(&self, language_id: &str) -> bool {
    if let Some(lang) = parser_core::language_registry::get_language(language_id)
      .or_else(|| parser_core::language_registry::get_language_by_alias(language_id))
    {
      lang.ast_grep_supported
    } else {
      false
    }
  }
}
