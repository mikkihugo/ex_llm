//! Language Registry - Centralized language management for parser engine
//!
//! This module provides a comprehensive language registry that serves as the single
//! source of truth for all language-related information across the parser engine.
//!
//! ## Features
//!
//! - **Single Source of Truth**: All language information in one place
//! - **Consistent Naming**: Standardized language identifiers across all components
//! - **Capability Tracking**: Explicit tracking of what each language supports
//! - **Performance Optimized**: Pre-built maps for fast lookups
//! - **Extensible**: Easy to add new languages and capabilities

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;

/// Language-level pattern signatures (syntax/keywords only, NOT libraries!)
///
/// **IMPORTANT**: This should ONLY contain language syntax features, NOT libraries/frameworks.
/// Libraries and frameworks (kafka, reqwest, NATS, etc.) should come from CentralCloud patterns.
///
/// Examples:
/// - ✅ Language features: "Result<", "async", "await", "?", "try:", "catch"
/// - ❌ Libraries: "kafka", "reqwest", "express" (these go in CentralCloud!)
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PatternSignatures {
    /// Error handling SYNTAX (language keywords, not libraries)
    /// Examples: ["Result<", "?", "unwrap"] for Rust, ["try:", "except"] for Python
    pub error_handling_syntax: Vec<String>,
    /// Async/concurrency SYNTAX (language keywords, not libraries)
    /// Examples: ["async", "await"] for Rust/JS, ["spawn", "Task"] for Elixir
    pub async_syntax: Vec<String>,
    /// Testing SYNTAX (language built-ins, not frameworks)
    /// Examples: ["#[test]", "assert!"] for Rust, ["deftest"] for Elixir
    pub testing_syntax: Vec<String>,
    /// Pattern matching SYNTAX
    /// Examples: ["match", "case"] for Rust, ["case", "when"] for Elixir
    pub pattern_matching_syntax: Vec<String>,
    /// Module/import SYNTAX
    /// Examples: ["use", "mod"] for Rust, ["import", "alias"] for Elixir
    pub module_syntax: Vec<String>,
}

/// Tokenization profile for semantic code analysis
///
/// Contains language-specific keywords and tokenization rules for
/// semantic analysis and vector generation.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TokenizationProfile {
    /// Keywords specific to this language for semantic tokenization
    pub keywords: Vec<String>,
}

/// Syntax patterns for code analysis and complexity calculation
///
/// Contains language-specific syntax patterns used for semantic analysis,
/// complexity calculation, and code understanding.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct SyntaxPatterns {
    /// Function definition patterns (e.g., ["fn ", "def ", "function "])
    pub function_definitions: Vec<String>,
    /// Control flow patterns (e.g., ["if ", "for ", "while "])
    pub control_flow: Vec<String>,
    /// Operator patterns (e.g., ["&&", "||", "=="])
    pub operators: Vec<String>,
    /// Opening delimiters for nesting (e.g., ["{", ":"], ["do"])
    pub opening_delimiters: Vec<String>,
    /// Closing delimiters for nesting (e.g., ["}"], ["end"])
    pub closing_delimiters: Vec<String>,
    /// Comment patterns (e.g., ["//", "/*", "#"])
    pub comments: Vec<String>,
    /// Error handling patterns (e.g., ["try", "catch", "Result"])
    pub error_handling: Vec<String>,
}

/// Comprehensive language information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageInfo {
    /// Unique language identifier (e.g., "rust", "elixir")
    pub id: String,
    /// Human-readable language name (e.g., "Rust", "Elixir")
    pub name: String,
    /// File extensions for this language (e.g., ["rs"], ["ex", "exs"])
    pub extensions: Vec<String>,
    /// Alternative names/aliases (e.g., ["js", "javascript"])
    pub aliases: Vec<String>,
    /// Tree-sitter language name (if supported)
    pub tree_sitter_language: Option<String>,
    /// Whether RCA (rust-code-analysis) supports this language
    pub rca_supported: bool,
    /// Whether AST-Grep supports this language
    pub ast_grep_supported: bool,
    /// MIME types for this language
    pub mime_types: Vec<String>,
    /// Language family (e.g., "BEAM", "C-like", "Web")
    pub family: Option<String>,
    /// Whether this is a compiled or interpreted language
    pub is_compiled: bool,
    /// Pattern signatures for cross-language pattern detection
    #[serde(default)]
    pub pattern_signatures: PatternSignatures,
    /// Tokenization profile for semantic analysis
    #[serde(default)]
    pub tokenization_profile: TokenizationProfile,
    /// Syntax patterns for code analysis and complexity calculation
    #[serde(default)]
    pub syntax_patterns: SyntaxPatterns,
}

/// Central language registry with optimized lookups
pub struct LanguageRegistry {
    /// Primary language storage by ID
    languages: HashMap<String, LanguageInfo>,
    /// Fast extension -> language ID mapping
    extension_map: HashMap<String, String>,
    /// Fast alias -> language ID mapping
    alias_map: HashMap<String, String>,
    /// Fast MIME type -> language ID mapping
    mime_map: HashMap<String, String>,
}

impl LanguageRegistry {
    /// Create a new language registry with all supported languages
    pub fn new() -> Self {
        let mut registry = Self {
            languages: HashMap::new(),
            extension_map: HashMap::new(),
            alias_map: HashMap::new(),
            mime_map: HashMap::new(),
        };

        // Register all supported languages
        registry.register_all_languages();
        registry
    }

    /// Register all supported languages
    fn register_all_languages(&mut self) {
        // BEAM Languages
        self.register_language(LanguageInfo {
            id: "elixir".to_string(),
            name: "Elixir".to_string(),
            extensions: vec!["ex".to_string(), "exs".to_string()],
            aliases: vec!["elixir".to_string()],
            tree_sitter_language: Some("elixir".to_string()),
            rca_supported: true, // Singularity implements full BEAM analysis + RCA metrics
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-elixir".to_string(),
                "application/x-elixir".to_string(),
            ],
            family: Some("BEAM".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "def".to_string(), "defp".to_string(), "defm".to_string(), "defmodule".to_string(),
                    "defstruct".to_string(), "defexception".to_string(), "defprotocol".to_string(),
                    "defimpl".to_string(), "if".to_string(), "unless".to_string(), "case".to_string(),
                    "cond".to_string(), "for".to_string(), "try".to_string(), "catch".to_string(),
                    "rescue".to_string(), "after".to_string(), "receive".to_string(), "import".to_string(),
                    "alias".to_string(), "require".to_string(), "use".to_string(), "when".to_string(),
                    "do".to_string(), "end".to_string(), "and".to_string(), "or".to_string(),
                    "not".to_string(), "in".to_string(), "fn".to_string(), "quote".to_string(),
                    "unquote".to_string(), "unquote_splicing".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["def ".to_string(), "defp ".to_string(), "defmacro ".to_string()],
                control_flow: vec!["if ".to_string(), "unless ".to_string(), "case ".to_string(), "cond ".to_string(), "with ".to_string(), "for ".to_string(), "while ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "and".to_string(), "or".to_string(), "|>".to_string(), "->".to_string(), "=>".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["#".to_string()],
                error_handling: vec!["try".to_string(), "catch".to_string(), "rescue".to_string(), "raise".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "erlang".to_string(),
            name: "Erlang".to_string(),
            extensions: vec!["erl".to_string(), "hrl".to_string()],
            aliases: vec!["erlang".to_string()],
            tree_sitter_language: Some("erlang".to_string()),
            rca_supported: true, // Singularity implements full BEAM analysis + RCA metrics
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-erlang".to_string(),
                "application/x-erlang".to_string(),
            ],
            family: Some("BEAM".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "module".to_string(), "export".to_string(), "import".to_string(), "function".to_string(),
                    "case".to_string(), "if".to_string(), "of".to_string(), "when".to_string(),
                    "try".to_string(), "catch".to_string(), "after".to_string(), "receive".to_string(),
                    "send".to_string(), "spawn".to_string(), "link".to_string(), "monitor".to_string(),
                    "record".to_string(), "include".to_string(), "define".to_string(), "ifdef".to_string(),
                    "ifndef".to_string(), "endif".to_string(), "error".to_string(), "warning".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["-spec ".to_string(), "when ".to_string()],
                control_flow: vec!["case ".to_string(), "if ".to_string(), "receive ".to_string()],
                operators: vec!["and".to_string(), "or".to_string(), "not".to_string(), "andalso".to_string(), "orelse".to_string()],
                opening_delimiters: vec!["(".to_string()],
                closing_delimiters: vec![")".to_string()],
                comments: vec!["%".to_string()],
                error_handling: vec!["try".to_string(), "catch".to_string(), "throw".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "gleam".to_string(),
            name: "Gleam".to_string(),
            extensions: vec!["gleam".to_string()],
            aliases: vec!["gleam".to_string()],
            tree_sitter_language: Some("gleam".to_string()),
            rca_supported: true, // Singularity implements full BEAM analysis + RCA metrics
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-gleam".to_string(),
                "application/x-gleam".to_string(),
            ],
            family: Some("BEAM".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "pub".to_string(), "fn".to_string(), "type".to_string(), "const".to_string(),
                    "assert".to_string(), "let".to_string(), "case".to_string(), "try".to_string(),
                    "use".to_string(), "import".to_string(), "as".to_string(), "assert_equal".to_string(),
                    "panic".to_string(), "todo".to_string(), "result".to_string(), "option".to_string(),
                    "ok".to_string(), "error".to_string(), "nil".to_string(), "true".to_string(),
                    "false".to_string(), "list".to_string(), "string".to_string(), "int".to_string(),
                    "float".to_string(), "bool".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["pub fn ".to_string(), "fn ".to_string()],
                control_flow: vec!["case ".to_string(), "if ".to_string(), "try ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "==".to_string(), "!=".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string()],
                error_handling: vec!["try".to_string(), "case".to_string(), "assert".to_string()],
            },
        });

        // Systems Programming Languages
        self.register_language(LanguageInfo {
            id: "rust".to_string(),
            name: "Rust".to_string(),
            extensions: vec!["rs".to_string()],
            aliases: vec!["rust".to_string()],
            tree_sitter_language: Some("rust".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-rust".to_string(), "application/x-rust".to_string()],
            family: Some("Systems".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures {
                // Only language syntax, NOT libraries!
                error_handling_syntax: vec![
                    "Result<".to_string(),
                    "Option<".to_string(),
                    "?".to_string(),
                    "unwrap".to_string(),
                    "expect".to_string(),
                ],
                async_syntax: vec![
                    "async".to_string(),
                    "await".to_string(),
                    ".await".to_string(),
                ],
                testing_syntax: vec![
                    "#[test]".to_string(),
                    "assert!".to_string(),
                    "assert_eq!".to_string(),
                    "#[cfg(test)]".to_string(),
                ],
                pattern_matching_syntax: vec![
                    "match".to_string(),
                    "if let".to_string(),
                    "while let".to_string(),
                ],
                module_syntax: vec![
                    "use".to_string(),
                    "mod".to_string(),
                    "pub".to_string(),
                    "crate::".to_string(),
                ],
            },
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "fn".to_string(), "struct".to_string(), "enum".to_string(), "trait".to_string(),
                    "impl".to_string(), "pub".to_string(), "async".to_string(), "await".to_string(),
                    "mod".to_string(), "use".to_string(), "let".to_string(), "mut".to_string(),
                    "const".to_string(), "static".to_string(), "type".to_string(), "if".to_string(),
                    "else".to_string(), "for".to_string(), "while".to_string(), "loop".to_string(),
                    "match".to_string(), "return".to_string(), "yield".to_string(), "break".to_string(),
                    "continue".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["fn ".to_string(), "async fn ".to_string()],
                control_flow: vec!["if ".to_string(), "match ".to_string(), "while ".to_string(), "for ".to_string(), "loop ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "&".to_string(), "|".to_string(), "->".to_string(), "=>".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["Result".to_string(), "Option".to_string(), "match".to_string(), "if let".to_string(), "unwrap".to_string(), "expect".to_string(), "?".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "c".to_string(),
            name: "C".to_string(),
            extensions: vec!["c".to_string(), "h".to_string()],
            aliases: vec!["c".to_string()],
            tree_sitter_language: Some("c".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-c".to_string(), "text/x-csrc".to_string()],
            family: Some("C-like".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // C keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["void ".to_string(), "int ".to_string(), "char ".to_string(), "float ".to_string()],
                control_flow: vec!["if ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "switch ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "==".to_string(), "!=".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["if".to_string(), "assert".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "cpp".to_string(),
            name: "C++".to_string(),
            extensions: vec![
                "cpp".to_string(),
                "cc".to_string(),
                "cxx".to_string(),
                "c++".to_string(),
                "hpp".to_string(),
            ],
            aliases: vec![
                "cpp".to_string(),
                "c++".to_string(),
                "cplusplus".to_string(),
            ],
            tree_sitter_language: Some("cpp".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-c++".to_string(), "text/x-cpp".to_string()],
            family: Some("C-like".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "int".to_string(), "float".to_string(), "double".to_string(), "char".to_string(),
                    "void".to_string(), "bool".to_string(), "struct".to_string(), "union".to_string(),
                    "enum".to_string(), "class".to_string(), "template".to_string(), "namespace".to_string(),
                    "using".to_string(), "typedef".to_string(), "define".to_string(), "ifdef".to_string(),
                    "ifndef".to_string(), "endif".to_string(), "if".to_string(), "else".to_string(),
                    "for".to_string(), "while".to_string(), "do".to_string(), "switch".to_string(),
                    "case".to_string(), "default".to_string(), "return".to_string(), "break".to_string(),
                    "continue".to_string(), "goto".to_string(), "static".to_string(), "const".to_string(),
                    "volatile".to_string(), "inline".to_string(), "virtual".to_string(), "public".to_string(),
                    "private".to_string(), "protected".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["void ".to_string(), "int ".to_string(), "bool ".to_string(), "string ".to_string()],
                control_flow: vec!["if ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "switch ".to_string(), "try ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "==".to_string(), "!=".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["try".to_string(), "catch".to_string(), "throw".to_string()],
            },
        });

        // Web Technologies
        self.register_language(LanguageInfo {
            id: "javascript".to_string(),
            name: "JavaScript".to_string(),
            extensions: vec!["js".to_string(), "jsx".to_string()],
            aliases: vec!["javascript".to_string(), "js".to_string()],
            tree_sitter_language: Some("javascript".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec![
                "text/javascript".to_string(),
                "application/javascript".to_string(),
            ],
            family: Some("Web".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "function".to_string(), "async".to_string(), "await".to_string(), "class".to_string(),
                    "import".to_string(), "export".to_string(), "const".to_string(), "let".to_string(),
                    "var".to_string(), "if".to_string(), "else".to_string(), "for".to_string(),
                    "while".to_string(), "do".to_string(), "switch".to_string(), "case".to_string(),
                    "default".to_string(), "return".to_string(), "break".to_string(), "continue".to_string(),
                    "try".to_string(), "catch".to_string(), "finally".to_string(), "throw".to_string(),
                    "new".to_string(), "this".to_string(), "super".to_string(), "static".to_string(),
                    "extends".to_string(), "implements".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["function ".to_string(), "=> ".to_string(), "async function ".to_string()],
                control_flow: vec!["if ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "switch ".to_string(), "try ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "===".to_string(), "!==".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["try".to_string(), "catch".to_string(), "throw".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "typescript".to_string(),
            name: "TypeScript".to_string(),
            extensions: vec!["ts".to_string(), "tsx".to_string()],
            aliases: vec!["typescript".to_string(), "ts".to_string()],
            tree_sitter_language: Some("typescript".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec![
                "text/typescript".to_string(),
                "application/typescript".to_string(),
            ],
            family: Some("Web".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "function".to_string(), "async".to_string(), "await".to_string(), "class".to_string(),
                    "interface".to_string(), "type".to_string(), "enum".to_string(), "import".to_string(),
                    "export".to_string(), "const".to_string(), "let".to_string(), "var".to_string(),
                    "if".to_string(), "else".to_string(), "for".to_string(), "while".to_string(),
                    "do".to_string(), "switch".to_string(), "case".to_string(), "return".to_string(),
                    "break".to_string(), "continue".to_string(), "default".to_string(), "static".to_string(),
                    "public".to_string(), "private".to_string(), "protected".to_string(), "readonly".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["function ".to_string(), "=> ".to_string(), "async function ".to_string()],
                control_flow: vec!["if ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "switch ".to_string(), "try ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "===".to_string(), "!==".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["try".to_string(), "catch".to_string(), "throw".to_string()],
            },
        });

        // High-Level Languages
        self.register_language(LanguageInfo {
            id: "python".to_string(),
            name: "Python".to_string(),
            extensions: vec!["py".to_string(), "pyw".to_string()],
            aliases: vec!["python".to_string(), "py".to_string()],
            tree_sitter_language: Some("python".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-python".to_string(),
                "application/x-python".to_string(),
            ],
            family: Some("Scripting".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "def".to_string(), "class".to_string(), "async".to_string(), "await".to_string(),
                    "import".to_string(), "from".to_string(), "if".to_string(), "elif".to_string(),
                    "else".to_string(), "for".to_string(), "while".to_string(), "with".to_string(),
                    "try".to_string(), "except".to_string(), "finally".to_string(), "return".to_string(),
                    "yield".to_string(), "break".to_string(), "continue".to_string(), "pass".to_string(),
                    "lambda".to_string(), "global".to_string(), "nonlocal".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["def ".to_string(), "async def ".to_string()],
                control_flow: vec!["if ".to_string(), "elif ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "try ".to_string()],
                operators: vec!["and".to_string(), "or".to_string(), "not".to_string(), "in".to_string(), "is".to_string()],
                opening_delimiters: vec![":".to_string()],
                closing_delimiters: vec!["".to_string()],
                comments: vec!["#".to_string()],
                error_handling: vec!["try".to_string(), "except".to_string(), "finally".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "java".to_string(),
            name: "Java".to_string(),
            extensions: vec!["java".to_string()],
            aliases: vec!["java".to_string()],
            tree_sitter_language: Some("java".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-java".to_string(), "application/x-java".to_string()],
            family: Some("JVM".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "class".to_string(), "interface".to_string(), "enum".to_string(), "public".to_string(),
                    "private".to_string(), "protected".to_string(), "static".to_string(), "final".to_string(),
                    "abstract".to_string(), "synchronized".to_string(), "volatile".to_string(),
                    "transient".to_string(), "native".to_string(), "strictfp".to_string(),
                    "extends".to_string(), "implements".to_string(), "new".to_string(), "throw".to_string(),
                    "throws".to_string(), "try".to_string(), "catch".to_string(), "finally".to_string(),
                    "if".to_string(), "else".to_string(), "for".to_string(), "while".to_string(),
                    "do".to_string(), "switch".to_string(), "case".to_string(), "return".to_string(),
                    "break".to_string(), "continue".to_string(), "default".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["public ".to_string(), "private ".to_string(), "protected ".to_string()],
                control_flow: vec!["if ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "switch ".to_string(), "try ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "==".to_string(), "!=".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["try".to_string(), "catch".to_string(), "throw".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "csharp".to_string(),
            name: "C#".to_string(),
            extensions: vec!["cs".to_string()],
            aliases: vec!["csharp".to_string(), "cs".to_string(), "c#".to_string()],
            tree_sitter_language: Some("c_sharp".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-csharp".to_string(),
                "application/x-csharp".to_string(),
            ],
            family: Some("CLR".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "class".to_string(), "struct".to_string(), "interface".to_string(), "enum".to_string(),
                    "delegate".to_string(), "namespace".to_string(), "using".to_string(), "public".to_string(),
                    "private".to_string(), "protected".to_string(), "internal".to_string(), "static".to_string(),
                    "readonly".to_string(), "volatile".to_string(), "const".to_string(), "abstract".to_string(),
                    "sealed".to_string(), "partial".to_string(), "async".to_string(), "await".to_string(),
                    "if".to_string(), "else".to_string(), "for".to_string(), "foreach".to_string(),
                    "while".to_string(), "do".to_string(), "switch".to_string(), "case".to_string(),
                    "default".to_string(), "return".to_string(), "break".to_string(), "continue".to_string(),
                    "throw".to_string(), "try".to_string(), "catch".to_string(), "finally".to_string(),
                    "yield".to_string(), "new".to_string(), "this".to_string(), "base".to_string(),
                    "virtual".to_string(), "override".to_string(), "abstract".to_string(), "is".to_string(),
                    "as".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["void ".to_string(), "public ".to_string(), "private ".to_string(), "async ".to_string()],
                control_flow: vec!["if ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "switch ".to_string(), "try ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "==".to_string(), "!=".to_string(), "??".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["try".to_string(), "catch".to_string(), "throw".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "go".to_string(),
            name: "Go".to_string(),
            extensions: vec!["go".to_string()],
            aliases: vec!["go".to_string(), "golang".to_string()],
            tree_sitter_language: Some("go".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-go".to_string(), "application/x-go".to_string()],
            family: Some("Systems".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![
                    "func".to_string(), "type".to_string(), "struct".to_string(), "interface".to_string(),
                    "import".to_string(), "package".to_string(), "const".to_string(), "var".to_string(),
                    "if".to_string(), "else".to_string(), "for".to_string(), "range".to_string(),
                    "switch".to_string(), "case".to_string(), "default".to_string(), "return".to_string(),
                    "break".to_string(), "continue".to_string(), "goto".to_string(), "fallthrough".to_string(),
                    "defer".to_string(), "go".to_string(), "chan".to_string(), "select".to_string(),
                    "map".to_string(), "make".to_string(), "new".to_string(), "len".to_string(),
                    "cap".to_string(), "append".to_string(), "copy".to_string(),
                ],
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["func ".to_string()],
                control_flow: vec!["if ".to_string(), "else ".to_string(), "for ".to_string(), "switch ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "==".to_string(), "!=".to_string()],
                opening_delimiters: vec!["{".to_string()],
                closing_delimiters: vec!["}".to_string()],
                comments: vec!["//".to_string(), "/*".to_string()],
                error_handling: vec!["if".to_string(), "err".to_string(), "panic".to_string()],
            },
        });

        // Scripting Languages
        self.register_language(LanguageInfo {
            id: "lua".to_string(),
            name: "Lua".to_string(),
            extensions: vec!["lua".to_string()],
            aliases: vec!["lua".to_string()],
            tree_sitter_language: Some("lua".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["text/x-lua".to_string(), "application/x-lua".to_string()],
            family: Some("Scripting".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Lua keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["function ".to_string()],
                control_flow: vec!["if ".to_string(), "elseif ".to_string(), "for ".to_string(), "while ".to_string()],
                operators: vec!["and".to_string(), "or".to_string(), "not".to_string()],
                opening_delimiters: vec!["do".to_string()],
                closing_delimiters: vec!["end".to_string()],
                comments: vec!["--".to_string()],
                error_handling: vec!["pcall".to_string(), "xpcall".to_string()],
            },
        });

        self.register_language(LanguageInfo {
            id: "bash".to_string(),
            name: "Bash".to_string(),
            extensions: vec!["sh".to_string(), "bash".to_string()],
            aliases: vec!["bash".to_string(), "sh".to_string(), "shell".to_string()],
            tree_sitter_language: Some("bash".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["text/x-sh".to_string(), "application/x-sh".to_string()],
            family: Some("Shell".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Bash keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // Data Formats
        self.register_language(LanguageInfo {
            id: "json".to_string(),
            name: "JSON".to_string(),
            extensions: vec!["json".to_string()],
            aliases: vec!["json".to_string()],
            tree_sitter_language: Some("json".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["application/json".to_string()],
            family: Some("Data".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // JSON has no keywords
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        self.register_language(LanguageInfo {
            id: "yaml".to_string(),
            name: "YAML".to_string(),
            extensions: vec!["yaml".to_string(), "yml".to_string()],
            aliases: vec!["yaml".to_string(), "yml".to_string()],
            tree_sitter_language: Some("yaml".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["text/yaml".to_string(), "application/x-yaml".to_string()],
            family: Some("Data".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // YAML has no keywords
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        self.register_language(LanguageInfo {
            id: "toml".to_string(),
            name: "TOML".to_string(),
            extensions: vec!["toml".to_string()],
            aliases: vec!["toml".to_string()],
            tree_sitter_language: Some("toml".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["text/x-toml".to_string(), "application/toml".to_string()],
            family: Some("Data".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // TOML has no keywords
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // Documentation
        self.register_language(LanguageInfo {
            id: "markdown".to_string(),
            name: "Markdown".to_string(),
            extensions: vec!["md".to_string(), "markdown".to_string()],
            aliases: vec!["markdown".to_string(), "md".to_string()],
            tree_sitter_language: Some("markdown".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["text/markdown".to_string(), "text/x-markdown".to_string()],
            family: Some("Documentation".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Markdown has no keywords
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // Infrastructure
        self.register_language(LanguageInfo {
            id: "dockerfile".to_string(),
            name: "Dockerfile".to_string(),
            extensions: vec!["dockerfile".to_string(), "Dockerfile".to_string()],
            aliases: vec!["dockerfile".to_string(), "docker".to_string()],
            tree_sitter_language: Some("dockerfile".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["text/x-dockerfile".to_string()],
            family: Some("Infrastructure".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Dockerfile keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        self.register_language(LanguageInfo {
            id: "sql".to_string(),
            name: "SQL".to_string(),
            extensions: vec!["sql".to_string()],
            aliases: vec!["sql".to_string()],
            tree_sitter_language: Some("sql".to_string()),
            rca_supported: false,
            ast_grep_supported: true,
            mime_types: vec!["text/x-sql".to_string(), "application/sql".to_string()],
            family: Some("Database".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // SQL keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // NEW: Ruby (0.21.0)
        self.register_language(LanguageInfo {
            id: "ruby".to_string(),
            name: "Ruby".to_string(),
            extensions: vec!["rb".to_string()],
            aliases: vec!["ruby".to_string()],
            tree_sitter_language: Some("ruby".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-ruby".to_string(), "application/x-ruby".to_string()],
            family: Some("Scripting".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Ruby keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns {
                function_definitions: vec!["def ".to_string()],
                control_flow: vec!["if ".to_string(), "elsif ".to_string(), "else ".to_string(), "for ".to_string(), "while ".to_string(), "begin ".to_string()],
                operators: vec!["&&".to_string(), "||".to_string(), "!".to_string(), "==".to_string(), "!=".to_string()],
                opening_delimiters: vec!["do".to_string(), "{".to_string()],
                closing_delimiters: vec!["end".to_string(), "}".to_string()],
                comments: vec!["#".to_string()],
                error_handling: vec!["begin".to_string(), "rescue".to_string(), "ensure".to_string()],
            },
        });

        // NEW: PHP (0.23.8)
        self.register_language(LanguageInfo {
            id: "php".to_string(),
            name: "PHP".to_string(),
            extensions: vec![
                "php".to_string(),
                "php5".to_string(),
                "php7".to_string(),
                "php8".to_string(),
            ],
            aliases: vec!["php".to_string()],
            tree_sitter_language: Some("php".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-php".to_string(), "application/x-php".to_string()],
            family: Some("Web".to_string()),
            is_compiled: false,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // PHP keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // NEW: Dart (0.8.2)
        self.register_language(LanguageInfo {
            id: "dart".to_string(),
            name: "Dart".to_string(),
            extensions: vec!["dart".to_string()],
            aliases: vec!["dart".to_string()],
            tree_sitter_language: Some("dart".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec!["text/x-dart".to_string(), "application/x-dart".to_string()],
            family: Some("Mobile".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Dart keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // NEW: Swift (0.3.7)
        self.register_language(LanguageInfo {
            id: "swift".to_string(),
            name: "Swift".to_string(),
            extensions: vec!["swift".to_string()],
            aliases: vec!["swift".to_string()],
            tree_sitter_language: Some("swift".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-swift".to_string(),
                "application/x-swift".to_string(),
            ],
            family: Some("Mobile".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Swift keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // NEW: Clojure (0.1.12)
        self.register_language(LanguageInfo {
            id: "clojure".to_string(),
            name: "Clojure".to_string(),
            extensions: vec![
                "clj".to_string(),
                "cljs".to_string(),
                "cljc".to_string(),
                "edn".to_string(),
            ],
            aliases: vec!["clojure".to_string()],
            tree_sitter_language: Some("clojure".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-clojure".to_string(),
                "application/x-clojure".to_string(),
            ],
            family: Some("Functional".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Clojure keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });

        // NEW: Scala (0.2.4)
        self.register_language(LanguageInfo {
            id: "scala".to_string(),
            name: "Scala".to_string(),
            extensions: vec!["scala".to_string(), "sc".to_string()],
            aliases: vec!["scala".to_string()],
            tree_sitter_language: Some("scala".to_string()),
            rca_supported: true,
            ast_grep_supported: true,
            mime_types: vec![
                "text/x-scala".to_string(),
                "application/x-scala".to_string(),
            ],
            family: Some("JVM".to_string()),
            is_compiled: true,
            pattern_signatures: PatternSignatures::default(),
            tokenization_profile: TokenizationProfile {
                keywords: vec![], // Scala keywords not implemented in custom_tokenizers.rs
            },
            syntax_patterns: SyntaxPatterns::default(),
        });
    }

    /// Register a single language
    fn register_language(&mut self, language: LanguageInfo) {
        let id = language.id.clone();

        // Store the language
        self.languages.insert(id.clone(), language);

        // Build extension map
        for ext in &self.languages[&id].extensions {
            self.extension_map.insert(ext.clone(), id.clone());
        }

        // Build alias map
        for alias in &self.languages[&id].aliases {
            self.alias_map.insert(alias.clone(), id.clone());
        }

        // Build MIME type map
        for mime_type in &self.languages[&id].mime_types {
            self.mime_map.insert(mime_type.clone(), id.clone());
        }
    }

    /// Detect language from file path
    pub fn detect_language(&self, file_path: &Path) -> Result<&LanguageInfo> {
        let extension = file_path
            .extension()
            .and_then(|ext| ext.to_str())
            .ok_or_else(|| anyhow::anyhow!("No file extension found"))?;

        let language_id = self
            .extension_map
            .get(extension)
            .ok_or_else(|| anyhow::anyhow!("Unsupported file extension: {}", extension))?;

        self.languages
            .get(language_id)
            .ok_or_else(|| anyhow::anyhow!("Language not found: {}", language_id))
    }

    /// Get language by ID
    pub fn get_language(&self, id: &str) -> Option<&LanguageInfo> {
        self.languages.get(id)
    }

    /// Get language by alias
    pub fn get_language_by_alias(&self, alias: &str) -> Option<&LanguageInfo> {
        let id = self.alias_map.get(alias)?;
        self.languages.get(id)
    }

    /// Get language by MIME type
    pub fn get_language_by_mime_type(&self, mime_type: &str) -> Option<&LanguageInfo> {
        let id = self.mime_map.get(mime_type)?;
        self.languages.get(id)
    }

    /// Get all supported languages
    pub fn supported_languages(&self) -> Vec<&LanguageInfo> {
        self.languages.values().collect()
    }

    /// Get languages that support RCA analysis
    pub fn rca_supported_languages(&self) -> Vec<&LanguageInfo> {
        self.languages
            .values()
            .filter(|lang| lang.rca_supported)
            .collect()
    }

    /// Get languages that support AST-Grep
    pub fn ast_grep_supported_languages(&self) -> Vec<&LanguageInfo> {
        self.languages
            .values()
            .filter(|lang| lang.ast_grep_supported)
            .collect()
    }

    /// Get languages by family
    pub fn languages_by_family(&self, family: &str) -> Vec<&LanguageInfo> {
        self.languages
            .values()
            .filter(|lang| lang.family.as_ref().is_some_and(|f| f == family))
            .collect()
    }

    /// Get all language IDs
    pub fn language_ids(&self) -> Vec<&String> {
        self.languages.keys().collect()
    }

    /// Get all file extensions
    pub fn all_extensions(&self) -> Vec<&String> {
        self.extension_map.keys().collect()
    }

    /// Check if language is supported
    pub fn is_supported(&self, id: &str) -> bool {
        self.languages.contains_key(id)
    }

    /// Check if file extension is supported
    pub fn is_extension_supported(&self, extension: &str) -> bool {
        self.extension_map.contains_key(extension)
    }

    /// Get language count
    pub fn language_count(&self) -> usize {
        self.languages.len()
    }
}

impl Default for LanguageRegistry {
    fn default() -> Self {
        Self::new()
    }
}

lazy_static::lazy_static! {
    /// Global language registry instance
    pub static ref LANGUAGE_REGISTRY: LanguageRegistry = LanguageRegistry::new();
}

/// Convenience functions for global registry
pub fn detect_language(file_path: &Path) -> Result<&'static LanguageInfo> {
    LANGUAGE_REGISTRY.detect_language(file_path)
}

pub fn get_language(id: &str) -> Option<&'static LanguageInfo> {
    LANGUAGE_REGISTRY.get_language(id)
}

pub fn get_language_by_alias(alias: &str) -> Option<&'static LanguageInfo> {
    LANGUAGE_REGISTRY.get_language_by_alias(alias)
}

pub fn supported_languages() -> Vec<&'static LanguageInfo> {
    LANGUAGE_REGISTRY.supported_languages()
}

pub fn rca_supported_languages() -> Vec<&'static LanguageInfo> {
    LANGUAGE_REGISTRY.rca_supported_languages()
}

pub fn ast_grep_supported_languages() -> Vec<&'static LanguageInfo> {
    LANGUAGE_REGISTRY.ast_grep_supported_languages()
}

pub fn get_language_by_mime_type(mime_type: &str) -> Option<&'static LanguageInfo> {
    LANGUAGE_REGISTRY.get_language_by_mime_type(mime_type)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn test_language_detection() {
        // Test Elixir detection
        let elixir_path = Path::new("test.ex");
        let language = detect_language(elixir_path).unwrap();
        assert_eq!(language.id, "elixir");
        assert_eq!(language.name, "Elixir");
        assert!(language.extensions.contains(&"ex".to_string()));
        assert!(language.extensions.contains(&"exs".to_string()));
        assert!(!language.rca_supported);
        assert!(language.ast_grep_supported);

        // Test Rust detection
        let rust_path = Path::new("test.rs");
        let language = detect_language(rust_path).unwrap();
        assert_eq!(language.id, "rust");
        assert_eq!(language.name, "Rust");
        assert!(language.rca_supported);
        assert!(language.ast_grep_supported);

        // Test JavaScript detection
        let js_path = Path::new("test.js");
        let language = detect_language(js_path).unwrap();
        assert_eq!(language.id, "javascript");
        assert_eq!(language.name, "JavaScript");
        assert!(language.aliases.contains(&"js".to_string()));
    }

    #[test]
    fn test_language_lookup() {
        // Test by ID
        let language = get_language("elixir").unwrap();
        assert_eq!(language.name, "Elixir");

        // Test by alias
        let language = get_language_by_alias("js").unwrap();
        assert_eq!(language.id, "javascript");

        // Test non-existent language
        assert!(get_language("nonexistent").is_none());
    }

    #[test]
    fn test_supported_languages() {
        let languages = supported_languages();
        assert!(languages.len() > 10); // Should have many languages
        assert!(languages.iter().any(|lang| lang.id == "elixir"));
        assert!(languages.iter().any(|lang| lang.id == "rust"));
        assert!(languages.iter().any(|lang| lang.id == "javascript"));
    }

    #[test]
    fn test_rca_supported_languages() {
        let rca_languages = rca_supported_languages();
        let rca_ids: Vec<&str> = rca_languages.iter().map(|lang| lang.id.as_str()).collect();

        // RCA should support these languages
        assert!(rca_ids.contains(&"rust"));
        assert!(rca_ids.contains(&"python"));
        assert!(rca_ids.contains(&"javascript"));
        assert!(rca_ids.contains(&"typescript"));
        assert!(rca_ids.contains(&"java"));
        assert!(rca_ids.contains(&"csharp"));
        assert!(rca_ids.contains(&"go"));
        assert!(rca_ids.contains(&"c"));
        assert!(rca_ids.contains(&"cpp"));

        // RCA should NOT support BEAM languages
        assert!(!rca_ids.contains(&"elixir"));
        assert!(!rca_ids.contains(&"erlang"));
        assert!(!rca_ids.contains(&"gleam"));
    }

    #[test]
    fn test_ast_grep_supported_languages() {
        let ast_grep_languages = ast_grep_supported_languages();
        let ast_grep_ids: Vec<&str> = ast_grep_languages
            .iter()
            .map(|lang| lang.id.as_str())
            .collect();

        // AST-Grep should support all languages
        assert!(ast_grep_ids.contains(&"elixir"));
        assert!(ast_grep_ids.contains(&"rust"));
        assert!(ast_grep_ids.contains(&"javascript"));
        assert!(ast_grep_ids.contains(&"python"));
        assert!(ast_grep_ids.contains(&"markdown"));
        assert!(ast_grep_ids.contains(&"yaml"));
        assert!(ast_grep_ids.contains(&"json"));
    }

    #[test]
    fn test_language_families() {
        let beam_languages = LANGUAGE_REGISTRY.languages_by_family("BEAM");
        let beam_ids: Vec<&str> = beam_languages.iter().map(|lang| lang.id.as_str()).collect();

        assert!(beam_ids.contains(&"elixir"));
        assert!(beam_ids.contains(&"erlang"));
        assert!(beam_ids.contains(&"gleam"));
        assert_eq!(beam_ids.len(), 3);
    }

    #[test]
    fn test_extension_mapping() {
        assert!(LANGUAGE_REGISTRY.is_extension_supported("rs"));
        assert!(LANGUAGE_REGISTRY.is_extension_supported("ex"));
        assert!(LANGUAGE_REGISTRY.is_extension_supported("js"));
        assert!(LANGUAGE_REGISTRY.is_extension_supported("py"));
        assert!(!LANGUAGE_REGISTRY.is_extension_supported("xyz"));
    }

    #[test]
    fn test_mime_type_detection() {
        let language = get_language_by_mime_type("text/x-rust").unwrap();
        assert_eq!(language.id, "rust");

        let language = get_language_by_mime_type("text/x-elixir").unwrap();
        assert_eq!(language.id, "elixir");

        let language = get_language_by_mime_type("application/json").unwrap();
        assert_eq!(language.id, "json");
    }
}
