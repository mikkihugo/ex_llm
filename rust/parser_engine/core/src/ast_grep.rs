//! AST-Grep Integration - Structural Search, Linting, and Code Transformation
//!
//! This module provides integration with ast-grep for:
//! - Structural code search using AST patterns
//! - AST-based linting rules
//! - Code transformation and refactoring
//!
//! ## Features
//!
//! - **Structural Search**: Find code patterns based on AST structure, not text
//! - **Multi-Language**: Supports all tree-sitter languages
//! - **Linting**: Define custom lint rules using AST patterns
//! - **Transformation**: Rewrite code based on AST patterns
//!
//! ## Example
//!
//! ```rust,no_run
//! use parser_core::ast_grep::{AstGrep, Pattern, SearchResult};
//!
//! // Search for all function calls with specific pattern
//! let grep = AstGrep::new("javascript");
//! let pattern = Pattern::new("console.log($$$ARGS)");
//! let results = grep.search(source_code, pattern)?;
//!
//! // Apply transformation
//! let replace_pattern = Pattern::new("logger.debug($$$ARGS)");
//! let transformed = grep.replace(source_code, pattern, replace_pattern)?;
//! ```

use std::collections::HashMap;

/// AST-Grep instance for a specific language
pub struct AstGrep {
    language: String,
}

impl AstGrep {
    /// Create a new AST-Grep instance for a language
    ///
    /// # Arguments
    ///
    /// * `language` - Language name (e.g., "javascript", "rust", "elixir")
    pub fn new(language: impl Into<String>) -> Self {
        Self {
            language: language.into(),
        }
    }

    /// Search for patterns in source code
    ///
    /// # Arguments
    ///
    /// * `source` - Source code to search
    /// * `pattern` - AST pattern to match
    ///
    /// # Returns
    ///
    /// Vector of search results with match locations and captured variables
    ///
    /// # Implementation Note
    ///
    /// Currently uses simple string matching as a working proof-of-concept.
    /// Full AST-based matching with ast-grep-core is complex and requires
    /// implementing the SupportLang trait for each language.
    ///
    /// This simple version allows testing the full Elixir → Rust → NIF pipeline
    /// while the proper ast-grep-core integration is completed.
    pub fn search(&self, source: &str, pattern: &Pattern) -> Result<Vec<SearchResult>, AstGrepError> {
        // Simple string-based matching (proof of concept)
        // TODO: Replace with ast-grep-core once Language trait is implemented

        let pattern_str = pattern.as_str();
        let mut results = Vec::new();

        // Simple line-by-line search
        for (line_num, line) in source.lines().enumerate() {
            if let Some(col) = line.find(pattern_str) {
                results.push(SearchResult {
                    text: line.trim().to_string(),
                    start: (line_num + 1, col),
                    end: (line_num + 1, col + pattern_str.len()),
                    captures: HashMap::new(),
                });
            }
        }

        Ok(results)
    }

    /// Replace patterns in source code
    ///
    /// # Arguments
    ///
    /// * `source` - Source code to transform
    /// * `pattern` - AST pattern to match
    /// * `replacement` - Replacement pattern
    ///
    /// # Returns
    ///
    /// Transformed source code
    ///
    /// # Implementation Note
    ///
    /// Currently uses simple string replacement as proof-of-concept.
    /// Full AST-based replacement with metavariable substitution pending.
    pub fn replace(
        &self,
        source: &str,
        pattern: &Pattern,
        replacement: &Pattern,
    ) -> Result<String, AstGrepError> {
        // Simple string replacement (proof of concept)
        // TODO: Replace with ast-grep-core for proper AST-based replacement

        let pattern_str = pattern.as_str();
        let replacement_str = replacement.as_str();

        Ok(source.replace(pattern_str, replacement_str))
    }

    /// Lint source code using custom rules
    ///
    /// # Arguments
    ///
    /// * `source` - Source code to lint
    /// * `rules` - Linting rules to apply
    ///
    /// # Returns
    ///
    /// Vector of lint violations found
    pub fn lint(&self, source: &str, rules: &[LintRule]) -> Result<Vec<LintViolation>, AstGrepError> {
        let mut violations = Vec::new();

        for rule in rules {
            let matches = self.search(source, &rule.pattern)?;

            for m in matches {
                let fix = if let Some(ref fix_pattern) = rule.fix {
                    Some(fix_pattern.as_str().to_string())
                } else {
                    None
                };

                violations.push(LintViolation {
                    rule_id: rule.id.clone(),
                    message: rule.message.clone(),
                    location: m.start,
                    text: m.text,
                    fix,
                    severity: rule.severity,
                });
            }
        }

        Ok(violations)
    }
}

/// AST pattern for matching code structures
#[derive(Debug, Clone)]
pub struct Pattern {
    pattern: String,
}

impl Pattern {
    /// Create a new pattern
    ///
    /// Patterns use tree-sitter syntax with metavariables:
    /// - `$VAR` - Single node metavariable
    /// - `$$$ARGS` - Multiple nodes metavariable
    ///
    /// # Example
    ///
    /// ```
    /// use parser_core::ast_grep::Pattern;
    ///
    /// // Match any function call to 'foo'
    /// let pattern = Pattern::new("foo($$$ARGS)");
    ///
    /// // Match specific patterns
    /// let pattern = Pattern::new("if ($COND) { $$$BODY }");
    /// ```
    pub fn new(pattern: impl Into<String>) -> Self {
        Self {
            pattern: pattern.into(),
        }
    }

    /// Get the raw pattern string
    pub fn as_str(&self) -> &str {
        &self.pattern
    }
}

/// Search result from pattern matching
#[derive(Debug, Clone)]
pub struct SearchResult {
    /// Matched text
    pub text: String,
    /// Start position (line, column)
    pub start: (usize, usize),
    /// End position (line, column)
    pub end: (usize, usize),
    /// Captured metavariables
    pub captures: HashMap<String, String>,
}

/// Lint rule for AST-based linting
#[derive(Debug, Clone)]
pub struct LintRule {
    /// Rule ID
    pub id: String,
    /// Rule description
    pub message: String,
    /// Pattern to match (violations)
    pub pattern: Pattern,
    /// Optional fix pattern
    pub fix: Option<Pattern>,
    /// Severity level
    pub severity: Severity,
}

impl LintRule {
    /// Create a new lint rule
    pub fn new(
        id: impl Into<String>,
        message: impl Into<String>,
        pattern: Pattern,
    ) -> Self {
        Self {
            id: id.into(),
            message: message.into(),
            pattern,
            fix: None,
            severity: Severity::Warning,
        }
    }

    /// Set fix pattern
    pub fn with_fix(mut self, fix: Pattern) -> Self {
        self.fix = Some(fix);
        self
    }

    /// Set severity
    pub fn with_severity(mut self, severity: Severity) -> Self {
        self.severity = severity;
        self
    }
}

/// Lint violation found by AST-based linting
#[derive(Debug, Clone)]
pub struct LintViolation {
    /// Rule that was violated
    pub rule_id: String,
    /// Violation message
    pub message: String,
    /// Location of violation
    pub location: (usize, usize),
    /// Matched text
    pub text: String,
    /// Suggested fix (if available)
    pub fix: Option<String>,
    /// Severity
    pub severity: Severity,
}

/// Severity level for lint rules
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Severity {
    Error,
    Warning,
    Info,
}

/// AST-Grep error types
#[derive(Debug, thiserror::Error)]
pub enum AstGrepError {
    #[error("Pattern parse error: {0}")]
    PatternError(String),

    #[error("Language not supported: {0}")]
    UnsupportedLanguage(String),

    #[error("Parse error: {0}")]
    ParseError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Other error: {0}")]
    Other(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pattern_creation() {
        let pattern = Pattern::new("console.log($$$ARGS)");
        assert_eq!(pattern.as_str(), "console.log($$$ARGS)");
    }

    #[test]
    fn test_lint_rule_creation() {
        let pattern = Pattern::new("console.log($$$)");
        let rule = LintRule::new(
            "no-console",
            "Avoid using console.log in production",
            pattern,
        )
        .with_severity(Severity::Warning);

        assert_eq!(rule.id, "no-console");
        assert_eq!(rule.severity, Severity::Warning);
    }

    #[test]
    fn test_ast_grep_creation() {
        let grep = AstGrep::new("javascript");
        assert_eq!(grep.language, "javascript");
    }
}
