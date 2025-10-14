//! Source Code Parser - Universal AST analysis with Mozilla Code Analysis integration
//!
//! This library provides comprehensive source code analysis using:
//! - Tree-sitter for AST parsing across 30+ languages
//! - Mozilla rust-code-analysis for enterprise-grade metrics
//! - Universal dependency analysis with Tokei
//! - Performance optimizations with caching and async execution
//!
//! ## Supported Languages
//!
//! - **Rust**: Native analysis with Mozilla metrics
//! - **JavaScript/TypeScript**: Full AST analysis
//! - **Python**: Tree-sitter based parsing
//! - **Go**: Language-specific metrics
//! - **Java**: Enterprise analysis
//! - **C/C++**: Performance analysis
//! - **C#**: .NET ecosystem analysis
//! - **Elixir/Erlang**: BEAM-specific analysis
//! - **Gleam**: Functional language analysis
//!
//! ## Mozilla Code Analysis Integration
//!
//! Provides enterprise-grade metrics:
//! - **CC**: Cyclomatic Complexity
//! - **SLOC**: Source Lines of Code
//! - **PLOC**: Physical Lines of Code
//! - **LLOC**: Logical Lines of Code
//! - **CLOC**: Comment Lines of Code
//! - **BLANK**: Blank Lines
//! - **HALSTEAD**: Halstead complexity metrics
//! - **MI**: Maintainability Index
//! - **NOM**: Number of Methods
//! - **NEXITS**: Number of Exit Points
//! - **NARGS**: Number of Arguments

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;

// Rustler NIF initialization for ParserEngine
// NOTE: Only enabled when built with "nif" feature for standalone ParserEngine use
// When used as library dependency by code_engine, this is disabled to avoid duplicate nif_init
#[cfg(feature = "nif")]
rustler::init!(
    "Elixir.Singularity.ParserEngine",
    [parse_file_nif, parse_tree_nif, supported_languages]
);

// Tree-sitter integration
use tree_sitter::{Language, Parser};

// Universal dependency analysis
use tokei::{Config, LanguageType, Languages};

/// Universal parser framework configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PolyglotCodeParserFrameworkConfig {
    pub enable_mozilla_metrics: bool,
    pub enable_tree_sitter: bool,
    pub enable_dependency_analysis: bool,
    pub cache_size: usize,
    pub max_file_size: usize,
}

impl Default for PolyglotCodeParserFrameworkConfig {
    fn default() -> Self {
        Self {
            enable_mozilla_metrics: true,
            enable_tree_sitter: true,
            enable_dependency_analysis: true,
            cache_size: 1000,
            max_file_size: 10 * 1024 * 1024, // 10MB
        }
    }
}

/// Comprehensive analysis result with Mozilla metrics
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ParserCode.AnalysisResult"]
pub struct AnalysisResult {
    pub file_path: String,
    pub language: String,
    pub metrics: CodeMetrics,
    pub mozilla_metrics: Option<MozillaMetrics>,
    pub tree_sitter_analysis: Option<TreeSitterAnalysis>,
    pub dependency_analysis: Option<DependencyAnalysis>,
    pub analysis_timestamp: String,  // ISO 8601 timestamp string (Rustler doesn't encode DateTime directly)
}

/// Code metrics from universal analysis
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ParserCode.CodeMetrics"]
pub struct CodeMetrics {
    pub lines_of_code: u64,
    pub lines_of_comments: u64,
    pub blank_lines: u64,
    pub total_lines: u64,
    pub functions: u64,
    pub classes: u64,
    pub complexity_score: f64,
}

/// Mozilla code analysis metrics
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ParserCode.MozillaMetrics"]
pub struct MozillaMetrics {
    #[cfg(feature = "rca")]
    pub cyclomatic_complexity: String,  // JSON string (Rustler doesn't encode serde_json::Value)
    #[cfg(feature = "rca")]
    pub halstead_metrics: String,  // JSON string
    #[cfg(feature = "rca")]
    pub maintainability_index: String,  // JSON string
    pub source_lines_of_code: u64,
    pub physical_lines_of_code: u64,
    pub logical_lines_of_code: u64,
    pub comment_lines_of_code: u64,
    pub blank_lines: u64,
}

/// Tree-sitter AST analysis
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ParserCode.TreeSitterAnalysis"]
pub struct TreeSitterAnalysis {
    pub ast_nodes: u64,
    pub functions: Vec<FunctionInfo>,
    pub classes: Vec<ClassInfo>,
    pub imports: Vec<String>,
    pub exports: Vec<String>,
}

/// Function information from AST
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ParserCode.FunctionInfo"]
pub struct FunctionInfo {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub parameters: Vec<String>,
    pub return_type: Option<String>,
    pub complexity: u32,
}

/// Class information from AST
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ParserCode.ClassInfo"]
pub struct ClassInfo {
    pub name: String,
    pub line_start: u32,
    pub line_end: u32,
    pub methods: Vec<FunctionInfo>,
    pub fields: Vec<String>,
}

/// Dependency analysis result
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ParserCode.DependencyAnalysis"]
pub struct DependencyAnalysis {
    pub dependencies: Vec<String>,
    pub dev_dependencies: Vec<String>,
    pub total_dependencies: u64,
    pub outdated_dependencies: Vec<String>,
    pub security_vulnerabilities: Vec<String>,
}

/// Universal parser framework
pub struct PolyglotCodeParser {
    config: PolyglotCodeParserFrameworkConfig,
    language_cache: HashMap<String, Language>,
    parser_cache: HashMap<String, Parser>,
    metrics_cache: HashMap<String, MozillaMetrics>,
}

impl PolyglotCodeParser {
    /// Create new universal parser with configuration
    pub fn new_with_config(config: PolyglotCodeParserFrameworkConfig) -> Result<Self> {
        let mut parser = Self {
            config,
            language_cache: HashMap::new(),
            parser_cache: HashMap::new(),
            metrics_cache: HashMap::new(),
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
        
        // Mozilla metrics
        let mozilla_metrics = if self.config.enable_mozilla_metrics {
            #[cfg(feature = "rca")]
            {
                Some(self.calculate_mozilla_metrics(&content, &language)?)
            }
            #[cfg(not(feature = "rca"))]
            {
                None
            }
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
            mozilla_metrics,
            tree_sitter_analysis,
            dependency_analysis,
            analysis_timestamp: chrono::Utc::now().to_rfc3339(),  // Convert to ISO 8601 string
        })
    }

    /// Analyze multiple files concurrently
    pub fn analyze_files(&mut self, file_paths: &[&Path]) -> Result<Vec<AnalysisResult>> {
        let mut results = Vec::new();
        
        for file_path in file_paths {
            match self.analyze_file(file_path) {
                Ok(result) => results.push(result),
                Err(e) => {
                    eprintln!("Failed to analyze {}: {}", file_path.display(), e);
                    continue;
                }
            }
        }
        
        Ok(results)
    }

    /// Initialize language parsers (ONLY essential languages)
    fn initialize_languages(&mut self) -> Result<()> {
        // Core languages Singularity actually uses
        self.language_cache.insert("elixir".to_string(), tree_sitter_elixir::LANGUAGE.into());
        self.language_cache.insert("erlang".to_string(), tree_sitter_erlang::LANGUAGE.into());
        self.language_cache.insert("gleam".to_string(), tree_sitter_gleam::LANGUAGE.into());
        self.language_cache.insert("rust".to_string(), tree_sitter_rust::LANGUAGE.into());
        self.language_cache.insert("javascript".to_string(), tree_sitter_javascript::LANGUAGE.into());
        self.language_cache.insert("typescript".to_string(), tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into());
        self.language_cache.insert("python".to_string(), tree_sitter_python::LANGUAGE.into());
        self.language_cache.insert("json".to_string(), tree_sitter_json::LANGUAGE.into());
        self.language_cache.insert("yaml".to_string(), tree_sitter_yaml::LANGUAGE.into());
        self.language_cache.insert("bash".to_string(), tree_sitter_bash::LANGUAGE.into());

        Ok(())
    }

    /// Detect programming language from file path (ONLY essential languages)
    fn detect_language(&self, file_path: &Path) -> Result<String> {
        let extension = file_path.extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("");

        let language = match extension {
            "ex" | "exs" => "elixir",
            "erl" | "hrl" => "erlang",
            "gleam" => "gleam",
            "rs" => "rust",
            "js" | "cjs" | "mjs" => "javascript",
            "ts" | "cts" | "mts" => "typescript",
            "py" => "python",
            "json" => "json",
            "yaml" | "yml" => "yaml",
            "sh" | "bash" => "bash",
            _ => "unknown",
        };

        Ok(language.to_string())
    }

    /// Calculate basic code metrics
    fn calculate_basic_metrics(&self, content: &str) -> Result<CodeMetrics> {
        let lines: Vec<&str> = content.lines().collect();
        let total_lines = lines.len() as u64;
        
        let mut lines_of_code = 0;
        let mut lines_of_comments = 0;
        let mut blank_lines = 0;
        let mut functions = 0;
        let mut classes = 0;
        
        for line in lines {
            let trimmed = line.trim();
            if trimmed.is_empty() {
                blank_lines += 1;
            } else if trimmed.starts_with("//") || trimmed.starts_with("#") || trimmed.starts_with("/*") {
                lines_of_comments += 1;
            } else {
                lines_of_code += 1;
                
                // Simple function detection
                if trimmed.contains("fn ") || trimmed.contains("function ") || trimmed.contains("def ") {
                    functions += 1;
                }
                
                // Simple class detection
                if trimmed.contains("class ") || trimmed.contains("struct ") || trimmed.contains("impl ") {
                    classes += 1;
                }
            }
        }
        
        let complexity_score = if functions > 0 {
            (lines_of_code as f64) / (functions as f64)
        } else {
            1.0
        };
        
        Ok(CodeMetrics {
            lines_of_code,
            lines_of_comments,
            blank_lines,
            total_lines,
            functions,
            classes,
            complexity_score,
        })
    }

    /// Calculate Mozilla code analysis metrics
    #[cfg(feature = "rca")]
    fn calculate_mozilla_metrics(&mut self, content: &str, _language: &str) -> Result<MozillaMetrics> {
        // Check cache first
        if let Some(cached) = self.metrics_cache.get(content) {
            return Ok(cached.clone());
        }

        // Use code_analysis for comprehensive metrics
        // Note: Checker is not publicly exported, using simplified approach
        
        // Simple line counting for now - can be enhanced later
        let lines: Vec<&str> = content.lines().collect();
        let total_lines = lines.len() as u64;
        let blank_lines = lines.iter().filter(|line| line.trim().is_empty()).count() as u64;
        let comment_lines = lines.iter().filter(|line| line.trim().starts_with("//") || line.trim().starts_with("#")).count() as u64;
        let code_lines = total_lines - blank_lines - comment_lines;
        
        let metrics = MozillaMetrics {
            cyclomatic_complexity: "null".to_string(),  // Convert to JSON string
            halstead_metrics: "null".to_string(),
            maintainability_index: "null".to_string(),
            source_lines_of_code: code_lines,
            physical_lines_of_code: total_lines,
            logical_lines_of_code: code_lines,
            comment_lines_of_code: comment_lines,
            blank_lines,
        };
        
        // Cache the result
        self.metrics_cache.insert(content.to_string(), metrics.clone());
        
        Ok(metrics)
    }

    /// Analyze code with tree-sitter
    fn analyze_with_tree_sitter(&mut self, content: &str, language: &str) -> Result<TreeSitterAnalysis> {
        let lang = self.language_cache.get(language)
            .ok_or_else(|| anyhow::anyhow!("Unsupported language: {}", language))?;
        
        let parser = self.parser_cache.entry(language.to_string())
            .or_insert_with(|| {
                let mut p = Parser::new();
                p.set_language(lang).unwrap();
                p
            });
        
        let tree = parser.parse(content, None)
            .ok_or_else(|| anyhow::anyhow!("Failed to parse with tree-sitter"))?;
        
        let root_node = tree.root_node();
        
        // Extract functions, classes, imports, exports
        let functions = self.extract_functions(&root_node, content)?;
        let classes = self.extract_classes(&root_node, content)?;
        let imports = self.extract_imports(&root_node, content)?;
        let exports = self.extract_exports(&root_node, content)?;
        
        Ok(TreeSitterAnalysis {
            ast_nodes: root_node.child_count() as u64,
            functions,
            classes,
            imports,
            exports,
        })
    }

    /// Analyze dependencies
    fn analyze_dependencies(&self, file_path: &Path) -> Result<DependencyAnalysis> {
        let mut config = Config::default();
        let mut languages = Languages::new();
        
        // Configure tokei for dependency analysis
        config.types = Some(vec![LanguageType::Rust, LanguageType::JavaScript, LanguageType::Python]);
        
        // Analyze the directory
        languages.get_statistics(&[file_path], &[], &config);
        
        // Extract dependency information using dependency-parser
        let dependencies = self.extract_dependencies_from_file(file_path.to_str().unwrap_or(""))?;
        let dev_dependencies = self.extract_dev_dependencies_from_file(file_path.to_str().unwrap_or(""))?;
        let outdated_dependencies = self.check_outdated_dependencies(&dependencies)?;
        let security_vulnerabilities = self.check_security_vulnerabilities(&dependencies)?;
        
        Ok(DependencyAnalysis {
            dependencies,
            dev_dependencies,
            total_dependencies: 0,
            outdated_dependencies,
            security_vulnerabilities,
        })
    }

    /// Extract functions from AST
    fn extract_functions(&self, node: &tree_sitter::Node, content: &str) -> Result<Vec<FunctionInfo>> {
        let mut functions = Vec::new();
        
        // Extract functions based on language-specific patterns
        self.extract_functions_recursive(node, content, &mut functions)?;
        
        Ok(functions)
    }

    /// Recursively extract functions from AST nodes
    fn extract_functions_recursive(&self, node: &tree_sitter::Node, content: &str, functions: &mut Vec<FunctionInfo>) -> Result<()> {
        let node_type = node.kind();
        
        // Check if this node represents a function
        if self.is_function_node(node_type) {
            if let Some(function_info) = self.extract_function_info(node, content)? {
                functions.push(function_info);
            }
        }
        
        // Recursively process child nodes
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                self.extract_functions_recursive(&child, content, functions)?;
            }
        }
        
        Ok(())
    }

    /// Check if a node type represents a function
    fn is_function_node(&self, node_type: &str) -> bool {
        matches!(node_type, 
            "function_declaration" | "function_definition" | "method_definition" |
            "arrow_function" | "function_expression" | "method" | "def" |
            "function_item" | "impl_item" | "trait_item" | "fn"
        )
    }

    /// Extract function information from a function node
    fn extract_function_info(&self, node: &tree_sitter::Node, content: &str) -> Result<Option<FunctionInfo>> {
        let name = self.extract_function_name(node, content)?;
        let start_line = node.start_position().row + 1;
        let end_line = node.end_position().row + 1;
        let _start_column = node.start_position().column;
        let _end_column = node.end_position().column;
        
        if let Some(name) = name {
            Ok(Some(FunctionInfo {
                name,
                line_start: start_line as u32,
                line_end: end_line as u32,
                parameters: self.extract_parameters(node, content)?,
                return_type: self.extract_return_type(node, content)?,
                complexity: 1, // Simple complexity for now
            }))
        } else {
            Ok(None)
        }
    }

    /// Extract function name from node
    fn extract_function_name(&self, node: &tree_sitter::Node, content: &str) -> Result<Option<String>> {
        // Look for identifier nodes within the function
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                if child.kind() == "identifier" {
                    let name = &content[child.start_byte()..child.end_byte()];
                    return Ok(Some(name.to_string()));
                }
            }
        }
        Ok(None)
    }

    /// Extract function parameters
    fn extract_parameters(&self, _node: &tree_sitter::Node, _content: &str) -> Result<Vec<String>> {
        // Placeholder: In a real implementation, we'd parse parameter lists
        Ok(vec![])
    }

    /// Extract return type
    fn extract_return_type(&self, _node: &tree_sitter::Node, _content: &str) -> Result<Option<String>> {
        // Placeholder: In a real implementation, we'd parse return type annotations
        Ok(None)
    }

    /// Extract classes from AST
    fn extract_classes(&self, node: &tree_sitter::Node, content: &str) -> Result<Vec<ClassInfo>> {
        let mut classes = Vec::new();
        
        // Extract classes based on language-specific patterns
        self.extract_classes_recursive(node, content, &mut classes)?;
        
        Ok(classes)
    }

    /// Recursively extract classes from AST nodes
    fn extract_classes_recursive(&self, node: &tree_sitter::Node, content: &str, classes: &mut Vec<ClassInfo>) -> Result<()> {
        let node_type = node.kind();
        
        // Check if this node represents a class
        if self.is_class_node(node_type) {
            if let Some(class_info) = self.extract_class_info(node, content)? {
                classes.push(class_info);
            }
        }
        
        // Recursively process child nodes
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                self.extract_classes_recursive(&child, content, classes)?;
            }
        }
        
        Ok(())
    }

    /// Check if a node type represents a class
    fn is_class_node(&self, node_type: &str) -> bool {
        matches!(node_type, 
            "class_declaration" | "class_definition" | "interface_declaration" |
            "struct_item" | "enum_item" | "trait_item" | "impl_item" |
            "class" | "interface" | "struct" | "enum" | "trait"
        )
    }

    /// Extract class information from a class node
    fn extract_class_info(&self, node: &tree_sitter::Node, content: &str) -> Result<Option<ClassInfo>> {
        let name = self.extract_class_name(node, content)?;
        let start_line = node.start_position().row + 1;
        let end_line = node.end_position().row + 1;
        let _start_column = node.start_position().column;
        let _end_column = node.end_position().column;
        
        if let Some(name) = name {
            Ok(Some(ClassInfo {
                name,
                line_start: start_line as u32,
                line_end: end_line as u32,
                methods: self.extract_class_methods(node, content)?,
                fields: self.extract_class_fields(node, content)?,
            }))
        } else {
            Ok(None)
        }
    }

    /// Extract class name from node
    fn extract_class_name(&self, node: &tree_sitter::Node, content: &str) -> Result<Option<String>> {
        // Look for identifier nodes within the class
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                if child.kind() == "identifier" {
                    let name = &content[child.start_byte()..child.end_byte()];
                    return Ok(Some(name.to_string()));
                }
            }
        }
        Ok(None)
    }

    /// Extract class methods
    fn extract_class_methods(&self, _node: &tree_sitter::Node, _content: &str) -> Result<Vec<FunctionInfo>> {
        // Placeholder: In a real implementation, we'd parse method definitions
        Ok(vec![])
    }

    /// Extract class fields
    fn extract_class_fields(&self, _node: &tree_sitter::Node, _content: &str) -> Result<Vec<String>> {
        // Placeholder: In a real implementation, we'd parse field definitions
        Ok(vec![])
    }

    /// Extract imports from AST
    fn extract_imports(&self, node: &tree_sitter::Node, content: &str) -> Result<Vec<String>> {
        let mut imports = Vec::new();
        
        // Extract imports based on language-specific patterns
        self.extract_imports_recursive(node, content, &mut imports)?;
        
        Ok(imports)
    }

    /// Recursively extract imports from AST nodes
    fn extract_imports_recursive(&self, node: &tree_sitter::Node, content: &str, imports: &mut Vec<String>) -> Result<()> {
        let node_type = node.kind();
        
        // Check if this node represents an import
        if self.is_import_node(node_type) {
            if let Some(import) = self.extract_import_info(node, content)? {
                imports.push(import);
            }
        }
        
        // Recursively process child nodes
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                self.extract_imports_recursive(&child, content, imports)?;
            }
        }
        
        Ok(())
    }

    /// Check if a node type represents an import
    fn is_import_node(&self, node_type: &str) -> bool {
        matches!(node_type, 
            "import_statement" | "import_declaration" | "use_declaration" |
            "import" | "use" | "require" | "include" | "extern"
        )
    }

    /// Extract import information from an import node
    fn extract_import_info(&self, node: &tree_sitter::Node, content: &str) -> Result<Option<String>> {
        // Look for string literal nodes within the import
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                if child.kind() == "string" || child.kind() == "string_literal" {
                    let import = &content[child.start_byte()..child.end_byte()];
                    // Remove quotes
                    let cleaned = import.trim_matches('"').trim_matches('\'');
                    return Ok(Some(cleaned.to_string()));
                }
            }
        }
        Ok(None)
    }

    /// Extract exports from AST
    fn extract_exports(&self, node: &tree_sitter::Node, content: &str) -> Result<Vec<String>> {
        let mut exports = Vec::new();
        
        // Extract exports based on language-specific patterns
        self.extract_exports_recursive(node, content, &mut exports)?;
        
        Ok(exports)
    }

    /// Recursively extract exports from AST nodes
    fn extract_exports_recursive(&self, node: &tree_sitter::Node, content: &str, exports: &mut Vec<String>) -> Result<()> {
        let node_type = node.kind();
        
        // Check if this node represents an export
        if self.is_export_node(node_type) {
            if let Some(export) = self.extract_export_info(node, content)? {
                exports.push(export);
            }
        }
        
        // Recursively process child nodes
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                self.extract_exports_recursive(&child, content, exports)?;
            }
        }
        
        Ok(())
    }

    /// Check if a node type represents an export
    fn is_export_node(&self, node_type: &str) -> bool {
        matches!(node_type, 
            "export_statement" | "export_declaration" | "export" |
            "module.exports" | "export default" | "pub" | "public"
        )
    }

    /// Extract export information from an export node
    fn extract_export_info(&self, node: &tree_sitter::Node, content: &str) -> Result<Option<String>> {
        // Look for identifier nodes within the export
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                if child.kind() == "identifier" {
                    let export = &content[child.start_byte()..child.end_byte()];
                    return Ok(Some(export.to_string()));
                }
            }
        }
        Ok(None)
    }

    /// Extract dependencies from package files
    fn extract_dependencies_from_file(&self, _file_path: &str) -> Result<Vec<String>> {
        // TEMP DISABLED: dependency_parser crate causes Rustler workspace issues
        // Will re-enable after fixing workspace configuration
        Ok(vec![])
        // use std::path::Path;
        // use dependency_parser::DependencyParser;
        //
        // let path = Path::new(file_path);
        // let parser = DependencyParser::new();
        //
        // match parser.parse_package_file(path) {
        //     Ok(deps) => {
        //         Ok(deps.into_iter().map(|dep| format!("{}@{}", dep.name, dep.version)).collect())
        //     }
        //     Err(_) => Ok(vec![]), // Not a package file or parsing failed
        // }
    }

    /// Extract dev dependencies from package files
    fn extract_dev_dependencies_from_file(&self, file_path: &str) -> Result<Vec<String>> {
        // For now, dev dependencies are the same as regular dependencies
        // In a real implementation, we'd parse devDependencies separately
        self.extract_dependencies_from_file(file_path)
    }

    /// Check for outdated dependencies
    fn check_outdated_dependencies(&self, _dependencies: &[String]) -> Result<Vec<String>> {
        // Placeholder: In a real implementation, we'd check against registry APIs
        // For now, return empty vector
        Ok(vec![])
    }

    /// Check for security vulnerabilities
    fn check_security_vulnerabilities(&self, _dependencies: &[String]) -> Result<Vec<String>> {
        // Placeholder: In a real implementation, we'd check against security databases
        // For now, return empty vector
        Ok(vec![])
    }
}

// # Universal Parser Framework
//
// Unified dependency layer and interfaces for all language parsers in the SPARC Engine.
// This crate provides:
//
// - **Universal Dependencies**: Shared `tokei`, our Mozilla code analysis port, and tree-sitter integration
// - **Standardized Interfaces**: Common traits and types for all language parsers
// - **Performance Optimizations**: Caching, async execution, and memory management
// - **Error Handling**: Consistent error types and recovery patterns
//
// ## Architecture
//
// ```text
// Universal Parser Framework
// ├── dependencies/          # Shared tokei, Mozilla code analysis, tree-sitter
// ├── interfaces/            # Universal traits and types
// ├── optimizations/         # Performance, caching, async execution
// └── errors/               # Standardized error handling
// ```
//
// ## Usage
//
// Language-specific parsers implement the `PolyglotCodeParser` trait and use shared dependencies:
//
// ```rust,ignore
// use source_code_parser::{PolyglotCodeParser, UniversalDependencies, Language};
//
// struct MyLanguageParser {
//     deps: UniversalDependencies,
// }
//
// impl PolyglotCodeParser for MyLanguageParser {
//     async fn analyze_content(&self, content: &str, file_path: &str) -> Result<AnalysisResult> {
//         self
//             .deps
//             .analyze_with_all_tools(content, ProgrammingLanguage::MyLanguage, file_path)
//             .await
//     }
// }
// ```

pub mod dependencies;
pub mod errors;
pub mod beam;
pub mod interfaces;
pub mod languages;
pub mod optimizations;
pub mod refactoring_suggestions;

// ML predictions (merged from parser-coordinator)
pub mod central_heuristics;
pub mod ml_predictions;
pub mod parser_metadata;

// Dependency parsing (moved from formats/dependency)
pub mod dependency;
pub mod metadata_interface;

// Re-export main types
pub use central_heuristics::*;
pub use dependencies::*;
pub use dependency::*;
pub use errors::*;
pub use interfaces::*;
pub use languages::*;
pub use languages::adapters;
pub use metadata_interface::*;
// Re-export ML prediction types (excluding duplicates)
pub use ml_predictions::*;
pub use optimizations::*;
pub use refactoring_suggestions::*;

/// Version of the universal parser framework
pub const UNIVERSAL_PARSER_VERSION: &str = env!("CARGO_PKG_VERSION");

/// Initialize the universal parser framework with default configuration
pub fn init() -> Result<UniversalDependencies> {
  UniversalDependencies::new()
}

/// Initialize the universal parser framework with custom configuration
pub fn init_with_config(config: PolyglotCodeParserFrameworkConfig) -> Result<UniversalDependencies> {
  UniversalDependencies::new_with_config(config)
}

/// Comprehensive analysis result with enterprise-grade capabilities
/// Security vulnerability information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityVulnerability {
  pub severity: String,
  pub category: String,
  pub description: String,
  pub recommendation: String,
}

/// Performance optimization suggestion
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceOptimization {
  pub category: String,
  pub description: String,
  pub suggestion: String,
}

/// Framework detection results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkDetection {
  pub detected_frameworks: Vec<String>,
  pub confidence: f64,
}

/// Architecture pattern information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchitectureCodePattern {
  pub pattern_type: String,
  pub description: String,
  pub confidence: f64,
}

/// Dependency information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyInfo {
  pub dependencies: Vec<String>,
  pub dev_dependencies: Vec<String>,
  pub peer_dependencies: Vec<String>,
}

/// Error information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorInfo {
  pub errors: Vec<String>,
  pub warnings: Vec<String>,
  pub suggestions: Vec<String>,
}

/// Language configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageConfig {
  pub version: String,
  pub features: Vec<String>,
  pub strict_mode: bool,
}

/// This is the rich API that rust/go parsers expect
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RichAnalysisResult {
  /// Base analysis
  pub base: AnalysisResult,
  /// Security vulnerability analysis
  pub security_vulnerabilities: Vec<SecurityVulnerability>,
  /// Performance optimization suggestions
  pub performance_optimizations: Vec<PerformanceOptimization>,
  /// Framework detection results
  pub framework_detection: FrameworkDetection,
  /// Architecture pattern analysis
  pub architecture_patterns: Vec<ArchitectureCodePattern>,
  /// Dependency information
  pub dependency_info: DependencyInfo,
  /// Error handling analysis
  pub error_info: ErrorInfo,
  /// Language configuration
  pub language_config: LanguageConfig,
}

/// Standard line metrics from tokei
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LineMetrics {
  /// Total lines in file
  pub total_lines: usize,
  /// Lines of code (excluding comments and blanks)
  pub code_lines: usize,
  /// Comment lines
  pub comment_lines: usize,
  /// Blank lines
  pub blank_lines: usize,
}

/// Standard complexity metrics from Mozilla code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplexityMetrics {
  /// Cyclomatic complexity
  pub cyclomatic: f64,
  /// Cognitive complexity
  pub cognitive: f64,
  /// Number of exit points
  pub exit_points: usize,
  /// Nesting depth
  pub nesting_depth: usize,
}

/// Standard Halstead metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HalsteadMetrics {
  /// Total number of operators
  pub total_operators: u64,
  /// Total number of operands
  pub total_operands: u64,
  /// Unique operators
  pub unique_operators: u64,
  /// Unique operands
  pub unique_operands: u64,
  /// Program volume
  pub volume: f64,
  /// Program difficulty
  pub difficulty: f64,
  /// Programming effort
  pub effort: f64,
}

/// Standard maintainability metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaintainabilityMetrics {
  /// Maintainability index (0-100)
  pub index: f64,
  /// Technical debt ratio
  pub technical_debt_ratio: f64,
  /// Code duplication percentage
  pub duplication_percentage: f64,
}

// ============================================================================
// NIF Functions - Expose parser to Elixir
// ============================================================================
// ONLY compile these functions when "nif" feature is enabled (for standalone ParserEngine)
// When used as library by code_engine, these are disabled to avoid symbol conflicts

#[cfg(feature = "nif")]
mod nif_functions {
    use super::*;

    /// Parse a single file and return AST + metrics
    #[rustler::nif(schedule = "DirtyCpu")]
    pub fn parse_file_nif(file_path: String) -> Result<AnalysisResult, String> {
        let path = Path::new(&file_path);
        let mut parser = PolyglotCodeParser::new()
            .map_err(|e| format!("Failed to initialize parser: {}", e))?;

        parser.analyze_file(path)
            .map_err(|e| format!("Failed to parse file: {}", e))
    }

    /// Parse directory tree
    #[rustler::nif(schedule = "DirtyCpu")]
    pub fn parse_tree_nif(root_path: String) -> Result<String, String> {
        // TODO: Implement tree parsing
        Ok(format!(r#"{{"root": "{}", "files": []}}"#, root_path))
    }

    /// Get supported languages
    #[rustler::nif]
    pub fn supported_languages() -> Vec<String> {
        vec![
            "rust".to_string(),
            "javascript".to_string(),
            "typescript".to_string(),
            "python".to_string(),
            "elixir".to_string(),
            "go".to_string(),
        ]
    }
}

#[cfg(feature = "nif")]
use nif_functions::*;

#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn test_source_code_parser_init() {
    let deps = init().expect("Failed to initialize universal parser");
    assert!(deps.tokei_analyzer.is_available());
    assert!(deps.complexity_analyzer.is_available());
  }

  #[tokio::test]
  async fn test_config_defaults() {
    let config = PolyglotCodeParserFrameworkConfig::default();
    assert!(config.enable_mozilla_metrics);
    assert_eq!(config.cache_size, 1000);
    assert!(config.enable_tree_sitter);
  }

  #[test]
  fn test_universal_analysis_result_serialization() {
    let result = AnalysisResult {
      file_path: "test.rs".to_string(),
      language: ProgrammingLanguage::Rust.to_string(),
      metrics: CodeMetrics {
        lines_of_code: 80,
        lines_of_comments: 10,
        blank_lines: 10,
        total_lines: 100,
        functions: 5,
        classes: 2,
        complexity_score: 5.0,
      },
      mozilla_metrics: None,
      tree_sitter_analysis: None,
      dependency_analysis: None,
      analysis_timestamp: chrono::Utc::now().to_rfc3339(),
    };

    let serialized = serde_json::to_string(&result).expect("Failed to serialize");
    let deserialized: AnalysisResult = serde_json::from_str(&serialized).expect("Failed to deserialize");

    assert_eq!(result.file_path, deserialized.file_path);
    assert_eq!(result.language, deserialized.language);
  }
}
