//! Error types for Smart Package Context backend
//!
//! All operations return `Result<T>` which is `std::result::Result<T, Error>`.

use thiserror::Error;

/// Result type for Smart Package Context operations
pub type Result<T> = std::result::Result<T, Error>;

/// Error type for Smart Package Context backend
#[derive(Error, Debug)]
pub enum Error {
    /// Package not found in any registry
    #[error("Package not found: {0}")]
    PackageNotFound(String),

    /// Invalid ecosystem (npm, cargo, hex, pypi, etc.)
    #[error("Invalid ecosystem: {0}")]
    InvalidEcosystem(String),

    /// File parsing or analysis error
    #[error("File analysis failed: {0}")]
    AnalysisFailed(String),

    /// Embedding generation failed
    #[error("Embedding generation failed: {0}")]
    EmbeddingFailed(String),

    /// Pattern aggregation failed
    #[error("Pattern aggregation failed: {0}")]
    PatternAggregationFailed(String),

    /// Database or storage error
    #[error("Storage error: {0}")]
    StorageError(String),

    /// Timeout during operation
    #[error("Operation timed out: {0}")]
    Timeout(String),

    /// Rate limit exceeded
    #[error("Rate limit exceeded: {0}")]
    RateLimited(String),

    /// Integration error (package_intelligence, patterns, embeddings)
    #[error("Integration error: {0}")]
    IntegrationError(String),

    /// Serialization/deserialization error
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),

    /// Generic internal error
    #[error("Internal error: {0}")]
    Internal(String),
}

impl Error {
    /// Create a new error with a custom message
    pub fn new(msg: impl Into<String>) -> Self {
        Self::Internal(msg.into())
    }

    /// Is this error a "not found" error?
    pub fn is_not_found(&self) -> bool {
        matches!(self, Error::PackageNotFound(_))
    }

    /// Is this error a rate limit error?
    pub fn is_rate_limited(&self) -> bool {
        matches!(self, Error::RateLimited(_))
    }

    /// Is this error a timeout error?
    pub fn is_timeout(&self) -> bool {
        matches!(self, Error::Timeout(_))
    }
}
