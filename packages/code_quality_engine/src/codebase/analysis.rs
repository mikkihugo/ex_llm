//! Analysis engine for codebase

use crate::codebase::metadata::CodebaseMetadata;
// CodebaseDatabase removed - NIF doesn't need storage
use crate::codebase::config::CodebaseConfig;
use crate::codebase::parser_registry::{ParserRegistry, ExpectedAnalysisFields, ParserRegistryEntry, ParserSpecificConfig};
use anyhow::Result;

// Universal parser and individual parser imports
use parser_core::{AnalysisResult as PolyglotAnalysisResult, PolyglotCodeParser};
use tempfile::Builder;

/// Core analysis engine (pure computation, no storage)
pub struct AnalysisEngine {
  /// Configuration for codebase-specific features
  config: CodebaseConfig,
  /// Parser registry for capability-aware analysis
  parser_registry: ParserRegistry,
}

impl AnalysisEngine {
  /// Create new analysis engine with default config
  pub fn new() -> Self {
    Self {
      config: CodebaseConfig::default(),
      parser_registry: ParserRegistry::new(),
    }
  }

  /// Create analysis engine with configuration
  pub fn with_config(config: CodebaseConfig) -> Self {
    Self {
      config,
      parser_registry: ParserRegistry::new(),
    }
  }

  // Database constructor removed - NIF doesn't need storage

  /// Register a parser with its capabilities
  pub fn register_parser(&mut self, parser_id: String, capabilities: ParserCapabilities, expected_fields: ExpectedAnalysisFields) {
    let entry = ParserRegistryEntry {
      parser_id,
      capabilities,
      expected_fields,
      config: ParserSpecificConfig::default(),
    };
    self.parser_registry.register_parser(entry);
  }

  /// Analyze file content with parser-aware expectations
  pub async fn analyze_file_with_parser(&self, path: &str, content: &str, parser_id: &str) -> Result<CodebaseMetadata> {
    let _ = self
      .parser_registry
      .get_expected_fields(parser_id)
      .ok_or_else(|| anyhow::anyhow!("Parser '{}' not registered", parser_id))?;

    self.analyze_file(path, content).await
  }

  /// Analyze file content using universal parser and return CodebaseMetadata
  pub async fn analyze_file(&self, path: &str, content: &str) -> Result<CodebaseMetadata> {
    let universal_result =
      self
        .analyze_with_polyglot(path, content)
        .map_err(|err| anyhow::anyhow!(err))?;

    self
      .convert_polyglot_to_metadata(&universal_result, path, content)
      .map_err(|err| anyhow::anyhow!(err))
  }

  /// Analyze file content with specific field expectations
  async fn analyze_file_with_expectations(
    &self,
    path: &str,
    content: &str,
    _expected_fields: &ExpectedAnalysisFields,
  ) -> Result<CodebaseMetadata> {
    self.analyze_file(path, content).await
  }

  /// Detect language from file path
  fn detect_language(&self, path: &str) -> String {
    if path.ends_with(".rs") { "rust".to_string() }
    else if path.ends_with(".py") { "python".to_string() }
    else if path.ends_with(".js") || path.ends_with(".ts") { "javascript".to_string() }
    else if path.ends_with(".go") { "go".to_string() }
    else if path.ends_with(".java") { "java".to_string() }
    else if path.ends_with(".cs") { "csharp".to_string() }
    else if path.ends_with(".cpp") || path.ends_with(".c") { "cpp".to_string() }
    else { "unknown".to_string() }
  }

  /// Analyze content using the polyglot parser backed by Singularity Code Analyzer
  fn analyze_with_polyglot(
    &self,
    path: &str,
    content: &str,
  ) -> Result<PolyglotAnalysisResult, String> {
    let mut parser =
      PolyglotCodeParser::new().map_err(|err| format!("Failed to create polyglot parser: {}", err))?;

    let extension = std::path::Path::new(path)
      .extension()
      .and_then(|ext| ext.to_str())
      .filter(|ext| !ext.is_empty())
      .unwrap_or("code");

    let suffix = format!(".{}", extension);
    let mut temp_file = Builder::new()
      .suffix(&suffix)
      .tempfile()
      .map_err(|err| format!("Failed to create temporary file: {}", err))?;

    use std::io::Write;
    temp_file
      .write_all(content.as_bytes())
      .map_err(|err| format!("Failed to write temporary file: {}", err))?;

    parser
      .analyze_file(temp_file.path())
      .map_err(|err| format!("Polyglot analysis failed: {}", err))
  }

  /// Convert polyglot parser result to CodebaseMetadata
  fn convert_polyglot_to_metadata(
    &self,
    universal_result: &PolyglotAnalysisResult,
    path: &str,
    content: &str,
  ) -> Result<CodebaseMetadata, String> {
    let mut metadata = CodebaseMetadata::default();
    
    // Basic file info
    metadata.path = path.to_string();
    metadata.size = content.len() as u64;
    metadata.lines = content.lines().count();
    metadata.language = universal_result.language.clone();
    metadata.last_modified = Self::parse_timestamp(&universal_result.analysis_timestamp);
    
    // Line metrics from universal parser
    metadata.total_lines = universal_result.metrics.total_lines;
    metadata.code_lines = universal_result.metrics.lines_of_code;
    metadata.comment_lines = universal_result.metrics.lines_of_comments;
    metadata.blank_lines = universal_result.metrics.blank_lines;
    
    // Complexity metrics from universal parser
    metadata.cyclomatic_complexity = universal_result.metrics.complexity_score;
    metadata.function_count = universal_result.metrics.functions;
    metadata.class_count = universal_result.metrics.classes;
    
    if let Some(rca) = &universal_result.rca_metrics {
      metadata.maintainability_index = Self::parse_float(&rca.maintainability_index);
      metadata.cyclomatic_complexity =
        Self::parse_float(&rca.cyclomatic_complexity).max(metadata.cyclomatic_complexity);

      if let Ok(halstead) = serde_json::from_str::<serde_json::Value>(&rca.halstead_metrics) {
        metadata.halstead_volume = halstead
          .get("volume")
          .and_then(|v| v.as_f64())
          .unwrap_or(metadata.halstead_volume);
        metadata.halstead_difficulty = halstead
          .get("difficulty")
          .and_then(|v| v.as_f64())
          .unwrap_or(metadata.halstead_difficulty);
        metadata.halstead_effort = halstead
          .get("effort")
          .and_then(|v| v.as_f64())
          .unwrap_or(metadata.halstead_effort);
        metadata.halstead_vocabulary = halstead
          .get("unique_operators")
          .and_then(|v| v.as_u64())
          .unwrap_or(metadata.halstead_vocabulary)
          + halstead
            .get("unique_operands")
            .and_then(|v| v.as_u64())
            .unwrap_or(0);
        metadata.halstead_length = halstead
          .get("total_operators")
          .and_then(|v| v.as_u64())
          .unwrap_or(0)
          + halstead
            .get("total_operands")
            .and_then(|v| v.as_u64())
            .unwrap_or(0);
      }

      metadata.total_lines = metadata.total_lines.max(rca.physical_lines_of_code);
      metadata.code_lines = metadata.code_lines.max(rca.source_lines_of_code);
      metadata.comment_lines = metadata.comment_lines.max(rca.comment_lines_of_code);
      metadata.blank_lines = metadata.blank_lines.max(rca.blank_lines);
    }

    if let Some(tree) = &universal_result.tree_sitter_analysis {
      metadata.functions = tree.functions.iter().map(|f| f.name.clone()).collect();
      metadata.classes = tree.classes.iter().map(|c| c.name.clone()).collect();
      metadata.function_count = metadata.functions.len() as u64;
      metadata.class_count = metadata.classes.len() as u64;
      metadata.imports = tree.imports.clone();
      metadata.exports = tree.exports.clone();
    }

    if let Some(dep_analysis) = &universal_result.dependency_analysis {
      metadata.dependencies = dep_analysis.dependencies.clone();
      metadata.dependency_count = dep_analysis.dependencies.len();
    }
    
    Ok(metadata)
  }

  fn parse_timestamp(timestamp: &str) -> u64 {
    chrono::DateTime::parse_from_rfc3339(timestamp)
      .map(|dt| dt.timestamp() as u64)
      .unwrap_or_default()
  }

  fn parse_float(value: &str) -> f64 {
    value.parse::<f64>().unwrap_or_default()
  }

  /// Process Python-specific data
  fn process_python_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    if let Some(python_data) = language_specific.get("python") {
      if let Ok(python_analysis) = serde_json::from_value::<python_parser::PythonAnalysisResult>(python_data.clone()) {
        // Extract framework information
        for framework in &python_analysis.framework_info.detected_frameworks {
          metadata.patterns.push(format!("framework:{}", framework));
        }
        
        // Extract security analysis
        for vulnerability in &python_analysis.security_analysis.vulnerabilities {
          metadata.security_characteristics.push(vulnerability.vulnerability_type.clone());
        }
        
        // Extract function and class counts
        metadata.function_count = python_analysis.language_features.function_count;
        metadata.class_count = python_analysis.language_features.class_count;
      }
    }
    Ok(())
  }

  /// Process JavaScript-specific data
  fn process_javascript_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    if let Some(js_data) = language_specific.get("javascript") {
      if let Ok(js_analysis) = serde_json::from_value::<javascript_parser::JavaScriptSpecificAnalysis>(js_data.clone()) {
        // Extract framework hints
        for framework in &js_analysis.framework_hints {
          metadata.patterns.push(format!("framework:{}", framework));
        }
        
        // Extract ES version
        metadata.features.push(format!("es_version:{}", js_analysis.es_version));
        
        // Extract function and class counts
        metadata.function_count = js_analysis.function_count as u64;
        metadata.class_count = js_analysis.class_count as u64;
      }
    }
    Ok(())
  }

  /// Process TypeScript-specific data
  fn process_typescript_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    // Similar to JavaScript but with TypeScript-specific features
    self.process_javascript_specific_data(metadata, language_specific)?;
    
    // Add TypeScript-specific features
    metadata.features.push("typescript".to_string());
    metadata.features.push("type_safety".to_string());
    
    Ok(())
  }

  /// Process Go-specific data
  fn process_go_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    if let Some(go_data) = language_specific.get("go") {
      if let Ok(go_analysis) = serde_json::from_value::<go_parser::GoSpecificAnalysis>(go_data.clone()) {
        // Extract Go-specific patterns
        if go_analysis.concurrency_patterns.get("goroutines").unwrap_or(&false) {
          metadata.patterns.push("goroutines".to_string());
        }
        if go_analysis.concurrency_patterns.get("channels").unwrap_or(&false) {
          metadata.patterns.push("channels".to_string());
        }
        
        // Extract function and struct counts
        metadata.function_count = go_analysis.function_count;
        metadata.struct_count = go_analysis.struct_count;
        metadata.interface_count = go_analysis.interface_count;
      }
    }
    Ok(())
  }

  /// Process Java-specific data
  fn process_java_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    if let Some(java_data) = language_specific.get("java") {
      if let Ok(java_analysis) = serde_json::from_value::<java_parser::JavaSpecificAnalysis>(java_data.clone()) {
        // Extract Java-specific patterns
        if java_analysis.oop_patterns.get("inheritance").unwrap_or(&false) {
          metadata.patterns.push("inheritance".to_string());
        }
        if java_analysis.oop_patterns.get("polymorphism").unwrap_or(&false) {
          metadata.patterns.push("polymorphism".to_string());
        }
        
        // Extract function and class counts
        metadata.function_count = java_analysis.method_count;
        metadata.class_count = java_analysis.class_count;
        metadata.interface_count = java_analysis.interface_count;
      }
    }
    Ok(())
  }

  /// Process C#-specific data
  fn process_csharp_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    if let Some(csharp_data) = language_specific.get("csharp") {
      if let Ok(csharp_analysis) = serde_json::from_value::<csharp_parser::CSharpSpecificAnalysis>(csharp_data.clone()) {
        // Extract C#-specific patterns
        if csharp_analysis.oop_patterns.get("inheritance").unwrap_or(&false) {
          metadata.patterns.push("inheritance".to_string());
        }
        if csharp_analysis.oop_patterns.get("polymorphism").unwrap_or(&false) {
          metadata.patterns.push("polymorphism".to_string());
        }
        
        // Extract function and class counts
        metadata.function_count = csharp_analysis.method_count;
        metadata.class_count = csharp_analysis.class_count;
        metadata.interface_count = csharp_analysis.interface_count;
      }
    }
    Ok(())
  }

  /// Extract basic counts for unsupported languages
  fn extract_basic_counts(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    // Try to extract basic counts from any language-specific data
    for (lang, data) in language_specific {
      if let Ok(counts) = serde_json::from_value::<std::collections::HashMap<String, u64>>(data.clone()) {
        if let Some(func_count) = counts.get("function_count") {
          metadata.function_count = *func_count;
        }
        if let Some(class_count) = counts.get("class_count") {
          metadata.class_count = *class_count;
        }
        if let Some(struct_count) = counts.get("struct_count") {
          metadata.struct_count = *struct_count;
        }
        break;
      }
    }
    Ok(())
  }

}

impl Default for AnalysisEngine {
  fn default() -> Self {
    Self::new()
  }
}
