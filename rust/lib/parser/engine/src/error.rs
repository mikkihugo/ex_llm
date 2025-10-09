use thiserror::Error;

/// Defines error types used throughout the parser engine.
/// Includes specific categories for parsing, I/O, and internal errors.
///
/// Top-level parser error used across the parser engine components.
#[derive(Debug, Error)]
pub enum ParserError {
    #[error("language not registered: {0}")]
    UnknownLanguage(String),

    #[error("no language capsule matched descriptor {0}")]
    NoMatchingCapsule(String),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("file '{path}' exceeds maximum supported size ({size} bytes > {max} bytes)")]
    FileTooLarge { path: String, size: u64, max: usize },

    #[error("capsule '{language}' failed ({kind:?}): {message}")]
    CapsuleFailure {
        language: String,
        kind: ParserErrorKind,
        message: String,
    },

    #[error("internal error: {0}")]
    Internal(String),
}

/// Specific parsing error categories.
#[derive(Debug, Clone, Copy)]
pub enum ParserErrorKind {
    Unknown,
    Io,
    Parse,
    Unsupported,
    TreeSitter,
    Query,
    InvalidAst,
    Utf8,
    Json,
    TooLarge,
}
