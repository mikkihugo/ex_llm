use ast_grep_core::matcher::PatternError;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AstGrepError {
    #[error("unsupported language: {0}")]
    UnsupportedLanguage(String),

    #[error("pattern `{pattern}` failed to compile: {source}")]
    PatternCompilation {
        pattern: String,
        source: PatternError,
    },

    #[error("constraint on `{variable}` failed to compile: {source}")]
    ConstraintCompilation {
        variable: String,
        source: PatternError,
    },

    #[error("failed to parse {language}: {details}")]
    ParseError { language: String, details: String },

    #[error("input size {size} bytes exceeds configured limit of {max} bytes")]
    FileTooLarge { size: usize, max: usize },

    #[error("unsupported flag: {0}")]
    UnsupportedFlag(String),

    #[error("unable to apply replacement edits: {0}")]
    ReplacementError(String),

    #[error("internal error: {0}")]
    Internal(String),
}

impl From<std::time::SystemTimeError> for AstGrepError {
    fn from(err: std::time::SystemTimeError) -> Self {
        AstGrepError::Internal(err.to_string())
    }
}
