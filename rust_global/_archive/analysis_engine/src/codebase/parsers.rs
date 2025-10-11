//! Parser interface for codebase

use crate::codebase::metadata::CodebaseMetadata;
use anyhow::Result;

/// Trait for parsers to return CodebaseMetadata
pub trait CodebaseParser {
  /// Parse file content and return CodebaseMetadata
  async fn parse(&self, path: &str, content: &str) -> Result<CodebaseMetadata>;
  
  /// Get supported language
  fn language(&self) -> &str;
}

/// Simple parser coordinator for codebase analysis
pub struct ParserCoordinator {
  /// Analysis cache
  cache: std::collections::HashMap<String, CodeMetadata>,
}

impl ParserCoordinator {
  /// Create new parser coordinator
  pub fn new() -> Self {
    Self {
      cache: std::collections::HashMap::new(),
    }
  }

  /// Parse content and return CodebaseMetadata
  pub async fn parse(&self, path: &str, content: &str) -> Result<CodebaseMetadata> {
    let mut metadata = CodebaseMetadata::default();
    
    // Basic analysis
    metadata.path = path.to_string();
    metadata.size = content.len() as u64;
    metadata.lines = content.lines().count();
    metadata.total_lines = content.lines().count() as u64;
    
    // Language detection
    metadata.language = self.detect_language(path);
    
    // Basic metrics
    metadata.function_count = self.count_functions(content);
    metadata.class_count = self.count_classes(content);
    metadata.cyclomatic_complexity = self.calculate_complexity(content);
    
    Ok(metadata)
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
    content.matches("class ").count() as u64 +
    content.matches("struct ").count() as u64 +
    content.matches("impl ").count() as u64
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
}

impl Default for ParserCoordinator {
  fn default() -> Self {
    Self::new()
  }
}
