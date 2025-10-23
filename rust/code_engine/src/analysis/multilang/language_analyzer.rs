//! Language Analysis
//!
//! Multi-language code analysis using the centralized language registry and semantic tokenizers.
//!
//! This module analyzes code across 18+ languages by combining:
//! - **Language Registry**: Centralized metadata (IDs, families, tool support)
//! - **Semantic Tokenizers**: Language-specific keyword-aware tokenization
//! - **Pattern Detection**: Bigram-based code structure analysis
//!
//! ## Design
//!
//! All language-specific logic is derived from the `parser_core::language_registry::LanguageInfo`:
//! - Language families (BEAM, Systems, Web, etc.) inform analysis strategies
//! - Tool support flags (RCA, AST-Grep) customize analysis pipeline
//! - Aliases enable flexible language name matching
//!
//! This ensures analysis scales with registry additions - no code changes needed.
//!
//! ## Supported Languages
//!
//! BEAM (3): Elixir, Erlang, Gleam
//! Systems (3): Rust, C, C++
//! Web (3): JavaScript, TypeScript, JSON
//! Dynamic (3): Python, Lua, Bash
//! Other (6+): Go, Java, YAML, SQL, Dockerfile, TOML, Markdown

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use crate::analysis::semantic::custom_tokenizers::SemanticTokenizer;

// Import language registry for centralized language metadata
use parser_core::language_registry::{LanguageRegistry, LANGUAGE_REGISTRY};

/// Extended language analysis result with registry metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageAnalysis {
  /// Language ID from registry (e.g., "rust", "elixir")
  pub language_id: String,
  /// Human-readable language name
  pub language_name: String,
  /// Language family (e.g., "BEAM", "Systems", "Web")
  pub family: Option<String>,
  /// Whether language supports RCA analysis
  pub rca_supported: bool,
  /// Whether language supports AST-Grep
  pub ast_grep_supported: bool,
  /// File count
  pub file_count: usize,
  /// Total lines
  pub total_lines: usize,
  /// Complexity score (0.0-1.0)
  pub complexity_score: f64,
  /// Quality score (0.0-1.0)
  pub quality_score: f64,
  /// Common patterns in code
  pub common_patterns: Vec<String>,
}

/// Multi-language analyzer using centralized registry and semantic tokenizers
#[derive(Debug, Clone)]
pub struct LanguageAnalyzer {
  /// Analysis results by language ID
  pub analysis: HashMap<String, LanguageAnalysis>,
  /// Reference to centralized language registry
  registry: &'static LanguageRegistry,
}

impl Default for LanguageAnalyzer {
  fn default() -> Self {
    Self::new()
  }
}

impl LanguageAnalyzer {
  /// Create new analyzer with access to language registry
  pub fn new() -> Self {
    Self {
      analysis: HashMap::new(),
      registry: &LANGUAGE_REGISTRY,
    }
  }

  /// Analyze code using language registry metadata
  ///
  /// Resolves language via registry (ID, alias, or extension),
  /// then performs semantic tokenization and pattern analysis.
  ///
  /// # Arguments
  /// * `code` - Source code to analyze
  /// * `language_hint` - Language ID, alias, or file extension
  ///
  /// # Returns
  /// Analysis result with registry-derived metadata and computed metrics
  pub fn analyze_language(&self, code: &str, language_hint: &str) -> Option<LanguageAnalysis> {
    // Resolve language via registry (tries ID → alias → extension)
    let language_info = self.registry
      .get_language(language_hint)
      .or_else(|| self.registry.get_language_by_alias(language_hint))?;

    let total_lines = code.lines().count();

    // Create semantic tokenizer for this language
    let tokenizer = SemanticTokenizer::new(&language_info.id);

    // Tokenize code
    let tokens = tokenizer.tokenize(code).unwrap_or_default();

    // Calculate metrics
    let complexity_score = calculate_complexity(&tokens);
    let quality_score = calculate_quality(&tokens, total_lines);
    let common_patterns = extract_patterns(&tokens);

    Some(LanguageAnalysis {
      language_id: language_info.id.clone(),
      language_name: language_info.name.clone(),
      family: language_info.family.clone(),
      rca_supported: language_info.rca_supported,
      ast_grep_supported: language_info.ast_grep_supported,
      file_count: 1,
      total_lines,
      complexity_score,
      quality_score,
      common_patterns,
    })
  }

  /// Add analysis result
  pub fn add_analysis(&mut self, language_id: String, analysis: LanguageAnalysis) {
    self.analysis.insert(language_id, analysis);
  }

  /// Get analysis for a language
  pub fn get_analysis(&self, language_id: &str) -> Option<&LanguageAnalysis> {
    self.analysis.get(language_id)
  }

  /// Get all supported languages from registry
  pub fn supported_languages(&self) -> Vec<String> {
    self.registry.language_ids()
      .iter()
      .map(|id| id.to_string())
      .collect()
  }

  /// Get languages by family
  pub fn languages_by_family(&self, family: &str) -> Vec<String> {
    self.registry.languages_by_family(family)
      .iter()
      .map(|lang| lang.id.clone())
      .collect()
  }

  /// Check if language is supported
  pub fn is_supported(&self, language_id: &str) -> bool {
    self.registry.is_supported(language_id)
  }
}

// ===========================
// Helper Functions
// ===========================

/// Calculate complexity score based on token patterns
fn calculate_complexity(tokens: &[crate::analysis::semantic::custom_tokenizers::DataToken]) -> f64 {
  if tokens.is_empty() {
    return 0.0;
  }

  // Count different token types
  let mut keyword_count = 0;
  let mut function_count = 0;
  let mut class_count = 0;

  for token in tokens {
    match token.token_type {
      crate::analysis::semantic::custom_tokenizers::TokenType::Keyword => keyword_count += 1,
      crate::analysis::semantic::custom_tokenizers::TokenType::Function => function_count += 1,
      crate::analysis::semantic::custom_tokenizers::TokenType::Class => class_count += 1,
      _ => {}
    }
  }

  // Complexity = (keywords + functions * 2 + classes * 3) / total_tokens
  let complexity = (keyword_count as f64 + (function_count as f64 * 2.0) + (class_count as f64 * 3.0))
    / tokens.len() as f64;

  // Normalize to 0-1 range
  (complexity / 2.0).min(1.0)
}

/// Calculate quality score based on code patterns and token weights
fn calculate_quality(tokens: &[crate::analysis::semantic::custom_tokenizers::DataToken], total_lines: usize) -> f64 {
  if tokens.is_empty() || total_lines == 0 {
    return 0.5; // Default neutral quality
  }

  // Quality metrics:
  // 1. Token weight distribution (higher weights = better patterns)
  // 2. Code density (reasonable lines per token)
  // 3. Function count (more functions = better modularity)

  let avg_weight: f64 = tokens.iter().map(|t| t.weight).sum::<f64>() / tokens.len() as f64;
  let code_density = tokens.len() as f64 / total_lines as f64;
  let modularity = tokens.iter().filter(|t| matches!(t.token_type, crate::analysis::semantic::custom_tokenizers::TokenType::Function)).count() as f64;

  // Quality = (avg_weight * 0.4) + (density * 0.3) + (modularity * 0.3)
  let density_score = (code_density / 0.5).min(1.0); // Good density is ~0.5 tokens per line
  let modularity_score = (modularity / 10.0).min(1.0); // 10+ functions is good

  (avg_weight * 0.4) + (density_score * 0.3) + (modularity_score * 0.3)
}

/// Extract common patterns from tokens
fn extract_patterns(tokens: &[crate::analysis::semantic::custom_tokenizers::DataToken]) -> Vec<String> {
  use std::collections::HashMap;

  let mut patterns: HashMap<String, usize> = HashMap::new();

  // Look for repeated token sequences (bigrams)
  for window in tokens.windows(2) {
    let pattern = format!("{:?}-{:?}", window[0].token_type, window[1].token_type);
    *patterns.entry(pattern).or_insert(0) += 1;
  }

  // Return top 5 patterns
  let mut sorted: Vec<_> = patterns.into_iter().collect();
  sorted.sort_by(|a, b| b.1.cmp(&a.1));

  sorted.into_iter().take(5).map(|(pattern, count)| format!("{} (x{})", pattern, count)).collect()
}
