//! Error types for the parser framework

use thiserror::Error;

/// Parser error types
#[derive(Error, Debug)]
pub enum ParseError {
    #[error("Tree-sitter error: {0}")]
    TreeSitterError(String),

    #[error("Query error: {0}")]
    QueryError(String),

    #[error("Parse error: {0}")]
    ParseError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("UTF-8 error: {0}")]
    Utf8Error(#[from] std::str::Utf8Error),

    #[error("JSON error: {0}")]
    JsonError(#[from] serde_json::Error),

    #[error("Unsupported language: {0}")]
    UnsupportedLanguage(String),

    #[error("Invalid AST structure: {0}")]
    InvalidAstStructure(String),
}