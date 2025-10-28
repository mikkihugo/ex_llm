//! Security Compliance Analysis with CentralCloud Integration
//!
//! Checks compliance with security frameworks using rules from CentralCloud.
//!
//! ## CentralCloud Integration
//!
//! - Queries "intelligence_hub.framework_rules.query" for compliance rules
//! - Publishes violations to "intelligence_hub.security_pattern.detected"
//! - No local framework databases - all rules from CentralCloud

use crate::centralcloud::{extract_data, publish_detection, query_centralcloud};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;

/// Compliance analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceAnalysis {
    pub compliance_score: f64,
    pub violations: Vec<ComplianceViolation>,
    pub recommendations: Vec<ComplianceRecommendation>,
    pub frameworks: Vec<ComplianceFramework>,
}

/// Compliance violation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceViolation {
    pub framework: String,
    pub requirement: String,
    pub severity: ComplianceSeverity,
    pub description: String,
    pub location: ViolationLocation,
    pub remediation: String,
}

/// Compliance severity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ComplianceSeverity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

/// Violation location
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ViolationLocation {
    pub file_path: String,
    pub line_number: Option<u32>,
    pub function_name: Option<String>,
    pub code_snippet: Option<String>,
}

/// Compliance recommendation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceRecommendation {
    pub priority: RecommendationPriority,
    pub framework: String,
    pub requirement: String,
    pub title: String,
    pub description: String,
    pub implementation: String,
}

/// Recommendation priority
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationPriority {
    Critical,
    High,
    Medium,
    Low,
}

/// Compliance framework
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceFramework {
    pub name: String,
    pub version: String,
    pub compliance_level: f64,
    pub requirements: Vec<ComplianceRequirement>,
}

/// Compliance requirement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceRequirement {
    pub id: String,
    pub title: String,
    pub description: String,
    pub pattern: String,
    pub severity: String,
}

/// Compliance status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ComplianceStatus {
    Compliant,
    NonCompliant,
    PartiallyCompliant,
    NotApplicable,
}

/// Compliance analyzer - CentralCloud integration (no local frameworks)
pub struct ComplianceAnalyzer {
    // No local framework database - query CentralCloud on-demand
}

impl ComplianceAnalyzer {
    pub fn new() -> Self {
        Self {}
    }

    /// Analyze compliance with CentralCloud framework rules
    pub async fn analyze(&self, content: &str, file_path: &str) -> Result<ComplianceAnalysis> {
        // 1. Query CentralCloud for framework rules
        let frameworks = self.query_framework_rules(file_path).await?;

        // 2. Check compliance (use content!)
        let violations = self
            .check_compliance(content, file_path, &frameworks)
            .await?;

        // 3. Generate recommendations (use violations!)
        let recommendations = self.generate_recommendations(&violations, &frameworks);

        // 4. Calculate compliance score (use violations and frameworks!)
        let compliance_score = self.calculate_compliance_score(&violations, &frameworks);

        // 5. Publish violations to CentralCloud
        self.publish_compliance_stats(&violations).await;

        Ok(ComplianceAnalysis {
            compliance_score,
            violations,
            recommendations,
            frameworks,
        })
    }

    /// Query CentralCloud for framework compliance rules
    async fn query_framework_rules(&self, file_path: &str) -> Result<Vec<ComplianceFramework>> {
        let language = Self::detect_language(file_path);

        let request = json!({
            "language": language,
            "frameworks": ["owasp", "nist", "soc2"],
            "include_remediation": true,
        });

        let response =
            query_centralcloud("intelligence_hub.framework_rules.query", &request, 3000)?;

        let rules: Vec<serde_json::Value> = extract_data(&response, "rules");

        // Convert to frameworks
        let mut frameworks = Vec::new();
        for (idx, rule_set) in rules.iter().enumerate() {
            let name = rule_set
                .get("framework")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown")
                .to_string();
            let version = rule_set
                .get("version")
                .and_then(|v| v.as_str())
                .unwrap_or("1.0")
                .to_string();

            let requirements: Vec<ComplianceRequirement> = rule_set
                .get("requirements")
                .and_then(|v| v.as_array())
                .map(|arr| {
                    arr.iter()
                        .enumerate()
                        .map(|(req_idx, req)| ComplianceRequirement {
                            id: format!("REQ-{}-{}", idx, req_idx),
                            title: req
                                .get("title")
                                .and_then(|v| v.as_str())
                                .unwrap_or("Unknown")
                                .to_string(),
                            description: req
                                .get("description")
                                .and_then(|v| v.as_str())
                                .unwrap_or("")
                                .to_string(),
                            pattern: req
                                .get("pattern")
                                .and_then(|v| v.as_str())
                                .unwrap_or("")
                                .to_string(),
                            severity: req
                                .get("severity")
                                .and_then(|v| v.as_str())
                                .unwrap_or("medium")
                                .to_string(),
                        })
                        .collect()
                })
                .unwrap_or_default();

            frameworks.push(ComplianceFramework {
                name,
                version,
                compliance_level: 0.0,
                requirements,
            });
        }

        Ok(frameworks)
    }

    /// Detect language from file path
    fn detect_language(file_path: &str) -> &str {
        if file_path.ends_with(".rs") {
            "rust"
        } else if file_path.ends_with(".ex") || file_path.ends_with(".exs") {
            "elixir"
        } else if file_path.ends_with(".py") {
            "python"
        } else if file_path.ends_with(".js") || file_path.ends_with(".ts") {
            "javascript"
        } else {
            "unknown"
        }
    }

    /// Check compliance against framework rules
    async fn check_compliance(
        &self,
        content: &str,
        file_path: &str,
        frameworks: &[ComplianceFramework],
    ) -> Result<Vec<ComplianceViolation>> {
        let mut violations = Vec::new();

        // Check each framework's requirements
        for framework in frameworks {
            for requirement in &framework.requirements {
                // Simple pattern matching (real impl would use AST)
                if !requirement.pattern.is_empty() && content.contains(&requirement.pattern) {
                    let severity = match requirement.severity.as_str() {
                        "critical" => ComplianceSeverity::Critical,
                        "high" => ComplianceSeverity::High,
                        "medium" => ComplianceSeverity::Medium,
                        "low" => ComplianceSeverity::Low,
                        _ => ComplianceSeverity::Info,
                    };

                    violations.push(ComplianceViolation {
                        framework: framework.name.clone(),
                        requirement: requirement.id.clone(),
                        severity,
                        description: requirement.description.clone(),
                        location: ViolationLocation {
                            file_path: file_path.to_string(),
                            line_number: None,
                            function_name: None,
                            code_snippet: Some(requirement.pattern.clone()),
                        },
                        remediation: format!("Address requirement: {}", requirement.title),
                    });
                }
            }
        }

        Ok(violations)
    }

    /// Generate recommendations from violations
    fn generate_recommendations(
        &self,
        violations: &[ComplianceViolation],
        frameworks: &[ComplianceFramework],
    ) -> Vec<ComplianceRecommendation> {
        let mut recommendations = Vec::new();

        // Create recommendations for each violation
        for violation in violations {
            let priority = match violation.severity {
                ComplianceSeverity::Critical => RecommendationPriority::Critical,
                ComplianceSeverity::High => RecommendationPriority::High,
                ComplianceSeverity::Medium => RecommendationPriority::Medium,
                _ => RecommendationPriority::Low,
            };

            recommendations.push(ComplianceRecommendation {
                priority,
                framework: violation.framework.clone(),
                requirement: violation.requirement.clone(),
                title: format!("Fix {} Compliance", violation.framework),
                description: violation.description.clone(),
                implementation: violation.remediation.clone(),
            });
        }

        // Add proactive recommendations for frameworks
        for framework in frameworks {
            if framework.requirements.len() > 5 {
                recommendations.push(ComplianceRecommendation {
                    priority: RecommendationPriority::Low,
                    framework: framework.name.clone(),
                    requirement: "general".to_string(),
                    title: format!("Improve {} Compliance", framework.name),
                    description: format!(
                        "Review all {} requirements for best practices",
                        framework.name
                    ),
                    implementation: "Conduct compliance audit and implement missing requirements"
                        .to_string(),
                });
            }
        }

        recommendations
    }

    /// Calculate compliance score from violations and frameworks
    fn calculate_compliance_score(
        &self,
        violations: &[ComplianceViolation],
        frameworks: &[ComplianceFramework],
    ) -> f64 {
        let total_requirements: usize = frameworks.iter().map(|f| f.requirements.len()).sum();

        if total_requirements == 0 {
            return 1.0;
        }

        // Calculate violation penalty
        let violation_penalty: f64 = violations
            .iter()
            .map(|v| match v.severity {
                ComplianceSeverity::Critical => 1.0,
                ComplianceSeverity::High => 0.7,
                ComplianceSeverity::Medium => 0.4,
                ComplianceSeverity::Low => 0.2,
                ComplianceSeverity::Info => 0.1,
            })
            .sum();

        let score = 1.0 - (violation_penalty / total_requirements as f64);
        score.max(0.0).min(1.0)
    }

    /// Publish compliance violations to CentralCloud for collective learning
    async fn publish_compliance_stats(&self, violations: &[ComplianceViolation]) {
        if violations.is_empty() {
            return;
        }

        let stats = json!({
            "type": "compliance_violation",
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "violations_found": violations.len(),
            "frameworks": violations.iter().map(|v| v.framework.clone()).collect::<Vec<_>>(),
            "severity_distribution": {
                "critical": violations.iter().filter(|v| matches!(v.severity, ComplianceSeverity::Critical)).count(),
                "high": violations.iter().filter(|v| matches!(v.severity, ComplianceSeverity::High)).count(),
                "medium": violations.iter().filter(|v| matches!(v.severity, ComplianceSeverity::Medium)).count(),
                "low": violations.iter().filter(|v| matches!(v.severity, ComplianceSeverity::Low)).count(),
            },
        });

        // Fire-and-forget publish
        publish_detection("intelligence_hub.security_pattern.detected", &stats).ok();
    }
}

impl Default for ComplianceAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}
