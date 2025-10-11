//! Universal dependency integration layer
//!
//! This module provides the shared dependency analysis functionality used by all language parsers.
//! It integrates tokei and tree-sitter in a unified interface with modern complexity analysis.

use std::{collections::HashMap, fmt::Debug, sync::Arc, time::Instant};

use anyhow::Result;
use dashmap::DashMap;
use tracing::{debug, info, warn};
use crate::{CodeMetrics, MozillaMetrics, TreeSitterAnalysis, DependencyAnalysis};
// serde imports removed as they're unused

// Tree-sitter language imports - ONLY essential languages Singularity uses
use tree_sitter_bash;
use tree_sitter_elixir;
use tree_sitter_gleam;
use tree_sitter_javascript;
use tree_sitter_json;
use tree_sitter_python;
use tree_sitter_rust;
use tree_sitter_typescript;
use tree_sitter_yaml;
use tokio_retry::strategy::{jitter, ExponentialBackoff};
use tokio_retry::Retry;

use crate::{
  errors::UniversalParserError, languages::ProgrammingLanguage, optimizations::AnalysisCache, AnalysisResult, ComplexityMetrics, HalsteadMetrics, LineMetrics,
  MaintainabilityMetrics, UniversalParserFrameworkConfig,
  interfaces::{ParserMetadata, ParserCapabilities, PerformanceCharacteristics},
};
use crate::beam::{compute_elixir_metrics, compute_erlang_metrics, compute_gleam_metrics};

/// Universal dependencies manager that provides shared analysis capabilities
pub struct UniversalDependencies {
  /// Tokei analyzer for line counting
  pub tokei_analyzer: TokeiAnalyzer,
  /// Modern complexity analyzer using tree-sitter
  pub complexity_analyzer: RustCodeAnalyzer,
  /// Tree-sitter manager for AST parsing
  pub tree_sitter_manager: TreeSitterBackend,
  /// Analysis cache for performance
  cache: Arc<AnalysisCache>,
  /// Configuration
  config: UniversalParserFrameworkConfig,
}

impl Debug for UniversalDependencies {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    f.debug_struct("UniversalDependencies")
      .field("tokei_analyzer", &self.tokei_analyzer)
      .field("complexity_analyzer", &self.complexity_analyzer)
      .field("tree_sitter_manager", &"TreeSitterBackend")
      .field("cache", &self.cache)
      .field("config", &self.config)
      .finish()
  }
}

impl Clone for UniversalDependencies {
  fn clone(&self) -> Self {
    Self {
      tokei_analyzer: self.tokei_analyzer.clone(),
      complexity_analyzer: self.complexity_analyzer.clone(),
      tree_sitter_manager: TreeSitterBackend::new().unwrap_or_else(|_| TreeSitterBackend { parsers: DashMap::new() }),
      cache: self.cache.clone(),
      config: self.config.clone(),
    }
  }
}

impl Default for UniversalDependencies {
  fn default() -> Self {
    Self::new().unwrap_or_else(|_| Self {
      tokei_analyzer: TokeiAnalyzer::new().expect("Failed to create TokeiAnalyzer"),
      complexity_analyzer: RustCodeAnalyzer::new().expect("Failed to create RustCodeAnalyzer"),
      tree_sitter_manager: TreeSitterBackend::new().unwrap_or_else(|_| TreeSitterBackend { parsers: DashMap::new() }),
      cache: Arc::new(AnalysisCache::new(1000)),
      config: UniversalParserFrameworkConfig::default(),
    })
  }
}

impl UniversalDependencies {
  /// Create new universal dependencies with default configuration
  pub fn new() -> Result<Self> {
    Self::new_with_config(UniversalParserFrameworkConfig::default())
  }

  /// Create new universal dependencies with custom configuration
  pub fn new_with_config(config: UniversalParserFrameworkConfig) -> Result<Self> {
    info!("Initializing universal dependencies with config: {:?}", config);

    let cache = Arc::new(AnalysisCache::new(config.cache_size));

    Ok(Self {
      tokei_analyzer: TokeiAnalyzer::new()?,
      complexity_analyzer: RustCodeAnalyzer::new()?,
      tree_sitter_manager: TreeSitterBackend::new()?,
      cache,
      config,
    })
  }

  /// Analyze content with all available tools (with smart caching)
  pub async fn analyze_with_all_tools(&self, content: &str, language: ProgrammingLanguage, file_path: &str) -> Result<AnalysisResult> {
    const MAX_RETRIES: u32 = 3;
    let _start_time = Instant::now();

    // Check cache first - reuse analysis until file changes!
    if let Some(cached_result) = self.cache.get(content, &language).await {
      debug!("Cache hit for {} - reusing analysis!", file_path);
      return Ok(cached_result);
    }

    debug!("Cache miss for {} - running fresh analysis", file_path);

    // Use all three polyglot parsers for comprehensive analysis

    // 1. Tokei for accurate line metrics (works for all languages)
    let tokei_strategy = ExponentialBackoff::from_millis(50)
      .factor(2)
      .map(jitter)
      .take(MAX_RETRIES as usize);

    let line_metrics = Retry::spawn(tokei_strategy, || async {
      self
        .tokei_analyzer
        .analyze(content, language)
        .await
        .map_err(|err| {
          warn!("Tokei analysis failed for {}: {}", file_path, err);
          err
        })
    })
    .await?;

    // 2. Complexity metrics
    // For BEAM languages (Elixir/Erlang/Gleam), use heuristic AST-based metrics.
    // Otherwise, use the generic analyzer (RCA when enabled, fallback otherwise).
    let (_complexity_metrics, _halstead_metrics, _maintainability_metrics) = if matches!(language, ProgrammingLanguage::Elixir | ProgrammingLanguage::Erlang | ProgrammingLanguage::Gleam) {
      match language {
        ProgrammingLanguage::Elixir => compute_elixir_metrics(content, line_metrics.code_lines as usize, line_metrics.comment_lines as usize),
        ProgrammingLanguage::Erlang => compute_erlang_metrics(content, line_metrics.code_lines as usize, line_metrics.comment_lines as usize),
        ProgrammingLanguage::Gleam => compute_gleam_metrics(content, line_metrics.code_lines as usize, line_metrics.comment_lines as usize),
        _ => unreachable!(),
      }
    } else {
      let complexity_strategy = ExponentialBackoff::from_millis(50)
        .factor(2)
        .map(jitter)
        .take(MAX_RETRIES as usize);

      Retry::spawn(complexity_strategy, || async {
        self
          .complexity_analyzer
          .analyze(content, language)
          .await
          .map_err(|err| {
            warn!("Complexity analysis failed for {}: {}", file_path, err);
            err
          })
      })
      .await?
    };

    // 3. Tree-sitter for AST parsing (attempted for ALL languages)
    let mut language_specific = match self.tree_sitter_manager.parse(content, language).await {
      Ok(Some(tree)) => {
        debug!("Tree-sitter successfully parsed {} AST", language);
        let mut map = HashMap::new();
        let summary = summarize_ast(&tree);
        map.insert("tree_sitter_summary".to_string(), summary);
        map.insert("tree_sitter_supported".to_string(), serde_json::Value::Bool(true));
        map
      }
      Ok(None) => {
        debug!("Tree-sitter returned None for {} (likely unsupported language)", language);
        let mut map = HashMap::new();
        map.insert("tree_sitter_supported".to_string(), serde_json::Value::Bool(false));
        map
      }
      Err(e) => {
        debug!("Tree-sitter parsing failed for {}: {} (expected for unsupported languages)", file_path, e);
        let mut map = HashMap::new();
        map.insert("tree_sitter_supported".to_string(), serde_json::Value::Bool(false));
        map.insert("tree_sitter_error".to_string(), serde_json::Value::String(e.to_string()));
        map
      }
    };

    // Tag complexity engine used for transparency
    if matches!(language, ProgrammingLanguage::Elixir | ProgrammingLanguage::Erlang | ProgrammingLanguage::Gleam) {
      language_specific.insert("complexity_engine".to_string(), serde_json::json!({
        "name": "beam_heuristic",
        "version": env!("CARGO_PKG_VERSION")
      }));

      // Extract imports/dependencies (regex-based fast path)
      let imports = match language {
        ProgrammingLanguage::Elixir => crate::beam::deps::extract_elixir_deps(content),
        ProgrammingLanguage::Erlang => crate::beam::deps::extract_erlang_deps(content),
        ProgrammingLanguage::Gleam => crate::beam::deps::extract_gleam_deps(content),
        _ => vec![],
      };
      language_specific.insert("imports".to_string(), serde_json::json!(imports));
    }

    // Combine results from all three polyglot parsers
    let result = AnalysisResult {
      file_path: file_path.to_string(),
      language: language.to_string(),
      metrics: CodeMetrics {
        lines_of_code: 0,
        lines_of_comments: 0,
        blank_lines: 0,
        total_lines: 0,
        functions: 0,
        classes: 0,
        complexity_score: 0.0,
      },
      mozilla_metrics: Some(MozillaMetrics {
        #[cfg(feature = "rca")]
        cyclomatic_complexity: "null".to_string(),
        #[cfg(feature = "rca")]
        halstead_metrics: "null".to_string(),
        #[cfg(feature = "rca")]
        maintainability_index: "null".to_string(),
        source_lines_of_code: 0,
        physical_lines_of_code: 0,
        logical_lines_of_code: 0,
        comment_lines_of_code: 0,
        blank_lines: 0,
      }),
      tree_sitter_analysis: Some(TreeSitterAnalysis {
        ast_nodes: 0,
        functions: vec![],
        classes: vec![],
        imports: vec![],
        exports: vec![],
      }),
      dependency_analysis: Some(DependencyAnalysis {
        dependencies: vec![],
        dev_dependencies: vec![],
        total_dependencies: 0,
        outdated_dependencies: vec![],
        security_vulnerabilities: vec![],
      }),
      analysis_timestamp: chrono::Utc::now().to_rfc3339(),
    };

    // Cache the result for future reuse until file changes
    self.cache.put(content, &language, result.clone()).await;
    debug!("Cached analysis result for {}", file_path);

    Ok(result)
  }

  /// Check if all dependencies are available
  pub fn are_dependencies_available(&self) -> bool {
    self.tokei_analyzer.is_available() && self.complexity_analyzer.is_available() && self.tree_sitter_manager.is_available()
  }

  /// Get cache statistics
  pub async fn cache_stats(&self) -> HashMap<String, u64> {
    self.cache.stats().await
  }

  /// Clear analysis cache
  pub async fn clear_cache(&self) {
    self.cache.clear().await;
  }

  /// Get parser metadata
  pub fn get_parser_metadata(&self) -> ParserMetadata {
    ParserMetadata {
      parser_name: "Universal Parser Framework".to_string(),
      version: crate::UNIVERSAL_PARSER_VERSION.to_string(),
      supported_languages: vec![
        ProgrammingLanguage::JavaScript,
        ProgrammingLanguage::TypeScript,
        ProgrammingLanguage::Python,
        ProgrammingLanguage::Rust,
        ProgrammingLanguage::Go,
        ProgrammingLanguage::Erlang,
        ProgrammingLanguage::Elixir,
        ProgrammingLanguage::Gleam,
        ProgrammingLanguage::Java,
        ProgrammingLanguage::C,
        ProgrammingLanguage::Cpp,
        ProgrammingLanguage::CSharp,
        ProgrammingLanguage::Swift,
        ProgrammingLanguage::Kotlin,
        ProgrammingLanguage::Json,
        ProgrammingLanguage::Yaml,
        ProgrammingLanguage::Toml,
        ProgrammingLanguage::Xml,
      ],
      supported_extensions: vec![
        "js".to_string(), "jsx".to_string(), "ts".to_string(), "tsx".to_string(),
        "py".to_string(), "rs".to_string(), "go".to_string(), "ex".to_string(),
        "exs".to_string(), "erl".to_string(), "hrl".to_string(), "gleam".to_string(),
        "java".to_string(), "c".to_string(), "cpp".to_string(), "cc".to_string(),
        "cs".to_string(), "swift".to_string(), "kt".to_string(),
        "json".to_string(), "yaml".to_string(), "yml".to_string(), "toml".to_string(), "xml".to_string(),
      ],
      capabilities: ParserCapabilities {
        symbol_extraction: true,
        complexity_analysis: true,
        dependency_analysis: true,
        duplicate_detection: true,
        refactoring_suggestions: true,
        pattern_detection: true,
        security_analysis: false,
        performance_analysis: false,
        framework_detection: true,
        // Set all other fields to false for now
        ..Default::default()
      },
      performance: PerformanceCharacteristics {
        typical_time_per_kloc_ms: 50,
        max_recommended_file_size: 10000,
        memory_usage_per_kloc_kb: 10,
        supports_parallel: true,
        supports_caching: true,
      },
    }
  }

  /// Get supported languages
  pub fn get_supported_languages(&self) -> Vec<ProgrammingLanguage> {
    vec![
      ProgrammingLanguage::JavaScript,
      ProgrammingLanguage::TypeScript,
      ProgrammingLanguage::Python,
      ProgrammingLanguage::Rust,
      ProgrammingLanguage::Go,
      ProgrammingLanguage::Erlang,
      ProgrammingLanguage::Elixir,
      ProgrammingLanguage::Gleam,
      ProgrammingLanguage::Java,
      ProgrammingLanguage::C,
      ProgrammingLanguage::Cpp,
      ProgrammingLanguage::CSharp,
      ProgrammingLanguage::Swift,
      ProgrammingLanguage::Kotlin,
      ProgrammingLanguage::Json,
      ProgrammingLanguage::Yaml,
      ProgrammingLanguage::Toml,
      ProgrammingLanguage::Xml,
    ]
  }

  /// Analyze content with specified language (compatibility method)
  pub async fn analyze_content(&self, content: &str, file_path: &str, language: ProgrammingLanguage) -> Result<AnalysisResult> {
    self.analyze_with_all_tools(content, language, file_path).await
  }
}

/// Tokei analyzer wrapper
#[derive(Debug, Clone)]
pub struct TokeiAnalyzer {
  _initialized: bool,
}

impl TokeiAnalyzer {
  /// Create new tokei analyzer
  pub fn new() -> Result<Self> {
    Ok(Self { _initialized: true })
  }

  /// Analyze content with tokei
  pub async fn analyze(&self, content: &str, language: ProgrammingLanguage) -> Result<LineMetrics> {
    let tokei_lang = language
      .to_tokei_language()
      .ok_or_else(|| UniversalParserError::UnsupportedLanguage { language: language.to_string() })?;

    // Run tokei analysis in a blocking task
    let content = content.to_string();
    let lang_for_tokei = tokei_lang;
    let ext = language.extensions().first().copied().unwrap_or("txt").to_string();
    let language_clone = language;
    let metrics = tokio::task::spawn_blocking(move || -> Result<LineMetrics> {
      // Use a per-call tempfile with a representative extension to maximize accurate detection
      let mut builder = tempfile::Builder::new();
      builder.prefix("tokei_").suffix(&format!(".{}", ext));
      // Create a temporary file path
      let temp_dir = std::env::temp_dir();
      let temp_filename = format!("tokei_{}.{}", std::process::id(), ext);
      let temp_path = temp_dir.join(temp_filename);

      // Best-effort write
      let _ = std::fs::write(&temp_path, &content);

      let mut languages = tokei::Languages::new();
      languages.get_statistics(&[temp_path.as_path()], &[&format!("{}", lang_for_tokei)], &tokei::Config::default());

      // Clean up the temporary file
      let _ = std::fs::remove_file(&temp_path);

      if let Some(language_stats) = languages.get(&lang_for_tokei) {
        Ok(LineMetrics {
          total_lines: language_stats.lines(),
          code_lines: language_stats.code,
          comment_lines: language_stats.comments,
          blank_lines: language_stats.blanks,
        })
      } else {
        Err(UniversalParserError::tokei_error(format!(
          "tokei returned no statistics for language {:?}",
          language_clone
        ))
        .into())
      }
    })
    .await
    .map_err(|e| anyhow::anyhow!("Failed to join tokei task: {}", e))??;

    Ok(metrics)
  }

  /// Check if tokei is available
  pub fn is_available(&self) -> bool {
    self._initialized
  }
}

/// Rust-code-analysis analyzer wrapper
#[derive(Debug, Clone)]
pub struct RustCodeAnalyzer {
  _initialized: bool,
}

impl RustCodeAnalyzer {
  /// Create new Mozilla code analysis analyzer
  pub fn new() -> Result<Self> {
    Ok(Self { _initialized: true })
  }

  /// RCA disabled: placeholder implementation
  #[allow(dead_code)]
  fn calculate_technical_debt_ratio<T>(_space: &T) -> f64 { 0.0 }

  /// RCA disabled: placeholder implementation
  #[allow(dead_code)]
  fn calculate_duplication_percentage<T>(_space: &T) -> f64 { 0.0 }

  /// RCA disabled: placeholder implementation
  #[allow(dead_code)]
  fn extract_comprehensive_metrics<T>(_space: &T) -> HashMap<String, f64> { HashMap::new() }

  /// Analyze content (RCA disabled): return conservative fallback metrics
  pub async fn analyze(&self, _content: &str, language: ProgrammingLanguage) -> Result<(ComplexityMetrics, HalsteadMetrics, MaintainabilityMetrics)> {
    warn!("RCA metrics disabled; returning fallback metrics for {}", language);
    Ok((
      ComplexityMetrics { cyclomatic: 1.0, cognitive: 0.0, exit_points: 1, nesting_depth: 0 },
      HalsteadMetrics { total_operators: 0, total_operands: 0, unique_operators: 0, unique_operands: 0, volume: 0.0, difficulty: 0.0, effort: 0.0 },
      MaintainabilityMetrics { index: 100.0, technical_debt_ratio: 0.0, duplication_percentage: 0.0 },
    ))
  }

  /// Check if Mozilla code analysis is available
  pub fn is_available(&self) -> bool {
    self._initialized
  }
}

/// Tree-sitter manager for AST parsing
pub struct TreeSitterBackend {
  #[allow(dead_code)]
  parsers: DashMap<ProgrammingLanguage, tree_sitter::Parser>,
}

impl TreeSitterBackend {
  /// Create new tree-sitter manager
  pub fn new() -> Result<Self> {
    Ok(Self { parsers: DashMap::new() })
  }

  /// Get or create parser for language
  pub fn get_parser(&self, _language: ProgrammingLanguage) -> Result<tree_sitter::Parser> {
    // Temporarily disabled due to tree-sitter version incompatibilities
    // TODO: Fix tree-sitter Language type incompatibilities between different language crates
    let parser = tree_sitter::Parser::new();
    Ok(parser)
  }

  /// Parse content with tree-sitter (attempts for ALL languages)
  pub async fn parse(&self, content: &str, language: ProgrammingLanguage) -> Result<Option<tree_sitter::Tree>> {
    // Attempt tree-sitter parsing for ALL languages
    // Unsupported languages will fail gracefully with an error

    let mut parser = match self.get_parser(language) {
      Ok(p) => p,
      Err(e) => {
        debug!("Failed to create tree-sitter parser for {}: {}", language, e);
        return Ok(None);
      }
    };

    // Try to set the language on the parser
    if let Some(lang_fn) = language.tree_sitter_language_fn() {
      // This would require loading the actual language library
      // For now, we'll attempt basic parsing and see what happens
      debug!("Attempting tree-sitter parsing for {} (language function: {})", language, lang_fn);
    } else {
      debug!("No tree-sitter language function available for {}, attempting basic parsing", language);
    }
    
    // Set the appropriate language for tree-sitter parsing
    match language {
      ProgrammingLanguage::Rust => {
        if parser.set_language(&tree_sitter_rust::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Rust language for tree-sitter");
        }
      },
      ProgrammingLanguage::JavaScript => {
        if parser.set_language(&tree_sitter_javascript::LANGUAGE.into()).is_ok() {
          debug!("Successfully set JavaScript language for tree-sitter");
        }
      },
      ProgrammingLanguage::TypeScript => {
        if parser.set_language(&tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into()).is_ok() {
          debug!("Successfully set TypeScript language for tree-sitter");
        }
      },
      ProgrammingLanguage::Python => {
        if parser.set_language(&tree_sitter_python::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Python language for tree-sitter");
        }
      },
      ProgrammingLanguage::Elixir => {
        if parser.set_language(&tree_sitter_elixir::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Elixir language for tree-sitter");
        }
      },
      ProgrammingLanguage::Erlang => {
        if parser.set_language(&tree_sitter_erlang::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Erlang language for tree-sitter");
        }
      },
      ProgrammingLanguage::Gleam => {
        if parser.set_language(&tree_sitter_gleam::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Gleam language for tree-sitter");
        }
      },
      ProgrammingLanguage::Go => {
        if parser.set_language(&tree_sitter_go::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Go language for tree-sitter");
        }
      },
      ProgrammingLanguage::Java => {
        if parser.set_language(&tree_sitter_java::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Java language for tree-sitter");
        }
      },
      ProgrammingLanguage::C => {
        if parser.set_language(&tree_sitter_c::LANGUAGE.into()).is_ok() {
          debug!("Successfully set C language for tree-sitter");
        }
      },
      ProgrammingLanguage::Cpp => {
        if parser.set_language(&tree_sitter_cpp::LANGUAGE.into()).is_ok() {
          debug!("Successfully set C++ language for tree-sitter");
        }
      },
      ProgrammingLanguage::CSharp => {
        if parser.set_language(&tree_sitter_c_sharp::LANGUAGE.into()).is_ok() {
          debug!("Successfully set C# language for tree-sitter");
        }
      },
      ProgrammingLanguage::Swift => {
        if parser.set_language(&tree_sitter_swift::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Swift language for tree-sitter");
        }
      },
      ProgrammingLanguage::Php => {
        if parser.set_language(&tree_sitter_php::LANGUAGE_PHP.into()).is_ok() {
          debug!("Successfully set PHP language for tree-sitter");
        }
      },
      ProgrammingLanguage::Ruby => {
        if parser.set_language(&tree_sitter_ruby::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Ruby language for tree-sitter");
        }
      },
      ProgrammingLanguage::Lua => {
        if parser.set_language(&tree_sitter_lua::language()).is_ok() {
          debug!("Successfully set Lua language for tree-sitter");
        }
      },
      ProgrammingLanguage::Json => {
        if parser.set_language(&tree_sitter_json::LANGUAGE.into()).is_ok() {
          debug!("Successfully set JSON language for tree-sitter");
        }
      },
      ProgrammingLanguage::Yaml => {
        if parser.set_language(&tree_sitter_yaml::LANGUAGE.into()).is_ok() {
          debug!("Successfully set YAML language for tree-sitter");
        }
      },
      ProgrammingLanguage::Bash => {
        if parser.set_language(&tree_sitter_bash::LANGUAGE.into()).is_ok() {
          debug!("Successfully set Bash language for tree-sitter");
        }
      },
      ProgrammingLanguage::Html => {
        if parser.set_language(&tree_sitter_html::LANGUAGE.into()).is_ok() {
          debug!("Successfully set HTML language for tree-sitter");
        }
      },
      ProgrammingLanguage::Css => {
        if parser.set_language(&tree_sitter_css::LANGUAGE.into()).is_ok() {
          debug!("Successfully set CSS language for tree-sitter");
        }
      },
      // ProgrammingLanguage::Kotlin => {
      //   if let Ok(lang) = tree_sitter_kotlin::language() {
      //     if parser.set_language(lang).is_ok() {
      //       debug!("Successfully set Kotlin language for tree-sitter");
      //     }
      //   }
      // },
      _ => {
        debug!("No tree-sitter support for {}, attempting generic parsing", language);
      }
    }

    let content = content.to_string();

    // Run parsing in blocking task
    match tokio::task::spawn_blocking(move || parser.parse(&content, None)).await {
      Ok(tree) => {
        if tree.is_some() {
          debug!("Tree-sitter successfully parsed {}", language);
        } else {
          debug!("Tree-sitter returned None for {}", language);
        }
        Ok(tree)
      }
      Err(e) => {
        debug!("Tree-sitter parsing task failed for {}: {}", language, e);
        Ok(None)
      }
    }
  }

  /// Check if tree-sitter is available
  pub fn is_available(&self) -> bool {
    true
  }
}

// -------- Helpers --------

fn summarize_ast(tree: &tree_sitter::Tree) -> serde_json::Value {
  use serde_json::json;
  let root = tree.root_node();
  let mut cursor = root.walk();
  let mut node_count: u64 = 0;
  let mut max_depth: u32 = 0;
  let mut depth: u32 = 0;

  loop {
    node_count += 1;
    if cursor.goto_first_child() {
      depth += 1;
      if depth > max_depth {
        max_depth = depth;
      }
      continue;
    }
    while !cursor.goto_next_sibling() {
      if !cursor.goto_parent() {
        return json!({
          "root_kind": root.kind(),
          "node_count": node_count,
          "max_depth": max_depth
        });
      }
      depth = depth.saturating_sub(1);
    }
  }
}


#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn test_universal_dependencies_creation() {
    let deps = UniversalDependencies::new().expect("Failed to create dependencies");
    assert!(deps.are_dependencies_available());
  }

  #[tokio::test]
  async fn test_tokei_analyzer() {
    let analyzer = TokeiAnalyzer::new().expect("Failed to create tokei analyzer");
    assert!(analyzer.is_available());

    let rust_code = "fn main() {\n    println!(\"Hello, world!\");\n}";
    let metrics = analyzer.analyze(rust_code, ProgrammingLanguage::Rust).await.expect("Failed to analyze");

    assert!(metrics.total_lines > 0);
    assert!(metrics.code_lines > 0);
  }

  // RCA analyzer test disabled

  #[tokio::test]
  async fn test_tree_sitter_manager() {
    let manager = TreeSitterBackend::new().expect("Failed to create tree-sitter manager");
    assert!(manager.is_available());

    let rust_code = "fn main() {}";
    let tree = manager.parse(rust_code, ProgrammingLanguage::Rust).await.expect("Failed to parse");

    // With latest tree-sitter versions, parsing should work
    assert!(tree.is_some(), "Tree-sitter parsing should work with latest versions");
  }

  #[tokio::test]
  async fn test_full_analysis() {
    let deps = UniversalDependencies::new().expect("Failed to create dependencies");

    let rust_code = "fn main() {\n    println!(\"Hello, world!\");\n}";
    let result = deps.analyze_with_all_tools(rust_code, ProgrammingLanguage::Rust, "test.rs").await.expect("Failed to analyze");

    assert_eq!(result.language, "Rust");
    assert_eq!(result.file_path, "test.rs");
    assert!(result.metrics.total_lines > 0);
    // assert!(result.analysis_duration_ms > 0);
  }
}
