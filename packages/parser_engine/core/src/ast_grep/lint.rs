use serde::{Deserialize, Serialize};

use super::pattern::Pattern;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum Severity {
    Error,
    Warning,
    Info,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LintRule {
    pub id: String,
    pub message: String,
    pub pattern: Pattern,
    pub fix: Option<String>,
    pub severity: Severity,
}

impl LintRule {
    pub fn new(id: impl Into<String>, message: impl Into<String>, pattern: Pattern) -> Self {
        Self {
            id: id.into(),
            message: message.into(),
            pattern,
            fix: None,
            severity: Severity::Warning,
        }
    }

    pub fn with_fix(mut self, fix: impl Into<String>) -> Self {
        self.fix = Some(fix.into());
        self
    }

    pub fn with_severity(mut self, severity: Severity) -> Self {
        self.severity = severity;
        self
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LintViolation {
    pub rule_id: String,
    pub message: String,
    pub location: (usize, usize),
    pub text: String,
    pub fix: Option<String>,
    pub severity: Severity,
}
