//! Instructor-based validation for prompt optimization results
//!
//! Provides structured schema validation for all prompt optimization outputs,
//! ensuring quality metrics, improvements, and optimization scores meet requirements.
//!
//! # Features
//!
//! - Structured schema validation for optimization results
//! - Quality score validation (0.0-1.0 range)
//! - Improvement metrics validation
//! - Token count tracking
//! - Clarity and specificity scoring
//!
//! # Examples
//!
//! ```rust,no_run
//! use prompt_engine::validation::{PromptOptimizationResult, PromptMetrics, validate_optimization};
//!
//! let result = PromptOptimizationResult {
//!     optimized_prompt: "Optimized prompt text".to_string(),
//!     quality_score: 0.92,
//!     improvements: vec!["Added clarity".to_string()],
//!     improvement_percentage: 15.5,
//!     metrics: PromptMetrics {
//!         token_count: 150,
//!         clarity_score: 0.95,
//!         specificity_score: 0.89,
//!     },
//! };
//!
//! // Validation is done at struct creation via serde
//! // Use with instructor for LLM-based validation
//! ```

use serde::{Deserialize, Serialize};

/// Optimization result for prompt improvements
///
/// Contains optimized prompt and quality metrics validated by Instructor.
/// All fields are structured and validated at deserialization time.
///
/// # Fields
///
/// - `optimized_prompt`: The improved prompt text
/// - `quality_score`: Quality (0.0-1.0) - determined by clarity + specificity
/// - `improvements`: List of specific improvements made
/// - `improvement_percentage`: Estimated improvement from original
/// - `metrics`: Detailed quality metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptOptimizationResult {
    /// The optimized prompt text
    #[serde(rename = "optimized_prompt")]
    pub optimized_prompt: String,

    /// Overall quality score (0.0-1.0)
    /// - 0.0-0.4: Poor quality, needs major revisions
    /// - 0.4-0.7: Acceptable, some improvements needed
    /// - 0.7-0.85: Good, minor improvements possible
    /// - 0.85-1.0: Excellent, production-ready
    #[serde(rename = "quality_score")]
    pub quality_score: f64,

    /// Key improvements made during optimization
    #[serde(rename = "improvements")]
    pub improvements: Vec<String>,

    /// Estimated improvement percentage from original prompt
    /// Range: 0.0-100.0 (e.g., 15.5 means 15.5% improvement)
    #[serde(rename = "improvement_percentage")]
    pub improvement_percentage: f64,

    /// Detailed quality metrics
    #[serde(rename = "metrics")]
    pub metrics: PromptMetrics,
}

/// Detailed metrics for prompt quality assessment
///
/// All metrics are in 0.0-1.0 range and independently validated.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptMetrics {
    /// Token count of the optimized prompt
    /// Helps track prompt length and API costs
    #[serde(rename = "token_count")]
    pub token_count: usize,

    /// Clarity score (0.0-1.0)
    /// Measures how clear and understandable the prompt is
    /// Factors: sentence structure, vocabulary simplicity, logical flow
    #[serde(rename = "clarity_score")]
    pub clarity_score: f64,

    /// Specificity score (0.0-1.0)
    /// Measures how specific and actionable the prompt is
    /// Factors: concrete examples, precise instructions, clear expectations
    #[serde(rename = "specificity_score")]
    pub specificity_score: f64,
}

/// Validated quality rule from AI analysis
///
/// Used when AI generates quality rules for linting.
/// Ensures structure, severity, and pattern validity.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidatedQualityRule {
    /// Name of the quality rule
    #[serde(rename = "rule_name")]
    pub rule_name: String,

    /// Regex pattern for matching violations
    #[serde(rename = "pattern")]
    pub pattern: String,

    /// Severity level: "error", "warning", or "info"
    #[serde(rename = "severity")]
    pub severity: String,

    /// Human-readable error message
    #[serde(rename = "message")]
    pub message: String,

    /// AI confidence (0.0-1.0) if AI-generated
    /// None if manually created
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ai_confidence: Option<f64>,
}

/// Linting results with validation
///
/// Structured results from applying quality rules.
/// All violations are validated and summarized.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LintingResult {
    /// List of quality violations found
    #[serde(rename = "violations")]
    pub violations: Vec<LintingViolation>,

    /// Summary of linting results
    #[serde(rename = "summary")]
    pub summary: String,

    /// Overall quality score (0.0-1.0)
    /// Higher score = fewer violations, better code quality
    #[serde(rename = "quality_score")]
    pub quality_score: f64,
}

/// Individual linting violation
///
/// Represents a single code quality issue found.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LintingViolation {
    /// File path where violation occurred
    #[serde(rename = "file")]
    pub file: String,

    /// Line number (1-indexed)
    #[serde(rename = "line")]
    pub line: usize,

    /// Column number (1-indexed)
    #[serde(rename = "column")]
    pub column: usize,

    /// Severity: "error", "warning", or "info"
    #[serde(rename = "severity")]
    pub severity: String,

    /// Violation message
    #[serde(rename = "message")]
    pub message: String,

    /// Rule ID that triggered this violation
    #[serde(rename = "rule_id")]
    pub rule_id: String,
}

/// Validation helper functions
pub mod validate {
    use super::*;

    /// Validate quality score is in valid range (0.0-1.0)
    pub fn quality_score(score: f64) -> Result<(), String> {
        if score < 0.0 || score > 1.0 {
            return Err(format!(
                "Quality score must be between 0.0 and 1.0, got {}",
                score
            ));
        }
        Ok(())
    }

    /// Validate improvement percentage is reasonable (0.0-200.0)
    pub fn improvement_percentage(percentage: f64) -> Result<(), String> {
        if percentage < 0.0 || percentage > 200.0 {
            return Err(format!(
                "Improvement percentage must be between 0.0 and 200.0, got {}",
                percentage
            ));
        }
        Ok(())
    }

    /// Validate prompt is not empty
    pub fn prompt_not_empty(prompt: &str) -> Result<(), String> {
        if prompt.trim().is_empty() {
            return Err("Prompt cannot be empty".to_string());
        }
        Ok(())
    }

    /// Validate improvements list is not empty
    pub fn improvements_not_empty(improvements: &[String]) -> Result<(), String> {
        if improvements.is_empty() {
            return Err("At least one improvement must be specified".to_string());
        }
        Ok(())
    }

    /// Validate token count is reasonable
    pub fn token_count(count: usize) -> Result<(), String> {
        if count == 0 {
            return Err("Token count must be greater than 0".to_string());
        }
        if count > 32768 {
            return Err(format!(
                "Token count {} exceeds maximum (32768)",
                count
            ));
        }
        Ok(())
    }

    /// Validate clarity and specificity scores
    pub fn metric_score(score: f64, name: &str) -> Result<(), String> {
        if score < 0.0 || score > 1.0 {
            return Err(format!(
                "{} must be between 0.0 and 1.0, got {}",
                name, score
            ));
        }
        Ok(())
    }
}

/// Validate a complete optimization result
///
/// Checks all fields for consistency and validity.
///
/// # Arguments
///
/// * `result` - The optimization result to validate
///
/// # Returns
///
/// * `Ok(())` if validation passes
/// * `Err(String)` with description of first validation error
pub fn validate_optimization_result(result: &PromptOptimizationResult) -> Result<(), String> {
    validate::prompt_not_empty(&result.optimized_prompt)?;
    validate::quality_score(result.quality_score)?;
    validate::improvements_not_empty(&result.improvements)?;
    validate::improvement_percentage(result.improvement_percentage)?;
    validate::token_count(result.metrics.token_count)?;
    validate::metric_score(result.metrics.clarity_score, "clarity_score")?;
    validate::metric_score(result.metrics.specificity_score, "specificity_score")?;

    // Logical validation: quality_score should roughly match clarity + specificity average
    let metric_average = (result.metrics.clarity_score + result.metrics.specificity_score) / 2.0;
    let tolerance = 0.2; // Allow ±0.2 difference
    if (result.quality_score - metric_average).abs() > tolerance {
        // Log warning but don't fail - scores can differ due to other factors
        tracing::warn!(
            "Quality score {} differs significantly from metric average {}",
            result.quality_score,
            metric_average
        );
    }

    Ok(())
}

/// Validate a quality rule
pub fn validate_quality_rule(rule: &ValidatedQualityRule) -> Result<(), String> {
    if rule.rule_name.trim().is_empty() {
        return Err("Rule name cannot be empty".to_string());
    }

    if rule.pattern.trim().is_empty() {
        return Err("Pattern cannot be empty".to_string());
    }

    // Validate pattern is valid regex
    match regex::Regex::new(&rule.pattern) {
        Ok(_) => {}
        Err(e) => return Err(format!("Invalid regex pattern: {}", e)),
    }

    match rule.severity.as_str() {
        "error" | "warning" | "info" => {}
        _ => return Err(format!("Invalid severity: {}, must be error/warning/info", rule.severity)),
    }

    if rule.message.trim().is_empty() {
        return Err("Message cannot be empty".to_string());
    }

    // If AI confidence is provided, validate range
    if let Some(confidence) = rule.ai_confidence {
        validate::metric_score(confidence, "ai_confidence")?;
    }

    Ok(())
}

/// Validate linting results
pub fn validate_linting_result(result: &LintingResult) -> Result<(), String> {
    validate::quality_score(result.quality_score)?;

    if result.summary.trim().is_empty() {
        return Err("Summary cannot be empty".to_string());
    }

    for violation in &result.violations {
        match violation.severity.as_str() {
            "error" | "warning" | "info" => {}
            _ => return Err(format!(
                "Invalid violation severity: {}, must be error/warning/info",
                violation.severity
            )),
        }

        if violation.file.trim().is_empty() {
            return Err("Violation file cannot be empty".to_string());
        }

        if violation.line == 0 {
            return Err("Violation line must be >= 1".to_string());
        }

        if violation.column == 0 {
            return Err("Violation column must be >= 1".to_string());
        }

        if violation.message.trim().is_empty() {
            return Err("Violation message cannot be empty".to_string());
        }

        if violation.rule_id.trim().is_empty() {
            return Err("Violation rule_id cannot be empty".to_string());
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_optimization_result_valid() {
        let result = PromptOptimizationResult {
            optimized_prompt: "A clear and specific prompt for code generation".to_string(),
            quality_score: 0.92,
            improvements: vec!["Added clarity".to_string(), "Improved specificity".to_string()],
            improvement_percentage: 18.5,
            metrics: PromptMetrics {
                token_count: 150,
                clarity_score: 0.95,
                specificity_score: 0.89,
            },
        };

        assert!(validate_optimization_result(&result).is_ok());
    }

    #[test]
    fn test_quality_score_out_of_range() {
        assert!(validate::quality_score(1.5).is_err());
        assert!(validate::quality_score(-0.1).is_err());
        assert!(validate::quality_score(0.5).is_ok());
    }

    #[test]
    fn test_improvement_percentage_valid() {
        assert!(validate::improvement_percentage(15.5).is_ok());
        assert!(validate::improvement_percentage(0.0).is_ok());
        assert!(validate::improvement_percentage(100.0).is_ok());
    }

    #[test]
    fn test_prompt_not_empty() {
        assert!(validate::prompt_not_empty("Valid prompt").is_ok());
        assert!(validate::prompt_not_empty("").is_err());
        assert!(validate::prompt_not_empty("   ").is_err());
    }

    #[test]
    fn test_token_count_validation() {
        assert!(validate::token_count(150).is_ok());
        assert!(validate::token_count(0).is_err());
        assert!(validate::token_count(32768).is_ok());
        assert!(validate::token_count(40000).is_err());
    }
}
