//! Analysis engine for codebase

use crate::codebase::metadata::{CodebaseMetadata, FileAnalysis};
use crate::codebase::storage::CodebaseDatabase;
use crate::codebase::config::CodebaseConfig;
use crate::codebase::parser_registry::{ParserRegistry, ExpectedAnalysisFields, ParserRegistryEntry, ParserSpecificConfig};
use anyhow::Result;
use sha2::{Sha256, Digest};

// Universal parser types (for language enum only - no direct parser calls)
use universal_parser::ProgrammingLanguage;

/// Core analysis engine that uses the clean CodebaseDatabase
pub struct AnalysisEngine {
  /// The single source of truth database
  database: CodebaseDatabase,
  /// Configuration for codebase-specific features
  config: CodebaseConfig,
  /// Parser registry for capability-aware analysis
  parser_registry: ParserRegistry,
}

impl AnalysisEngine {
  /// Create new analysis engine with default config
  pub fn new() -> Self {
    Self {
      database: CodebaseDatabase::new(),
      config: CodebaseConfig::default(),
      parser_registry: ParserRegistry::new(),
    }
  }

  /// Create analysis engine with configuration
  pub fn with_config(config: CodebaseConfig) -> Self {
    Self {
      database: CodebaseDatabase::new(),
      config,
      parser_registry: ParserRegistry::new(),
    }
  }

  /// Create analysis engine with existing database and config
  pub fn with_database_and_config(database: CodebaseDatabase, config: CodebaseConfig) -> Self {
    Self { 
      database,
      config,
      parser_registry: ParserRegistry::new(),
    }
  }

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

  /// Analyze file content using pre-parsed AST data from database
  pub async fn analyze_file(&self, path: &str, content: &str) -> Result<CodebaseMetadata> {
    // Check if already cached
    let content_hash = self.calculate_hash(content);
    if self.database.is_cached(path, &content_hash).await {
      if let Some(metadata) = self.database.get_metadata(path).await {
        return Ok(metadata);
      }
    }

    // AST data should be read from database by the calling Elixir code
    // The parser_engine_nif populates ast_functions, ast_classes, ast_imports, ast_exports columns
    return Err(anyhow::anyhow!("AST data must be provided from database. Use analyze_file_with_ast_data() instead."));
  }

  /// Analyze file content with pre-parsed AST data from database
  pub async fn analyze_file_with_ast_data(
    &self,
    path: &str,
    content: &str,
    ast_functions: Option<serde_json::Value>,
    ast_classes: Option<serde_json::Value>,
    ast_imports: Option<serde_json::Value>,
    ast_exports: Option<serde_json::Value>,
  ) -> Result<CodebaseMetadata> {
    // Check if already cached
    let content_hash = self.calculate_hash(content);
    if self.database.is_cached(path, &content_hash).await {
      if let Some(metadata) = self.database.get_metadata(path).await {
        return Ok(metadata);
      }
    }

    // Convert AST data to CodebaseMetadata
    let metadata = self.convert_ast_to_metadata(path, content, ast_functions, ast_classes, ast_imports, ast_exports)?;

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
    _content: &str,
    _language: universal_parser::ProgrammingLanguage,
    _file_path: &str,
  ) -> Result<serde_json::Value, String> {
    // Parser integration has been decoupled. AST data should be read from the database
    // where it was populated by the standalone parser_engine_nif.
    Err("AST data should be read from database (ast_functions, ast_classes, ast_imports, ast_exports columns in code_files table). Parser is now a standalone NIF that populates the database.".to_string())
  }

  /// Convert AST data from database to CodebaseMetadata
  fn convert_ast_to_metadata(
    &self,
    path: &str,
    content: &str,
    ast_functions: Option<serde_json::Value>,
    ast_classes: Option<serde_json::Value>,
    ast_imports: Option<serde_json::Value>,
    ast_exports: Option<serde_json::Value>,
  ) -> Result<CodebaseMetadata> {
    let mut metadata = CodebaseMetadata::default();

    // Basic file info
    metadata.path = path.to_string();
    metadata.size = content.len() as u64;
    metadata.language = self.detect_language_from_path(path);

    // Calculate basic metrics from content
    metadata.lines_of_code = content.lines().count() as u64;
    metadata.complexity = self.calculate_complexity(content);

    // Extract data from AST JSONB columns
    if let Some(functions) = ast_functions {
      if let Ok(func_array) = serde_json::from_value::<Vec<serde_json::Value>>(functions) {
        metadata.function_count = func_array.len() as u64;
        // Extract function names for patterns
        for func in func_array {
          if let Some(name) = func.get("name").and_then(|n| n.as_str()) {
            metadata.function_names.push(name.to_string());
          }
        }
      }
    }

    if let Some(classes) = ast_classes {
      if let Ok(class_array) = serde_json::from_value::<Vec<serde_json::Value>>(classes) {
        metadata.class_count = class_array.len() as u64;
        // Extract class names
        for class in class_array {
          if let Some(name) = class.get("name").and_then(|n| n.as_str()) {
            metadata.class_names.push(name.to_string());
          }
        }
      }
    }

    if let Some(imports) = ast_imports {
      if let Ok(import_array) = serde_json::from_value::<Vec<serde_json::Value>>(imports) {
        metadata.import_count = import_array.len() as u64;
      }
    }

    if let Some(exports) = ast_exports {
      if let Ok(export_array) = serde_json::from_value::<Vec<serde_json::Value>>(exports) {
        metadata.export_count = export_array.len() as u64;
      }
    }

    // Extract patterns and characteristics from AST data
    self.extract_patterns_from_ast(&mut metadata, ast_functions, ast_classes, ast_imports, ast_exports)?;

    Ok(metadata)
  }

  /// Extract patterns and characteristics from AST data
  fn extract_patterns_from_ast(
    &self,
    metadata: &mut CodebaseMetadata,
    _ast_functions: Option<serde_json::Value>,
    _ast_classes: Option<serde_json::Value>,
    _ast_imports: Option<serde_json::Value>,
    _ast_exports: Option<serde_json::Value>,
  ) -> Result<()> {
    // TODO: Extract patterns from AST data based on language-specific analysis
    // This would analyze the AST structure to identify patterns like:
    // - Design patterns (Singleton, Factory, Observer, etc.)
    // - Architecture patterns (MVC, layered, etc.)
    // - Code smells and anti-patterns
    // - Security patterns and vulnerabilities

    // For now, extract basic patterns from function/class names and content
    let language = metadata.language.clone();

    // Language-specific pattern extraction
    match language {
      universal_parser::ProgrammingLanguage::Rust => {
        self.extract_rust_patterns(metadata)?;
      }
      universal_parser::ProgrammingLanguage::Python => {
        self.extract_python_patterns(metadata)?;
      }
      universal_parser::ProgrammingLanguage::JavaScript | universal_parser::ProgrammingLanguage::TypeScript => {
        self.extract_js_patterns(metadata)?;
      }
      _ => {
        // Basic pattern extraction for other languages
        self.extract_basic_patterns(metadata)?;
      }
    }

    Ok(())
  }

  /// Extract Rust-specific patterns
  fn extract_rust_patterns(&self, _metadata: &mut CodebaseMetadata) -> Result<()> {
    // TODO: Implement Rust pattern extraction from AST data
    Ok(())
  }

  /// Extract Python-specific patterns
  fn extract_python_patterns(&self, _metadata: &mut CodebaseMetadata) -> Result<()> {
    // TODO: Implement Python pattern extraction from AST data
    Ok(())
  }

  /// Extract JavaScript/TypeScript-specific patterns
  fn extract_js_patterns(&self, _metadata: &mut CodebaseMetadata) -> Result<()> {
    // TODO: Implement JS/TS pattern extraction from AST data
    Ok(())
  }

  /// Extract basic patterns for other languages
  fn extract_basic_patterns(&self, _metadata: &mut CodebaseMetadata) -> Result<()> {
    // TODO: Implement basic pattern extraction
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
  fn detect_language_from_path(&self, path: &str) -> universal_parser::ProgrammingLanguage {
    use universal_parser::ProgrammingLanguage;
    
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
