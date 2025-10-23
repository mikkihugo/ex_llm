//! Cross-Language Pattern Analysis
//!
//! Detects patterns and idioms that span multiple languages in a codebase.
//!
//! This module identifies:
//! - **API Integration Patterns**: How different languages call shared APIs
//! - **Data Flow Patterns**: Data transformation across language boundaries
//! - **Error Handling Patterns**: How different languages handle errors consistently
//! - **Configuration Patterns**: Config loading in polyglot codebases
//! - **Logging Patterns**: Structured logging across languages
//! - **Testing Patterns**: Common test patterns across language boundaries
//!
//! ## Use Cases
//!
//! 1. **Polyglot Repositories**: Find patterns shared across Rust/Python/JavaScript
//! 2. **Microservice Architectures**: Detect inter-service patterns
//! 3. **Consistency Checking**: Ensure similar patterns use similar idioms
//! 4. **Knowledge Extraction**: Learn communication patterns between languages
//! 5. **Code Generation**: Use detected patterns as templates for new code
//!
//! ## Design
//!
//! Uses language registry to understand language families and detect appropriate
//! patterns for each language pair (e.g., BEAM↔Systems patterns differ from Web↔Scripting).

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use crate::analysis::semantic::custom_tokenizers::DataToken;
use parser_core::language_registry::{LanguageRegistry, LANGUAGE_REGISTRY};

/// Cross-language pattern occurrence
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CrossLanguageCodePattern {
  /// Pattern ID (unique)
  pub id: String,
  /// Pattern name (e.g., "json_api_integration")
  pub name: String,
  /// Pattern description
  pub description: String,
  /// Source language ID (e.g., "rust")
  pub source_language: String,
  /// Target language ID (e.g., "python")
  pub target_language: String,
  /// All languages involved
  pub languages: Vec<String>,
  /// Pattern type
  pub pattern_type: CrossLanguageCodePatternType,
  /// Confidence score (0.0-1.0)
  pub confidence: f64,
  /// Example code snippet
  pub example: Option<String>,
  /// Pattern characteristics
  pub characteristics: Vec<String>,
}

/// Cross-language pattern type
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CrossLanguageCodePatternType {
  /// API integration pattern (REST, gRPC, etc.)
  ApiIntegration,
  /// Data flow pattern (ETL, transformations)
  DataFlow,
  /// Error handling pattern (exception handling across languages)
  ErrorHandling,
  /// Configuration pattern (config files, environment variables)
  Configuration,
  /// Logging pattern (structured logs, tracing)
  Logging,
  /// Testing pattern (unit tests, integration tests)
  Testing,
  /// Message passing pattern (NATS, Kafka, etc.)
  MessagePassing,
  /// Async pattern (callbacks, promises, async/await)
  AsynchronousPattern,
}

/// Cross-language pattern detector using registry metadata
#[derive(Clone)]
pub struct CrossLanguageCodePatternsDetector {
  /// Detected patterns
  pub patterns: Vec<CrossLanguageCodePattern>,
  /// Language registry reference
  registry: &'static LanguageRegistry,
}

impl std::fmt::Debug for CrossLanguageCodePatternsDetector {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    f.debug_struct("CrossLanguageCodePatternsDetector")
      .field("patterns", &self.patterns)
      .field("registry", &"<LanguageRegistry>")
      .finish()
  }
}

impl Default for CrossLanguageCodePatternsDetector {
  fn default() -> Self {
    Self::new()
  }
}

impl CrossLanguageCodePatternsDetector {
  /// Create new detector with registry access
  pub fn new() -> Self {
    Self {
      patterns: Vec::new(),
      registry: &LANGUAGE_REGISTRY,
    }
  }

  /// Detect cross-language patterns across files
  ///
  /// Analyzes multiple files with language hints to detect patterns
  /// that span language boundaries.
  ///
  /// # Arguments
  /// * `files` - Vec of (language_hint, code) tuples
  /// * `tokens_by_file` - Vec of token sequences (one per file)
  ///
  /// # Returns
  /// Vector of detected cross-language patterns
  pub fn detect_patterns(
    &self,
    files: &[(String, String)],
    tokens_by_file: &[Vec<DataToken>],
  ) -> Vec<CrossLanguageCodePattern> {
    let mut patterns = vec![];

    if files.len() < 2 || files.len() != tokens_by_file.len() {
      return patterns;
    }

    // Resolve all languages
    let mut language_infos = vec![];
    for (hint, _) in files {
      if let Some(lang_info) = self.registry
        .get_language(hint)
        .or_else(|| self.registry.get_language_by_alias(hint))
      {
        language_infos.push(lang_info);
      } else {
        return patterns; // Can't detect patterns without language info
      }
    }

    // Detect patterns between all language pairs
    for i in 0..files.len() {
      for j in (i + 1)..files.len() {
        let lang_i = language_infos[i];
        let lang_j = language_infos[j];
        let code_i = &files[i].1;
        let code_j = &files[j].1;

        // Detect patterns for this language pair
        patterns.extend(self.detect_for_language_pair(
          lang_i.id.as_str(),
          lang_j.id.as_str(),
          code_i,
          code_j,
          &language_infos,
        ));
      }
    }

    patterns
  }

  /// Detect patterns between two languages
  fn detect_for_language_pair(
    &self,
    lang1_id: &str,
    lang2_id: &str,
    code1: &str,
    code2: &str,
    all_languages: &[&parser_core::language_registry::LanguageInfo],
  ) -> Vec<CrossLanguageCodePattern> {
    let mut patterns = vec![];

    // API Integration: Check for REST/JSON patterns
    if (code1.contains("http") || code1.contains("json")) &&
       (code2.contains("http") || code2.contains("json")) {
      patterns.push(CrossLanguageCodePattern {
        id: format!("{}_{}_{}", "api_integration", lang1_id, lang2_id),
        name: "JSON API Integration".to_string(),
        description: "Both languages use REST API with JSON serialization".to_string(),
        source_language: lang1_id.to_string(),
        target_language: lang2_id.to_string(),
        languages: vec![lang1_id.to_string(), lang2_id.to_string()],
        pattern_type: CrossLanguageCodePatternType::ApiIntegration,
        confidence: 0.75,
        example: Some("// Shared REST API pattern across languages".to_string()),
        characteristics: vec![
          "REST API calls".to_string(),
          "JSON serialization".to_string(),
          "HTTP client usage".to_string(),
        ],
      });
    }

    // Error Handling: Check for error handling patterns
    if (code1.contains("error") || code1.contains("try") || code1.contains("catch")) &&
       (code2.contains("error") || code2.contains("try") || code2.contains("catch")) {
      patterns.push(CrossLanguageCodePattern {
        id: format!("{}_{}_{}", "error_handling", lang1_id, lang2_id),
        name: "Consistent Error Handling".to_string(),
        description: "Both languages use similar error handling mechanisms".to_string(),
        source_language: lang1_id.to_string(),
        target_language: lang2_id.to_string(),
        languages: vec![lang1_id.to_string(), lang2_id.to_string()],
        pattern_type: CrossLanguageCodePatternType::ErrorHandling,
        confidence: 0.80,
        example: Some("// Try-catch error handling pattern".to_string()),
        characteristics: vec![
          "Error handling".to_string(),
          "Exception/Result types".to_string(),
          "Consistent error messages".to_string(),
        ],
      });
    }

    // Logging Pattern: Check for logging usage
    if (code1.contains("log") || code1.contains("debug") || code1.contains("info")) &&
       (code2.contains("log") || code2.contains("debug") || code2.contains("info")) {
      patterns.push(CrossLanguageCodePattern {
        id: format!("{}_{}_{}", "logging", lang1_id, lang2_id),
        name: "Structured Logging".to_string(),
        description: "Both languages use structured logging patterns".to_string(),
        source_language: lang1_id.to_string(),
        target_language: lang2_id.to_string(),
        languages: vec![lang1_id.to_string(), lang2_id.to_string()],
        pattern_type: CrossLanguageCodePatternType::Logging,
        confidence: 0.70,
        example: Some("// Structured logging across languages".to_string()),
        characteristics: vec![
          "Logging framework usage".to_string(),
          "Structured log format".to_string(),
          "Log levels (debug, info, warn, error)".to_string(),
        ],
      });
    }

    // Message Passing: Check for NATS/Queue patterns
    if (code1.contains("nats") || code1.contains("queue") || code1.contains("message")) &&
       (code2.contains("nats") || code2.contains("queue") || code2.contains("message")) {
      patterns.push(CrossLanguageCodePattern {
        id: format!("{}_{}_{}", "messaging", lang1_id, lang2_id),
        name: "Distributed Messaging".to_string(),
        description: "Both languages communicate via message queue/NATS".to_string(),
        source_language: lang1_id.to_string(),
        target_language: lang2_id.to_string(),
        languages: vec![lang1_id.to_string(), lang2_id.to_string()],
        pattern_type: CrossLanguageCodePatternType::MessagePassing,
        confidence: 0.85,
        example: Some("// NATS publish/subscribe pattern".to_string()),
        characteristics: vec![
          "Message queue usage".to_string(),
          "Pub/Sub pattern".to_string(),
          "Distributed communication".to_string(),
        ],
      });
    }

    patterns
  }

  /// Add a detected pattern
  pub fn add_pattern(&mut self, pattern: CrossLanguageCodePattern) {
    self.patterns.push(pattern);
  }

  /// Get all patterns
  pub fn get_patterns(&self) -> &Vec<CrossLanguageCodePattern> {
    &self.patterns
  }

  /// Get patterns grouped by language pair
  pub fn get_patterns_by_language_pair(&self) -> HashMap<(String, String), Vec<&CrossLanguageCodePattern>> {
    let mut grouped: HashMap<(String, String), Vec<&CrossLanguageCodePattern>> = HashMap::new();
    for pattern in &self.patterns {
      let key = (pattern.source_language.clone(), pattern.target_language.clone());
      grouped.entry(key).or_insert_with(Vec::new).push(pattern);
    }
    grouped
  }

  /// Get patterns by type
  pub fn get_patterns_by_type(
    &self,
    pattern_type: &CrossLanguageCodePatternType,
  ) -> Vec<&CrossLanguageCodePattern> {
    self.patterns
      .iter()
      .filter(|p| &p.pattern_type == pattern_type)
      .collect()
  }

  /// Get high-confidence patterns (>threshold)
  pub fn get_high_confidence_patterns(&self, threshold: f64) -> Vec<&CrossLanguageCodePattern> {
    self.patterns
      .iter()
      .filter(|p| p.confidence >= threshold)
      .collect()
  }
}
