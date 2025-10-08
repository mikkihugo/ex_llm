//! Core traits for language parsers

use crate::{AST, LanguageMetrics, ParseError, Function, Import, Comment};

/// Core trait that all language parsers must implement
pub trait LanguageParser: Send + Sync {
    /// Parse source code into an AST
    fn parse(&self, content: &str) -> Result<AST, ParseError>;
    
    /// Get language-specific metrics from an AST
    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError>;
    
    /// Extract functions from an AST
    fn get_functions(&self, ast: &AST) -> Result<Vec<Function>, ParseError>;
    
    /// Extract imports from an AST
    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError>;
    
    /// Extract comments from an AST
    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError>;
    
    /// Get the language name
    fn get_language(&self) -> &str;
    
    /// Get supported file extensions
    fn get_extensions(&self) -> Vec<&str>;
}

/// Trait for specialized parsers (config files, Docker, etc.)
pub trait SpecializedParser: Send + Sync {
    /// Parse specialized content
    fn parse(&self, content: &str) -> Result<serde_json::Value, ParseError>;
    
    /// Get the parser type
    fn get_type(&self) -> &str;
    
    /// Get supported file extensions
    fn get_extensions(&self) -> Vec<&str>;
}

/// Trait for parser factories
pub trait ParserFactory: Send + Sync {
    /// Create a language parser
    fn create_language_parser(&self, language: &str) -> Result<Box<dyn LanguageParser>, ParseError>;
    
    /// Create a specialized parser
    fn create_specialized_parser(&self, parser_type: &str) -> Result<Box<dyn SpecializedParser>, ParseError>;
    
    /// List available language parsers
    fn list_language_parsers(&self) -> Vec<String>;
    
    /// List available specialized parsers
    fn list_specialized_parsers(&self) -> Vec<String>;
}