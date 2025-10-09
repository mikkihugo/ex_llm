//! Parser Registry for Analysis Engine
//!
//! Maps parser capabilities to analysis expectations so the analysis engine
//! knows what to expect from each parser and can adapt accordingly.

use std::collections::HashMap;
use serde::{Deserialize, Serialize};

/// Parser registry entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParserRegistryEntry {
  /// Parser identifier
  pub parser_id: String,
  /// Parser capabilities
  pub capabilities: ParserCapabilities,
  /// Expected analysis fields
  pub expected_fields: ExpectedAnalysisFields,
  /// Parser-specific configuration
  pub config: ParserSpecificConfig,
}

/// Expected analysis fields based on parser capabilities
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExpectedAnalysisFields {
  /// Basic file info (always available)
  pub basic_info: bool,
  /// Symbol extraction fields
  pub symbols: SymbolFields,
  /// Complexity analysis fields
  pub complexity: ComplexityFields,
  /// Security analysis fields
  pub security: SecurityFields,
  /// Performance analysis fields
  pub performance: PerformanceFields,
  /// Dependency analysis fields
  pub dependencies: DependencyFields,
  /// Framework detection fields
  pub frameworks: FrameworkFields,
}

/// Symbol extraction fields
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SymbolFields {
  /// Can extract functions
  pub functions: bool,
  /// Can extract classes
  pub classes: bool,
  /// Can extract structs
  pub structs: bool,
  /// Can extract enums
  pub enums: bool,
  /// Can extract traits/interfaces
  pub traits: bool,
  /// Can extract modules/namespaces
  pub modules: bool,
  /// Can extract variables
  pub variables: bool,
}

/// Complexity analysis fields
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplexityFields {
  /// Can calculate cyclomatic complexity
  pub cyclomatic_complexity: bool,
  /// Can calculate cognitive complexity
  pub cognitive_complexity: bool,
  /// Can calculate maintainability index
  pub maintainability_index: bool,
  /// Can calculate nesting depth
  pub nesting_depth: bool,
  /// Can calculate Halstead metrics
  pub halstead_metrics: bool,
}

/// Security analysis fields
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityFields {
  /// Can detect security vulnerabilities
  pub vulnerability_detection: bool,
  /// Can calculate security score
  pub security_score: bool,
  /// Can detect security patterns
  pub security_patterns: bool,
  /// Can analyze authentication/authorization
  pub auth_analysis: bool,
}

/// Performance analysis fields
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceFields {
  /// Can detect performance bottlenecks
  pub bottleneck_detection: bool,
  /// Can suggest performance optimizations
  pub optimization_suggestions: bool,
  /// Can analyze memory usage patterns
  pub memory_analysis: bool,
  /// Can analyze concurrency patterns
  pub concurrency_analysis: bool,
}

/// Dependency analysis fields
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyFields {
  /// Can extract imports
  pub imports: bool,
  /// Can extract exports
  pub exports: bool,
  /// Can analyze dependency relationships
  pub relationships: bool,
  /// Can detect circular dependencies
  pub circular_dependencies: bool,
}

/// Framework detection fields
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkFields {
  /// Can detect frameworks
  pub framework_detection: bool,
  /// Can detect libraries
  pub library_detection: bool,
  /// Can detect architectural patterns
  pub architectural_patterns: bool,
  /// Can detect design patterns
  pub design_patterns: bool,
}

/// Parser-specific configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParserSpecificConfig {
  /// Language-specific settings
  pub language_config: HashMap<String, String>,
  /// Analysis depth (shallow, medium, deep)
  pub analysis_depth: AnalysisDepth,
  /// Timeout for analysis (milliseconds)
  pub analysis_timeout: u64,
  /// Memory limit for analysis (bytes)
  pub memory_limit: u64,
}

/// Analysis depth levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AnalysisDepth {
  /// Quick analysis - basic metrics only
  Shallow,
  /// Standard analysis - most metrics
  Medium,
  /// Deep analysis - all available metrics
  Deep,
}

/// Parser registry for managing parser capabilities
#[derive(Debug, Clone)]
pub struct ParserRegistry {
  /// Registered parsers
  parsers: HashMap<String, ParserRegistryEntry>,
}

impl ParserRegistry {
  /// Create a new parser registry
  pub fn new() -> Self {
    Self {
      parsers: HashMap::new(),
    }
  }

  /// Register a parser with its capabilities
  pub fn register_parser(&mut self, entry: ParserRegistryEntry) {
    self.parsers.insert(entry.parser_id.clone(), entry);
  }

  /// Get parser capabilities
  pub fn get_parser_capabilities(&self, parser_id: &str) -> Option<&ParserCapabilities> {
    self.parsers.get(parser_id).map(|entry| &entry.capabilities)
  }

  /// Get expected analysis fields for a parser
  pub fn get_expected_fields(&self, parser_id: &str) -> Option<&ExpectedAnalysisFields> {
    self.parsers.get(parser_id).map(|entry| &entry.expected_fields)
  }

  /// Get parser-specific configuration
  pub fn get_parser_config(&self, parser_id: &str) -> Option<&ParserSpecificConfig> {
    self.parsers.get(parser_id).map(|entry| &entry.config)
  }

  /// Check if parser supports a specific capability
  pub fn supports_capability(&self, parser_id: &str, capability: &str) -> bool {
    if let Some(capabilities) = self.get_parser_capabilities(parser_id) {
      match capability {
        "symbol_extraction" => capabilities.symbol_extraction,
        "complexity_analysis" => capabilities.complexity_analysis,
        "security_analysis" => capabilities.security_analysis,
        "performance_analysis" => capabilities.performance_analysis,
        "dependency_analysis" => capabilities.dependency_analysis,
        "framework_detection" => capabilities.framework_detection,
        _ => false,
      }
    } else {
      false
    }
  }

  /// Get all registered parser IDs
  pub fn get_parser_ids(&self) -> Vec<String> {
    self.parsers.keys().cloned().collect()
  }

  /// Get parsers that support a specific capability
  pub fn get_parsers_with_capability(&self, capability: &str) -> Vec<String> {
    self.parsers
      .iter()
      .filter(|(_, entry)| self.supports_capability(entry.parser_id.as_str(), capability))
      .map(|(id, _)| id.clone())
      .collect()
  }
}

impl Default for ParserRegistry {
  fn default() -> Self {
    Self::new()
  }
}

impl Default for ExpectedAnalysisFields {
  fn default() -> Self {
    Self {
      basic_info: true,
      symbols: SymbolFields::default(),
      complexity: ComplexityFields::default(),
      security: SecurityFields::default(),
      performance: PerformanceFields::default(),
      dependencies: DependencyFields::default(),
      frameworks: FrameworkFields::default(),
    }
  }
}

impl Default for SymbolFields {
  fn default() -> Self {
    Self {
      functions: true,
      classes: true,
      structs: true,
      enums: true,
      traits: true,
      modules: true,
      variables: true,
    }
  }
}

impl Default for ComplexityFields {
  fn default() -> Self {
    Self {
      cyclomatic_complexity: true,
      cognitive_complexity: true,
      maintainability_index: true,
      nesting_depth: true,
      halstead_metrics: true,
    }
  }
}

impl Default for SecurityFields {
  fn default() -> Self {
    Self {
      vulnerability_detection: false,
      security_score: false,
      security_patterns: false,
      auth_analysis: false,
    }
  }
}

impl Default for PerformanceFields {
  fn default() -> Self {
    Self {
      bottleneck_detection: false,
      optimization_suggestions: false,
      memory_analysis: false,
      concurrency_analysis: false,
    }
  }
}

impl Default for DependencyFields {
  fn default() -> Self {
    Self {
      imports: true,
      exports: true,
      relationships: true,
      circular_dependencies: false,
    }
  }
}

impl Default for FrameworkFields {
  fn default() -> Self {
    Self {
      framework_detection: false,
      library_detection: false,
      architectural_patterns: false,
      design_patterns: false,
    }
  }
}

impl Default for ParserSpecificConfig {
  fn default() -> Self {
    Self {
      language_config: HashMap::new(),
      analysis_depth: AnalysisDepth::Medium,
      analysis_timeout: 30000, // 30 seconds
      memory_limit: 100 * 1024 * 1024, // 100MB
    }
  }
}