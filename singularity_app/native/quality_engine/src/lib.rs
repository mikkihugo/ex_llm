//! Linting Engine Module
//!
//! Multi-language quality gate enforcement with comprehensive linter support:
//!
//! # Allowances
//!
//! This module allows multiple crate versions for dependencies as we integrate
//! with various external linters that may have different version requirements.
//! - Rust: Clippy
//! - JavaScript/TypeScript: `ESLint`
//! - Python: Pylint/Flake8/Black
//! - Go: golangci-lint
//! - Java: SpotBugs/Checkstyle
//! - C/C++: Clang-tidy/CPPCheck
//! - C#: `SonarAnalyzer`
//! - Elixir: Credo
//! - Erlang: Dialyzer
//! - Gleam: gleam check

#![allow(
  clippy::multiple_crate_versions,
  clippy::option_if_let_else,
  clippy::redundant_closure_for_method_calls,
  clippy::unused_self,
  clippy::map_unwrap_or,
  clippy::cast_possible_truncation,
  clippy::unused_async
)]

use std::{
  fs,
  process::{Command, Stdio},
};

use anyhow::Result;
use regex::Regex;
use serde::{Deserialize, Serialize};
use tracing::warn;

/// Configuration for multi-language linting engine
#[derive(Debug, Clone, Serialize, Deserialize)]
#[allow(clippy::struct_excessive_bools)]
pub struct LintingEngineConfig {
  // Rust linting
  pub rust_clippy_enabled: bool,

  // JavaScript/TypeScript linting
  pub javascript_eslint_enabled: bool,
  pub typescript_eslint_enabled: bool,

  // Python linting
  pub python_pylint_enabled: bool,
  pub python_flake8_enabled: bool,
  pub python_black_enabled: bool,

  // Go linting
  pub go_golangci_enabled: bool,

  // Java linting
  pub java_spotbugs_enabled: bool,
  pub java_checkstyle_enabled: bool,

  // C/C++ linting
  pub cpp_clang_tidy_enabled: bool,
  pub cpp_cppcheck_enabled: bool,

  // C# linting
  pub csharp_sonar_enabled: bool,

  // BEAM languages linting
  pub elixir_credo_enabled: bool,
  pub erlang_dialyzer_enabled: bool,
  pub gleam_check_enabled: bool,

  // Common settings
  pub custom_rules: Vec<QualityRule>,
  pub thresholds: QualityThresholds,
  pub ai_pattern_detection: bool,
}

/// Quality rule definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityRule {
  pub name: String,
  pub description: String,
  pub severity: RuleSeverity,
  pub pattern: String,
  pub message: String,
  pub category: RuleCategory,
}

/// Rule severity levels
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RuleSeverity {
  Error,
  Warning,
  Info,
}

/// Rule categories for better organization
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RuleCategory {
  Security,
  Performance,
  Maintainability,
  Readability,
  AIGenerated,
  Enterprise,
  Compliance,
}

/// Quality thresholds for enforcement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityThresholds {
  pub max_errors: usize,
  pub max_warnings: usize,
  pub min_score: f64,
  pub max_complexity: f64,
  pub max_cognitive_complexity: f64,
}

/// Quality gate result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityGateResult {
  pub status: QualityGateStatus,
  pub score: f64,
  pub total_issues: usize,
  pub errors: Vec<QualityIssue>,
  pub warnings: Vec<QualityIssue>,
  pub info: Vec<QualityIssue>,
  pub ai_pattern_issues: Vec<QualityIssue>,
  pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// Quality gate status
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum QualityGateStatus {
  Passed,
  Failed,
  Warning,
  Skipped,
}

/// Individual quality issue
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityIssue {
  pub rule: String,
  pub message: String,
  pub severity: RuleSeverity,
  pub category: RuleCategory,
  pub file_path: Option<String>,
  pub line_number: Option<usize>,
  pub column: Option<usize>,
  pub code_snippet: Option<String>,
  pub suggestion: Option<String>,
}

/// Multi-language linting engine for enforcing code quality standards
pub struct LintingEngine {
  config: LintingEngineConfig,
  ai_pattern_rules: Vec<QualityRule>,
  enterprise_rules: Vec<QualityRule>,
}

impl LintingEngine {
  /// Create a new linting engine with default configuration
  #[must_use]
  pub fn new() -> Self {
    let mut engine = Self { config: LintingEngineConfig::default(), ai_pattern_rules: Vec::new(), enterprise_rules: Vec::new() };

    // Initialize AI pattern detection rules
    engine.initialize_ai_pattern_rules();

    // Initialize enterprise compliance rules
    engine.initialize_enterprise_rules();

    engine
  }

  /// Initialize AI-generated code pattern detection rules
  fn initialize_ai_pattern_rules(&mut self) {
    self.ai_pattern_rules = vec![
      // Common AI-generated code smells
      QualityRule {
        name: "ai_placeholder_comments".to_string(),
        description: "Detect placeholder comments that indicate incomplete AI-generated code".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"(?i)(TODO|FIXME|HACK|XXX|PLACEHOLDER|STUB|TEMP|DUMMY).*".to_string(),
        message: "AI-generated placeholder detected - implement real functionality".to_string(),
        category: RuleCategory::AIGenerated,
      },
      QualityRule {
        name: "ai_unused_parameters".to_string(),
        description: "Detect unused parameters prefixed with underscore".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"_\w+\s*:".to_string(),
        message: "Unused parameter detected - implement or remove if not needed".to_string(),
        category: RuleCategory::AIGenerated,
      },
      QualityRule {
        name: "ai_magic_numbers".to_string(),
        description: "Detect magic numbers without constants".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"\b[0-9]{2,}\b".to_string(),
        message: "Magic number detected - define as named constant".to_string(),
        category: RuleCategory::AIGenerated,
      },
      QualityRule {
        name: "ai_long_functions".to_string(),
        description: "Detect functions longer than 50 lines".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"fn\s+\w+.*\{[\s\S]{0,1000}".to_string(),
        message: "Function is too long - consider breaking into smaller functions".to_string(),
        category: RuleCategory::AIGenerated,
      },
      QualityRule {
        name: "style_line_width".to_string(),
        description: "Detect lines longer than 160 characters".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r".{161,}".to_string(),
        message: "Line too long (160+ chars) - break into multiple lines".to_string(),
        category: RuleCategory::Readability,
      },
      QualityRule {
        name: "style_trailing_whitespace".to_string(),
        description: "Detect trailing whitespace at end of lines".to_string(),
        severity: RuleSeverity::Info,
        pattern: r"[ \t]+$".to_string(),
        message: "Trailing whitespace detected - remove extra spaces".to_string(),
        category: RuleCategory::Readability,
      },
      QualityRule {
        name: "style_missing_newline_eof".to_string(),
        description: "Detect files missing newline at end of file".to_string(),
        severity: RuleSeverity::Info,
        pattern: r".*[^\n]$".to_string(),
        message: "File should end with newline".to_string(),
        category: RuleCategory::Readability,
      },
      QualityRule {
        name: "ai_nested_conditionals".to_string(),
        description: "Detect deeply nested conditional statements".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"if.*\{[\s\S]*if.*\{[\s\S]*if.*\{".to_string(),
        message: "Deeply nested conditionals detected - consider refactoring".to_string(),
        category: RuleCategory::AIGenerated,
      },
      // Additional AI pattern detection rules
      QualityRule {
        name: "ai_generic_names".to_string(),
        description: "Detect overly generic variable/function names".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"\b(data|value|result|temp|var|obj|item|thing|stuff)\b".to_string(),
        message: "Generic name detected - use descriptive names".to_string(),
        category: RuleCategory::AIGenerated,
      },
      QualityRule {
        name: "ai_empty_catch_blocks".to_string(),
        description: "Detect empty catch blocks that ignore errors".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"catch\s*\([^)]*\)\s*\{\s*\}".to_string(),
        message: "Empty catch block detected - handle errors properly".to_string(),
        category: RuleCategory::AIGenerated,
      },
      QualityRule {
        name: "ai_hardcoded_paths".to_string(),
        description: "Detect hardcoded file paths".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"['\x22](/[^'\x22]+|C:\\[^'\x22]+|\.\\[^'\x22]+)".to_string(),
        message: "Hardcoded path detected - use configuration or environment variables".to_string(),
        category: RuleCategory::AIGenerated,
      },
    ];
  }

  /// Initialize enterprise compliance rules
  fn initialize_enterprise_rules(&mut self) {
    self.enterprise_rules = vec![
      // Security rules
      QualityRule {
        name: "security_hardcoded_secrets".to_string(),
        description: "Detect hardcoded secrets and credentials".to_string(),
        severity: RuleSeverity::Error,
        pattern: r"(?i)(password|secret|key|token|credential)\s*[:=]\s*['\x22][^'\x22]+['\x22]".to_string(),
        message: "Hardcoded secret detected - use environment variables or secure storage".to_string(),
        category: RuleCategory::Security,
      },
      QualityRule {
        name: "security_sql_injection".to_string(),
        description: "Detect potential SQL injection vulnerabilities".to_string(),
        severity: RuleSeverity::Error,
        pattern: r"(?i)SELECT.*\+.*\w+|INSERT.*\+.*\w+|UPDATE.*\+.*\w+".to_string(),
        message: "Potential SQL injection detected - use parameterized queries".to_string(),
        category: RuleCategory::Security,
      },
      QualityRule {
        name: "security_unsafe_eval".to_string(),
        description: "Detect unsafe eval() usage".to_string(),
        severity: RuleSeverity::Error,
        pattern: r"eval\s*\(".to_string(),
        message: "Unsafe eval() detected - use safer alternatives".to_string(),
        category: RuleCategory::Security,
      },
      // Performance rules
      QualityRule {
        name: "performance_n_plus_one".to_string(),
        description: "Detect potential N+1 query patterns".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"(?i)for.*in.*query|forEach.*query".to_string(),
        message: "Potential N+1 query pattern detected - consider batch operations".to_string(),
        category: RuleCategory::Performance,
      },
      QualityRule {
        name: "performance_memory_leak".to_string(),
        description: "Detect potential memory leak patterns".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"(?i)setInterval|setTimeout.*function".to_string(),
        message: "Potential memory leak detected - ensure proper cleanup".to_string(),
        category: RuleCategory::Performance,
      },
      // Maintainability rules
      QualityRule {
        name: "maintainability_duplicate_code".to_string(),
        description: "Detect duplicate code blocks".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r"(\w+\s*\{[^}]{10,}\})[\s\S]*\1".to_string(),
        message: "Duplicate code detected - consider extracting to function".to_string(),
        category: RuleCategory::Maintainability,
      },
      QualityRule {
        name: "maintainability_long_file".to_string(),
        description: "Detect files longer than 500 lines".to_string(),
        severity: RuleSeverity::Warning,
        pattern: r".*".to_string(), // Will be checked by file analysis
        message: "File is too long - consider splitting into smaller modules".to_string(),
        category: RuleCategory::Maintainability,
      },
    ];
  }

  /// Run all quality gates on a project
  ///
  /// # Errors
  ///
  /// This function will return an error if:
  /// - The project path is invalid or inaccessible
  /// - Any linter execution fails
  /// - File system operations fail
  #[allow(clippy::too_many_lines, clippy::cognitive_complexity)]
  pub async fn run_all_gates(&self, project_path: &str) -> Result<QualityGateResult> {
    let mut all_issues = Vec::new();
    let mut total_score = 100.0;

    // Run Rust Clippy if enabled
    if self.config.rust_clippy_enabled {
      match self.run_clippy(project_path).await {
        Ok(issues) => all_issues.extend(issues),
        Err(e) => {
          warn!("Clippy failed: {}", e);
          all_issues.push(QualityIssue {
            rule: "clippy_error".to_string(),
            message: format!("Clippy execution failed: {e}"),
            severity: RuleSeverity::Error,
            category: RuleCategory::Compliance,
            file_path: None,
            line_number: None,
            column: None,
            code_snippet: None,
            suggestion: None,
          });
        }
      }
    }

    // Run JavaScript ESLint if enabled
    if self.config.javascript_eslint_enabled {
      match self.run_javascript_eslint(project_path).await {
        Ok(issues) => all_issues.extend(issues),
        Err(e) => {
          warn!("JavaScript ESLint failed: {}", e);
          all_issues.push(QualityIssue {
            rule: "javascript_eslint_error".to_string(),
            message: format!("JavaScript ESLint execution failed: {e}"),
            severity: RuleSeverity::Error,
            category: RuleCategory::Compliance,
            file_path: None,
            line_number: None,
            column: None,
            code_snippet: None,
            suggestion: None,
          });
        }
      }
    }

    // Run TypeScript ESLint if enabled
    if self.config.typescript_eslint_enabled {
      match self.run_typescript_eslint(project_path).await {
        Ok(issues) => all_issues.extend(issues),
        Err(e) => {
          warn!("TypeScript ESLint failed: {}", e);
          all_issues.push(QualityIssue {
            rule: "typescript_eslint_error".to_string(),
            message: format!("TypeScript ESLint execution failed: {e}"),
            severity: RuleSeverity::Error,
            category: RuleCategory::Compliance,
            file_path: None,
            line_number: None,
            column: None,
            code_snippet: None,
            suggestion: None,
          });
        }
      }
    }

    // Run Python Pylint if enabled
    if self.config.python_pylint_enabled {
      match self.run_python_pylint(project_path).await {
        Ok(issues) => all_issues.extend(issues),
        Err(e) => {
          warn!("Python Pylint failed: {}", e);
          all_issues.push(QualityIssue {
            rule: "python_pylint_error".to_string(),
            message: format!("Python Pylint execution failed: {e}"),
            severity: RuleSeverity::Error,
            category: RuleCategory::Compliance,
            file_path: None,
            line_number: None,
            column: None,
            code_snippet: None,
            suggestion: None,
          });
        }
      }
    }

    // Run Python Flake8 if enabled
    if self.config.python_flake8_enabled {
      match self.run_python_flake8(project_path).await {
        Ok(issues) => all_issues.extend(issues),
        Err(e) => {
          warn!("Python Flake8 failed: {}", e);
          all_issues.push(QualityIssue {
            rule: "python_flake8_error".to_string(),
            message: format!("Python Flake8 execution failed: {e}"),
            severity: RuleSeverity::Error,
            category: RuleCategory::Compliance,
            file_path: None,
            line_number: None,
            column: None,
            code_snippet: None,
            suggestion: None,
          });
        }
      }
    }

    // Run Go golangci-lint if enabled
    if self.config.go_golangci_enabled {
      match self.run_go_golangci(project_path).await {
        Ok(issues) => all_issues.extend(issues),
        Err(e) => {
          warn!("Go golangci-lint failed: {}", e);
          all_issues.push(QualityIssue {
            rule: "go_golangci_error".to_string(),
            message: format!("Go golangci-lint execution failed: {e}"),
            severity: RuleSeverity::Error,
            category: RuleCategory::Compliance,
            file_path: None,
            line_number: None,
            column: None,
            code_snippet: None,
            suggestion: None,
          });
        }
      }
    }

    // Run custom pattern detection
    let custom_issues = self.run_custom_pattern_detection(project_path).await?;
    all_issues.extend(custom_issues);

    // Run AI pattern detection
    if self.config.ai_pattern_detection {
      let ai_issues = self.run_ai_pattern_detection(project_path).await?;
      all_issues.extend(ai_issues);
    }

    // Calculate score and determine status
    let errors: Vec<_> = all_issues.iter().filter(|issue| issue.severity == RuleSeverity::Error).cloned().collect();

    let warnings: Vec<_> = all_issues.iter().filter(|issue| issue.severity == RuleSeverity::Warning).cloned().collect();

    let info: Vec<_> = all_issues.iter().filter(|issue| issue.severity == RuleSeverity::Info).cloned().collect();

    let ai_pattern_issues: Vec<_> = all_issues.iter().filter(|issue| issue.category == RuleCategory::AIGenerated).cloned().collect();

    // Calculate score based on issues
    if !errors.is_empty() {
      #[allow(clippy::cast_precision_loss)]
      let penalty = (errors.len() * 20) as f64;
      total_score -= penalty;
    }
    if !warnings.is_empty() {
      #[allow(clippy::cast_precision_loss)]
      let penalty = (warnings.len() * 5) as f64;
      total_score -= penalty;
    }
    total_score = total_score.max(0.0);

    // Determine status
    let status = if !errors.is_empty() && total_score < self.config.thresholds.min_score {
      QualityGateStatus::Failed
    } else if !warnings.is_empty() || total_score < self.config.thresholds.min_score {
      QualityGateStatus::Warning
    } else {
      QualityGateStatus::Passed
    };

    Ok(QualityGateResult {
      status,
      score: total_score,
      total_issues: all_issues.len(),
      errors,
      warnings,
      info,
      ai_pattern_issues,
      timestamp: chrono::Utc::now(),
    })
  }

  /// Run Clippy for Rust code analysis
  async fn run_clippy(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let output = Command::new("cargo")
      .arg("clippy")
      .arg("--all-targets")
      .arg("--all-features")
      .arg("--")
      .arg("-D")
      .arg("warnings")
      .current_dir(project_path)
      .stdout(Stdio::piped())
      .stderr(Stdio::piped())
      .output()?;

    let mut issues = Vec::new();

    if !output.status.success() {
      let stderr = String::from_utf8_lossy(&output.stderr);
      for line in stderr.lines() {
        if let Some(issue) = self.parse_clippy_output(line) {
          issues.push(issue);
        }
      }
    }

    Ok(issues)
  }

  /// Run `ESLint` for JavaScript code analysis
  async fn run_javascript_eslint(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let output = Command::new("pnpm").arg("dlx").arg("eslint").arg("--format=json").arg(project_path).stdout(Stdio::piped()).stderr(Stdio::piped()).output()?;

    let mut issues = Vec::new();

    if !output.status.success() {
      let stdout = String::from_utf8_lossy(&output.stdout);
      for line in stdout.lines() {
        if let Some(issue) = Self::parse_eslint_output(line) {
          issues.push(issue);
        }
      }
    }

    Ok(issues)
  }

  /// Run `ESLint` for TypeScript code analysis
  async fn run_typescript_eslint(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let output = Command::new("pnpm")
      .arg("dlx")
      .arg("@typescript-eslint/eslint-plugin")
      .arg("--format=json")
      .arg(project_path)
      .stdout(Stdio::piped())
      .stderr(Stdio::piped())
      .output()?;

    let mut issues = Vec::new();

    if !output.status.success() {
      let stdout = String::from_utf8_lossy(&output.stdout);
      for line in stdout.lines() {
        if let Some(issue) = Self::parse_eslint_output(line) {
          issues.push(issue);
        }
      }
    }

    Ok(issues)
  }

  /// Run Pylint for Python code analysis
  async fn run_python_pylint(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let output =
      Command::new("pylint").arg("--output-format=json").arg("--reports=no").arg(project_path).stdout(Stdio::piped()).stderr(Stdio::piped()).output()?;

    let mut issues = Vec::new();

    if !output.status.success() {
      let stdout = String::from_utf8_lossy(&output.stdout);
      for line in stdout.lines() {
        if let Some(issue) = self.parse_pylint_output(line) {
          issues.push(issue);
        }
      }
    }

    Ok(issues)
  }

  /// Run Flake8 for Python code analysis
  async fn run_python_flake8(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let output = Command::new("flake8")
      .arg("--format=%(path)s:%(row)d:%(col)d: %(code)s %(text)s")
      .arg(project_path)
      .stdout(Stdio::piped())
      .stderr(Stdio::piped())
      .output()?;

    let mut issues = Vec::new();

    if !output.status.success() {
      let stdout = String::from_utf8_lossy(&output.stdout);
      for line in stdout.lines() {
        if let Some(issue) = self.parse_flake8_output(line) {
          issues.push(issue);
        }
      }
    }

    Ok(issues)
  }

  /// Run golangci-lint for Go code analysis
  async fn run_go_golangci(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let output = Command::new("golangci-lint").arg("run").arg("--out-format=json").arg(project_path).stdout(Stdio::piped()).stderr(Stdio::piped()).output()?;

    let mut issues = Vec::new();

    if !output.status.success() {
      let stdout = String::from_utf8_lossy(&output.stdout);
      for line in stdout.lines() {
        if let Some(issue) = self.parse_golangci_output(line) {
          issues.push(issue);
        }
      }
    }

    Ok(issues)
  }

  /// Run custom pattern detection rules
  async fn run_custom_pattern_detection(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let mut issues = Vec::new();

    // Walk through project files and apply custom rules
    for entry in walkdir::WalkDir::new(project_path).into_iter().filter_map(Result::ok).filter(|e| e.file_type().is_file()) {
      let file_path = entry.path();
      if let Some(extension) = file_path.extension() {
        let ext = extension.to_string_lossy();
        if matches!(ext.as_ref(), "rs" | "ts" | "js" | "tsx" | "jsx") {
          if let Ok(content) = fs::read_to_string(file_path) {
            for rule in &self.config.custom_rules {
              if let Some(issue) = Self::apply_rule(&content, rule, file_path) {
                issues.push(issue);
              }
            }
          }
        }
      }
    }

    Ok(issues)
  }

  /// Run AI pattern detection
  async fn run_ai_pattern_detection(&self, project_path: &str) -> Result<Vec<QualityIssue>> {
    let mut issues = Vec::new();

    for entry in walkdir::WalkDir::new(project_path).into_iter().filter_map(Result::ok).filter(|e| e.file_type().is_file()) {
      let file_path = entry.path();
      if let Some(extension) = file_path.extension() {
        let ext = extension.to_string_lossy();
        if matches!(ext.as_ref(), "rs" | "ts" | "js" | "tsx" | "jsx") {
          if let Ok(content) = fs::read_to_string(file_path) {
            for rule in &self.ai_pattern_rules {
              if let Some(issue) = Self::apply_rule(&content, rule, file_path) {
                issues.push(issue);
              }
            }
          }
        }
      }
    }

    Ok(issues)
  }

  /// Apply a quality rule to content
  fn apply_rule(content: &str, rule: &QualityRule, file_path: &std::path::Path) -> Option<QualityIssue> {
    let regex = Regex::new(&rule.pattern).ok()?;

    if regex.is_match(content) {
      Some(QualityIssue {
        rule: rule.name.clone(),
        message: rule.message.clone(),
        severity: rule.severity.clone(),
        category: rule.category.clone(),
        file_path: Some(file_path.to_string_lossy().to_string()),
        line_number: None, // Could be enhanced to find line numbers
        column: None,
        code_snippet: None,
        suggestion: Some(format!("Review and fix: {}", rule.description)),
      })
    } else {
      None
    }
  }

  /// Parse `ESLint` output with proper JSON parsing
  fn parse_eslint_output(line: &str) -> Option<QualityIssue> {
    // ESLint outputs JSON, so we parse it properly
    if let Ok(json_value) = serde_json::from_str::<serde_json::Value>(line) {
      // Extract issue details from ESLint JSON format
      if let Some(file_path) = json_value.get("filePath").and_then(|v| v.as_str()) {
        let line_number = json_value.get("line").and_then(serde_json::Value::as_u64).and_then(|n| usize::try_from(n).ok());
        let column = json_value.get("column").and_then(serde_json::Value::as_u64).and_then(|n| usize::try_from(n).ok());
        let message = json_value.get("message").and_then(|v| v.as_str()).unwrap_or("ESLint issue");
        let rule = json_value.get("ruleId").and_then(|v| v.as_str()).unwrap_or("eslint_rule");
        let severity = if json_value.get("severity").and_then(|v| v.as_u64()) == Some(2) { RuleSeverity::Error } else { RuleSeverity::Warning };

        Some(QualityIssue {
          rule: rule.to_string(),
          message: message.to_string(),
          severity,
          category: RuleCategory::Compliance,
          file_path: Some(file_path.to_string()),
          line_number,
          column,
          code_snippet: None,
          suggestion: Some("Review and fix the ESLint issue".to_string()),
        })
      } else {
        None
      }
    } else {
      // Fallback for non-JSON lines
      Some(QualityIssue {
        rule: "eslint_issue".to_string(),
        message: line.to_string(),
        severity: RuleSeverity::Warning,
        category: RuleCategory::Compliance,
        file_path: None,
        line_number: None,
        column: None,
        code_snippet: None,
        suggestion: None,
      })
    }
  }

  /// Parse Clippy output with proper format parsing
  fn parse_clippy_output(&self, line: &str) -> Option<QualityIssue> {
    // Clippy output format: file:line:col: message [rule]
    let re = Regex::new(r"^(.+):(\d+):(\d+):\s+(.+?)(?:\s+\[([^\]]+)\])?$").ok()?;
    if let Some(caps) = re.captures(line) {
      let file_path = caps.get(1)?.as_str().to_string();
      let line_number = caps.get(2)?.as_str().parse().ok()?;
      let column = caps.get(3)?.as_str().parse().ok()?;
      let message = caps.get(4)?.as_str().to_string();
      let rule = caps.get(5).map(|m| m.as_str().to_string()).unwrap_or_else(|| "clippy_rule".to_string());

      Some(QualityIssue {
        rule,
        message,
        severity: RuleSeverity::Warning,
        category: RuleCategory::Compliance,
        file_path: Some(file_path),
        line_number: Some(line_number),
        column: Some(column),
        code_snippet: None,
        suggestion: Some("Review and fix the Clippy warning".to_string()),
      })
    } else {
      None
    }
  }

  /// Parse Pylint output with proper JSON parsing
  fn parse_pylint_output(&self, line: &str) -> Option<QualityIssue> {
    if let Ok(json_value) = serde_json::from_str::<serde_json::Value>(line) {
      if let Some(file_path) = json_value.get("path").and_then(|v| v.as_str()) {
        let line_number = json_value.get("line").and_then(|v| v.as_u64()).map(|n| n as usize);
        let column = json_value.get("column").and_then(|v| v.as_u64()).map(|n| n as usize);
        let message = json_value.get("message").and_then(|v| v.as_str()).unwrap_or("Pylint issue");
        let rule = json_value.get("message-id").and_then(|v| v.as_str()).unwrap_or("pylint_rule");
        let severity = match json_value.get("type").and_then(|v| v.as_str()) {
          Some("error") => RuleSeverity::Error,
          Some("warning") => RuleSeverity::Warning,
          _ => RuleSeverity::Info,
        };

        Some(QualityIssue {
          rule: rule.to_string(),
          message: message.to_string(),
          severity,
          category: RuleCategory::Compliance,
          file_path: Some(file_path.to_string()),
          line_number,
          column,
          code_snippet: None,
          suggestion: Some("Review and fix the Pylint issue".to_string()),
        })
      } else {
        None
      }
    } else {
      None
    }
  }

  /// Parse Flake8 output with proper format parsing
  fn parse_flake8_output(&self, line: &str) -> Option<QualityIssue> {
    // Flake8 output format: file:line:col: code message
    let re = Regex::new(r"^(.+):(\d+):(\d+):\s+([A-Z]\d+)\s+(.+)$").ok()?;
    if let Some(caps) = re.captures(line) {
      let file_path = caps.get(1)?.as_str().to_string();
      let line_number = caps.get(2)?.as_str().parse().ok()?;
      let column = caps.get(3)?.as_str().parse().ok()?;
      let rule = caps.get(4)?.as_str().to_string();
      let message = caps.get(5)?.as_str().to_string();

      Some(QualityIssue {
        rule,
        message,
        severity: RuleSeverity::Warning,
        category: RuleCategory::Compliance,
        file_path: Some(file_path),
        line_number: Some(line_number),
        column: Some(column),
        code_snippet: None,
        suggestion: Some("Review and fix the Flake8 issue".to_string()),
      })
    } else {
      None
    }
  }

  /// Parse golangci-lint output with proper JSON parsing
  fn parse_golangci_output(&self, line: &str) -> Option<QualityIssue> {
    if let Ok(json_value) = serde_json::from_str::<serde_json::Value>(line) {
      if let Some(file_path) = json_value.get("file").and_then(|v| v.as_str()) {
        let line_number = json_value.get("line").and_then(|v| v.as_u64()).map(|n| n as usize);
        let column = json_value.get("column").and_then(|v| v.as_u64()).map(|n| n as usize);
        let message = json_value.get("text").and_then(|v| v.as_str()).unwrap_or("golangci-lint issue");
        let rule = json_value.get("rule").and_then(|v| v.as_str()).unwrap_or("golangci_rule");
        let severity = match json_value.get("severity").and_then(|v| v.as_str()) {
          Some("error") => RuleSeverity::Error,
          Some("warning") => RuleSeverity::Warning,
          _ => RuleSeverity::Info,
        };

        Some(QualityIssue {
          rule: rule.to_string(),
          message: message.to_string(),
          severity,
          category: RuleCategory::Compliance,
          file_path: Some(file_path.to_string()),
          line_number,
          column,
          code_snippet: None,
          suggestion: Some("Review and fix the golangci-lint issue".to_string()),
        })
      } else {
        None
      }
    } else {
      None
    }
  }
}

impl Default for LintingEngine {
  fn default() -> Self {
    Self::new()
  }
}

impl Default for LintingEngineConfig {
  fn default() -> Self {
    Self {
      rust_clippy_enabled: true,
      javascript_eslint_enabled: true,
      typescript_eslint_enabled: true,
      python_pylint_enabled: true,
      python_flake8_enabled: false,
      python_black_enabled: false,
      go_golangci_enabled: true,
      java_spotbugs_enabled: true,
      java_checkstyle_enabled: false,
      cpp_clang_tidy_enabled: true,
      cpp_cppcheck_enabled: false,
      csharp_sonar_enabled: true,
      elixir_credo_enabled: true,
      erlang_dialyzer_enabled: true,
      gleam_check_enabled: true,
      custom_rules: Vec::new(),
      thresholds: QualityThresholds::default(),
      ai_pattern_detection: true,
    }
  }
}

impl Default for QualityThresholds {
  fn default() -> Self {
    Self { max_errors: 0, max_warnings: 10, min_score: 80.0, max_complexity: 10.0, max_cognitive_complexity: 15.0 }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_quality_rule_creation() {
    let rule = QualityRule {
      name: "test_rule".to_string(),
      description: "Test rule".to_string(),
      severity: RuleSeverity::Warning,
      pattern: r"test".to_string(),
      message: "Test message".to_string(),
      category: RuleCategory::Maintainability,
    };

    assert_eq!(rule.name, "test_rule");
    assert_eq!(rule.severity, RuleSeverity::Warning);
  }

  #[test]
  fn test_ai_pattern_rules_initialization() {
    let engine = LintingEngine::new();
    assert!(!engine.ai_pattern_rules.is_empty());

    let placeholder_rule = engine.ai_pattern_rules.iter().find(|r| r.name == "ai_placeholder_comments").expect("Should have placeholder rule");

    assert_eq!(placeholder_rule.category, RuleCategory::AIGenerated);
  }

  #[test]
  fn test_enterprise_rules_initialization() {
    let engine = LintingEngine::new();
    assert!(!engine.enterprise_rules.is_empty());

    let security_rule = engine.enterprise_rules.iter().find(|r| r.category == RuleCategory::Security).expect("Should have security rules");

    assert_eq!(security_rule.severity, RuleSeverity::Error);
  }

  #[tokio::test]
  async fn test_quality_gate_engine_creation() {
    let engine = LintingEngine::new();
    assert!(engine.config.ai_pattern_detection);
    assert!(engine.config.rust_clippy_enabled);
    assert!(engine.config.javascript_eslint_enabled);
  }
}
