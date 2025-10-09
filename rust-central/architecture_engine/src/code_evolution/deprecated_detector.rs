//! Deprecated Code Detection
//!
//! This module provides deprecated code detection and analysis.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

/// Deprecated code entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeprecatedCode {
    /// Deprecated element name
    pub name: String,
    /// Deprecation reason
    pub reason: String,
    /// Alternative suggestion
    pub alternative: Option<String>,
    /// Severity
    pub severity: DeprecationSeverity,
    /// File path
    pub file_path: String,
    /// Line number
    pub line_number: Option<usize>,
}

/// Deprecation severity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeprecationSeverity {
    /// Warning - still works but not recommended
    Warning,
    /// Deprecated - will be removed in future
    Deprecated,
    /// Obsolete - should not be used
    Obsolete,
}

/// Deprecated code detector
#[derive(Debug, Clone, Default)]
pub struct DeprecatedDetector {
    /// Deprecated code by file
    pub deprecated: HashMap<String, Vec<DeprecatedCode>>,
}

impl DeprecatedDetector {
    /// Create a new deprecated detector
    pub fn new() -> Self {
        Self::default()
    }

    /// Detect deprecated code
    pub fn detect_deprecated(&self, _code: &str, _file_path: &str) -> Vec<DeprecatedCode> {
        // TODO: Implement deprecated code detection
        vec![]
    }

    /// Add deprecated code entry
    pub fn add_deprecated(&mut self, file_path: String, deprecated: DeprecatedCode) {
        self.deprecated
            .entry(file_path)
            .or_insert_with(Vec::new)
            .push(deprecated);
    }

    /// Get deprecated code for a file
    pub fn get_deprecated(&self, file_path: &str) -> Option<&Vec<DeprecatedCode>> {
        self.deprecated.get(file_path)
    }
}
