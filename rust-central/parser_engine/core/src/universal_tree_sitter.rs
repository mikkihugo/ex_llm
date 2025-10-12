//! Universal Tree-Sitter Parser
//!
//! Provides tree-sitter parsing for all supported languages.
//! Each language uses its optimal tree-sitter grammar.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tree_sitter::{Language, Parser, Tree, Node};
use anyhow::Result;

/// Supported programming languages with tree-sitter
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum SupportedLanguage {
    // Core languages
    Rust,
    Python,
    JavaScript,
    TypeScript,
    Go,
    Java,
    C,
    Cpp,
    CSharp,
    
    // Functional languages
    Elixir,
    Erlang,
    Gleam,
    Haskell,
    Ocaml,
    FSharp,
    
    // Web languages
    Html,
    Css,
    Php,
    Dart,
    
    // Scripting languages
    Ruby,
    Lua,
    Perl,
    Bash,
    PowerShell,
    
    // Mobile languages
    Swift,
    Kotlin,
    
    // Data languages
    Json,
    Yaml,
    Toml,
    Xml,
    Markdown,
    
    // System languages
    Zig,
    Nim,
    V,
}

impl SupportedLanguage {
    pub fn from_extension(ext: &str) -> Option<Self> {
        match ext.to_lowercase().as_str() {
            "rs" => Some(Self::Rust),
            "py" => Some(Self::Python),
            "js" => Some(Self::JavaScript),
            "ts" | "tsx" => Some(Self::TypeScript),
            "go" => Some(Self::Go),
            "java" => Some(Self::Java),
            "c" => Some(Self::C),
            "cpp" | "cc" | "cxx" => Some(Self::Cpp),
            "cs" => Some(Self::CSharp),
            "ex" | "exs" => Some(Self::Elixir),
            "erl" | "hrl" => Some(Self::Erlang),
            "gleam" => Some(Self::Gleam),
            "hs" => Some(Self::Haskell),
            "ml" | "mli" => Some(Self::Ocaml),
            "fs" | "fsi" => Some(Self::FSharp),
            "html" | "htm" => Some(Self::Html),
            "css" => Some(Self::Css),
            "php" => Some(Self::Php),
            "dart" => Some(Self::Dart),
            "rb" => Some(Self::Ruby),
            "lua" => Some(Self::Lua),
            "pl" | "pm" => Some(Self::Perl),
            "sh" | "bash" => Some(Self::Bash),
            "ps1" => Some(Self::PowerShell),
            "swift" => Some(Self::Swift),
            "kt" | "kts" => Some(Self::Kotlin),
            "json" => Some(Self::Json),
            "yaml" | "yml" => Some(Self::Yaml),
            "toml" => Some(Self::Toml),
            "xml" => Some(Self::Xml),
            "md" | "markdown" => Some(Self::Markdown),
            "zig" => Some(Self::Zig),
            "nim" => Some(Self::Nim),
            "v" => Some(Self::V),
            _ => None,
        }
    }

    pub fn get_tree_sitter_language(&self) -> Result<Language> {
        match self {
            Self::Rust => Ok(tree_sitter_rust::language()),
            Self::Python => Ok(tree_sitter_python::language()),
            Self::JavaScript => Ok(tree_sitter_javascript::language()),
            Self::TypeScript => Ok(tree_sitter_typescript::language_typescript()),
            Self::Go => Ok(tree_sitter_go::language()),
            Self::Java => Ok(tree_sitter_java::language()),
            Self::C => Ok(tree_sitter_c::language()),
            Self::Cpp => Ok(tree_sitter_cpp::language()),
            Self::CSharp => Ok(tree_sitter_c_sharp::language()),
            Self::Elixir => Ok(tree_sitter_elixir::language()),
            Self::Erlang => Ok(tree_sitter_erlang::language()),
            Self::Gleam => Ok(tree_sitter_gleam::language()),
            Self::Haskell => Ok(tree_sitter_haskell::language()),
            Self::Ocaml => Ok(tree_sitter_ocaml::language()),
            Self::FSharp => Ok(tree_sitter_fsharp::language()),
            Self::Html => Ok(tree_sitter_html::language()),
            Self::Css => Ok(tree_sitter_css::language()),
            Self::Php => Ok(tree_sitter_php::language_php()),
            Self::Dart => Ok(tree_sitter_dart::language()),
            Self::Ruby => Ok(tree_sitter_ruby::language()),
            Self::Lua => Ok(tree_sitter_lua::language()),
            Self::Perl => Ok(tree_sitter_perl::language()),
            Self::Bash => Ok(tree_sitter_bash::language()),
            Self::PowerShell => Ok(tree_sitter_powershell::language()),
            Self::Swift => Ok(tree_sitter_swift::language()),
            Self::Kotlin => Ok(tree_sitter_kotlin::language()),
            Self::Json => Ok(tree_sitter_json::language()),
            Self::Yaml => Ok(tree_sitter_yaml::language()),
            Self::Toml => Ok(tree_sitter_toml::language()),
            Self::Xml => Ok(tree_sitter_xml::language()),
            Self::Markdown => Ok(tree_sitter_markdown::language()),
            Self::Zig => Ok(tree_sitter_zig::language()),
            Self::Nim => Ok(tree_sitter_nim::language()),
            Self::V => Ok(tree_sitter_v::language()),
        }
    }
}

/// Universal Tree-Sitter Parser
pub struct UniversalTreeSitterParser {
    parser: Parser,
    language_cache: HashMap<SupportedLanguage, Language>,
}

impl UniversalTreeSitterParser {
    pub fn new() -> Result<Self> {
        let mut parser = Parser::new();
        let mut language_cache = HashMap::new();
        
        // Pre-load all languages for better performance
        for lang in [
            SupportedLanguage::Rust,
            SupportedLanguage::Python,
            SupportedLanguage::JavaScript,
            SupportedLanguage::TypeScript,
            SupportedLanguage::Go,
            SupportedLanguage::Java,
            SupportedLanguage::C,
            SupportedLanguage::Cpp,
            SupportedLanguage::CSharp,
            SupportedLanguage::Elixir,
            SupportedLanguage::Erlang,
            SupportedLanguage::Gleam,
            SupportedLanguage::Html,
            SupportedLanguage::Css,
            SupportedLanguage::Php,
            SupportedLanguage::Ruby,
            SupportedLanguage::Lua,
            SupportedLanguage::Bash,
            SupportedLanguage::Swift,
            SupportedLanguage::Json,
            SupportedLanguage::Yaml,
            SupportedLanguage::Toml,
            SupportedLanguage::Xml,
        ] {
            if let Ok(language) = lang.get_tree_sitter_language() {
                language_cache.insert(lang, language);
            }
        }
        
        Ok(Self {
            parser,
            language_cache,
        })
    }

    pub fn parse(&mut self, source: &str, language: SupportedLanguage) -> Result<Tree> {
        let tree_sitter_lang = self.language_cache.get(&language)
            .ok_or_else(|| anyhow::anyhow!("Language {:?} not supported", language))?;
        
        self.parser.set_language(tree_sitter_lang)?;
        self.parser.parse(source, None)
            .ok_or_else(|| anyhow::anyhow!("Failed to parse source code"))
    }

    pub fn parse_file(&mut self, file_path: &str, source: &str) -> Result<Tree> {
        let ext = std::path::Path::new(file_path)
            .extension()
            .and_then(|s| s.to_str())
            .unwrap_or("");
        
        let language = SupportedLanguage::from_extension(ext)
            .ok_or_else(|| anyhow::anyhow!("Unsupported file extension: {}", ext))?;
        
        self.parse(source, language)
    }

    pub fn get_supported_languages(&self) -> Vec<SupportedLanguage> {
        self.language_cache.keys().cloned().collect()
    }

    pub fn is_language_supported(&self, language: SupportedLanguage) -> bool {
        self.language_cache.contains_key(&language)
    }
}

/// AST Node representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ASTNode {
    pub node_type: String,
    pub text: String,
    pub start_byte: usize,
    pub end_byte: usize,
    pub start_point: (usize, usize), // (row, column)
    pub end_point: (usize, usize),   // (row, column)
    pub children: Vec<ASTNode>,
    pub is_named: bool,
    pub is_missing: bool,
}

impl From<Node> for ASTNode {
    fn from(node: Node) -> Self {
        let mut children = Vec::new();
        for i in 0..node.child_count() {
            if let Some(child) = node.child(i) {
                children.push(ASTNode::from(child));
            }
        }

        Self {
            node_type: node.kind().to_string(),
            text: node.utf8_text(node.start_byte()..node.end_byte()).unwrap_or("").to_string(),
            start_byte: node.start_byte(),
            end_byte: node.end_byte(),
            start_point: (node.start_position().row, node.start_position().column),
            end_point: (node.end_position().row, node.end_position().column),
            children,
            is_named: node.is_named(),
            is_missing: node.is_missing(),
        }
    }
}

/// Parse result with AST and metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParseResult {
    pub language: SupportedLanguage,
    pub ast: ASTNode,
    pub parse_time_ms: u64,
    pub node_count: usize,
    pub error_count: usize,
}

impl UniversalTreeSitterParser {
    pub fn parse_with_metadata(&mut self, source: &str, language: SupportedLanguage) -> Result<ParseResult> {
        let start_time = std::time::Instant::now();
        
        let tree = self.parse(source, language)?;
        let root_node = tree.root_node();
        
        let parse_time = start_time.elapsed().as_millis() as u64;
        let ast = ASTNode::from(root_node);
        
        // Count nodes and errors
        let node_count = count_nodes(&ast);
        let error_count = count_error_nodes(&ast);
        
        Ok(ParseResult {
            language,
            ast,
            parse_time_ms: parse_time,
            node_count,
            error_count,
        })
    }
}

fn count_nodes(node: &ASTNode) -> usize {
    1 + node.children.iter().map(count_nodes).sum::<usize>()
}

fn count_error_nodes(node: &ASTNode) -> usize {
    let mut count = if node.node_type == "ERROR" { 1 } else { 0 };
    count += node.children.iter().map(count_error_nodes).sum::<usize>();
    count
}