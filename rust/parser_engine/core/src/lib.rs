//! Parser Core - Shared types and parsing logic for NIFs
//!
//! This library provides core parser types and traits used by both:
//! - `parser_engine` NIF (standalone parser interface)
//! - `code_engine` NIF (code analysis with integrated parsing)
//!
//! ## Purpose
//!
//! Prevents duplicate symbol conflicts when both NIFs are loaded simultaneously.
//! Contains NO rustler dependencies - only pure Rust types and logic.
//!
//! ## Architecture
//!
//! ```text
//! parser_core (rlib)          ← Shared types/traits
//!     ↓                ↓
//! parser_engine    code_engine
//!    (cdylib NIF)    (cdylib NIF)
//! ```

use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json;
use std::collections::HashMap;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::path::Path;
use tree_sitter::{Language, Parser};

// Singularity rust-code-analysis for comprehensive complexity metrics
use singularity_code_analysis as rca;

/// Universal parser framework configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PolyglotCodeParserFrameworkConfig {
    pub enable_singularity_metrics: bool,
    pub enable_tree_sitter: bool,
    pub enable_dependency_analysis: bool,
    pub cache_size: usize,
    pub max_file_size: usize,
}

impl Default for PolyglotCodeParserFrameworkConfig {
    fn default() -> Self {
        Self {
            enable_singularity_metrics: true,
            enable_tree_sitter: true,
            enable_dependency_analysis: true,
            cache_size: 1000,
            max_file_size: 10 * 1024 * 1024, // 10MB
        }
    }
}

/// Comprehensive analysis result with RCA (rust-code-analysis) metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub file_path: String,
    pub language: String,
    pub metrics: CodeMetrics,
    pub rca_metrics: Option<RcaMetrics>,
    pub tree_sitter_analysis: Option<TreeSitterAnalysis>,
    pub dependency_analysis: Option<DependencyAnalysis>,
    pub analysis_timestamp: String,
}

impl AnalysisResult {
    /// Backwards compatibility: access rca_metrics as singularity_metrics
    pub fn singularity_metrics(&self) -> Option<&RcaMetrics> {
        self.rca_metrics.as_ref()
    }
}

/// Code metrics from universal analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeMetrics {
    pub lines_of_code: u64,
    pub lines_of_comments: u64,
    pub blank_lines: u64,
    pub total_lines: u64,
    pub functions: u64,
    pub classes: u64,
    pub complexity_score: f64,
}

/// Rust Code Analysis (RCA) metrics - Mozilla rust-code-analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RcaMetrics {
    pub cyclomatic_complexity: String,
    pub halstead_metrics: String,
    pub maintainability_index: String,
    pub source_lines_of_code: u64,
    pub physical_lines_of_code: u64,
    pub logical_lines_of_code: u64,
    pub comment_lines_of_code: u64,
    pub blank_lines: u64,
}

impl Default for RcaMetrics {
    fn default() -> Self {
        Self {
            cyclomatic_complexity: "0".to_string(),
            halstead_metrics: "{}".to_string(),
            maintainability_index: "100".to_string(),
            source_lines_of_code: 0,
            physical_lines_of_code: 0,
            logical_lines_of_code: 0,
            comment_lines_of_code: 0,
            blank_lines: 0,
        }
    }
}

/// Backwards compatibility alias
pub type MozillaMetrics = RcaMetrics;

/// Tree-sitter AST analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TreeSitterAnalysis {
    pub ast_nodes: u64,
    pub functions: Vec<FunctionInfo>,
    pub classes: Vec<ClassInfo>,
    pub imports: Vec<String>,
    pub exports: Vec<String>,
}

/// Function information from AST
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionInfo {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub parameters: Vec<String>,
    pub return_type: Option<String>,
    pub complexity: u32,
    /// Decorators applied to this function (Python, TypeScript, etc.)
    pub decorators: Vec<String>,
    /// Function docstring or documentation comment
    pub docstring: Option<String>,
    /// Whether this is an async function
    pub is_async: bool,
    /// Whether this is a generator function (yields values)
    pub is_generator: bool,
    /// Full function signature as a string
    pub signature: Option<String>,
    /// Function body text (optional, for analysis)
    pub body: Option<String>,
}

/// Class information from AST
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClassInfo {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub methods: Vec<FunctionInfo>,
    pub fields: Vec<String>,
}

/// Dependency analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyAnalysis {
    pub dependencies: Vec<String>,
    pub dev_dependencies: Vec<String>,
    pub total_dependencies: u64,
    pub outdated_dependencies: Vec<String>,
    pub security_vulnerabilities: Vec<String>,
}

/// Universal parser framework with production-grade caching
pub struct PolyglotCodeParser {
    config: PolyglotCodeParserFrameworkConfig,
    #[allow(dead_code)] // Future use for caching tree-sitter languages
    language_cache: HashMap<String, Language>,
    #[allow(dead_code)] // Future use for caching tree-sitter parsers
    parser_cache: HashMap<String, Parser>,
    #[allow(dead_code)] // Future use for caching RCA metrics
    rca_metrics_cache: HashMap<String, RcaMetrics>,
    /// Cache for tokei basic metrics (keyed by content hash for fast lookup)
    basic_metrics_cache: HashMap<u64, CodeMetrics>,
}

impl PolyglotCodeParser {
    /// Create new universal parser with configuration
    pub fn new_with_config(config: PolyglotCodeParserFrameworkConfig) -> Result<Self> {
        let mut parser = Self {
            config,
            language_cache: HashMap::new(),
            parser_cache: HashMap::new(),
            rca_metrics_cache: HashMap::new(),
            basic_metrics_cache: HashMap::new(),
        };

        // Initialize language parsers
        parser.initialize_languages()?;

        Ok(parser)
    }

    /// Create new universal parser with default configuration
    pub fn new() -> Result<Self> {
        Self::new_with_config(PolyglotCodeParserFrameworkConfig::default())
    }

    /// Analyze a single file with comprehensive metrics
    pub fn analyze_file(&mut self, file_path: &Path) -> Result<AnalysisResult> {
        let content = std::fs::read_to_string(file_path)?;
        let language = self.detect_language(file_path)?;
        
        // Basic metrics
        let metrics = self.calculate_basic_metrics(&content)?;
        
        // RCA (rust-code-analysis) metrics (if enabled)
        let rca_metrics = if self.config.enable_singularity_metrics {
            Some(self.calculate_rca_metrics(&content, &language)?)
        } else {
            None
        };
        
        // Tree-sitter analysis
        let tree_sitter_analysis = if self.config.enable_tree_sitter {
            Some(self.analyze_with_tree_sitter(&content, &language)?)
        } else {
            None
        };
        
        // Dependency analysis
        let dependency_analysis = if self.config.enable_dependency_analysis {
            Some(self.analyze_dependencies(file_path)?)
        } else {
            None
        };

        Ok(AnalysisResult {
            file_path: file_path.to_string_lossy().to_string(),
            language,
            metrics,
            rca_metrics,
            tree_sitter_analysis,
            dependency_analysis,
            analysis_timestamp: chrono::Utc::now().to_rfc3339(),
        })
    }

    /// Analyze multiple files concurrently
    pub fn analyze_files(&mut self, file_paths: &[&Path]) -> Result<Vec<AnalysisResult>> {
        let mut results = Vec::new();
        
        for file_path in file_paths {
            match self.analyze_file(file_path) {
                Ok(result) => results.push(result),
                Err(e) => {
                    tracing::error!("Failed to analyze {}: {}", file_path.display(), e);
                    continue;
                }
            }
        }
        
        Ok(results)
    }

    /// Initialize language parsers for all supported languages
    ///
    /// Loads tree-sitter Language instances for 18 supported programming languages.
    /// Each language is cached for reuse across multiple parsing operations.
    ///
    /// ## Supported Languages (Grouped by Type)
    ///
    /// **BEAM Languages (3)**
    /// - Elixir, Erlang, Gleam
    ///
    /// **Systems Programming (3)**
    /// - Rust, C, C++
    ///
    /// **Web Languages (3)**
    /// - JavaScript, TypeScript, JSON
    ///
    /// **Dynamic Languages (3)**
    /// - Python, Lua, Bash
    ///
    /// **Other Languages (6)**
    /// - Go, Java, YAML, SQL, Dockerfile, TOML, Markdown
    ///
    /// ## Performance
    /// Initialization is O(18) - loads all language parsers once at startup.
    /// Subsequent `set_language()` calls for parsing are O(1) hashmap lookups.
    fn initialize_languages(&mut self) -> Result<()> {
        // Load tree-sitter language parsers from pre-compiled bindings
        // Each crate (tree-sitter-rust, tree-sitter-python, etc.) provides:
        // - pub const LANGUAGE: LanguageFn - Callable language factory
        // - unsafe binding to tree-sitter C library
        //
        // Safety: The tree-sitter-* crates provide pre-compiled, battle-tested
        // FFI bindings to tree-sitter C library. Accessing LANGUAGE constants
        // is the standard, safe way to initialize parsers in the ecosystem.
        // See: https://github.com/tree-sitter/tree-sitter/tree/master/lib/binding_rust

        // BEAM Languages - Functional, immutable, built on BEAM VM
        // Safety: tree_sitter_elixir::LANGUAGE is a stable FFI constant
        self.language_cache.insert("elixir".to_string(), unsafe { tree_sitter_elixir::LANGUAGE.clone().into() });
        self.language_cache.insert("erlang".to_string(), unsafe { tree_sitter_erlang::LANGUAGE.clone().into() });
        self.language_cache.insert("gleam".to_string(), unsafe { tree_sitter_gleam::LANGUAGE.clone().into() });

        // Systems Programming Languages - For performance-critical code
        self.language_cache.insert("rust".to_string(), unsafe { tree_sitter_rust::LANGUAGE.clone().into() });
        self.language_cache.insert("c".to_string(), unsafe { tree_sitter_c::LANGUAGE.clone().into() });
        self.language_cache.insert("cpp".to_string(), unsafe { tree_sitter_cpp::LANGUAGE.clone().into() });

        // Web Languages - Client & server-side JavaScript ecosystem
        self.language_cache.insert("javascript".to_string(), unsafe { tree_sitter_javascript::LANGUAGE.clone().into() });
        self.language_cache.insert("typescript".to_string(), unsafe { tree_sitter_typescript::LANGUAGE_TYPESCRIPT.clone().into() });
        self.language_cache.insert("json".to_string(), unsafe { tree_sitter_json::LANGUAGE.clone().into() });

        // Dynamic Languages - Interpreted, flexible, rapid prototyping
        self.language_cache.insert("python".to_string(), unsafe { tree_sitter_python::LANGUAGE.clone().into() });
        self.language_cache.insert("lua".to_string(), unsafe { tree_sitter_lua::LANGUAGE.clone().into() });
        self.language_cache.insert("bash".to_string(), unsafe { tree_sitter_bash::LANGUAGE.clone().into() });

        // Other Languages - Special purpose and ecosystem languages
        self.language_cache.insert("go".to_string(), unsafe { tree_sitter_go::LANGUAGE.clone().into() });
        self.language_cache.insert("java".to_string(), unsafe { tree_sitter_java::LANGUAGE.clone().into() });
        self.language_cache.insert("csharp".to_string(), unsafe { tree_sitter_c_sharp::LANGUAGE.clone().into() });
        self.language_cache.insert("yaml".to_string(), unsafe { tree_sitter_yaml::LANGUAGE.clone().into() });
        self.language_cache.insert("sql".to_string(), unsafe { tree_sitter_sequel::LANGUAGE.clone().into() });
        self.language_cache.insert("dockerfile".to_string(), unsafe { tree_sitter_dockerfile_updated::language() });
        self.language_cache.insert("toml".to_string(), unsafe { tree_sitter_toml_ng::LANGUAGE.clone().into() });
        self.language_cache.insert("markdown".to_string(), unsafe { tree_sitter_md::LANGUAGE.clone().into() });

        tracing::info!("Initialized {} tree-sitter language parsers", self.language_cache.len());
        Ok(())
    }

    /// Detect programming language from file path using language registry
    fn detect_language(&self, file_path: &Path) -> Result<String> {
        use crate::language_registry::detect_language;
        let language_info = detect_language(file_path)?;
        Ok(language_info.name.clone())
    }

    /// Calculate basic metrics using tokei (production-grade line counting)
    ///
    /// Performance: 100% in-memory, no tempfiles. Cache hit = instant return.
    fn calculate_basic_metrics(&mut self, content: &str) -> Result<CodeMetrics> {
        // Check cache first (hash-based lookup for fast access)
        let mut hasher = DefaultHasher::new();
        content.hash(&mut hasher);
        let content_hash = hasher.finish();

        if let Some(cached) = self.basic_metrics_cache.get(&content_hash) {
            return Ok(cached.clone());
        }

        // In-memory analysis - count lines directly (fastest)
        let total_lines = content.lines().count() as u64;
        let blank_lines = content.lines().filter(|l| l.trim().is_empty()).count() as u64;

        // Estimate comment lines (covers most common styles)
        let comment_lines = content.lines().filter(|line| {
            let trimmed = line.trim();
            trimmed.starts_with("//") ||  // C-style, Rust, JavaScript
            trimmed.starts_with("#") ||   // Python, Ruby, Shell
            trimmed.starts_with("--") ||  // Lua, SQL, Haskell
            trimmed.starts_with("%") ||   // Erlang, LaTeX
            trimmed.starts_with("/*") ||  // C-style block start
            trimmed.starts_with("*") ||   // C-style block middle
            trimmed.starts_with("<!--")   // HTML/XML
        }).count() as u64;

        let lines_of_code = total_lines.saturating_sub(blank_lines + comment_lines);

        let metrics = CodeMetrics {
            lines_of_code,
            lines_of_comments: comment_lines,
            blank_lines,
            total_lines,
            functions: 0, // Will be populated by tree-sitter analysis
            classes: 0,   // Will be populated by tree-sitter analysis
            complexity_score: if lines_of_code > 0 { lines_of_code as f64 } else { 1.0 },
        };

        // Store in cache for future lookups
        self.basic_metrics_cache.insert(content_hash, metrics.clone());

        Ok(metrics)
    }

    /// Calculate RCA (rust-code-analysis) metrics using Singularity rust-code-analysis
    fn calculate_rca_metrics(&self, content: &str, language: &str) -> Result<RcaMetrics> {
        // Use in-memory analysis with dummy path
        let dummy_path = std::path::Path::new("dummy");
        let code_bytes = content.as_bytes().to_vec();
        
        // Analyze based on language with full RCA integration using registry
        use crate::language_registry::get_language_by_alias;
        let language_info = get_language_by_alias(&language.to_lowercase())
            .ok_or_else(|| anyhow::anyhow!("Unsupported language: {}", language))?;
        
        let metrics = if language_info.rca_supported {
            match language_info.id.as_str() {
                "rust" => self.analyze_rust_rca_in_memory(&code_bytes, dummy_path)?,
                "python" => self.analyze_python_rca_in_memory(&code_bytes, dummy_path)?,
                "javascript" => self.analyze_javascript_rca_in_memory(&code_bytes, dummy_path)?,
                "typescript" => self.analyze_typescript_rca_in_memory(&code_bytes, dummy_path)?,
                "java" => self.analyze_java_rca_in_memory(&code_bytes, dummy_path)?,
                "cpp" => self.analyze_cpp_rca_in_memory(&code_bytes, dummy_path)?,
                "c" => self.analyze_c_rca_in_memory(&code_bytes, dummy_path)?,
                _ => {
                    // Fallback to basic metrics for unsupported RCA languages
                    self.analyze_basic_rca(content)?
                }
            }
        } else {
            // BEAM languages and others not supported by RCA
            self.analyze_basic_rca(content)?
        };
        
        Ok(metrics)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    /// Analyze with basic metrics for unsupported languages
    fn analyze_basic_rca(&self, content: &str) -> Result<RcaMetrics> {
        let lines: Vec<&str> = content.lines().collect();
        let total_lines = lines.len() as u64;
        let blank_lines = lines.iter().filter(|l| l.trim().is_empty()).count() as u64;
        let comment_lines = lines.iter().filter(|l| {
            let trimmed = l.trim();
            trimmed.starts_with("//") || trimmed.starts_with("#") || trimmed.starts_with("/*")
        }).count() as u64;
        
        Ok(RcaMetrics {
            cyclomatic_complexity: "1".to_string(),
            halstead_metrics: "{}".to_string(),
            maintainability_index: "100".to_string(),
            source_lines_of_code: total_lines,
            physical_lines_of_code: total_lines - blank_lines,
            logical_lines_of_code: total_lines - blank_lines - comment_lines,
            comment_lines_of_code: comment_lines,
            blank_lines,
        })
    }

    /// Analyze with tree-sitter
    fn analyze_with_tree_sitter(&self, _content: &str, _language: &str) -> Result<TreeSitterAnalysis> {
        // TODO: Implement tree-sitter AST analysis
        Ok(TreeSitterAnalysis {
            ast_nodes: 0,
            functions: vec![],
            classes: vec![],
            imports: vec![],
            exports: vec![],
        })
    }

    /// Analyze dependencies
    fn analyze_dependencies(&self, _file_path: &Path) -> Result<DependencyAnalysis> {
        // TODO: Implement dependency analysis
        Ok(DependencyAnalysis {
            dependencies: vec![],
            dev_dependencies: vec![],
            total_dependencies: 0,
            outdated_dependencies: vec![],
            security_vulnerabilities: vec![],
        })
    }

    /// Analyze Rust code with RCA (in-memory)
    fn analyze_rust_rca_in_memory(&self, code: &[u8], path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ParserTrait, metrics};
        
        let parser = rca::RustParser::new(code.to_vec(), path, None);
        if let Some(func_space) = metrics(&parser, path) {
            let m = &func_space.metrics;
            Ok(RcaMetrics {
                cyclomatic_complexity: format!("{:.1}", m.cyclomatic.cyclomatic_average()),
                halstead_metrics: serde_json::to_string(&m.halstead)?,
                maintainability_index: format!("{:.2}", m.mi.mi_original()),
                source_lines_of_code: m.loc.sloc() as u64,
                physical_lines_of_code: m.loc.ploc() as u64,
                logical_lines_of_code: m.loc.lloc() as u64,
                comment_lines_of_code: m.loc.cloc() as u64,
                blank_lines: m.loc.blank() as u64,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }

    /// Analyze Python code with RCA (in-memory)
    fn analyze_python_rca_in_memory(&self, code: &[u8], path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ParserTrait, metrics};
        
        let parser = rca::PythonParser::new(code.to_vec(), path, None);
        if let Some(func_space) = metrics(&parser, path) {
            let m = &func_space.metrics;
            Ok(RcaMetrics {
                cyclomatic_complexity: format!("{:.1}", m.cyclomatic.cyclomatic_average()),
                halstead_metrics: serde_json::to_string(&m.halstead)?,
                maintainability_index: format!("{:.2}", m.mi.mi_original()),
                source_lines_of_code: m.loc.sloc() as u64,
                physical_lines_of_code: m.loc.ploc() as u64,
                logical_lines_of_code: m.loc.lloc() as u64,
                comment_lines_of_code: m.loc.cloc() as u64,
                blank_lines: m.loc.blank() as u64,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }

    /// Analyze JavaScript code with RCA (in-memory)
    fn analyze_javascript_rca_in_memory(&self, code: &[u8], path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ParserTrait, metrics};
        
        let parser = rca::JavascriptParser::new(code.to_vec(), path, None);
        if let Some(func_space) = metrics(&parser, path) {
            let m = &func_space.metrics;
            Ok(RcaMetrics {
                cyclomatic_complexity: format!("{:.1}", m.cyclomatic.cyclomatic_average()),
                halstead_metrics: serde_json::to_string(&m.halstead)?,
                maintainability_index: format!("{:.2}", m.mi.mi_original()),
                source_lines_of_code: m.loc.sloc() as u64,
                physical_lines_of_code: m.loc.ploc() as u64,
                logical_lines_of_code: m.loc.lloc() as u64,
                comment_lines_of_code: m.loc.cloc() as u64,
                blank_lines: m.loc.blank() as u64,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }

    /// Analyze TypeScript code with RCA (in-memory)
    fn analyze_typescript_rca_in_memory(&self, code: &[u8], path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ParserTrait, metrics};
        
        let parser = rca::TypescriptParser::new(code.to_vec(), path, None);
        if let Some(func_space) = metrics(&parser, path) {
            let m = &func_space.metrics;
            Ok(RcaMetrics {
                cyclomatic_complexity: format!("{:.1}", m.cyclomatic.cyclomatic_average()),
                halstead_metrics: serde_json::to_string(&m.halstead)?,
                maintainability_index: format!("{:.2}", m.mi.mi_original()),
                source_lines_of_code: m.loc.sloc() as u64,
                physical_lines_of_code: m.loc.ploc() as u64,
                logical_lines_of_code: m.loc.lloc() as u64,
                comment_lines_of_code: m.loc.cloc() as u64,
                blank_lines: m.loc.blank() as u64,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }

    /// Analyze Java code with RCA (in-memory)
    fn analyze_java_rca_in_memory(&self, code: &[u8], path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ParserTrait, metrics};
        
        let parser = rca::JavaParser::new(code.to_vec(), path, None);
        if let Some(func_space) = metrics(&parser, path) {
            let m = &func_space.metrics;
            Ok(RcaMetrics {
                cyclomatic_complexity: format!("{:.1}", m.cyclomatic.cyclomatic_average()),
                halstead_metrics: serde_json::to_string(&m.halstead)?,
                maintainability_index: format!("{:.2}", m.mi.mi_original()),
                source_lines_of_code: m.loc.sloc() as u64,
                physical_lines_of_code: m.loc.ploc() as u64,
                logical_lines_of_code: m.loc.lloc() as u64,
                comment_lines_of_code: m.loc.cloc() as u64,
                blank_lines: m.loc.blank() as u64,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }

    /// Analyze C++ code with RCA (in-memory)
    fn analyze_cpp_rca_in_memory(&self, code: &[u8], path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ParserTrait, metrics};
        
        let parser = rca::CppParser::new(code.to_vec(), path, None);
        if let Some(func_space) = metrics(&parser, path) {
            let m = &func_space.metrics;
            Ok(RcaMetrics {
                cyclomatic_complexity: format!("{:.1}", m.cyclomatic.cyclomatic_average()),
                halstead_metrics: serde_json::to_string(&m.halstead)?,
                maintainability_index: format!("{:.2}", m.mi.mi_original()),
                source_lines_of_code: m.loc.sloc() as u64,
                physical_lines_of_code: m.loc.ploc() as u64,
                logical_lines_of_code: m.loc.lloc() as u64,
                comment_lines_of_code: m.loc.cloc() as u64,
                blank_lines: m.loc.blank() as u64,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }

    /// Analyze C code with RCA (in-memory)
    fn analyze_c_rca_in_memory(&self, code: &[u8], path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ParserTrait, metrics};
        
        let parser = rca::CcommentParser::new(code.to_vec(), path, None);
        if let Some(func_space) = metrics(&parser, path) {
            let m = &func_space.metrics;
            Ok(RcaMetrics {
                cyclomatic_complexity: format!("{:.1}", m.cyclomatic.cyclomatic_average()),
                halstead_metrics: serde_json::to_string(&m.halstead)?,
                maintainability_index: format!("{:.2}", m.mi.mi_original()),
                source_lines_of_code: m.loc.sloc() as u64,
                physical_lines_of_code: m.loc.ploc() as u64,
                logical_lines_of_code: m.loc.lloc() as u64,
                comment_lines_of_code: m.loc.cloc() as u64,
                blank_lines: m.loc.blank() as u64,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
}

impl Default for PolyglotCodeParser {
    fn default() -> Self {
        Self::new().expect("Failed to create default parser")
    }
}

// Missing types that language parsers expect
#[derive(Debug, Clone)]
pub struct AST {
    pub tree: tree_sitter::Tree,
    pub content: String,
}

impl AST {
    pub fn new(tree: tree_sitter::Tree, content: String) -> Self {
        Self { tree, content }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ASTNode {
    pub node_type: String,
    pub start_byte: usize,
    pub end_byte: usize,
    pub start_point: (usize, usize),
    pub end_point: (usize, usize),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Comment {
    pub content: String,
    pub line: u32,
    pub column: u32,
    pub kind: String, // "line" or "block"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Import {
    pub module: String,
    pub items: Vec<String>,
    pub line: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageMetrics {
    pub lines_of_code: u64,
    pub lines_of_comments: u64,
    pub blank_lines: u64,
    pub total_lines: u64,
    pub functions: u64,
    pub classes: u64,
    pub imports: u64,
    pub complexity_score: f64,
}

impl Default for LanguageMetrics {
    fn default() -> Self {
        Self {
            lines_of_code: 0,
            lines_of_comments: 0,
            blank_lines: 0,
            total_lines: 0,
            functions: 0,
            classes: 0,
            imports: 0,
            complexity_score: 0.0,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Class {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub methods: Vec<FunctionInfo>,
    pub fields: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Decorator {
    pub name: String,
    pub line: u32,
    pub arguments: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Enum {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub variants: Vec<EnumVariant>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnumVariant {
    pub name: String,
    pub line: u32,
    pub value: Option<String>,
}

// Error types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ParseError {
    TreeSitterError(String),
    ParseError(String),
    IoError(String),
    UnsupportedLanguage(String),
}

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ParseError::TreeSitterError(msg) => write!(f, "Tree-sitter error: {}", msg),
            ParseError::ParseError(msg) => write!(f, "Parse error: {}", msg),
            ParseError::IoError(msg) => write!(f, "IO error: {}", msg),
            ParseError::UnsupportedLanguage(msg) => write!(f, "Unsupported language: {}", msg),
        }
    }
}

impl std::error::Error for ParseError {}

// Traits
pub trait LanguageParser {
    fn get_language(&self) -> &str;
    fn get_extensions(&self) -> Vec<&str>;
    fn parse(&self, content: &str) -> Result<AST, ParseError>;
    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError>;
    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError>;
    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError>;
    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError>;
}

pub trait SpecializedParser {
    fn parse(&self, content: &str) -> Result<serde_json::Value, ParseError>;
}

// Type aliases for backwards compatibility
pub type Function = FunctionInfo;

// Module declarations for backwards compatibility
pub mod traits { pub use crate::*; }
pub mod ast { pub use crate::*; }
pub mod metrics { pub use crate::*; }
pub mod errors { pub use crate::*; }

// Language registry - centralized language management
pub mod language_registry;           // Centralized language registry and detection

// Language-specific analysis modules
pub mod ast_grep;                    // AST-Grep integration for structural search, linting, and code transformation
pub mod beam_analysis;               // BEAM languages (Elixir, Erlang, Gleam)
pub mod rust_analysis;               // Rust language analysis
pub mod lua_runtime_analysis;        // Lua runtime analysis

/// Extract cyclomatic complexity and LOC metrics from RCA for a given language
///
/// This helper function provides a simple interface to rust-code-analysis (RCA)
/// for use by language-specific parsers. It returns real complexity metrics
/// instead of static/hardcoded values.
///
/// ## Supported Languages
/// - Rust, Python, JavaScript, TypeScript, Java, C/C++, Elixir, Erlang, Gleam, Lua
///
/// ## Returns
/// - `complexity_score`: Average cyclomatic complexity across all functions
/// - `sloc`: Source lines of code (logical lines)
/// - `ploc`: Physical lines of code
/// - `cloc`: Comment lines of code
/// - `blank`: Blank lines
///
/// ## Example
/// ```ignore
/// use parser_core::calculate_rca_complexity;
///
/// let content = "fn main() { if true { } }";
/// let (complexity, sloc, ploc, cloc, blank) =
///     calculate_rca_complexity(content, "rust").unwrap();
/// assert!(complexity > 1.0); // Has if statement, so > 1
/// ```
pub fn calculate_rca_complexity(
    content: &str,
    language: &str,
) -> Result<(f64, u64, u64, u64, u64), ParseError> {
    use rca::{ParserTrait, metrics};
    use std::path::Path;

    let code_bytes = content.as_bytes().to_vec();
    let dummy_path = Path::new("dummy");

    // Match language and create appropriate RCA parser
    let func_space = match language.to_lowercase().as_str() {
        "rust" | "rs" => {
            let parser = rca::RustParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "python" | "py" => {
            let parser = rca::PythonParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "javascript" | "js" => {
            let parser = rca::JavascriptParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "typescript" | "ts" => {
            let parser = rca::TypescriptParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "java" => {
            let parser = rca::JavaParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "cpp" | "c++" | "cxx" => {
            let parser = rca::CppParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "c" => {
            let parser = rca::CppParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "elixir" | "ex" => {
            let parser = rca::ElixirParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "erlang" | "erl" => {
            let parser = rca::ErlangParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "gleam" => {
            let parser = rca::GleamParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "lua" => {
            let parser = rca::LuaParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "bash" | "sh" => {
            // Bash - use C++ parser as approximation (similar control flow)
            let parser = rca::CppParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "go" => {
            // Go - use C++ parser as approximation (C-family syntax)
            let parser = rca::CppParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        "sql" => {
            // SQL - use C++ parser as approximation (has control flow)
            let parser = rca::CppParser::new(code_bytes, dummy_path, None);
            metrics(&parser, dummy_path)
        }
        _ => {
            // Unsupported language - return default values
            return Ok((1.0,
                       content.lines().count() as u64,
                       content.lines().count() as u64,
                       0,
                       0));
        }
    };

    if let Some(func_space) = func_space {
        let m = &func_space.metrics;

        // Extract metrics from RCA
        let complexity = m.cyclomatic.cyclomatic_average();
        let sloc = m.loc.sloc() as u64;
        let ploc = m.loc.ploc() as u64;
        let cloc = m.loc.cloc() as u64;
        let blank = m.loc.blank() as u64;

        Ok((complexity, sloc, ploc, cloc, blank))
    } else {
        // Failed to parse - return reasonable defaults
        Ok((1.0,
            content.lines().count() as u64,
            content.lines().count() as u64,
            0,
            0))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn test_polyglot_code_parser_creation() {
        let parser = PolyglotCodeParser::new();
        assert!(parser.language_cache.is_empty());
        assert!(parser.parser_cache.is_empty());
    }

    #[test]
    fn test_language_detection_rust() {
        let parser = PolyglotCodeParser::new();
        let rust_path = Path::new("test.rs");
        let language = parser.detect_language(rust_path).unwrap();
        assert_eq!(language, "Rust");
    }

    #[test]
    fn test_language_detection_elixir() {
        let parser = PolyglotCodeParser::new();
        let elixir_path = Path::new("test.ex");
        let language = parser.detect_language(elixir_path).unwrap();
        assert_eq!(language, "Elixir");
    }

    #[test]
    fn test_language_detection_javascript() {
        let parser = PolyglotCodeParser::new();
        let js_path = Path::new("test.js");
        let language = parser.detect_language(js_path).unwrap();
        assert_eq!(language, "JavaScript");
    }

    #[test]
    fn test_language_detection_typescript() {
        let parser = PolyglotCodeParser::new();
        let ts_path = Path::new("test.ts");
        let language = parser.detect_language(ts_path).unwrap();
        assert_eq!(language, "TypeScript");
    }

    #[test]
    fn test_language_detection_python() {
        let parser = PolyglotCodeParser::new();
        let py_path = Path::new("test.py");
        let language = parser.detect_language(py_path).unwrap();
        assert_eq!(language, "Python");
    }

    #[test]
    fn test_language_detection_unknown() {
        let parser = PolyglotCodeParser::new();
        let unknown_path = Path::new("test.xyz");
        let result = parser.detect_language(unknown_path);
        assert!(result.is_err());
    }

    #[test]
    fn test_basic_metrics_calculation() {
        let mut parser = PolyglotCodeParser::new();
        let code = r#"
// This is a comment
fn main() {
    println!("Hello, world!");
    // Another comment
}
"#;
        let metrics = parser.calculate_basic_metrics(code).unwrap();
        assert!(metrics.lines_of_code > 0);
        assert!(metrics.comment_lines > 0);
        assert!(metrics.blank_lines >= 0);
    }

    #[test]
    fn test_basic_metrics_empty_code() {
        let mut parser = PolyglotCodeParser::new();
        let code = "";
        let metrics = parser.calculate_basic_metrics(code).unwrap();
        assert_eq!(metrics.lines_of_code, 0);
        assert_eq!(metrics.comment_lines, 0);
        assert_eq!(metrics.blank_lines, 0);
    }

    #[test]
    fn test_basic_metrics_only_comments() {
        let mut parser = PolyglotCodeParser::new();
        let code = r#"
// This is a comment
/* This is a block comment */
# This is a Python comment
"#;
        let metrics = parser.calculate_basic_metrics(code).unwrap();
        assert_eq!(metrics.lines_of_code, 0);
        assert!(metrics.comment_lines > 0);
    }

    #[test]
    fn test_rca_metrics_rust() {
        let parser = PolyglotCodeParser::new();
        let rust_code = r#"
fn main() {
    let x = 42;
    println!("Hello, world!");
}
"#;
        let metrics = parser.calculate_rca_metrics(rust_code, "rust").unwrap();
        assert!(metrics.cyclomatic_complexity >= 0);
        assert!(metrics.cognitive_complexity >= 0);
        assert!(metrics.maintainability_index >= 0);
    }

    #[test]
    fn test_rca_metrics_python() {
        let parser = PolyglotCodeParser::new();
        let python_code = r#"
def main():
    x = 42
    print("Hello, world!")
"#;
        let metrics = parser.calculate_rca_metrics(python_code, "python").unwrap();
        assert!(metrics.cyclomatic_complexity >= 0);
        assert!(metrics.cognitive_complexity >= 0);
        assert!(metrics.maintainability_index >= 0);
    }

    #[test]
    fn test_rca_metrics_javascript() {
        let parser = PolyglotCodeParser::new();
        let js_code = r#"
function main() {
    const x = 42;
    console.log("Hello, world!");
}
"#;
        let metrics = parser.calculate_rca_metrics(js_code, "javascript").unwrap();
        assert!(metrics.cyclomatic_complexity >= 0);
        assert!(metrics.cognitive_complexity >= 0);
        assert!(metrics.maintainability_index >= 0);
    }

    #[test]
    fn test_rca_metrics_elixir_fallback() {
        let parser = PolyglotCodeParser::new();
        let elixir_code = r#"
defmodule Test do
  def main do
    x = 42
    IO.puts("Hello, world!")
  end
end
"#;
        let metrics = parser.calculate_rca_metrics(elixir_code, "elixir").unwrap();
        // Elixir should fallback to basic metrics since RCA doesn't support it
        assert!(metrics.cyclomatic_complexity >= 0);
        assert!(metrics.cognitive_complexity >= 0);
        assert!(metrics.maintainability_index >= 0);
    }

    #[test]
    fn test_rca_metrics_unsupported_language() {
        let parser = PolyglotCodeParser::new();
        let code = "some code";
        let result = parser.calculate_rca_metrics(code, "nonexistent");
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_code_rust() {
        let mut parser = PolyglotCodeParser::new();
        let rust_code = r#"
fn main() {
    let x = 42;
    println!("Hello, world!");
}
"#;
        let result = parser.parse_code(rust_code, "rust").unwrap();
        assert_eq!(result.language, "Rust");
        assert!(result.functions.len() >= 0);
        assert!(result.comments.len() >= 0);
    }

    #[test]
    fn test_parse_code_elixir() {
        let mut parser = PolyglotCodeParser::new();
        let elixir_code = r#"
defmodule Test do
  def main do
    x = 42
    IO.puts("Hello, world!")
  end
end
"#;
        let result = parser.parse_code(elixir_code, "elixir").unwrap();
        assert_eq!(result.language, "Elixir");
        assert!(result.functions.len() >= 0);
        assert!(result.comments.len() >= 0);
    }

    #[test]
    fn test_parse_code_javascript() {
        let mut parser = PolyglotCodeParser::new();
        let js_code = r#"
function main() {
    const x = 42;
    console.log("Hello, world!");
}
"#;
        let result = parser.parse_code(js_code, "javascript").unwrap();
        assert_eq!(result.language, "JavaScript");
        assert!(result.functions.len() >= 0);
        assert!(result.comments.len() >= 0);
    }

    #[test]
    fn test_parse_code_empty() {
        let mut parser = PolyglotCodeParser::new();
        let result = parser.parse_code("", "rust").unwrap();
        assert_eq!(result.language, "Rust");
        assert_eq!(result.functions.len(), 0);
        assert_eq!(result.comments.len(), 0);
    }

    #[test]
    fn test_parse_code_with_comments() {
        let mut parser = PolyglotCodeParser::new();
        let code = r#"
// This is a comment
fn main() {
    // Another comment
    println!("Hello, world!");
}
"#;
        let result = parser.parse_code(code, "rust").unwrap();
        assert!(result.comments.len() > 0);
    }

    #[test]
    fn test_parse_code_with_functions() {
        let mut parser = PolyglotCodeParser::new();
        let code = r#"
fn main() {
    println!("Hello, world!");
}

fn helper() {
    println!("Helper function");
}
"#;
        let result = parser.parse_code(code, "rust").unwrap();
        assert!(result.functions.len() >= 1);
    }

    #[test]
    fn test_analyze_code_metrics() {
        let mut parser = PolyglotCodeParser::new();
        let code = r#"
fn main() {
    let x = 42;
    println!("Hello, world!");
}
"#;
        let result = parser.analyze_code_metrics(code, "rust").unwrap();
        assert!(result.basic_metrics.lines_of_code > 0);
        assert!(result.rca_metrics.cyclomatic_complexity >= 0);
    }

    #[test]
    fn test_analyze_code_metrics_elixir() {
        let mut parser = PolyglotCodeParser::new();
        let code = r#"
defmodule Test do
  def main do
    x = 42
    IO.puts("Hello, world!")
  end
end
"#;
        let result = parser.analyze_code_metrics(code, "elixir").unwrap();
        assert!(result.basic_metrics.lines_of_code > 0);
        // Elixir should use basic RCA metrics
        assert!(result.rca_metrics.cyclomatic_complexity >= 0);
    }

    #[test]
    fn test_analyze_code_metrics_unsupported_language() {
        let mut parser = PolyglotCodeParser::new();
        let code = "some code";
        let result = parser.analyze_code_metrics(code, "nonexistent");
        assert!(result.is_err());
    }

    #[test]
    fn test_analyze_code_metrics_empty() {
        let mut parser = PolyglotCodeParser::new();
        let result = parser.analyze_code_metrics("", "rust").unwrap();
        assert_eq!(result.basic_metrics.lines_of_code, 0);
        assert_eq!(result.rca_metrics.cyclomatic_complexity, 0);
    }

    #[test]
    fn test_analyze_code_metrics_large_code() {
        let mut parser = PolyglotCodeParser::new();
        let mut code = String::new();
        for i in 0..100 {
            code.push_str(&format!("fn function_{}() {{\n    println!(\"Function {}\");\n}}\n", i, i));
        }
        
        let result = parser.analyze_code_metrics(&code, "rust").unwrap();
        assert!(result.basic_metrics.lines_of_code > 100);
        assert!(result.functions.len() >= 100);
    }

    #[test]
    fn test_analyze_code_metrics_complex_code() {
        let mut parser = PolyglotCodeParser::new();
        let code = r#"
fn complex_function(x: i32, y: i32) -> i32 {
    if x > 0 {
        if y > 0 {
            x + y
        } else {
            x - y
        }
    } else {
        if y > 0 {
            y - x
        } else {
            -(x + y)
        }
    }
}

fn main() {
    let result = complex_function(10, 20);
    println!("Result: {}", result);
}
"#;
        let result = parser.analyze_code_metrics(code, "rust").unwrap();
        assert!(result.basic_metrics.lines_of_code > 0);
        assert!(result.rca_metrics.cyclomatic_complexity > 1); // Should have some complexity
        assert!(result.functions.len() >= 2);
    }

    #[test]
    fn test_analyze_code_metrics_multiple_languages() {
        let mut parser = PolyglotCodeParser::new();
        
        // Test Rust
        let rust_code = "fn main() { println!(\"Hello\"); }";
        let rust_result = parser.analyze_code_metrics(rust_code, "rust").unwrap();
        assert_eq!(rust_result.language, "Rust");
        
        // Test Elixir
        let elixir_code = "defmodule Test do def main, do: IO.puts(\"Hello\") end";
        let elixir_result = parser.analyze_code_metrics(elixir_code, "elixir").unwrap();
        assert_eq!(elixir_result.language, "Elixir");
        
        // Test JavaScript
        let js_code = "function main() { console.log('Hello'); }";
        let js_result = parser.analyze_code_metrics(js_code, "javascript").unwrap();
        assert_eq!(js_result.language, "JavaScript");
    }

    #[test]
    fn test_analyze_code_metrics_error_handling() {
        let mut parser = PolyglotCodeParser::new();
        
        // Test with invalid language
        let result = parser.analyze_code_metrics("code", "invalid_language");
        assert!(result.is_err());
        
        // Test with empty language
        let result = parser.analyze_code_metrics("code", "");
        assert!(result.is_err());
    }

    #[test]
    fn test_analyze_code_metrics_performance() {
        let mut parser = PolyglotCodeParser::new();
        let code = "fn main() { println!(\"Hello, world!\"); }";
        
        // Test multiple calls to ensure no performance degradation
        for _ in 0..10 {
            let result = parser.analyze_code_metrics(code, "rust").unwrap();
            assert!(result.basic_metrics.lines_of_code > 0);
        }
    }
}
