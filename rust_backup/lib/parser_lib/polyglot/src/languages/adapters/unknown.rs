use anyhow::Result;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::{
  dependencies::UniversalDependencies,
  interfaces::{ParserCapabilities, ParserMetadata, PerformanceCharacteristics, UniversalParser},
  languages::ProgrammingLanguage,
  AnalysisResult,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnknownLanguageAnalysis {
  pub basic_metrics: BasicMetrics,
  pub detected_patterns: Vec<String>,
  pub file_info: FileInfo,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BasicMetrics {
  pub lines_of_code: usize,
  pub lines_of_comments: usize,
  pub blank_lines: usize,
  pub total_lines: usize,
  pub estimated_complexity: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileInfo {
  pub extension: String,
  pub size_bytes: usize,
  pub encoding_hint: String,
  pub language_hint: String,
}

pub struct UnknownLanguageParser {
  dependencies: UniversalDependencies,
}

#[async_trait]
impl UniversalParser for UnknownLanguageParser {
  type Config = ();
  type ProgrammingLanguageSpecific = UnknownLanguageAnalysis;

  fn new() -> Result<Self> {
    Ok(Self { dependencies: UniversalDependencies::new()? })
  }

  fn new_with_config(_config: Self::Config) -> Result<Self> {
    Self::new()
  }

  async fn analyze_content(&self, content: &str, file_path: &str) -> Result<AnalysisResult> {
    let _unknown_specific = self.analyze_unknown_language(content, file_path)?;

    let result = self
      .dependencies
      .analyze_with_all_tools(content, ProgrammingLanguage::Unknown, file_path)
      .await?;
    // Store unknown language-specific analysis in tree_sitter_analysis
    // result.tree_sitter_analysis.language_specific = Some(serde_json::to_value(unknown_specific)?);

    Ok(result)
  }

  async fn extract_language_specific(&self, content: &str, file_path: &str) -> Result<Self::ProgrammingLanguageSpecific> {
    self.analyze_unknown_language(content, file_path)
  }

  fn get_metadata(&self) -> ParserMetadata {
    let capabilities = ParserCapabilities {
      pattern_detection: true,
      complexity_analysis: true,
      symbol_extraction: true,
      ..Default::default()
    };

    ParserMetadata {
      parser_name: "Unknown Language Parser".to_string(),
      version: crate::UNIVERSAL_PARSER_VERSION.to_string(),
      supported_languages: vec![ProgrammingLanguage::Unknown],
      supported_extensions: vec!["*".to_string()], // All extensions
      capabilities,
      performance: PerformanceCharacteristics::default(),
    }
  }

  fn get_current_config(&self) -> &Self::Config {
    &()
  }
}

impl UnknownLanguageParser {
  fn analyze_unknown_language(&self, content: &str, file_path: &str) -> Result<UnknownLanguageAnalysis> {
    let lines: Vec<&str> = content.lines().collect();
    let total_lines = lines.len();
    
    let mut lines_of_code = 0;
    let mut lines_of_comments = 0;
    let mut blank_lines = 0;
    
    for line in lines {
      let trimmed = line.trim();
      if trimmed.is_empty() {
        blank_lines += 1;
      } else if self.is_comment_line(trimmed) {
        lines_of_comments += 1;
      } else {
        lines_of_code += 1;
      }
    }
    
    let extension = self.extract_extension(file_path);
    let size_bytes = content.len();
    let encoding_hint = self.detect_encoding(content);
    let language_hint = self.guess_language_from_content(content, &extension);
    
    let detected_patterns = self.detect_patterns(content);
    let estimated_complexity = self.estimate_complexity(content);
    
    Ok(UnknownLanguageAnalysis {
      basic_metrics: BasicMetrics {
        lines_of_code,
        lines_of_comments,
        blank_lines,
        total_lines,
        estimated_complexity,
      },
      detected_patterns,
      file_info: FileInfo {
        extension,
        size_bytes,
        encoding_hint,
        language_hint,
      },
    })
  }
  
  fn is_comment_line(&self, line: &str) -> bool {
    // Common comment patterns across languages
    let comment_prefixes = [
      "//", "/*", "#", "<!--", "%", ";", "--", "REM", "rem", 
      "'", "\"", "!\"", "c ", "C ", "*", "!"
    ];
    
    for prefix in &comment_prefixes {
      if line.starts_with(prefix) {
        return true;
      }
    }
    
    false
  }
  
  fn extract_extension(&self, file_path: &str) -> String {
    if let Some(pos) = file_path.rfind('.') {
      file_path[pos + 1..].to_lowercase()
    } else {
      "unknown".to_string()
    }
  }
  
  fn detect_encoding(&self, content: &str) -> String {
    // Simple encoding detection based on byte patterns
    if content.contains('\u{FFFE}') || content.contains('\u{FEFF}') {
      "UTF-16".to_string()
    } else if content.chars().any(|c| c as u32 > 127) {
      "UTF-8".to_string()
    } else {
      "ASCII".to_string()
    }
  }
  
  fn guess_language_from_content(&self, content: &str, extension: &str) -> String {
    // Language detection based on content patterns and extensions
    let patterns = [
      ("function", "JavaScript/TypeScript"),
      ("def ", "Python"),
      ("fn ", "Rust"),
      ("func ", "Go"),
      ("class ", "Java/C#/JavaScript"),
      ("package ", "Java/Go"),
      ("import ", "Python/JavaScript"),
      ("require(", "JavaScript"),
      ("<?php", "PHP"),
      ("<!DOCTYPE", "HTML"),
      ("<html", "HTML"),
      ("<div", "HTML"),
      ("SELECT ", "SQL"),
      ("CREATE TABLE", "SQL"),
      ("#include", "C/C++"),
      ("main(", "C/C++/Java"),
      ("module ", "Elixir/Erlang"),
      ("defmodule ", "Elixir"),
      ("pub fn", "Rust"),
      ("let ", "Rust/JavaScript"),
      ("const ", "JavaScript/TypeScript"),
      ("var ", "JavaScript"),
    ];
    
    for (pattern, language) in &patterns {
      if content.contains(pattern) {
        return language.to_string();
      }
    }
    
    // Extension-based detection
    match extension {
      "js" | "mjs" | "cjs" => "JavaScript".to_string(),
      "ts" | "tsx" => "TypeScript".to_string(),
      "py" => "Python".to_string(),
      "rs" => "Rust".to_string(),
      "go" => "Go".to_string(),
      "java" => "Java".to_string(),
      "cs" => "C#".to_string(),
      "php" => "PHP".to_string(),
      "html" | "htm" => "HTML".to_string(),
      "css" => "CSS".to_string(),
      "sql" => "SQL".to_string(),
      "c" | "h" => "C".to_string(),
      "cpp" | "cc" | "cxx" | "hpp" => "C++".to_string(),
      "ex" | "exs" => "Elixir".to_string(),
      "erl" => "Erlang".to_string(),
      "gleam" => "Gleam".to_string(),
      "swift" => "Swift".to_string(),
      "kt" => "Kotlin".to_string(),
      "scala" => "Scala".to_string(),
      "hs" => "Haskell".to_string(),
      "clj" | "cljs" => "Clojure".to_string(),
      "rb" => "Ruby".to_string(),
      "sh" | "bash" => "Shell".to_string(),
      "ps1" => "PowerShell".to_string(),
      "yaml" | "yml" => "YAML".to_string(),
      "json" => "JSON".to_string(),
      "xml" => "XML".to_string(),
      "toml" => "TOML".to_string(),
      "ini" => "INI".to_string(),
      "md" | "markdown" => "Markdown".to_string(),
      _ => "Unknown".to_string(),
    }
  }
  
  fn detect_patterns(&self, content: &str) -> Vec<String> {
    let mut patterns = Vec::new();
    
    // Common programming patterns
    if content.contains("if ") || content.contains("if(") {
      patterns.push("Conditional Logic".to_string());
    }
    if content.contains("for ") || content.contains("while ") {
      patterns.push("Loops".to_string());
    }
    if content.contains("function") || content.contains("def ") || content.contains("fn ") {
      patterns.push("Functions".to_string());
    }
    if content.contains("class ") || content.contains("struct ") {
      patterns.push("Classes/Structures".to_string());
    }
    if content.contains("import ") || content.contains("require(") || content.contains("include") {
      patterns.push("Imports/Dependencies".to_string());
    }
    if content.contains("try ") || content.contains("catch ") || content.contains("except ") {
      patterns.push("Error Handling".to_string());
    }
    if content.contains("async ") || content.contains("await ") {
      patterns.push("Asynchronous Code".to_string());
    }
    if content.contains("test") || content.contains("spec") {
      patterns.push("Testing".to_string());
    }
    if content.contains("config") || content.contains("settings") {
      patterns.push("Configuration".to_string());
    }
    if content.contains("api") || content.contains("endpoint") {
      patterns.push("API".to_string());
    }
    if content.contains("database") || content.contains("db") || content.contains("sql") {
      patterns.push("Database".to_string());
    }
    
    patterns
  }
  
  fn estimate_complexity(&self, content: &str) -> f64 {
    let mut complexity = 1.0; // Base complexity
    
    // Count control flow structures
    let control_flow_patterns = [
      "if ", "if(", "else", "elif", "case ", "switch ", "match ",
      "for ", "while ", "do ", "loop ", "foreach",
      "try ", "catch ", "except ", "finally",
      "&&", "||", "and ", "or ", "not ", "!"
    ];
    
    for pattern in &control_flow_patterns {
      let count = content.matches(pattern).count();
      complexity += count as f64 * 0.5;
    }
    
    // Count nesting indicators (basic heuristic)
    let nesting_indicators = ["{", "}", "(", ")", "[", "]"];
    let mut nesting_score = 0.0;
    for indicator in &nesting_indicators {
      nesting_score += content.matches(indicator).count() as f64;
    }
    complexity += nesting_score * 0.1;
    
    // Normalize complexity
    complexity.clamp(1.0, 100.0)
  }
}