//! Analysis engine for codebase

use crate::codebase::metadata::{CodebaseMetadata, FileAnalysis};
// CodebaseDatabase removed - NIF doesn't need storage
use crate::codebase::config::CodebaseConfig;
use crate::codebase::parser_registry::{ParserRegistry, ExpectedAnalysisFields, ParserRegistryEntry, ParserSpecificConfig};
use anyhow::Result;
use sha2::{Sha256, Digest};

// Universal parser and individual parser imports
use rust_parser::RustParser;
use python_parser::PythonParser;
use javascript_parser::JavascriptParser;
use typescript_parser::TypescriptParser;
use elixir_parser::ElixirParser;
use gleam_parser::GleamParser;

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
    // Get expected fields for this parser
    let expected_fields = self.parser_registry.get_expected_fields(parser_id)
      .ok_or_else(|| anyhow::anyhow!("Parser '{}' not registered", parser_id))?;

    // Perform analysis based on parser capabilities
    self.analyze_file_with_expectations(path, content, expected_fields).await
  }

  /// Analyze file content using universal parser and return CodebaseMetadata
  pub async fn analyze_file(&self, path: &str, content: &str) -> Result<CodebaseMetadata> {
    // Check if already cached
    let content_hash = self.calculate_hash(content);
    if self.database.is_cached(path, &content_hash).await {
      if let Some(metadata) = self.database.get_metadata(path).await {
        return Ok(metadata);
      }
    }

    // Use universal parser for comprehensive analysis
    let language = self.detect_language_from_path(path);
    let universal_result = self.analyze_with_universal_parser(content, language, path).await?;
    
    // Convert universal parser result to CodebaseMetadata
    let metadata = self.convert_universal_to_metadata(&universal_result, path, content)?;
    
    // Store in database
    self.database.store_metadata(path.to_string(), metadata.clone()).await?;
    
    // Create file analysis
    let file_analysis = FileAnalysis {
      path: path.to_string(),
      metadata: metadata.clone(),
      analyzed_at: chrono::Utc::now().timestamp() as u64,
      content_hash,
    };
    
    self.database.store_file_analysis(file_analysis).await?;
    
    Ok(metadata)
  }

  /// Analyze file content with specific field expectations
  async fn analyze_file_with_expectations(&self, path: &str, content: &str, expected_fields: &ExpectedAnalysisFields) -> Result<CodebaseMetadata> {
    // Check if already cached
    let content_hash = self.calculate_hash(content);
    if self.database.is_cached(path, &content_hash).await {
      if let Some(metadata) = self.database.get_metadata(path).await {
        return Ok(metadata);
      }
    }

    // Perform analysis based on expected fields
    let mut metadata = CodebaseMetadata::default();
    
    // Basic analysis (always available)
    metadata.path = path.to_string();
    metadata.size = content.len() as u64;
    metadata.lines = content.lines().count();
    metadata.total_lines = content.lines().count() as u64;
    metadata.language = self.detect_language(path);
    
    // Symbol extraction (if expected)
    if expected_fields.symbols.functions {
      metadata.function_count = self.count_functions(content);
      metadata.functions = self.extract_functions(content);
    }
    if expected_fields.symbols.classes {
      metadata.class_count = self.count_classes(content);
      metadata.classes = self.extract_classes(content);
    }
    if expected_fields.symbols.structs {
      metadata.struct_count = self.count_structs(content);
      metadata.structs = self.extract_structs(content);
    }
    if expected_fields.symbols.enums {
      metadata.enum_count = self.count_enums(content);
      metadata.enums = self.extract_enums(content);
    }
    if expected_fields.symbols.traits {
      metadata.trait_count = self.count_traits(content);
      metadata.traits = self.extract_traits(content);
    }
    
    // Complexity analysis (if expected)
    if expected_fields.complexity.cyclomatic_complexity {
      metadata.cyclomatic_complexity = self.calculate_complexity(content);
    }
    if expected_fields.complexity.cognitive_complexity {
      metadata.cognitive_complexity = self.calculate_cognitive_complexity(content);
    }
    
    // Line analysis (if expected)
    if expected_fields.basic_info {
      metadata.code_lines = self.count_code_lines(content);
      metadata.comment_lines = self.count_comment_lines(content);
      metadata.blank_lines = self.count_blank_lines(content);
    }
    
    // Store in database
    self.database.store_metadata(path.to_string(), metadata.clone()).await?;
    
    // Create file analysis
    let file_analysis = FileAnalysis {
      path: path.to_string(),
      metadata: metadata.clone(),
      analyzed_at: chrono::Utc::now().timestamp() as u64,
      content_hash,
    };
    
    self.database.store_file_analysis(file_analysis).await?;
    
    Ok(metadata)
  }

  /// Get the database reference
  pub fn database(&self) -> &CodebaseDatabase {
    &self.database
  }

  /// Calculate content hash
  fn calculate_hash(&self, content: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    format!("{:x}", hasher.finalize())
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

  /// Count functions in content
  fn count_functions(&self, content: &str) -> u64 {
    content.matches("fn ").count() as u64 +
    content.matches("function ").count() as u64 +
    content.matches("def ").count() as u64 +
    content.matches("func ").count() as u64
  }

  /// Count classes in content
  fn count_classes(&self, content: &str) -> u64 {
    content.matches("class ").count() as u64
  }

  /// Count structs in content
  fn count_structs(&self, content: &str) -> u64 {
    content.matches("struct ").count() as u64
  }

  /// Count enums in content
  fn count_enums(&self, content: &str) -> u64 {
    content.matches("enum ").count() as u64
  }

  /// Count traits in content
  fn count_traits(&self, content: &str) -> u64 {
    content.matches("trait ").count() as u64 +
    content.matches("interface ").count() as u64
  }

  /// Count code lines (non-empty, non-comment)
  fn count_code_lines(&self, content: &str) -> u64 {
    content.lines()
      .filter(|line| {
        let trimmed = line.trim();
        !trimmed.is_empty() && !trimmed.starts_with("//") && !trimmed.starts_with("#")
      })
      .count() as u64
  }

  /// Count comment lines
  fn count_comment_lines(&self, content: &str) -> u64 {
    content.lines()
      .filter(|line| {
        let trimmed = line.trim();
        trimmed.starts_with("//") || trimmed.starts_with("#") || trimmed.starts_with("/*")
      })
      .count() as u64
  }

  /// Count blank lines
  fn count_blank_lines(&self, content: &str) -> u64 {
    content.lines()
      .filter(|line| line.trim().is_empty())
      .count() as u64
  }

  /// Calculate cyclomatic complexity
  fn calculate_complexity(&self, content: &str) -> f64 {
    let mut complexity = 1.0;
    
    complexity += content.matches("if ").count() as f64;
    complexity += content.matches("while ").count() as f64;
    complexity += content.matches("for ").count() as f64;
    complexity += content.matches("switch ").count() as f64;
    complexity += content.matches("case ").count() as f64;
    complexity += content.matches("&&").count() as f64;
    complexity += content.matches("||").count() as f64;
    
    complexity
  }

  /// Calculate cognitive complexity
  fn calculate_cognitive_complexity(&self, content: &str) -> f64 {
    let mut complexity = 0.0;
    
    // Base complexity for control structures
    complexity += content.matches("if ").count() as f64;
    complexity += content.matches("while ").count() as f64;
    complexity += content.matches("for ").count() as f64;
    
    // Additional complexity for nesting
    let mut nesting_level = 0;
    for line in content.lines() {
      let trimmed = line.trim();
      if trimmed.contains("{") {
        nesting_level += 1;
      }
      if trimmed.contains("}") {
        nesting_level = nesting_level.saturating_sub(1);
      }
      complexity += nesting_level as f64 * 0.1; // Small penalty for nesting
    }
    
    complexity
  }

  /// Analyze content using universal parser
  async fn analyze_with_universal_parser(
    &self,
    content: &str,
    language: parser_code::ProgrammingLanguage,
    file_path: &str,
  ) -> Result<parser_code::AnalysisResult, String> {
    use parser_core::ProgrammingLanguage;

    match language {
      ProgrammingLanguage::Rust => {
        match rust_parser::RustParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path).await.map_err(|e| format!("Rust parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Rust parser: {}", e)),
        }
      }
      ProgrammingLanguage::Python => {
        match python_parser::PythonParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path).await.map_err(|e| format!("Python parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Python parser: {}", e)),
        }
      }
      ProgrammingLanguage::JavaScript => {
        match javascript_parser::JavascriptParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path).await.map_err(|e| format!("JavaScript parser error: {}", e)),
          Err(e) => Err(format!("Failed to create JavaScript parser: {}", e)),
        }
      }
      ProgrammingLanguage::TypeScript => {
        match typescript_parser::TypescriptParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path).await.map_err(|e| format!("TypeScript parser error: {}", e)),
          Err(e) => Err(format!("Failed to create TypeScript parser: {}", e)),
        }
      }
      // Unsupported languages - no dedicated parsers available
      // ProgrammingLanguage::Go |
      // ProgrammingLanguage::Java |
      // ProgrammingLanguage::CSharp |
      // ProgrammingLanguage::C |
      // ProgrammingLanguage::Cpp |
      // ProgrammingLanguage::Erlang => {
      //   // No dedicated parsers - return error or use fallback
      // }
      ProgrammingLanguage::Elixir => {
        match elixir_parser::ElixirParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path).await.map_err(|e| format!("Elixir parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Elixir parser: {}", e)),
        }
      }
      ProgrammingLanguage::Gleam => {
        match gleam_parser::GleamParser::new() {
          Ok(parser) => parser.analyze_content(content, file_path).await.map_err(|e| format!("Gleam parser error: {}", e)),
          Err(e) => Err(format!("Failed to create Gleam parser: {}", e)),
        }
      }
      _ => Err(format!("Unsupported language: {:?}", language)),
    }
  }

  /// Convert universal parser result to CodebaseMetadata
  fn convert_universal_to_metadata(
    &self,
    universal_result: &parser_code::AnalysisResult,
    path: &str,
    content: &str,
  ) -> Result<CodebaseMetadata, String> {
    let mut metadata = CodebaseMetadata::default();
    
    // Basic file info
    metadata.path = path.to_string();
    metadata.size = content.len() as u64;
    metadata.lines = content.lines().count();
    metadata.language = universal_result.language.to_string();
    metadata.last_modified = universal_result.timestamp.timestamp() as u64;
    
    // Line metrics from universal parser
    metadata.total_lines = universal_result.line_metrics.total_lines;
    metadata.code_lines = universal_result.line_metrics.code_lines;
    metadata.comment_lines = universal_result.line_metrics.comment_lines;
    metadata.blank_lines = universal_result.line_metrics.blank_lines;
    
    // Complexity metrics from universal parser
    metadata.cyclomatic_complexity = universal_result.complexity_metrics.cyclomatic;
    metadata.cognitive_complexity = universal_result.complexity_metrics.cognitive;
    metadata.nesting_depth = universal_result.complexity_metrics.nesting_depth;
    
    // Halstead metrics from universal parser
    metadata.halstead_vocabulary = universal_result.halstead_metrics.unique_operators + universal_result.halstead_metrics.unique_operands;
    metadata.halstead_length = universal_result.halstead_metrics.total_operators + universal_result.halstead_metrics.total_operands;
    metadata.halstead_volume = universal_result.halstead_metrics.volume;
    metadata.halstead_difficulty = universal_result.halstead_metrics.difficulty;
    metadata.halstead_effort = universal_result.halstead_metrics.effort;
    
    // Maintainability metrics from universal parser
    metadata.maintainability_index = universal_result.maintainability_metrics.index;
    metadata.technical_debt_ratio = universal_result.maintainability_metrics.technical_debt_ratio;
    metadata.duplication_percentage = universal_result.maintainability_metrics.duplication_percentage;
    
    // Extract language-specific data
    self.extract_language_specific_data(&mut metadata, universal_result)?;
    
    Ok(metadata)
  }

  /// Extract language-specific data from universal parser result
  fn extract_language_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    universal_result: &parser_code::AnalysisResult,
  ) -> Result<(), String> {
    // Process language-specific data for each supported language
    match universal_result.language {
      parser_code::ProgrammingLanguage::Rust => {
        self.process_rust_specific_data(metadata, &universal_result.language_specific)?;
      }
      parser_code::ProgrammingLanguage::Python => {
        self.process_python_specific_data(metadata, &universal_result.language_specific)?;
      }
      parser_code::ProgrammingLanguage::JavaScript => {
        self.process_javascript_specific_data(metadata, &universal_result.language_specific)?;
      }
      parser_code::ProgrammingLanguage::TypeScript => {
        self.process_typescript_specific_data(metadata, &universal_result.language_specific)?;
      }
      parser_code::ProgrammingLanguage::Go => {
        self.process_go_specific_data(metadata, &universal_result.language_specific)?;
      }
      parser_code::ProgrammingLanguage::Java => {
        self.process_java_specific_data(metadata, &universal_result.language_specific)?;
      }
      parser_code::ProgrammingLanguage::CSharp => {
        self.process_csharp_specific_data(metadata, &universal_result.language_specific)?;
      }
      _ => {
        // For unsupported languages, just extract basic counts
        self.extract_basic_counts(metadata, &universal_result.language_specific)?;
      }
    }
    
    Ok(())
  }

  /// Process Rust-specific data
  fn process_rust_specific_data(
    &self,
    metadata: &mut CodebaseMetadata,
    language_specific: &std::collections::HashMap<String, serde_json::Value>,
  ) -> Result<(), String> {
    if let Some(rust_data) = language_specific.get("rust") {
      if let Ok(rust_analysis) = serde_json::from_value::<rust_parser::RustSpecificAnalysis>(rust_data.clone()) {
        // Extract Rust-specific patterns
        if rust_analysis.ownership_patterns.get("borrowing").unwrap_or(&false) {
          metadata.patterns.push("borrowing".to_string());
        }
        if rust_analysis.concurrency_patterns.get("async").unwrap_or(&false) {
          metadata.patterns.push("async".to_string());
        }
        if rust_analysis.memory_safety.get("unsafe_code").unwrap_or(&false) {
          metadata.security_characteristics.push("unsafe_code".to_string());
        }
        
        // Extract function and struct counts from Rust analysis
        metadata.function_count = rust_analysis.function_count;
        metadata.struct_count = rust_analysis.struct_count;
        metadata.enum_count = rust_analysis.enum_count;
        metadata.trait_count = rust_analysis.trait_count;
      }
    }
    Ok(())
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

  /// Detect language from file path
  fn detect_language_from_path(&self, path: &str) -> parser_code::ProgrammingLanguage {
    use parser_core::ProgrammingLanguage;
    
    let extension = std::path::Path::new(path)
      .extension()
      .and_then(|ext| ext.to_str())
      .unwrap_or("")
      .to_lowercase();
    
    match extension.as_str() {
      "rs" => ProgrammingLanguage::Rust,
      "py" => ProgrammingLanguage::Python,
      "js" | "jsx" | "mjs" | "cjs" => ProgrammingLanguage::JavaScript,
      "ts" | "tsx" => ProgrammingLanguage::TypeScript,
      "go" => ProgrammingLanguage::Go,
      "java" => ProgrammingLanguage::Java,
      "cs" => ProgrammingLanguage::CSharp,
      "c" => ProgrammingLanguage::C,
      "cpp" | "cc" | "cxx" | "hpp" => ProgrammingLanguage::Cpp,
      "erl" => ProgrammingLanguage::Erlang,
      "ex" | "exs" => ProgrammingLanguage::Elixir,
      "gleam" => ProgrammingLanguage::Gleam,
      _ => ProgrammingLanguage::Unknown,
    }
  }
}

impl Default for AnalysisEngine {
  fn default() -> Self {
    Self::new()
  }
}
