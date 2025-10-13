//! Universal parser error types and handling
//!
//! This module provides standardized error types and recovery patterns
//! used across all language parsers.

use serde::{Deserialize, Serialize};

/// Universal parser error types - now using anyhow for better error context
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PolyglotCodeParserError {
  /// Parse timeout error
  Timeout { duration_ms: u64 },

  /// File too large error
  FileTooLarge { size_bytes: u64, max_size_bytes: u64 },

  /// Unsupported language error
  UnsupportedLanguage { language: String },

  /// Dependency unavailable error
  DependencyUnavailable { dependency: String },

  /// Analysis failed error
  AnalysisFailed { details: String },

  /// Configuration error
  ConfigurationError { message: String },

  /// Memory limit exceeded
  MemoryLimitExceeded { requested_bytes: u64, available_bytes: u64 },

  /// Cache error
  CacheError { message: String },

  /// Tree-sitter parse error
  TreeSitterError { language: String, message: String },

  /// Tokei analysis error
  TokeiError { message: String },

  /// Rust-code-analysis error
  RustCodeAnalysisError { message: String },

  /// IO error wrapper
  IoError { message: String },

  /// Serialization error
  SerializationError { message: String },

  /// Generic error for compatibility
  Generic { message: String },
}

impl PolyglotCodeParserError {
  /// Check if this error is recoverable
  pub fn is_recoverable(&self) -> bool {
    match self {
      // Recoverable errors - can retry or use fallback
      PolyglotCodeParserError::Timeout { .. } => true,
      PolyglotCodeParserError::DependencyUnavailable { .. } => true,
      PolyglotCodeParserError::CacheError { .. } => true,
      PolyglotCodeParserError::TreeSitterError { .. } => true,
      PolyglotCodeParserError::TokeiError { .. } => true,
      PolyglotCodeParserError::RustCodeAnalysisError { .. } => true,
      PolyglotCodeParserError::IoError { .. } => true,

      // Non-recoverable errors - fundamental problems
      PolyglotCodeParserError::FileTooLarge { .. } => false,
      PolyglotCodeParserError::UnsupportedLanguage { .. } => false,
      PolyglotCodeParserError::ConfigurationError { .. } => false,
      PolyglotCodeParserError::MemoryLimitExceeded { .. } => false,
      PolyglotCodeParserError::SerializationError { .. } => false,

      // Analysis failed and generic could be either
      PolyglotCodeParserError::AnalysisFailed { .. } => true,
      PolyglotCodeParserError::Generic { .. } => true,
    }
  }

  /// Get error severity level
  pub fn severity(&self) -> ErrorSeverity {
    match self {
      PolyglotCodeParserError::Timeout { .. } => ErrorSeverity::Warning,
      PolyglotCodeParserError::FileTooLarge { .. } => ErrorSeverity::Error,
      PolyglotCodeParserError::UnsupportedLanguage { .. } => ErrorSeverity::Error,
      PolyglotCodeParserError::DependencyUnavailable { .. } => ErrorSeverity::Warning,
      PolyglotCodeParserError::AnalysisFailed { .. } => ErrorSeverity::Error,
      PolyglotCodeParserError::ConfigurationError { .. } => ErrorSeverity::Error,
      PolyglotCodeParserError::MemoryLimitExceeded { .. } => ErrorSeverity::Error,
      PolyglotCodeParserError::CacheError { .. } => ErrorSeverity::Warning,
      PolyglotCodeParserError::TreeSitterError { .. } => ErrorSeverity::Warning,
      PolyglotCodeParserError::TokeiError { .. } => ErrorSeverity::Warning,
      PolyglotCodeParserError::RustCodeAnalysisError { .. } => ErrorSeverity::Warning,
      PolyglotCodeParserError::IoError { .. } => ErrorSeverity::Error,
      PolyglotCodeParserError::SerializationError { .. } => ErrorSeverity::Error,
      PolyglotCodeParserError::Generic { .. } => ErrorSeverity::Info,
    }
  }

  /// Get error category
  pub fn category(&self) -> ErrorCategory {
    match self {
      PolyglotCodeParserError::Timeout { .. } => ErrorCategory::Performance,
      PolyglotCodeParserError::FileTooLarge { .. } => ErrorCategory::Resource,
      PolyglotCodeParserError::UnsupportedLanguage { .. } => ErrorCategory::Configuration,
      PolyglotCodeParserError::DependencyUnavailable { .. } => ErrorCategory::Dependency,
      PolyglotCodeParserError::AnalysisFailed { .. } => ErrorCategory::Analysis,
      PolyglotCodeParserError::ConfigurationError { .. } => ErrorCategory::Configuration,
      PolyglotCodeParserError::MemoryLimitExceeded { .. } => ErrorCategory::Resource,
      PolyglotCodeParserError::CacheError { .. } => ErrorCategory::Performance,
      PolyglotCodeParserError::TreeSitterError { .. } => ErrorCategory::Dependency,
      PolyglotCodeParserError::TokeiError { .. } => ErrorCategory::Dependency,
      PolyglotCodeParserError::RustCodeAnalysisError { .. } => ErrorCategory::Dependency,
      PolyglotCodeParserError::IoError { .. } => ErrorCategory::System,
      PolyglotCodeParserError::SerializationError { .. } => ErrorCategory::System,
      PolyglotCodeParserError::Generic { .. } => ErrorCategory::Unclassified,
    }
  }

  /// Create timeout error
  pub fn timeout(duration_ms: u64) -> Self {
    Self::Timeout { duration_ms }
  }

  /// Create file too large error
  pub fn file_too_large(size_bytes: u64, max_size_bytes: u64) -> Self {
    Self::FileTooLarge { size_bytes, max_size_bytes }
  }

  /// Create unsupported language error
  pub fn unsupported_language(language: impl Into<String>) -> Self {
    Self::UnsupportedLanguage { language: language.into() }
  }

  /// Create dependency unavailable error
  pub fn dependency_unavailable(dependency: impl Into<String>) -> Self {
    Self::DependencyUnavailable { dependency: dependency.into() }
  }

  /// Create analysis failed error
  pub fn analysis_failed(details: impl Into<String>) -> Self {
    Self::AnalysisFailed { details: details.into() }
  }

  /// Create configuration error
  pub fn configuration_error(message: impl Into<String>) -> Self {
    Self::ConfigurationError { message: message.into() }
  }

  /// Create memory limit exceeded error
  pub fn memory_limit_exceeded(requested_bytes: u64, available_bytes: u64) -> Self {
    Self::MemoryLimitExceeded { requested_bytes, available_bytes }
  }

  /// Create cache error
  pub fn cache_error(message: impl Into<String>) -> Self {
    Self::CacheError { message: message.into() }
  }

  /// Create tree-sitter error
  pub fn tree_sitter_error(language: impl Into<String>, message: impl Into<String>) -> Self {
    Self::TreeSitterError { language: language.into(), message: message.into() }
  }

  /// Create tokei error
  pub fn tokei_error(message: impl Into<String>) -> Self {
    Self::TokeiError { message: message.into() }
  }

  /// Create Mozilla code analysis error
  pub fn rust_code_analysis_error(message: impl Into<String>) -> Self {
    Self::RustCodeAnalysisError { message: message.into() }
  }

  /// Create IO error
  pub fn io_error(message: impl Into<String>) -> Self {
    Self::IoError { message: message.into() }
  }

  /// Create serialization error
  pub fn serialization_error(message: impl Into<String>) -> Self {
    Self::SerializationError { message: message.into() }
  }

  /// Create generic error
  pub fn generic(message: impl Into<String>) -> Self {
    Self::Generic { message: message.into() }
  }
}

/// Error implementation for PolyglotCodeParserError to enable anyhow compatibility
impl std::error::Error for PolyglotCodeParserError {
  fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
    None
  }
}

/// Display implementation for PolyglotCodeParserError to provide detailed error messages
impl std::fmt::Display for PolyglotCodeParserError {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    match self {
      PolyglotCodeParserError::Timeout { duration_ms } => {
        write!(f, "Analysis timeout after {duration_ms}ms - consider increasing timeout or optimizing input")
      }
      PolyglotCodeParserError::FileTooLarge { size_bytes, max_size_bytes } => {
        write!(f, "File too large: {size_bytes} bytes (max: {max_size_bytes} bytes) - consider splitting or excluding large files")
      }
      PolyglotCodeParserError::UnsupportedLanguage { language } => {
        write!(f, "Unsupported language: '{language}' - check available parsers or add custom parser")
      }
      PolyglotCodeParserError::DependencyUnavailable { dependency } => {
        write!(f, "Required dependency '{dependency}' unavailable - ensure dependency is installed and accessible")
      }
      PolyglotCodeParserError::AnalysisFailed { details } => {
        write!(f, "Analysis failed: {details} - check input validity and parser configuration")
      }
      PolyglotCodeParserError::ConfigurationError { message } => {
        write!(f, "Configuration error: {message} - verify parser settings and options")
      }
      PolyglotCodeParserError::MemoryLimitExceeded { requested_bytes, available_bytes } => {
        write!(
          f,
          "Memory limit exceeded: requested {requested_bytes} bytes but only {available_bytes} bytes available - reduce input size or increase memory limit"
        )
      }
      PolyglotCodeParserError::CacheError { message } => {
        write!(f, "Cache error: {message} - cache may be corrupted or inaccessible")
      }
      PolyglotCodeParserError::TreeSitterError { language, message } => {
        write!(f, "Tree-sitter parse failed for {language}: {message} - check syntax or parser compatibility")
      }
      PolyglotCodeParserError::TokeiError { message } => {
        write!(f, "Tokei analysis failed: {message} - check file permissions and accessibility")
      }
      PolyglotCodeParserError::RustCodeAnalysisError { message } => {
        write!(f, "Rust-code-analysis failed: {message} - verify Rust code syntax and dependencies")
      }
      PolyglotCodeParserError::IoError { message } => {
        write!(f, "IO error: {message} - check file permissions, disk space, and accessibility")
      }
      PolyglotCodeParserError::SerializationError { message } => {
        write!(f, "Serialization error: {message} - data format may be corrupted or incompatible")
      }
      PolyglotCodeParserError::Generic { message } => {
        write!(f, "Generic error: {message} - see logs for additional details")
      }
    }
  }
}

/// Error severity levels
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ErrorSeverity {
  /// Informational - no action required
  Info,
  /// Warning - may need attention
  Warning,
  /// Error - requires attention
  Error,
  /// Critical - immediate attention required
  Critical,
}

impl std::fmt::Display for ErrorSeverity {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    match self {
      ErrorSeverity::Info => write!(f, "INFO"),
      ErrorSeverity::Warning => write!(f, "WARN"),
      ErrorSeverity::Error => write!(f, "ERROR"),
      ErrorSeverity::Critical => write!(f, "CRITICAL"),
    }
  }
}

/// Error categories for classification
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ErrorCategory {
  /// System-level errors (IO, etc.)
  System,
  /// Configuration errors
  Configuration,
  /// Resource limitation errors
  Resource,
  /// Performance-related errors
  Performance,
  /// Dependency-related errors
  Dependency,
  /// Analysis-specific errors
  Analysis,
  /// Error category not classified
  Unclassified,
}

impl std::fmt::Display for ErrorCategory {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    match self {
      ErrorCategory::System => write!(f, "SYSTEM"),
      ErrorCategory::Configuration => write!(f, "CONFIG"),
      ErrorCategory::Resource => write!(f, "RESOURCE"),
      ErrorCategory::Performance => write!(f, "PERFORMANCE"),
      ErrorCategory::Dependency => write!(f, "DEPENDENCY"),
      ErrorCategory::Analysis => write!(f, "ANALYSIS"),
      ErrorCategory::Unclassified => write!(f, "UNCLASSIFIED"),
    }
  }
}

/// Error recovery strategy
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RecoveryStrategy {
  /// Retry the operation
  Retry { max_attempts: usize, delay_ms: u64 },
  /// Use fallback implementation
  Fallback,
  /// Skip the operation and continue
  Skip,
  /// Fail fast - don't attempt recovery
  FailFast,
}

/// Error context with additional information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorContext {
  /// The original error
  pub error: PolyglotCodeParserError,
  /// File path being analyzed (if applicable)
  pub file_path: Option<String>,
  /// Language being analyzed (if applicable)
  pub language: Option<String>,
  /// Parser name
  pub parser_name: Option<String>,
  /// Additional context information
  pub context: std::collections::HashMap<String, String>,
  /// Timestamp when error occurred
  pub timestamp: chrono::DateTime<chrono::Utc>,
}

impl ErrorContext {
  /// Create new error context
  pub fn new(error: PolyglotCodeParserError) -> Self {
    Self { error, file_path: None, language: None, parser_name: None, context: std::collections::HashMap::new(), timestamp: chrono::Utc::now() }
  }

  /// Add file path to context
  pub fn with_file_path(mut self, file_path: impl Into<String>) -> Self {
    self.file_path = Some(file_path.into());
    self
  }

  /// Add language to context
  pub fn with_language(mut self, language: impl Into<String>) -> Self {
    self.language = Some(language.into());
    self
  }

  /// Add parser name to context
  pub fn with_parser(mut self, parser_name: impl Into<String>) -> Self {
    self.parser_name = Some(parser_name.into());
    self
  }

  /// Add context information
  pub fn with_context(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
    self.context.insert(key.into(), value.into());
    self
  }

  /// Get recovery strategy for this error
  pub fn recovery_strategy(&self) -> RecoveryStrategy {
    match &self.error {
      PolyglotCodeParserError::Timeout { .. } => RecoveryStrategy::Retry { max_attempts: 2, delay_ms: 1000 },
      PolyglotCodeParserError::DependencyUnavailable { .. } => RecoveryStrategy::Fallback,
      PolyglotCodeParserError::TreeSitterError { .. } => RecoveryStrategy::Fallback,
      PolyglotCodeParserError::TokeiError { .. } => RecoveryStrategy::Fallback,
      PolyglotCodeParserError::RustCodeAnalysisError { .. } => RecoveryStrategy::Fallback,
      PolyglotCodeParserError::CacheError { .. } => RecoveryStrategy::Skip,
      PolyglotCodeParserError::IoError { .. } => RecoveryStrategy::Retry { max_attempts: 3, delay_ms: 500 },
      PolyglotCodeParserError::AnalysisFailed { .. } => RecoveryStrategy::Fallback,
      _ => RecoveryStrategy::FailFast,
    }
  }
}

/// Error reporter for collecting and reporting parser errors
#[derive(Debug)]
pub struct ErrorReporter {
  /// Collected errors
  errors: std::sync::Arc<std::sync::Mutex<Vec<ErrorContext>>>,
  /// Error statistics
  stats: std::sync::Arc<std::sync::Mutex<ErrorStats>>,
}

/// Error statistics
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ErrorStats {
  /// Total error count
  pub total_errors: u64,
  /// Errors by severity
  pub by_severity: std::collections::HashMap<String, u64>,
  /// Errors by category
  pub by_category: std::collections::HashMap<String, u64>,
  /// Errors by parser
  pub by_parser: std::collections::HashMap<String, u64>,
  /// Recoverable vs non-recoverable
  pub recoverable_count: u64,
  pub non_recoverable_count: u64,
}

impl ErrorReporter {
  /// Create new error reporter
  pub fn new() -> Self {
    Self { errors: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())), stats: std::sync::Arc::new(std::sync::Mutex::new(ErrorStats::default())) }
  }

  /// Report an error
  pub fn report(&self, error_context: ErrorContext) {
    let mut errors = self.errors.lock().unwrap();
    let mut stats = self.stats.lock().unwrap();

    // Update statistics
    stats.total_errors += 1;

    let severity_key = error_context.error.severity().to_string();
    *stats.by_severity.entry(severity_key).or_insert(0) += 1;

    let category_key = error_context.error.category().to_string();
    *stats.by_category.entry(category_key).or_insert(0) += 1;

    if let Some(parser_name) = &error_context.parser_name {
      *stats.by_parser.entry(parser_name.clone()).or_insert(0) += 1;
    }

    if error_context.error.is_recoverable() {
      stats.recoverable_count += 1;
    } else {
      stats.non_recoverable_count += 1;
    }

    // Store the error
    errors.push(error_context);
  }

  /// Get error statistics
  pub fn stats(&self) -> ErrorStats {
    self.stats.lock().unwrap().clone()
  }

  /// Get all errors
  pub fn errors(&self) -> Vec<ErrorContext> {
    self.errors.lock().unwrap().clone()
  }

  /// Clear all errors
  pub fn clear(&self) {
    self.errors.lock().unwrap().clear();
    *self.stats.lock().unwrap() = ErrorStats::default();
  }

  /// Get errors by severity
  pub fn errors_by_severity(&self, severity: ErrorSeverity) -> Vec<ErrorContext> {
    self.errors().into_iter().filter(|ctx| ctx.error.severity() == severity).collect()
  }

  /// Get errors by category
  pub fn errors_by_category(&self, category: ErrorCategory) -> Vec<ErrorContext> {
    self.errors().into_iter().filter(|ctx| ctx.error.category() == category).collect()
  }
}

impl Default for ErrorReporter {
  fn default() -> Self {
    Self::new()
  }
}

// Conversion implementations for common error types
impl From<std::io::Error> for PolyglotCodeParserError {
  fn from(err: std::io::Error) -> Self {
    PolyglotCodeParserError::IoError { message: err.to_string() }
  }
}

impl From<serde_json::Error> for PolyglotCodeParserError {
  fn from(err: serde_json::Error) -> Self {
    PolyglotCodeParserError::SerializationError { message: err.to_string() }
  }
}

impl From<tree_sitter::LanguageError> for PolyglotCodeParserError {
  fn from(err: tree_sitter::LanguageError) -> Self {
    PolyglotCodeParserError::TreeSitterError { language: "language not specified".to_string(), message: err.to_string() }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_error_classification() {
    let timeout_error = PolyglotCodeParserError::timeout(5000);
    assert!(timeout_error.is_recoverable());
    assert_eq!(timeout_error.severity(), ErrorSeverity::Warning);
    assert_eq!(timeout_error.category(), ErrorCategory::Performance);

    let unsupported_error = PolyglotCodeParserError::unsupported_language("unsupported language");
    assert!(!unsupported_error.is_recoverable());
    assert_eq!(unsupported_error.severity(), ErrorSeverity::Error);
    assert_eq!(unsupported_error.category(), ErrorCategory::Configuration);
  }

  #[test]
  fn test_error_context() {
    let error = PolyglotCodeParserError::analysis_failed("test failure");
    let context = ErrorContext::new(error).with_file_path("test.rs").with_language("rust").with_parser("rust-parser").with_context("line", "42");

    assert_eq!(context.file_path, Some("test.rs".to_string()));
    assert_eq!(context.language, Some("rust".to_string()));
    assert_eq!(context.parser_name, Some("rust-parser".to_string()));
    assert_eq!(context.context.get("line"), Some(&"42".to_string()));

    let strategy = context.recovery_strategy();
    assert_eq!(strategy, RecoveryStrategy::Fallback);
  }

  #[test]
  fn test_error_reporter() {
    let reporter = ErrorReporter::new();

    let error1 = ErrorContext::new(PolyglotCodeParserError::timeout(1000)).with_parser("test-parser");
    let error2 = ErrorContext::new(PolyglotCodeParserError::unsupported_language("test")).with_parser("test-parser");

    reporter.report(error1);
    reporter.report(error2);

    let stats = reporter.stats();
    assert_eq!(stats.total_errors, 2);
    assert_eq!(stats.recoverable_count, 1);
    assert_eq!(stats.non_recoverable_count, 1);
    assert_eq!(stats.by_parser.get("test-parser"), Some(&2));

    let warning_errors = reporter.errors_by_severity(ErrorSeverity::Warning);
    assert_eq!(warning_errors.len(), 1);

    let performance_errors = reporter.errors_by_category(ErrorCategory::Performance);
    assert_eq!(performance_errors.len(), 1);
  }

  #[test]
  fn test_error_conversions() {
    let io_error = std::io::Error::new(std::io::ErrorKind::NotFound, "File not found");
    let universal_error: PolyglotCodeParserError = io_error.into();
    assert!(matches!(universal_error, PolyglotCodeParserError::IoError { .. }));

    let json_error = serde_json::from_str::<serde_json::Value>("{").unwrap_err();
    let universal_error: PolyglotCodeParserError = json_error.into();
    assert!(matches!(universal_error, PolyglotCodeParserError::SerializationError { .. }));
  }
}
