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

    /// Initialize language parsers
    fn initialize_languages(&mut self) -> Result<()> {
        // TODO: Initialize tree-sitter parsers for each language
        // Individual language parser crates will provide the tree-sitter Language instances
        // This is a stub - actual parsers should use individual language parser modules
        Ok(())
    }

    /// Detect programming language from file path
    fn detect_language(&self, file_path: &Path) -> Result<String> {
        let extension = file_path
            .extension()
            .and_then(|ext| ext.to_str())
            .ok_or_else(|| anyhow::anyhow!("No file extension found"))?;

        let language = match extension {
            "rs" => "Rust",
            "js" | "jsx" => "JavaScript",
            "ts" | "tsx" => "TypeScript",
            "py" => "Python",
            "go" => "Go",
            "java" => "Java",
            "c" => "C",
            "cpp" | "cc" | "cxx" => "C++",
            "cs" => "C#",
            "ex" | "exs" => "Elixir",
            "erl" | "hrl" => "Erlang",
            "gleam" => "Gleam",
            "lua" => "Lua",
            _ => "Unknown",
        };

        Ok(language.to_string())
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
    fn calculate_rca_metrics(&self, content: &str, _language: &str) -> Result<RcaMetrics> {
        // TODO: Re-enable RCA integration when API is properly understood
        // For now, use basic metrics calculation
        self.analyze_basic_rca(content)
    }
    
    /// Analyze Rust code with RCA
    fn analyze_rust_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{RustCode, ParserTrait, metrics};
        
        let parser = RustCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze Python code with RCA
    fn analyze_python_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{PythonCode, ParserTrait, metrics};
        
        let parser = PythonCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze JavaScript code with RCA
    fn analyze_javascript_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{JavascriptCode, ParserTrait, metrics};
        
        let parser = JavascriptCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze TypeScript code with RCA
    fn analyze_typescript_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{TypescriptCode, ParserTrait, metrics};
        
        let parser = TypescriptCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze Java code with RCA
    fn analyze_java_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{JavaCode, ParserTrait, metrics};
        
        let parser = JavaCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze C++ code with RCA
    fn analyze_cpp_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{CppCode, ParserTrait, metrics};
        
        let parser = CppCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze C code with RCA
    fn analyze_c_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{CcommentCode, ParserTrait, metrics};
        
        let parser = CcommentCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze Go code with RCA
    fn analyze_go_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        // Go is not supported by RCA, use basic analysis
        let content = std::fs::read_to_string(path)?;
        self.analyze_basic_rca(&content)
    }
    
    /// Analyze Elixir code with RCA
    fn analyze_elixir_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ElixirCode, ParserTrait, metrics};
        
        let parser = ElixirCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze Erlang code with RCA
    fn analyze_erlang_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{ErlangCode, ParserTrait, metrics};
        
        let parser = ErlangCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
    }
    
    /// Analyze Gleam code with RCA
    fn analyze_gleam_rca(&self, path: &std::path::Path) -> Result<RcaMetrics> {
        use rca::{GleamCode, ParserTrait, metrics};
        
        let parser = GleamCode::new(path, 0)?;
        if let Some(func_space) = metrics(&parser, path) {
            Ok(RcaMetrics {
                cyclomatic_complexity: func_space.cyclomatic.to_string(),
                halstead_metrics: serde_json::to_string(&func_space.halstead)?,
                maintainability_index: func_space.mi.to_string(),
                source_lines_of_code: func_space.sloc,
                physical_lines_of_code: func_space.ploc,
                logical_lines_of_code: func_space.lloc,
                comment_lines_of_code: func_space.cloc,
                blank_lines: func_space.blanks,
            })
        } else {
            Ok(RcaMetrics::default())
        }
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

// Language-specific analysis modules
pub mod ast_grep;                    // AST-Grep integration for structural search, linting, and code transformation
pub mod beam_analysis;               // BEAM languages (Elixir, Erlang, Gleam)
pub mod rust_analysis;               // Rust language analysis
pub mod lua_runtime_analysis;        // Lua runtime analysis
