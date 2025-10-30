//! Pattern Detection Integration with Elixir PatternRegistry
//!
//! Provides high-level API for querying code quality patterns from Elixir PatternRegistry
//! and matching them against code. This bridges Rust analysis engines with centralized pattern management.
//!
//! # Architecture
//!
//! ```text
//! Rust Code Analysis (code_quality_engine)
//!     ↓
//! pattern_detection module (this file)
//!     ↓ [Query patterns via NIF]
//! PatternRegistry (Elixir)
//!     ↓ [Database query]
//! PostgreSQL knowledge_artifacts (55 patterns)
//! ```
//!
//! # Usage
//!
//! ```rust,ignore
//! let patterns = query_patterns_for_language(&content, "python")?;
//! for pattern in patterns {
//!     if matches_pattern_in_ast(&ast, &pattern) {
//!         record_pattern_match(&pattern.id, metadata)?;
//!     }
//! }
//! ```

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Pattern returned from PatternRegistry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistryPattern {
    /// Unique pattern identifier (e.g., "owasp_sql_injection")
    pub pattern_id: String,
    /// Human-readable pattern name
    pub name: String,
    /// Detailed description
    pub description: String,
    /// Pattern category (security, compliance, language, package, architecture, framework)
    pub category: String,
    /// Severity level (critical, high, medium, low)
    pub severity: String,
    /// Languages this pattern applies to
    pub applicable_languages: Vec<String>,
    /// Frameworks this pattern applies to
    pub applicable_frameworks: Vec<String>,
    /// Raw pattern (AST, regex, or heuristic depending on type)
    pub pattern_rule: Option<String>,
    /// Additional metadata
    #[serde(flatten)]
    pub extra: serde_json::Map<String, Value>,
}

/// Result of pattern matching
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternMatch {
    /// Pattern that matched
    pub pattern: RegistryPattern,
    /// Whether pattern matched
    pub matched: bool,
    /// Location in code (file path)
    pub file: Option<String>,
    /// Line number where match occurred
    pub line: Option<u32>,
    /// Column where match occurred
    pub column: Option<u32>,
    /// Matched text
    pub matched_text: Option<String>,
    /// Is this a false positive?
    pub false_positive: bool,
}

/// Phase 2b: Stub - Will be implemented to call Elixir PatternRegistry via NIF
///
/// This function will:
/// 1. Call Elixir's PatternRegistry.find_by_language(language) via NIF
/// 2. Deserialize returned JSON patterns
/// 3. Return list of patterns for the language
pub fn query_patterns_for_language(
    _language: &str,
) -> Result<Vec<RegistryPattern>, Box<dyn std::error::Error>> {
    // Phase 2b implementation will call Elixir here
    // For now, return empty list (stub)
    Ok(vec![])
}

/// Phase 2b: Stub - Will be implemented to call Elixir PatternRegistry via NIF
pub fn query_patterns_for_category(
    _category: &str,
) -> Result<Vec<RegistryPattern>, Box<dyn std::error::Error>> {
    // Phase 2b implementation will call Elixir here
    // For now, return empty list (stub)
    Ok(vec![])
}

/// Check if code matches a specific pattern (placeholder)
///
/// Phase 2b will implement actual matching logic:
/// - AST-based matching for structural patterns
/// - Regex matching for simple rules
/// - Semantic matching for vulnerability patterns
pub fn matches_pattern(
    _content: &str,
    _pattern: &RegistryPattern,
) -> Result<PatternMatch, Box<dyn std::error::Error>> {
    // Phase 2b implementation will do actual matching
    Ok(PatternMatch {
        pattern: _pattern.clone(),
        matched: false,
        file: None,
        line: None,
        column: None,
        matched_text: None,
        false_positive: false,
    })
}

/// Phase 2b: Stub - Will record pattern match with Elixir for Genesis feedback loop
pub fn record_pattern_match(
    _pattern_id: &str,
    _matched: bool,
    _severity: &str,
    _file: Option<&str>,
    _line: Option<u32>,
) -> Result<(), Box<dyn std::error::Error>> {
    // Phase 2b will call PatternRegistry.record_match via NIF
    Ok(())
}

/// Enhanced vulnerability detection using PatternRegistry patterns
///
/// Replaces hardcoded vulnerability detection with comprehensive pattern matching.
/// Uses query_patterns_for_category("security") to get all security patterns,
/// then applies them to the code to detect vulnerabilities.
pub fn detect_vulnerabilities_from_patterns(
    content: &str,
) -> Result<Vec<PatternMatch>, Box<dyn std::error::Error>> {
    let patterns = query_patterns_for_category("security")?;
    let mut matches = Vec::new();

    for pattern in patterns {
        match matches_pattern(content, &pattern) {
            Ok(pattern_match) => {
                if pattern_match.matched {
                    matches.push(pattern_match);
                }
            }
            Err(e) => {
                // Log error but continue checking other patterns
                eprintln!("Error matching pattern {}: {}", pattern.pattern_id, e);
            }
        }
    }

    Ok(matches)
}

/// Enhanced security pattern detection using PatternRegistry
///
/// Replaces hardcoded security pattern detection with comprehensive pattern matching.
/// Uses query_patterns_for_language(language) to get language-specific patterns,
/// filters for security category, and applies them.
pub fn detect_security_patterns_from_registry(
    content: &str,
    language: &str,
) -> Result<Vec<PatternMatch>, Box<dyn std::error::Error>> {
    let patterns = query_patterns_for_language(language)?;

    let mut matches = Vec::new();
    for pattern in patterns {
        // Filter for security category patterns
        if pattern.category != "security" {
            continue;
        }

        match matches_pattern(content, &pattern) {
            Ok(pattern_match) => {
                if pattern_match.matched {
                    matches.push(pattern_match);
                }
            }
            Err(e) => {
                eprintln!("Error matching pattern {}: {}", pattern.pattern_id, e);
            }
        }
    }

    Ok(matches)
}

/// Fallback: Original hardcoded vulnerability detection (for Phase 1 compatibility)
///
/// This is the original implementation. Phase 2b will deprecate this
/// in favor of pattern-based detection via PatternRegistry.
pub fn detect_vulnerabilities_hardcoded(content: &str) -> Vec<String> {
    let mut vulns = Vec::new();

    if content.contains("unsafe") {
        vulns.push("Unsafe Code".to_string());
    }
    if content.contains("eval") {
        vulns.push("Code Evaluation".to_string());
    }
    if content.contains("sql") && content.contains("\"") {
        vulns.push("Potential SQL Injection".to_string());
    }

    vulns
}

/// Fallback: Original hardcoded security pattern detection
///
/// This is the original implementation. Phase 2b will deprecate this
/// in favor of pattern-based detection via PatternRegistry.
pub fn detect_security_patterns_hardcoded(content: &str) -> Vec<String> {
    let mut patterns = Vec::new();

    if content.contains("encrypt") || content.contains("decrypt") {
        patterns.push("Encryption/Decryption".to_string());
    }
    if content.contains("hash") || content.contains("sha") {
        patterns.push("Hashing".to_string());
    }

    patterns
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_query_patterns_returns_empty_stub() {
        let result = query_patterns_for_language("python");
        assert!(result.is_ok());
        assert_eq!(result.unwrap().len(), 0);
    }

    #[test]
    fn test_hardcoded_detection_still_works() {
        let code = "password = hash(secret)";
        let patterns = detect_security_patterns_hardcoded(code);
        assert!(patterns.contains(&"Hashing".to_string()));
    }
}
