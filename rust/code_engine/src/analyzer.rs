//! Main Codebase Analyzer
//!
//! This module provides the main orchestrator that coordinates all
//! codebase analysis systems. It uses the storage layer for data
//! and the analysis layer for logic.

// Import core types from main sparc-engine crate
// Circular dependency - temporarily stubbed until sparc-engine integration
// use sparc_engine::{
//     graph::vector_dag::VectorDAG,
//     memory::CodeGraph,
//     naming::IntelligentNamer,
// };

// Import real implementations from analysis module
use std::path::Path;

use crate::{
  analysis::{graph::CodeGraph, *},
  storage::{graph::Graph, *},
  types::*,
};

// Temporary placeholder for CodeNamer (will integrate with sparc-engine later)
// Note: Real implementation is in sparc-engine/src/naming/codenamer (renamed to CodeNamer)
#[derive(Debug, Clone)]
pub struct CodeNamer;
impl CodeNamer {
  pub fn new() -> Self {
    Self
  }

  // Delegate to existing intelligent naming system
  pub fn suggest_name(
    &self,
    base_name: &str,
    _element_type: crate::CodeElementType,
    _category: crate::CodeElementCategory,
    _context: &crate::CodeContext,
  ) -> Vec<String> {
    // TODO: Integrate with existing IntelligentNamer system
    // For now, return basic fallback to avoid duplication
    // The real implementation should call the existing intelligent namer
    vec![base_name.to_lowercase().replace('_', "-")]
  }
}


use anyhow::Result;
// use crate::prompt_engine::ProjectTechStackFact;  // DISABLED: prompt_engine in separate crate
use tracing::info;

// NOTE: CodebaseDatabase removed - all storage now in Elixir (PostgreSQL)
// use crate::codebase::CodebaseDatabase;

/// Framework detector - delegates to existing framework detection system
#[derive(Debug, Clone)]
pub struct FrameworkDetector;

impl FrameworkDetector {
  pub fn new() -> Result<Self> {
    Ok(Self)
  }

  /// Detect frameworks using existing framework detection system
  pub fn detect_frameworks(&self, path: &Path) -> Result<Vec<String>> {
    // TODO: Integrate with existing framework detection system
    // For now, return empty to avoid duplication
    // The real implementation should call the existing framework detector
    Ok(Vec::new())
  }
}
impl Default for FrameworkDetector {
  fn default() -> Self {
    Self
  }
}



// Temporary placeholder for IntelligenceEngine (from sparc-engine)
#[derive(Debug, Clone)]
pub struct IntelligenceEngine;
impl Default for IntelligenceEngine {
  fn default() -> Self {
    Self
  }
}

// LibraryAnalysisCache removed - use codebase::storage::CodebaseDatabase instead
// All database functionality moved to codebase module

// External crate dependencies
// parser-coordinator merged into universal-parser/ml_predictions
// DISABLED: These are separate crates, not part of code_engine
// use crate::linting_engine::LintingEngine;
// use crate::prompt_engine::PromptEngine;
// use crate::sparc_methodology::{SPARCProject, ProjectComplexity};
use parser_core::interfaces::PolyglotCodeParser; // Trait for parser methods
use parser_core::{CodeAnalysisEngine, UniversalDependencies, PolyglotCodeParserFrameworkConfig};

/// Main codebase analyzer that orchestrates all analysis systems
///
/// **Pure Analysis Library** - No cross-project caching, no sessions, no engine state
/// Those belong in sparc-engine orchestration layer
pub struct CodebaseAnalyzer {
  // NOTE: storage removed - all data stored in Elixir (PostgreSQL), Rust does pure computation
  // TODO: Remove global_cache - belongs in sparc-engine, not pure analysis
  // /// Global cache manager
  // pub global_cache: GlobalCacheCoordinator,
  // TODO: Remove session_manager - belongs in sparc-engine
  // /// Session manager
  // pub session_manager: SessionCoordinator,
  // TODO: Remove smart_intelligence - belongs in sparc-engine
  // /// Smart intelligence engine
  // pub smart_intelligence: SmartIntelligenceEngine,
  /// Performance tracker
  pub performance_tracker: PerformanceTracker,
  /// Analysis systems
  pub namer: CodeNamer,
  pub metrics_collector: crate::analysis::metrics::MetricsCollector,
  pub pattern_detector: CodePatternDetector,
  pub graph_analyzer: CodeGraph,
  pub dag_analyzer: VectorDAG,

  /// External crate dependencies
  pub code_analysis_engine: CodeAnalysisEngine,
  pub linting_engine: LintingEngine,
  pub universal_parser: UniversalDependencies,
  pub sparc_methodology: SPARCProject,
  pub prompt_engine: PromptEngine,
  /// Framework detection system
  pub framework_detector: FrameworkDetector,
}

impl CodebaseAnalyzer {
  /// Create a new codebase analyzer (pure computation, no storage)
  pub fn new() -> Result<Self> {
    // Pure computation - no storage needed
    // Data is passed in via NIF parameters

    Ok(Self {
      // No storage - pure computation, data passed via parameters
      performance_tracker: PerformanceTracker::new(),
      namer: CodeNamer::new(),
      metrics_collector: crate::analysis::metrics::MetricsCollector::new(),
      pattern_detector: CodePatternDetector::new(),
      graph_analyzer: CodeGraph::new(crate::analysis::graph::code_graph::GraphType::CallGraph),
      dag_analyzer: Graph::new(),

      // External crate dependencies
      code_analysis_engine: CodeAnalysisEngine::new(),
      linting_engine: LintingEngine::new(),
      universal_parser: UniversalDependencies::new()
        .unwrap_or_else(|_| UniversalDependencies::new_with_config(PolyglotCodeParserFrameworkConfig::default()).unwrap()),
      sparc_methodology: SPARCProject::new(
        "default_project".to_string(),
        "Default Project".to_string(),
        "general".to_string(),
        sparc_methodology::ProjectComplexity::Moderate,
      )
      .unwrap_or_else(|_| panic!("Failed to initialize SPARCProject")),
      prompt_engine: PromptEngine::new().unwrap_or_else(|_| {
        // Fallback implementation if prompt engine fails to initialize
        panic!("Failed to initialize PromptEngine - this is required for ML-based analysis")
      }),
      framework_detector: FrameworkDetector::new().unwrap_or_else(|_| FrameworkDetector::default()),
    })
  }

  /// Analyze a project and return comprehensive results
  pub async fn analyze_project(&self, project_path: &Path) -> Result<ProjectAnalysis, String> {
    // 1. Detect frameworks first
    let framework_result = self.detect_frameworks(project_path).await?;

    // 2. Parse and store all files
    let files = self.parse_and_store_files(project_path).await?;

    // 3. Generate naming suggestions (simplified for now)
    let naming = self.generate_naming_suggestions(&files).await?;

    // 4. Combine analysis results with framework information
    Ok(ProjectAnalysis { files, naming, framework_detection: Some(framework_result) })
  }

  /// Detect frameworks in the project using NPM-based detection
  pub async fn detect_frameworks(&self, _project_path: &Path) -> Result<Vec<String>, String> {
    // detect_frameworks is synchronous, not async
    // Return empty vec for now since detector stub returns Vec<String>
    Ok(Vec::new())
  }

  /// Analyze code using the main quality analyzer
  pub async fn analyze_code(&self, code: &str, context: &crate::CodeContext) -> Result<crate::analysis::quality_analyzer::CodeAnalysisResult, String> {
    // TODO: Implement proper code analysis integration
    // For now, return a default result
    Err("Code analysis not yet implemented".to_string())
  }

  /// Get intelligent naming suggestions
  pub fn get_naming_suggestions(&self, base_name: &str, element_type: CodeElementType, category: CodeElementCategory, context: &CodeContext) -> Vec<String> {
    self.namer.suggest_name(base_name, element_type, category, context)
  }

  /// Get performance report
  pub fn get_performance_report(&self) -> PerformanceReport {
    self.performance_tracker.get_performance_report()
  }

  // TODO: Remove global cache methods - belong in sparc-engine orchestration
  // These methods reference global_cache which is engine-specific, not pure analysis
  // Get global cache statistics
  // pub fn get_cache_stats(&self) -> Result<GlobalCacheStats, String> {
  // self.global_cache.get_global_stats().map_err(|e| e.to_string())
  // }
  //
  // Cache library analysis
  // pub fn cache_library_analysis(
  // &self,
  // library_name: &str,
  // version: &str,
  // analysis: LibraryAnalysisCache,
  // ) -> Result<(), String> {
  // self.global_cache.cache_library_analysis(library_name, version, analysis)
  // .map_err(|e| e.to_string())
  // }
  //
  // Get cached library analysis
  // pub fn get_library_analysis(
  // &self,
  // library_name: &str,
  // version: &str,
  // ) -> Result<Option<LibraryAnalysisCache>, String> {
  // self.global_cache.get_library_analysis(library_name, version)
  // .map_err(|e| e.to_string())
  // }

  // /// Analyze code quality
  // pub fn analyze_code_quality(&self, code: &str) -> QualityAnalysis {
  //     self.quality_analyzer.analyze(code)
  // }

  // /// Detect patterns in code
  // pub fn detect_learned_code_patterns(&self, code: &str) -> CodePatternAnalysis {
  //     self.pattern_detector.detect_patterns(code)
  // }

  // /// Collect code metrics
  // pub fn collect_code_metrics(&self, code: &str) -> MetricsAnalysis {
  //     self.metrics_collector.collect(code)
  // }

  // Private helper methods
  async fn parse_and_store_files(&self, project_path: &Path) -> Result<Vec<ParsedFile>, String> {
    use std::fs;

    use parser_core::ProgrammingLanguage;
    use walkdir::WalkDir;

    let mut parsed_files = Vec::new();

    // Walk through all files in the project
    for entry in WalkDir::new(project_path).into_iter().filter_map(|e| e.ok()).filter(|e| e.file_type().is_file()) {
      let file_path = entry.path();
      let file_name = file_path.file_name().and_then(|n| n.to_str()).unwrap_or("unknown");

      // Detect programming language from file extension
      let language = self.detect_language_from_extension(file_path);

      // Skip non-programming files
      if language == ProgrammingLanguage::Unknown {
        continue;
      }

      // Read file content
      let content = match fs::read_to_string(file_path) {
        Ok(content) => content,
        Err(e) => {
          eprintln!("Warning: Failed to read file {}: {}", file_path.display(), e);
          continue;
        }
      };

      // Use the appropriate language parser directly
      match self.analyze_with_language_parser(&content, language, file_path).await {
        Ok(analysis_result) => {
          // Store the parsed file
          let parsed_file = ParsedFile {
            path: file_path.to_path_buf(),
            name: file_name.to_string(),
            language,
            content: content.clone(),
            analysis_result: analysis_result.clone(),
            metrics: self.extract_metrics_from_analysis(&analysis_result),
            timestamp: chrono::Utc::now(),
          };

          // Storage is currently a stub - skip for now
          // TODO: Implement proper file analysis storage when storage is ready

          parsed_files.push(parsed_file);
        }
        Err(e) => {
          eprintln!("Warning: Failed to analyze file {}: {}", file_path.display(), e);
          // Still create a basic parsed file entry for tracking
          let parsed_file = ParsedFile {
            path: file_path.to_path_buf(),
            name: file_name.to_string(),
            language,
            content: content.clone(),
            analysis_result: self.create_fallback_analysis_result(file_path.to_str().unwrap_or("unknown"), &content, language),
            metrics: FileMetrics::default(),
            timestamp: chrono::Utc::now(),
          };
          parsed_files.push(parsed_file);
        }
      }
    }

    info!("Successfully parsed {} files from project", parsed_files.len());
    Ok(parsed_files)
  }

  /// Analyze file using the appropriate language parser
  async fn analyze_with_language_parser(
    &self,
    content: &str,
    language: parser_code::ProgrammingLanguage,
    file_path: &std::path::Path,
  ) -> Result<parser_code::AnalysisResult, String> {
    use parser_core::ProgrammingLanguage;

    match language {
      ProgrammingLanguage::Rust => {
        // Use Rust parser directly
        match rust_parser::RustParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("Rust parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Rust parser: {}", e)),
        }
      }
      ProgrammingLanguage::Python => {
        // Use Python parser directly
        match python_parser::PythonParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("Python parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Python parser: {}", e)),
        }
      }
      ProgrammingLanguage::JavaScript => {
        // Use JavaScript parser directly
        match javascript_parser::JavascriptParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("JavaScript parser error: {}", e)),
          Err(e) => Err(format!("Failed to create JavaScript parser: {}", e)),
        }
      }
      ProgrammingLanguage::TypeScript => {
        // Use TypeScript parser directly
        match typescript_parser::TypescriptParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("TypeScript parser error: {}", e)),
          Err(e) => Err(format!("Failed to create TypeScript parser: {}", e)),
        }
      }
      ProgrammingLanguage::Go => {
        // Use Go parser directly
        match go_parser::GoParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("Go parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Go parser: {}", e)),
        }
      }
      ProgrammingLanguage::Java => {
        // Use Java parser directly
        match java_parser::JavaParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("Java parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Java parser: {}", e)),
        }
      }
      ProgrammingLanguage::CSharp => {
        // Use C# parser directly
        match csharp_parser::CSharpParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("C# parser error: {}", e)),
          Err(e) => Err(format!("Failed to create C# parser: {}", e)),
        }
      }
      ProgrammingLanguage::C => {
        // Use C parser directly
        match c_parser::CParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("C parser error: {}", e)),
          Err(e) => Err(format!("Failed to create C parser: {}", e)),
        }
      }
      ProgrammingLanguage::Cpp => {
        // Use C++ parser directly
        match cpp_parser::CppParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("C++ parser error: {}", e)),
          Err(e) => Err(format!("Failed to create C++ parser: {}", e)),
        }
      }
      ProgrammingLanguage::Elixir => {
        // Use Elixir parser directly
        match elixir_parser::ElixirParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("Elixir parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Elixir parser: {}", e)),
        }
      }
      ProgrammingLanguage::Erlang => {
        // Use Erlang parser directly
        match erlang_parser::ErlangParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("Erlang parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Erlang parser: {}", e)),
        }
      }
      ProgrammingLanguage::Gleam => {
        // Use Gleam parser directly
        match gleam_parser::GleamParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path.to_str().unwrap_or("unknown")).await.map_err(|e| format!("Gleam parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Gleam parser: {}", e)),
        }
      }
      _ => {
        // Fallback to universal parser for unknown languages
        self
          .universal_parser
          .analyze_with_all_tools(content, language, file_path.to_str().unwrap_or("unknown"))
          .await
          .map_err(|e| format!("Universal parser error: {}", e))
      }
    }
  }

  /// Detect programming language from file extension
  fn detect_language_from_extension(&self, file_path: &Path) -> parser_code::ProgrammingLanguage {
    use parser_core::ProgrammingLanguage;

    if let Some(extension) = file_path.extension().and_then(|ext| ext.to_str()) {
      match extension.to_lowercase().as_str() {
        "rs" => ProgrammingLanguage::Rust,
        "py" | "pyi" | "pyc" => ProgrammingLanguage::Python,
        "js" | "mjs" => ProgrammingLanguage::JavaScript,
        "ts" | "tsx" => ProgrammingLanguage::TypeScript,
        "go" => ProgrammingLanguage::Go,
        "java" => ProgrammingLanguage::Java,
        "cs" => ProgrammingLanguage::CSharp,
        "c" | "h" => ProgrammingLanguage::C,
        "cpp" | "cc" | "cxx" | "hpp" | "hxx" => ProgrammingLanguage::Cpp,
        "ex" | "exs" => ProgrammingLanguage::Elixir,
        "erl" | "hrl" => ProgrammingLanguage::Erlang,
        "gleam" => ProgrammingLanguage::Gleam,
        _ => ProgrammingLanguage::Unknown,
      }
    } else {
      ProgrammingLanguage::Unknown
    }
  }

  /// Extract metrics from analysis result
  fn extract_metrics_from_analysis(&self, analysis_result: &parser_code::AnalysisResult) -> FileMetrics {
    // Extract basic metrics
    let mut metrics = FileMetrics {
      lines_of_code: analysis_result.line_metrics.code_lines,
      blank_lines: analysis_result.line_metrics.blank_lines,
      comment_lines: analysis_result.line_metrics.comment_lines,
      total_lines: analysis_result.line_metrics.code_lines + analysis_result.line_metrics.blank_lines + analysis_result.line_metrics.comment_lines,
      cyclomatic_complexity: analysis_result.complexity_metrics.cyclomatic,
      cognitive_complexity: analysis_result.complexity_metrics.cognitive,
      maintainability_index: analysis_result.maintainability_metrics.index,
      technical_debt_ratio: analysis_result.maintainability_metrics.technical_debt_ratio,
      duplication_percentage: analysis_result.maintainability_metrics.duplication_percentage,
      halstead_volume: analysis_result.halstead_metrics.volume,
      halstead_difficulty: analysis_result.halstead_metrics.difficulty,
      halstead_effort: analysis_result.halstead_metrics.effort,
    };

    // Extract language-specific insights and enhance metrics
    self.enhance_metrics_with_language_data(&mut metrics, analysis_result);

    metrics
  }

  /// Enhance metrics with language-specific analysis data
  fn enhance_metrics_with_language_data(&self, metrics: &mut FileMetrics, analysis_result: &parser_code::AnalysisResult) {
    // Process language-specific data for each supported language
    match analysis_result.language {
      parser_code::ProgrammingLanguage::Rust => {
        self.process_rust_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::Python => {
        self.process_python_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::JavaScript => {
        self.process_javascript_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::TypeScript => {
        self.process_typescript_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::Go => {
        self.process_go_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::Java => {
        self.process_java_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::CSharp => {
        self.process_csharp_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::C | parser_code::ProgrammingLanguage::Cpp => {
        self.process_cpp_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::Erlang => {
        self.process_erlang_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::Elixir => {
        self.process_elixir_specific_data(metrics, &analysis_result.language_specific);
      }
      parser_code::ProgrammingLanguage::Gleam => {
        self.process_gleam_specific_data(metrics, &analysis_result.language_specific);
      }
      _ => {
        // Generic processing for unknown languages
        self.process_generic_language_data(metrics, &analysis_result.language_specific);
      }
    }
  }

  /// Process Rust-specific analysis data
  fn process_rust_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(rust_data) = language_data.get("rust") {
      if let Ok(rust_analysis) = serde_json::from_value::<rust_parser::RustSpecificAnalysis>(rust_data.clone()) {
        // Adjust complexity based on Rust-specific patterns
        if rust_analysis.unsafe_usage.len() > 0 {
          metrics.cyclomatic_complexity += rust_analysis.unsafe_usage.len() as f64 * 2.0; // Unsafe code increases complexity
        }

        if rust_analysis.async_await_usage {
          metrics.cognitive_complexity += 1.0; // Async adds cognitive load
        }

        // Adjust maintainability based on ownership patterns
        if rust_analysis.ownership_patterns.len() > 5 {
          metrics.maintainability_index -= 5.0; // Complex ownership patterns reduce maintainability
        }

        // Adjust technical debt based on unsafe usage
        if rust_analysis.unsafe_usage.len() > 0 {
          metrics.technical_debt_ratio += 0.1 * rust_analysis.unsafe_usage.len() as f64;
        }

        // Process Rustler integration patterns
        self.process_rustler_integration(&rust_analysis.rustler_integration, metrics);
      }
    }
  }

  /// Process Rustler integration patterns
  fn process_rustler_integration(&self, rustler: &rust_parser::RustlerIntegration, metrics: &mut FileMetrics) {
    if rustler.has_rustler {
      // NIF functions add significant complexity
      if !rustler.nif_functions.is_empty() {
        let nif_count = rustler.nif_functions.len();
        metrics.cognitive_complexity += nif_count as f64 * 3.0; // NIFs are very complex
        metrics.cyclomatic_complexity += nif_count as f64 * 2.0; // Cross-language boundaries
      }

      // Resource types add memory management complexity
      if !rustler.resource_types.is_empty() {
        let resource_count = rustler.resource_types.len();
        metrics.cognitive_complexity += resource_count as f64 * 2.5; // Resource management is complex
        metrics.technical_debt_ratio += resource_count as f64 * 0.15; // Resource leaks are dangerous
      }

      // Binary handling adds complexity
      if rustler.binary_handling {
        metrics.cognitive_complexity += 2.0; // Binary handling is complex
        metrics.cyclomatic_complexity += 1.5; // Binary parsing adds branches
      }

      // BEAM interop patterns add architectural complexity
      if !rustler.beam_interop_patterns.is_empty() {
        let interop_count = rustler.beam_interop_patterns.len();
        metrics.cognitive_complexity += interop_count as f64 * 2.0; // Cross-language interop is complex
      }

      // Error handling patterns
      if rustler.error_handling.contains(&"Panic usage".to_string()) {
        metrics.technical_debt_ratio += 0.3; // Panics in NIFs are dangerous
      }

      if rustler.error_handling.contains(&"Unwrap usage".to_string()) {
        metrics.technical_debt_ratio += 0.2; // Unwraps can crash the BEAM
      }

      if rustler.error_handling.contains(&"Result type usage".to_string()) {
        metrics.maintainability_index += 3.0; // Proper error handling improves maintainability
      }

      if rustler.error_handling.contains(&"Option type usage".to_string()) {
        metrics.maintainability_index += 2.0; // Option types improve safety
      }

      // Performance optimizations
      if rustler.performance_optimizations.contains(&"Inline functions".to_string()) {
        metrics.maintainability_index += 1.0; // Inline can improve performance
      }

      if rustler.performance_optimizations.contains(&"Const functions".to_string()) {
        metrics.maintainability_index += 1.5; // Const functions are good
      }

      if rustler.performance_optimizations.contains(&"No-std optimization".to_string()) {
        metrics.maintainability_index += 2.0; // No-std reduces dependencies
      }

      // Memory management patterns
      if rustler.memory_management.contains(&"Box allocation".to_string()) {
        metrics.cognitive_complexity += 1.0; // Heap allocation adds complexity
      }

      if rustler.memory_management.contains(&"Arc atomic reference counting".to_string()) {
        metrics.cognitive_complexity += 2.0; // Arc adds concurrency complexity
      }

      if rustler.memory_management.contains(&"Vec dynamic allocation".to_string()) {
        metrics.cognitive_complexity += 0.8; // Vec adds some complexity
      }

      // Concurrency patterns
      if !rustler.concurrency_patterns.is_empty() {
        let concurrency_count = rustler.concurrency_patterns.len();
        metrics.cognitive_complexity += concurrency_count as f64 * 2.5; // Concurrency is very complex
        metrics.cyclomatic_complexity += concurrency_count as f64 * 1.5; // Concurrency adds branches
      }

      // Atom definitions improve BEAM integration
      if !rustler.atom_definitions.is_empty() {
        metrics.maintainability_index += 1.0; // Atoms improve BEAM integration
      }
    }
  }

  /// Process Python-specific analysis data
  fn process_python_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(python_data) = language_data.get("python") {
      // Process Python-specific patterns like decorators, generators, async/await
      // Adjust metrics based on Python-specific complexity patterns
      if let Some(decorators) = python_data.get("decorators") {
        if let Some(count) = decorators.as_u64() {
          metrics.cognitive_complexity += count as f64 * 0.5;
        }
      }

      if let Some(generators) = python_data.get("generators") {
        if let Some(count) = generators.as_u64() {
          metrics.cyclomatic_complexity += count as f64 * 1.5;
        }
      }
    }
  }

  /// Process JavaScript-specific analysis data
  fn process_javascript_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(js_data) = language_data.get("javascript") {
      // Process ES6+ features, async/await, modules, classes
      if let Some(async_functions) = js_data.get("async_functions") {
        if let Some(count) = async_functions.as_u64() {
          metrics.cognitive_complexity += count as f64 * 1.0;
        }
      }

      if let Some(callbacks) = js_data.get("callbacks") {
        if let Some(count) = callbacks.as_u64() {
          metrics.cyclomatic_complexity += count as f64 * 2.0; // Callback hell increases complexity
        }
      }
    }
  }

  /// Process TypeScript-specific analysis data
  fn process_typescript_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(ts_data) = language_data.get("typescript") {
      // Process type annotations, generics, interfaces
      if let Some(generics) = ts_data.get("generics") {
        if let Some(count) = generics.as_u64() {
          metrics.cognitive_complexity += count as f64 * 0.8;
        }
      }

      if let Some(interfaces) = ts_data.get("interfaces") {
        if let Some(count) = interfaces.as_u64() {
          metrics.maintainability_index += count as f64 * 2.0; // Interfaces improve maintainability
        }
      }
    }
  }

  /// Process Go-specific analysis data
  fn process_go_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(go_data) = language_data.get("go") {
      // Process goroutines, channels, interfaces, generics
      if let Some(goroutines) = go_data.get("goroutines") {
        if let Some(count) = goroutines.as_u64() {
          metrics.cognitive_complexity += count as f64 * 1.5; // Concurrency adds complexity
        }
      }

      if let Some(channels) = go_data.get("channels") {
        if let Some(count) = channels.as_u64() {
          metrics.cyclomatic_complexity += count as f64 * 1.2;
        }
      }
    }
  }

  /// Process Java-specific analysis data
  fn process_java_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(java_data) = language_data.get("java") {
      // Process annotations, generics, streams, lambdas
      if let Some(annotations) = java_data.get("annotations") {
        if let Some(count) = annotations.as_u64() {
          metrics.cognitive_complexity += count as f64 * 0.3;
        }
      }

      if let Some(lambdas) = java_data.get("lambdas") {
        if let Some(count) = lambdas.as_u64() {
          metrics.maintainability_index += count as f64 * 1.0; // Lambdas can improve readability
        }
      }
    }
  }

  /// Process C#-specific analysis data
  fn process_csharp_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(csharp_data) = language_data.get("csharp") {
      // Process LINQ, async/await, attributes, generics
      if let Some(linq_queries) = csharp_data.get("linq_queries") {
        if let Some(count) = linq_queries.as_u64() {
          metrics.cognitive_complexity += count as f64 * 0.7;
        }
      }

      if let Some(async_methods) = csharp_data.get("async_methods") {
        if let Some(count) = async_methods.as_u64() {
          metrics.cognitive_complexity += count as f64 * 1.0;
        }
      }
    }
  }

  /// Process C/C++-specific analysis data
  fn process_cpp_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(cpp_data) = language_data.get("cpp") {
      // Process templates, RAII, smart pointers, memory management
      if let Some(templates) = cpp_data.get("templates") {
        if let Some(count) = templates.as_u64() {
          metrics.cognitive_complexity += count as f64 * 2.0; // Templates are complex
        }
      }

      if let Some(raw_pointers) = cpp_data.get("raw_pointers") {
        if let Some(count) = raw_pointers.as_u64() {
          metrics.technical_debt_ratio += count as f64 * 0.05; // Raw pointers increase technical debt
        }
      }
    }
  }

  /// Process Erlang-specific analysis data
  fn process_erlang_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(erlang_data) = language_data.get("erlang") {
      // Erlang parser available - process OTP behaviors, message passing, etc.
      // Fallback to simple processing if detailed analysis is not available
      if let Some(processes) = erlang_data.get("processes") {
        if let Some(count) = processes.as_u64() {
          metrics.cognitive_complexity += count as f64 * 1.2;
        }
      }

      if let Some(message_passing) = erlang_data.get("message_passing") {
        if let Some(count) = message_passing.as_u64() {
          metrics.cyclomatic_complexity += count as f64 * 1.0;
        }
      }

      if let Some(otp_behaviors) = erlang_data.get("otp_behaviors") {
        if let Some(count) = otp_behaviors.as_u64() {
          metrics.cognitive_complexity += count as f64 * 2.0; // OTP behaviors are complex
        }
      }
    }
  }

  /// Process Elixir-specific analysis data
  fn process_elixir_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(elixir_data) = language_data.get("elixir") {
      // Try to parse as ElixirAnalysisResult
      if let Ok(elixir_analysis) = serde_json::from_value::<elixir_parser::ElixirAnalysisResult>(elixir_data.clone()) {
        // Process OTP behaviors
        if !elixir_analysis.otp_analysis.detected_behaviours.is_empty() {
          let behavior_count = elixir_analysis.otp_analysis.detected_behaviours.len();
          metrics.cognitive_complexity += behavior_count as f64 * 2.0; // OTP behaviors are complex

          // GenServer adds significant complexity
          if elixir_analysis.otp_analysis.detected_behaviours.contains(&"GenServer".to_string()) {
            metrics.cyclomatic_complexity += 3.0;
          }

          // Supervisor adds architectural complexity
          if elixir_analysis.otp_analysis.detected_behaviours.contains(&"Supervisor".to_string()) {
            metrics.cognitive_complexity += 2.5;
          }

          // Agent adds state management complexity
          if elixir_analysis.otp_analysis.detected_behaviours.contains(&"Agent".to_string()) {
            metrics.cognitive_complexity += 1.5;
          }
        }

        // Process Phoenix patterns
        if !elixir_analysis.phoenix_analysis.detected_components.is_empty() {
          let component_count = elixir_analysis.phoenix_analysis.detected_components.len();
          metrics.cognitive_complexity += component_count as f64 * 1.8; // Phoenix components are complex

          // LiveView adds real-time complexity
          if elixir_analysis.phoenix_analysis.detected_components.contains(&"LiveView".to_string()) {
            metrics.cyclomatic_complexity += 4.0; // LiveView is very complex
          }

          // Channels add concurrency complexity
          if elixir_analysis.phoenix_analysis.detected_components.contains(&"Channel".to_string()) {
            metrics.cognitive_complexity += 2.0;
          }
        }

        // Process concurrency patterns
        if !elixir_analysis.concurrency_analysis.process_patterns.is_empty() {
          let process_count = elixir_analysis.concurrency_analysis.process_patterns.len();
          metrics.cognitive_complexity += process_count as f64 * 1.5; // Process spawning is complex
        }

        if !elixir_analysis.concurrency_analysis.message_patterns.is_empty() {
          let message_count = elixir_analysis.concurrency_analysis.message_patterns.len();
          metrics.cyclomatic_complexity += message_count as f64 * 1.2; // Message passing adds complexity
        }

        // Process fault tolerance
        if elixir_analysis.fault_tolerance.fault_tolerance_score > 80.0 {
          metrics.maintainability_index += 5.0; // High fault tolerance improves maintainability
        } else if elixir_analysis.fault_tolerance.fault_tolerance_score < 40.0 {
          metrics.technical_debt_ratio += 0.2; // Low fault tolerance increases technical debt
        }

        // Process performance issues
        if !elixir_analysis.performance_metrics.performance_issues.is_empty() {
          let issue_count = elixir_analysis.performance_metrics.performance_issues.len();
          metrics.technical_debt_ratio += issue_count as f64 * 0.1;
        }

        // Process functional patterns
        if elixir_analysis.functional_analysis.immutability_score > 90.0 {
          metrics.maintainability_index += 3.0; // High immutability improves maintainability
        }

        // Pipe operators improve readability
        if elixir_analysis.functional_analysis.functional_features.get("pipe_operators").unwrap_or(&false) == &true {
          metrics.maintainability_index += 2.0; // Pipes improve readability
        }

        // CodePattern matching complexity
        if elixir_analysis.functional_analysis.pattern_match_complexity > 5.0 {
          metrics.cognitive_complexity += elixir_analysis.functional_analysis.pattern_match_complexity * 0.5;
        }
      } else {
        // Fallback to simple processing if parsing fails
        if let Some(genservers) = elixir_data.get("genservers") {
          if let Some(count) = genservers.as_u64() {
            metrics.cognitive_complexity += count as f64 * 1.5;
          }
        }

        if let Some(pipes) = elixir_data.get("pipes") {
          if let Some(count) = pipes.as_u64() {
            metrics.maintainability_index += count as f64 * 0.5; // Pipes improve readability
          }
        }
      }
    }
  }

  /// Process Gleam-specific analysis data
  fn process_gleam_specific_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    if let Some(gleam_data) = language_data.get("gleam") {
      // Try to parse as GleamAnalysisResult
      if let Ok(gleam_analysis) = serde_json::from_value::<gleam_parser::GleamAnalysisResult>(gleam_data.clone()) {
        // Process type system
        if !gleam_analysis.type_analysis.custom_types.is_empty() {
          let type_count = gleam_analysis.type_analysis.custom_types.len();
          metrics.maintainability_index += type_count as f64 * 2.0; // Custom types improve maintainability
        }

        // Generic types add complexity
        if gleam_analysis.type_analysis.type_features.get("generic_types").unwrap_or(&false) == &true {
          metrics.cognitive_complexity += 1.5; // Generics are complex
        }

        // Type annotations improve maintainability
        if gleam_analysis.type_analysis.type_features.get("type_annotations").unwrap_or(&false) == &true {
          metrics.maintainability_index += 3.0; // Type annotations help maintainability
        }

        // Process actor patterns
        if !gleam_analysis.actor_analysis.actor_patterns.is_empty() {
          let actor_count = gleam_analysis.actor_analysis.actor_patterns.len();
          metrics.cognitive_complexity += actor_count as f64 * 2.0; // Actor patterns are complex
        }

        if !gleam_analysis.actor_analysis.message_types.is_empty() {
          let message_count = gleam_analysis.actor_analysis.message_types.len();
          metrics.cyclomatic_complexity += message_count as f64 * 1.5; // Message types add complexity
        }

        // Process functional patterns
        if gleam_analysis.functional_analysis.immutability_score > 95.0 {
          metrics.maintainability_index += 5.0; // Gleam is always immutable, improves maintainability
        }

        // CodePattern matching complexity
        if gleam_analysis.functional_analysis.pattern_match_complexity > 5.0 {
          metrics.cognitive_complexity += gleam_analysis.functional_analysis.pattern_match_complexity * 0.8;
        }

        // Higher-order functions add complexity
        if gleam_analysis.functional_analysis.functional_features.get("higher_order_functions").unwrap_or(&false) == &true {
          metrics.cognitive_complexity += 2.0;
        }

        // Process BEAM integration
        if !gleam_analysis.beam_integration.interop_patterns.is_empty() {
          let interop_count = gleam_analysis.beam_integration.interop_patterns.len();
          metrics.cognitive_complexity += interop_count as f64 * 1.5; // Interop adds complexity
        }

        if !gleam_analysis.beam_integration.otp_usage.is_empty() {
          let otp_count = gleam_analysis.beam_integration.otp_usage.len();
          metrics.cognitive_complexity += otp_count as f64 * 2.0; // OTP usage is complex
        }

        // Process modern features
        if gleam_analysis.modern_features.language_features.get("result_types").unwrap_or(&false) == &true {
          metrics.maintainability_index += 1.0; // Result types improve error handling
        }

        if gleam_analysis.modern_features.language_features.get("option_types").unwrap_or(&false) == &true {
          metrics.maintainability_index += 0.8; // Option types improve safety
        }

        // Pipe operators improve readability
        if gleam_analysis.modern_features.language_features.get("pipe_operators").unwrap_or(&false) == &true {
          metrics.maintainability_index += 0.5;
        }

        // Process web patterns
        if !gleam_analysis.web_patterns.http_patterns.is_empty() {
          let handler_count = gleam_analysis.web_patterns.http_patterns.len();
          metrics.cognitive_complexity += handler_count as f64 * 1.2; // HTTP patterns add complexity
        }

        if !gleam_analysis.web_patterns.web_safety_features.is_empty() {
          let safety_count = gleam_analysis.web_patterns.web_safety_features.len();
          metrics.maintainability_index += safety_count as f64 * 0.5; // Safety features improve quality
        }
      } else {
        // Fallback to simple processing if parsing fails
        if let Some(functions) = gleam_data.get("functions") {
          if let Some(count) = functions.as_u64() {
            metrics.cognitive_complexity += count as f64 * 0.8;
          }
        }

        if let Some(types) = gleam_data.get("types") {
          if let Some(count) = types.as_u64() {
            metrics.maintainability_index += count as f64 * 1.0; // Strong typing improves maintainability
          }
        }
      }
    }
  }

  /// Process generic language data for unknown languages
  fn process_generic_language_data(&self, metrics: &mut FileMetrics, language_data: &std::collections::HashMap<String, serde_json::Value>) {
    // Generic processing for any language-specific data
    for (key, value) in language_data {
      if let Some(count) = value.as_u64() {
        match key.as_str() {
          "functions" | "methods" => {
            metrics.cognitive_complexity += count as f64 * 0.5;
          }
          "classes" | "structs" | "types" => {
            metrics.maintainability_index += count as f64 * 1.0;
          }
          "async" | "await" | "promises" => {
            metrics.cognitive_complexity += count as f64 * 1.0;
          }
          _ => {
            // Generic complexity adjustment
            metrics.cognitive_complexity += count as f64 * 0.3;
          }
        }
      }
    }
  }

  /// Create fallback analysis result for files that couldn't be parsed
  fn create_fallback_analysis_result(
    &self,
    file_path: &str,
    content: &str,
    language: parser_code::ProgrammingLanguage,
  ) -> parser_code::AnalysisResult {
    use parser_core::*;

    AnalysisResult {
      file_path: file_path.to_string(),
      language,
      line_metrics: LineMetrics {
        total_lines: content.lines().count(),
        code_lines: content.lines().filter(|line| !line.trim().is_empty() && !line.trim().starts_with("//")).count(),
        comment_lines: content.lines().filter(|line| line.trim().starts_with("//") || line.trim().starts_with("/*")).count(),
        blank_lines: content.lines().filter(|line| line.trim().is_empty()).count(),
      },
      complexity_metrics: ComplexityMetrics {
        cyclomatic_complexity: 1.0,
        cognitive_complexity: 1.0,
        halstead_complexity: HalsteadMetrics {
          vocabulary: 0.0,
          length: 0.0,
          volume: 0.0,
          difficulty: 0.0,
          effort: 0.0,
          time: 0.0,
          bugs: 0.0,
        },
        nesting_depth: 1.0,
        parameter_count: 0.0,
        line_count: 0.0,
      },
      halstead_metrics: HalsteadMetrics {
        vocabulary: 0.0,
        length: 0.0,
        volume: 0.0,
        difficulty: 0.0,
        effort: 0.0,
        time: 0.0,
        bugs: 0.0,
      },
      maintainability_metrics: MaintainabilityMetrics { index: 50.0, technical_debt_ratio: 0.1, duplication_percentage: 0.0 },
      language_specific: std::collections::HashMap::new(),
      timestamp: chrono::Utc::now(),
      analysis_duration_ms: 0,
    }
  }

  async fn generate_naming_suggestions(&self, files: &[ParsedFile]) -> Result<NamingAnalysis, String> {
    let mut analysis = NamingAnalysis::default();

    // TODO: AST-based naming analysis requires function/variable extraction
    // ParsedFile.analysis_result only contains metrics, not AST with function/variable names
    // Need to either:
    // 1. Add AST parsing to universal-parser that extracts functions/variables
    // 2. Use language_specific HashMap to extract AST data if available
    // 3. Integrate tree-sitter or other AST parsers here

    for _file in files {
      // Placeholder: Would analyze function and variable names from AST
      // Currently ParsedFile only has:
      // - path, language, content
      // - analysis_result (metrics only: line_metrics, complexity_metrics, halstead_metrics)
      // - metrics (FileMetrics)
    }

    // Calculate overall score
    analysis.overall_score =
      if analysis.suggestions.is_empty() { 1.0 } else { analysis.suggestions.iter().map(|s| s.confidence).sum::<f64>() / analysis.suggestions.len() as f64 };

    Ok(analysis)
  }

  /// Perform comprehensive cross-language analysis
  pub async fn analyze_cross_language_patterns(&self, files: &[ParsedFile]) -> Result<CrossLanguageAnalysis, String> {
    let mut analysis = CrossLanguageAnalysis::default();

    // Group files by language
    let mut language_groups: std::collections::HashMap<parser_code::ProgrammingLanguage, Vec<&ParsedFile>> = std::collections::HashMap::new();
    for file in files {
      language_groups.entry(file.language).or_insert_with(Vec::new).push(file);
    }

    // Analyze technology stack
    analysis.technology_stack = self.analyze_technology_stack(&language_groups);

    // Analyze integration patterns
    analysis.integration_patterns = self.analyze_integration_patterns(files);

    // Analyze architectural patterns across languages
    analysis.architectural_patterns = self.analyze_architectural_patterns(files);

    // Analyze quality consistency across languages
    analysis.quality_consistency = self.analyze_quality_consistency(files);

    // Analyze complexity distribution
    analysis.complexity_distribution = self.analyze_complexity_distribution(files);

    Ok(analysis)
  }

  /// Analyze technology stack from language distribution
  fn analyze_technology_stack(&self, language_groups: &std::collections::HashMap<parser_code::ProgrammingLanguage, Vec<&ParsedFile>>) -> TechnologyStack {
    let mut stack = TechnologyStack::default();

    for (language, files) in language_groups {
  let file_count: usize = files.len();
      let total_lines: usize = files.iter().map(|f| f.metrics.lines_of_code).sum();

      match language {
        parser_code::ProgrammingLanguage::Rust => {
          stack.backend_languages.push("Rust".to_string());
          stack.performance_focused = true;
        }
        parser_code::ProgrammingLanguage::Python => {
          stack.backend_languages.push("Python".to_string());
          stack.data_science_focused = true;
        }
        parser_code::ProgrammingLanguage::JavaScript => {
          stack.frontend_languages.push("JavaScript".to_string());
          stack.web_focused = true;
        }
        parser_code::ProgrammingLanguage::TypeScript => {
          stack.frontend_languages.push("TypeScript".to_string());
          stack.type_safety_focused = true;
        }
        parser_code::ProgrammingLanguage::Go => {
          stack.backend_languages.push("Go".to_string());
          stack.concurrency_focused = true;
        }
        parser_code::ProgrammingLanguage::Java => {
          stack.backend_languages.push("Java".to_string());
          stack.enterprise_focused = true;
        }
        parser_code::ProgrammingLanguage::CSharp => {
          stack.backend_languages.push("C#".to_string());
          stack.microsoft_ecosystem = true;
        }
        parser_code::ProgrammingLanguage::C | parser_code::ProgrammingLanguage::Cpp => {
          stack.system_languages.push("C/C++".to_string());
          stack.low_level_focused = true;
        }
        parser_code::ProgrammingLanguage::Erlang | parser_code::ProgrammingLanguage::Elixir => {
          stack.backend_languages.push(format!("{:?}", language));
          stack.fault_tolerance_focused = true;
        }
        parser_code::ProgrammingLanguage::Gleam => {
          stack.backend_languages.push("Gleam".to_string());
          stack.functional_focused = true;
        }
        _ => {}
      }

      // Determine primary language
      if file_count > stack.primary_language_file_count {
        stack.primary_language = format!("{:?}", language);
        stack.primary_language_file_count = file_count;
        stack.primary_language_lines = total_lines;
      }
    }

    stack
  }

  /// Analyze integration patterns between languages
  fn analyze_integration_patterns(&self, files: &[ParsedFile]) -> Vec<IntegrationCodePattern> {
    let mut patterns = Vec::new();

    // Look for common integration patterns
    let mut api_patterns = 0;
    let mut database_patterns = 0;
    let mut message_queue_patterns = 0;
    let mut file_io_patterns = 0;

    for file in files.iter() {
      // Simple pattern detection based on file content and language
      match file.language {
        parser_code::ProgrammingLanguage::Rust => {
          if file.content.contains("serde") || file.content.contains("json") {
            api_patterns += 1;
          }
          if file.content.contains("sqlx") || file.content.contains("diesel") {
            database_patterns += 1;
          }
        }
        parser_code::ProgrammingLanguage::Python => {
          if file.content.contains("flask") || file.content.contains("fastapi") {
            api_patterns += 1;
          }
          if file.content.contains("sqlalchemy") || file.content.contains("django") {
            database_patterns += 1;
          }
        }
        parser_code::ProgrammingLanguage::JavaScript | parser_code::ProgrammingLanguage::TypeScript => {
          if file.content.contains("express") || file.content.contains("koa") {
            api_patterns += 1;
          }
          if file.content.contains("mongoose") || file.content.contains("prisma") {
            database_patterns += 1;
          }
        }
        _ => {}
      }
    }

    if api_patterns > 0 {
      patterns.push(IntegrationCodePattern {
        pattern_type: "API Integration".to_string(),
        frequency: api_patterns,
        description: "REST/GraphQL API patterns detected".to_string(),
      });
    }

    if database_patterns > 0 {
      patterns.push(IntegrationCodePattern {
        pattern_type: "Database Integration".to_string(),
        frequency: database_patterns,
        description: "Database ORM/query patterns detected".to_string(),
      });
    }

    patterns
  }

  /// Analyze architectural patterns across languages
  fn analyze_architectural_patterns(&self, files: &[ParsedFile]) -> Vec<ArchitecturalCodePattern> {
    let mut patterns = Vec::new();

    // Analyze microservices patterns
    let mut service_count = 0;
    let mut api_count = 0;

    for file in files.iter() {
      if file.name.contains("service") || file.name.contains("api") {
        service_count += 1;
      }
      if file.content.contains("microservice") || file.content.contains("service") {
        api_count += 1;
      }
    }

    if service_count > 3 {
      patterns.push(ArchitecturalCodePattern {
        pattern_type: "Microservices".to_string(),
        confidence: 0.8,
        description: "Multiple service files detected".to_string(),
      });
    }

    // Analyze layered architecture
    let mut layer_count = 0;
    for file in files.iter() {
      if file.name.contains("controller") || file.name.contains("service") || file.name.contains("repository") {
        layer_count += 1;
      }
    }

    if layer_count > 2 {
      patterns.push(ArchitecturalCodePattern {
        pattern_type: "Layered Architecture".to_string(),
        confidence: 0.7,
        description: "Multiple architectural layers detected".to_string(),
      });
    }

    patterns
  }

  /// Analyze quality consistency across languages
  fn analyze_quality_consistency(&self, files: &[ParsedFile]) -> QualityConsistency {
    let mut consistency = QualityConsistency::default();

    let mut total_complexity = 0.0;
    let mut total_maintainability = 0.0;
    let mut total_technical_debt = 0.0;
    let mut file_count = 0;

    for file in files.iter() {
      total_complexity += file.metrics.cyclomatic_complexity;
      total_maintainability += file.metrics.maintainability_index;
      total_technical_debt += file.metrics.technical_debt_ratio;
      file_count += 1;
    }

    if file_count > 0 {
      consistency.average_complexity = total_complexity / file_count as f64;
      consistency.average_maintainability = total_maintainability / file_count as f64;
      consistency.average_technical_debt = total_technical_debt / file_count as f64;

      // Calculate consistency score
      consistency.consistency_score = self.calculate_consistency_score(files);
    }

    consistency
  }

  /// Calculate consistency score across files
  fn calculate_consistency_score(&self, files: &[ParsedFile]) -> f64 {
    if files.len() < 2 {
      return 1.0;
    }

    let complexities: Vec<f64> = files.iter().map(|f| f.metrics.cyclomatic_complexity).collect();
    let maintainabilities: Vec<f64> = files.iter().map(|f| f.metrics.maintainability_index).collect();

    // Calculate coefficient of variation (lower is more consistent)
    let complexity_cv = self.coefficient_of_variation(&complexities);
    let maintainability_cv = self.coefficient_of_variation(&maintainabilities);

    // Convert to consistency score (higher is more consistent)
    let complexity_score = (1.0 - complexity_cv).max(0.0);
    let maintainability_score = (1.0 - maintainability_cv).max(0.0);

    (complexity_score + maintainability_score) / 2.0
  }

  /// Calculate coefficient of variation
  fn coefficient_of_variation(&self, values: &[f64]) -> f64 {
    if values.is_empty() {
      return 0.0;
    }

    let mean = values.iter().sum::<f64>() / values.len() as f64;
    if mean == 0.0 {
      return 0.0;
    }

    let variance = values.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / values.len() as f64;
    let std_dev = variance.sqrt();

    std_dev / mean
  }

  /// Analyze complexity distribution across files
  fn analyze_complexity_distribution(&self, files: &[ParsedFile]) -> ComplexityDistribution {
    let mut distribution = ComplexityDistribution::default();

    for file in files.iter() {
      let complexity = file.metrics.cyclomatic_complexity;

      if complexity < 5.0 {
        distribution.low_complexity += 1;
      } else if complexity < 15.0 {
        distribution.medium_complexity += 1;
      } else {
        distribution.high_complexity += 1;
      }

      distribution.total_files += 1;
    }

    distribution
  }

  /// Implement quality gates based on analysis results
  pub async fn evaluate_quality_gates(&self, files: &[ParsedFile]) -> Result<QualityGateResults, String> {
    let mut results = QualityGateResults::default();

    // Gate 1: Complexity threshold
    let high_complexity_files: Vec<&ParsedFile> = files.iter().filter(|f| f.metrics.cyclomatic_complexity > 15.0).collect();

    results.complexity_gate = QualityGate {
      name: "Cyclomatic Complexity".to_string(),
      passed: high_complexity_files.is_empty(),
      threshold: 15.0,
      actual_value: if files.is_empty() { 0.0 } else { files.iter().map(|f| f.metrics.cyclomatic_complexity).sum::<f64>() / files.len() as f64 },
      failed_files: high_complexity_files.iter().map(|f| f.name.clone()).collect(),
    };

    // Gate 2: Maintainability threshold
    let low_maintainability_files: Vec<&ParsedFile> = files.iter().filter(|f| f.metrics.maintainability_index < 20.0).collect();

    results.maintainability_gate = QualityGate {
      name: "Maintainability Index".to_string(),
      passed: low_maintainability_files.is_empty(),
      threshold: 20.0,
      actual_value: if files.is_empty() { 0.0 } else { files.iter().map(|f| f.metrics.maintainability_index).sum::<f64>() / files.len() as f64 },
      failed_files: low_maintainability_files.iter().map(|f| f.name.clone()).collect(),
    };

    // Gate 3: Technical debt threshold
    let high_debt_files: Vec<&ParsedFile> = files.iter().filter(|f| f.metrics.technical_debt_ratio > 0.5).collect();

    results.technical_debt_gate = QualityGate {
      name: "Technical Debt Ratio".to_string(),
      passed: high_debt_files.is_empty(),
      threshold: 0.5,
      actual_value: if files.is_empty() { 0.0 } else { files.iter().map(|f| f.metrics.technical_debt_ratio).sum::<f64>() / files.len() as f64 },
      failed_files: high_debt_files.iter().map(|f| f.name.clone()).collect(),
    };

    // Overall gate result
    results.overall_passed = results.complexity_gate.passed && results.maintainability_gate.passed && results.technical_debt_gate.passed;

    Ok(results)
  }
}

// Note: Default trait not implemented because CodebaseAnalyzer::new() is async
// and requires a project_id parameter. Use CodebaseAnalyzer::new(project_id).await instead.

/// Comprehensive project analysis results
#[derive(Debug, Clone)]
pub struct ProjectAnalysis {
  pub files: Vec<ParsedFile>,
  pub naming: NamingAnalysis,
  pub framework_detection: Option<Vec<String>>,
}

/// Represents a parsed file with analysis results
#[derive(Debug, Clone)]
pub struct ParsedFile {
  pub path: std::path::PathBuf,
  pub name: String,
  pub language: parser_code::ProgrammingLanguage,
  pub content: String,
  pub analysis_result: parser_code::AnalysisResult,
  pub metrics: FileMetrics,
  pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// File-level metrics extracted from analysis
#[derive(Debug, Clone, Default)]
pub struct FileMetrics {
  pub lines_of_code: usize,
  pub blank_lines: usize,
  pub comment_lines: usize,
  pub total_lines: usize,
  pub cyclomatic_complexity: f64,
  pub cognitive_complexity: f64,
  pub maintainability_index: f64,
  pub technical_debt_ratio: f64,
  pub duplication_percentage: f64,
  pub halstead_volume: f64,
  pub halstead_difficulty: f64,
  pub halstead_effort: f64,
}

/// Analysis result types (placeholders for now)
#[derive(Debug, Clone, Default)]
pub struct SemanticAnalysis {}

impl SemanticAnalysis {
  pub fn new() -> Self {
    Self::default()
  }
}

/// Cross-language analysis results
#[derive(Debug, Clone, Default)]
pub struct CrossLanguageAnalysis {
  pub technology_stack: TechnologyStack,
  pub integration_patterns: Vec<IntegrationCodePattern>,
  pub architectural_patterns: Vec<ArchitecturalCodePattern>,
  pub quality_consistency: QualityConsistency,
  pub complexity_distribution: ComplexityDistribution,
}

/// Technology stack analysis
#[derive(Debug, Clone, Default)]
pub struct TechnologyStack {
  pub primary_language: String,
  pub primary_language_file_count: usize,
  pub primary_language_lines: usize,
  pub backend_languages: Vec<String>,
  pub frontend_languages: Vec<String>,
  pub system_languages: Vec<String>,
  pub performance_focused: bool,
  pub data_science_focused: bool,
  pub web_focused: bool,
  pub type_safety_focused: bool,
  pub concurrency_focused: bool,
  pub enterprise_focused: bool,
  pub microsoft_ecosystem: bool,
  pub low_level_focused: bool,
  pub fault_tolerance_focused: bool,
  pub functional_focused: bool,
}

/// Integration pattern analysis
#[derive(Debug, Clone)]
pub struct IntegrationCodePattern {
  pub pattern_type: String,
  pub frequency: usize,
  pub description: String,
}

/// Architectural pattern analysis
#[derive(Debug, Clone)]
pub struct ArchitecturalCodePattern {
  pub pattern_type: String,
  pub confidence: f64,
  pub description: String,
}

/// Quality consistency analysis
#[derive(Debug, Clone, Default)]
pub struct QualityConsistency {
  pub average_complexity: f64,
  pub average_maintainability: f64,
  pub average_technical_debt: f64,
  pub consistency_score: f64,
}

/// Complexity distribution analysis
#[derive(Debug, Clone, Default)]
pub struct ComplexityDistribution {
  pub low_complexity: usize,
  pub medium_complexity: usize,
  pub high_complexity: usize,
  pub total_files: usize,
}

/// Quality gate results
#[derive(Debug, Clone, Default)]
pub struct QualityGateResults {
  pub complexity_gate: QualityGate,
  pub maintainability_gate: QualityGate,
  pub technical_debt_gate: QualityGate,
  pub overall_passed: bool,
}

/// Individual quality gate
#[derive(Debug, Clone)]
pub struct QualityGate {
  pub name: String,
  pub passed: bool,
  pub threshold: f64,
  pub actual_value: f64,
  pub failed_files: Vec<String>,
}

impl Default for QualityGate {
  fn default() -> Self {
    Self { name: String::new(), passed: true, threshold: 0.0, actual_value: 0.0, failed_files: Vec::new() }
  }
}

#[derive(Debug, Clone, Default)]
pub struct MetricsAnalysis {}

#[derive(Debug, Clone, Default)]
pub struct CodePatternAnalysis {}

#[derive(Debug, Clone, Default)]
pub struct NamingAnalysis {
  pub suggestions: Vec<NamingSuggestion>,
  pub overall_score: f64,
}

#[derive(Debug, Clone)]
pub struct NamingSuggestion {
  pub original_name: String,
  pub suggested_name: String,
  pub element_type: crate::CodeElementType,
  pub confidence: f64,
  pub reasoning: String,
}
