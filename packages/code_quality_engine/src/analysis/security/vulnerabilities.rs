//! Security Vulnerability Analysis with CentralCloud Integration
//!
//! Detects security vulnerabilities using patterns from CentralCloud.
//!
//! ## CentralCloud Integration
//!
//! - Queries "intelligence_hub.security_patterns.query" for vulnerability patterns
//! - Publishes detections to "intelligence_hub.security_pattern.detected"
//! - No local pattern databases - all patterns from CentralCloud

use crate::centralcloud::{extract_data, publish_detection, query_centralcloud};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;

/// Vulnerability analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VulnerabilityAnalysis {
    pub vulnerabilities: Vec<Vulnerability>,
    pub risk_score: f64,
    pub recommendations: Vec<VulnerabilityRecommendation>,
    pub metadata: VulnerabilityMetadata,
}

/// Security vulnerability
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vulnerability {
    pub id: String,
    pub severity: VulnerabilitySeverity,
    pub category: VulnerabilityCategory,
    pub description: String,
    pub location: VulnerabilityLocation,
    pub remediation: String,
    pub cwe_id: Option<String>,
    pub owasp_category: Option<String>,
}

/// Vulnerability severity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum VulnerabilitySeverity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

/// Vulnerability categories
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum VulnerabilityCategory {
    Injection,
    Authentication,
    Authorization,
    DataExposure,
    Cryptography,
    InputValidation,
    ErrorHandling,
    Logging,
    Other(String),
}

/// Vulnerability location
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VulnerabilityLocation {
    pub file_path: String,
    pub line_number: Option<u32>,
    pub column: Option<u32>,
    pub function_name: Option<String>,
    pub code_snippet: Option<String>,
}

/// Vulnerability recommendation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VulnerabilityRecommendation {
    pub priority: RecommendationPriority,
    pub category: VulnerabilityCategory,
    pub title: String,
    pub description: String,
    pub implementation: String,
    pub resources: Vec<String>,
}

/// Recommendation priority
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationPriority {
    Critical,
    High,
    Medium,
    Low,
}

/// Vulnerability metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VulnerabilityMetadata {
    pub analysis_time: chrono::DateTime<chrono::Utc>,
    pub files_analyzed: usize,
    pub patterns_checked: usize,
    pub detector_version: String,
}

/// Vulnerability pattern from CentralCloud
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VulnerabilityPattern {
    pub name: String,
    pub pattern: String,
    pub category: String,
    pub severity: String,
    pub description: String,
    pub remediation: String,
    pub cwe_id: Option<String>,
    pub owasp_category: Option<String>,
}

/// Vulnerability analyzer - CentralCloud integration (no local patterns)
pub struct VulnerabilityAnalyzer {
    // No local pattern database - query CentralCloud on-demand
}

impl VulnerabilityAnalyzer {
    pub fn new() -> Self {
        Self {}
    }

    /// Initialize (no-op for CentralCloud mode)
    pub async fn initialize(&mut self) -> Result<()> {
        // No initialization needed - queries CentralCloud on-demand
        Ok(())
    }

    /// Analyze vulnerabilities with CentralCloud security patterns
    pub async fn analyze(&self, content: &str, file_path: &str) -> Result<VulnerabilityAnalysis> {
        let start_time = std::time::Instant::now();
        
        // Perform security analysis
        let vulnerabilities = self.detect_vulnerabilities(content, file_path, &[]).await?;
        
        let duration = start_time.elapsed();
        tracing::info!("Security analysis completed in {:?}", duration);

        // 1. Query CentralCloud for security patterns
        let patterns = self.query_security_patterns(file_path).await?;

        // 2. Detect vulnerabilities in content (use content!)
        let vulnerabilities = self
            .detect_vulnerabilities(content, file_path, &patterns)
            .await?;

        // 3. Calculate risk score (use vulnerabilities!)
        let risk_score = self.calculate_risk_score(&vulnerabilities);

        // 4. Generate recommendations (use vulnerabilities!)
        let recommendations = self.generate_recommendations(&vulnerabilities);

        // 5. Publish detections to CentralCloud
        self.publish_vulnerability_stats(&vulnerabilities).await;

        Ok(VulnerabilityAnalysis {
            vulnerabilities,
            risk_score,
            recommendations,
            metadata: VulnerabilityMetadata {
                analysis_time: chrono::Utc::now(),
                files_analyzed: 1,
                patterns_checked: patterns.len(),
                detector_version: "1.0.0".to_string(),
            },
        })
    }

    /// Query CentralCloud for security vulnerability patterns
    async fn query_security_patterns(&self, file_path: &str) -> Result<Vec<VulnerabilityPattern>> {
        let language = Self::detect_language(file_path);

        let request = json!({
            "language": language,
            "pattern_types": ["sql_injection", "xss", "command_injection", "path_traversal", "insecure_crypto"],
            "include_remediation": true,
            "include_cwe": true,
        });

        let response =
            query_centralcloud("intelligence_hub.security_patterns.query", &request, 3000)?;

        Ok(extract_data(&response, "patterns"))
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
        } else if file_path.ends_with(".sql") {
            "sql"
        } else {
            "unknown"
        }
    }

    /// Detect vulnerabilities in content using CentralCloud patterns
    async fn detect_vulnerabilities(
        &self,
        content: &str,
        file_path: &str,
        patterns: &[VulnerabilityPattern],
    ) -> Result<Vec<Vulnerability>> {
        let mut vulnerabilities = Vec::new();

        // Check each security pattern
        for (idx, pattern) in patterns.iter().enumerate() {
            if content.contains(&pattern.pattern) {
                let severity = match pattern.severity.as_str() {
                    "critical" => VulnerabilitySeverity::Critical,
                    "high" => VulnerabilitySeverity::High,
                    "medium" => VulnerabilitySeverity::Medium,
                    "low" => VulnerabilitySeverity::Low,
                    _ => VulnerabilitySeverity::Info,
                };

                let category = match pattern.category.as_str() {
                    "injection" | "sql_injection" | "command_injection" => {
                        VulnerabilityCategory::Injection
                    }
                    "authentication" => VulnerabilityCategory::Authentication,
                    "authorization" => VulnerabilityCategory::Authorization,
                    "data_exposure" | "sensitive_data" => VulnerabilityCategory::DataExposure,
                    "cryptography" | "insecure_crypto" => VulnerabilityCategory::Cryptography,
                    "input_validation" | "xss" => VulnerabilityCategory::InputValidation,
                    "error_handling" => VulnerabilityCategory::ErrorHandling,
                    "logging" => VulnerabilityCategory::Logging,
                    other => VulnerabilityCategory::Other(other.to_string()),
                };

                vulnerabilities.push(Vulnerability {
                    id: format!("VULN-{}", idx),
                    severity,
                    category,
                    description: pattern.description.clone(),
                    location: VulnerabilityLocation {
                        file_path: file_path.to_string(),
                        line_number: None,
                        column: None,
                        function_name: None,
                        code_snippet: Some(pattern.pattern.clone()),
                    },
                    remediation: pattern.remediation.clone(),
                    cwe_id: pattern.cwe_id.clone(),
                    owasp_category: pattern.owasp_category.clone(),
                });
            }
        }

        Ok(vulnerabilities)
    }

    /// Calculate risk score from vulnerabilities
    fn calculate_risk_score(&self, vulnerabilities: &[Vulnerability]) -> f64 {
        if vulnerabilities.is_empty() {
            return 1.0;
        }

        let mut risk_score: f64 = 1.0;

        for vulnerability in vulnerabilities {
            let penalty = match vulnerability.severity {
                VulnerabilitySeverity::Critical => 0.3,
                VulnerabilitySeverity::High => 0.2,
                VulnerabilitySeverity::Medium => 0.1,
                VulnerabilitySeverity::Low => 0.05,
                VulnerabilitySeverity::Info => 0.01,
            };
            risk_score -= penalty;
        }

        risk_score.max(0.0).min(1.0)
    }

    /// Generate recommendations from vulnerabilities
    fn generate_recommendations(
        &self,
        vulnerabilities: &[Vulnerability],
    ) -> Vec<VulnerabilityRecommendation> {
        let mut recommendations = Vec::new();

        for vulnerability in vulnerabilities {
            let priority = match vulnerability.severity {
                VulnerabilitySeverity::Critical => RecommendationPriority::Critical,
                VulnerabilitySeverity::High => RecommendationPriority::High,
                VulnerabilitySeverity::Medium => RecommendationPriority::Medium,
                _ => RecommendationPriority::Low,
            };

            let category_str = match &vulnerability.category {
                VulnerabilityCategory::Injection => "Injection Vulnerability",
                VulnerabilityCategory::Authentication => "Authentication Issue",
                VulnerabilityCategory::Authorization => "Authorization Issue",
                VulnerabilityCategory::DataExposure => "Data Exposure",
                VulnerabilityCategory::Cryptography => "Cryptography Issue",
                VulnerabilityCategory::InputValidation => "Input Validation",
                VulnerabilityCategory::ErrorHandling => "Error Handling",
                VulnerabilityCategory::Logging => "Logging Issue",
                VulnerabilityCategory::Other(s) => s.as_str(),
            };

            let resources = match &vulnerability.category {
                VulnerabilityCategory::Injection => vec![
                    "https://owasp.org/www-community/Injection_Flaws".to_string(),
                    "https://cwe.mitre.org/data/definitions/89.html".to_string(),
                ],
                VulnerabilityCategory::Cryptography => vec![
                    "https://owasp.org/www-community/vulnerabilities/Insecure_Cryptographic_Storage".to_string(),
                ],
                _ => vec![
                    "https://owasp.org/www-project-top-ten/".to_string(),
                ],
            };

            recommendations.push(VulnerabilityRecommendation {
                priority,
                category: vulnerability.category.clone(),
                title: format!("Fix {}", category_str),
                description: vulnerability.description.clone(),
                implementation: vulnerability.remediation.clone(),
                resources,
            });
        }

        recommendations
    }

    /// Publish vulnerability detections to CentralCloud for collective learning
    async fn publish_vulnerability_stats(&self, vulnerabilities: &[Vulnerability]) {
        if vulnerabilities.is_empty() {
            return;
        }

        let stats = json!({
            "type": "security_vulnerability_detection",
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "vulnerabilities_found": vulnerabilities.len(),
            "severity_distribution": {
                "critical": vulnerabilities.iter().filter(|v| matches!(v.severity, VulnerabilitySeverity::Critical)).count(),
                "high": vulnerabilities.iter().filter(|v| matches!(v.severity, VulnerabilitySeverity::High)).count(),
                "medium": vulnerabilities.iter().filter(|v| matches!(v.severity, VulnerabilitySeverity::Medium)).count(),
                "low": vulnerabilities.iter().filter(|v| matches!(v.severity, VulnerabilitySeverity::Low)).count(),
            },
            "categories": vulnerabilities.iter().map(|v| format!("{:?}", v.category)).collect::<Vec<_>>(),
            "cwe_ids": vulnerabilities.iter().filter_map(|v| v.cwe_id.clone()).collect::<Vec<_>>(),
        });

        // Fire-and-forget publish
        publish_detection("intelligence_hub.security_pattern.detected", &stats).ok();
    }
}

impl Default for VulnerabilityAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}
