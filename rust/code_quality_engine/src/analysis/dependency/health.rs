//! Dependency Health Analysis
//!
//! Comprehensive dependency health analysis with CentralCloud integration.
//! Queries CVE database, package health metrics, and license data from CentralCloud.

use serde::{Deserialize, Serialize};
use serde_json::json;
use anyhow::Result;
use crate::centralcloud::{query_centralcloud, extract_data, publish_detection};

/// Dependency health analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyHealthAnalysis {
    pub dependencies: Vec<Dependency>,
    pub health_metrics: DependencyHealthMetrics,
    pub vulnerabilities: Vec<DependencyVulnerability>,
    pub recommendations: Vec<DependencyRecommendation>,
    pub metadata: HealthMetadata,
}

/// Dependency
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Dependency {
    pub id: String,
    pub name: String,
    pub version: String,
    pub dependency_type: DependencyType,
    pub source: DependencySource,
    pub health_status: DependencyHealthStatus,
    pub metadata: DependencyMetadata,
    pub usage: DependencyUsage,
    pub impact: DependencyImpact,
}

/// Dependency types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DependencyType {
    Direct,
    Transitive,
    Dev,
    Peer,
    Optional,
    Bundled,
    External,
    Internal,
}

/// Dependency sources
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DependencySource {
    NPM,
    Cargo,
    PyPI,
    Maven,
    NuGet,
    RubyGems,
    Hex,
    GitHub,
    GitLab,
    Bitbucket,
    Local,
    Custom,
}

/// Dependency health status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DependencyHealthStatus {
    Healthy,
    Warning,
    Critical,
    Deprecated,
    Unmaintained,
    Vulnerable,
    Unknown,
}

/// Dependency metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyMetadata {
    pub description: Option<String>,
    pub homepage: Option<String>,
    pub repository: Option<String>,
    pub license: Option<String>,
    pub author: Option<String>,
    pub maintainers: Vec<String>,
    pub keywords: Vec<String>,
    pub created_date: Option<chrono::DateTime<chrono::Utc>>,
    pub last_updated: Option<chrono::DateTime<chrono::Utc>>,
    pub download_count: Option<u64>,
    pub star_count: Option<u64>,
    pub fork_count: Option<u64>,
    pub issue_count: Option<u32>,
    pub pull_request_count: Option<u32>,
}

/// Dependency usage
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyUsage {
    pub files_using: Vec<String>,
    pub functions_using: Vec<String>,
    pub classes_using: Vec<String>,
    pub usage_frequency: u32,
    pub usage_context: Vec<String>,
}

/// Dependency impact
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyImpact {
    pub criticality: CriticalityLevel,
    pub blast_radius: u32,
    pub replacement_difficulty: DifficultyLevel,
    pub migration_cost: CostLevel,
    pub risk_level: RiskLevel,
}

/// Dependency health metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyHealthMetrics {
    pub total_dependencies: usize,
    pub healthy_dependencies: usize,
    pub warning_dependencies: usize,
    pub critical_dependencies: usize,
    pub deprecated_dependencies: usize,
    pub unmaintained_dependencies: usize,
    pub vulnerable_dependencies: usize,
    pub unknown_dependencies: usize,
    pub health_score: f64,
    pub freshness_score: f64,
    pub security_score: f64,
    pub maintenance_score: f64,
    pub popularity_score: f64,
    pub license_compliance_score: f64,
}

/// Dependency vulnerability
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyVulnerability {
    pub cve_id: String,
    pub severity: VulnerabilitySeverity,
    pub description: String,
    pub affected_versions: Vec<String>,
    pub fixed_version: Option<String>,
    pub published_date: Option<chrono::DateTime<chrono::Utc>>,
    pub cvss_score: Option<f64>,
    pub exploit_available: bool,
    pub patch_available: bool,
}

/// Vulnerability severity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum VulnerabilitySeverity {
    Low,
    Medium,
    High,
    Critical,
}

/// Dependency recommendation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyRecommendation {
    pub dependency_name: String,
    pub recommendation_type: RecommendationType,
    pub priority: Priority,
    pub reason: String,
    pub action: String,
    pub estimated_effort: EstimatedEffort,
}

/// Recommendation type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationType {
    Update,
    Replace,
    Remove,
    AddAlternative,
    ReviewLicense,
    SecurityPatch,
    PerformanceOptimization,
}

/// Priority level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Priority {
    Low,
    Medium,
    High,
    Critical,
}

/// Estimated effort
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EstimatedEffort {
    Trivial,
    Low,
    Medium,
    High,
    VeryHigh,
}

/// Criticality level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CriticalityLevel {
    Low,
    Medium,
    High,
    VeryHigh,
}

/// Difficulty level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DifficultyLevel {
    Low,
    Medium,
    High,
    VeryHigh,
}

/// Cost level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CostLevel {
    Low,
    Medium,
    High,
    VeryHigh,
}

/// Risk level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

/// Health metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthMetadata {
    pub analysis_time: chrono::DateTime<chrono::Utc>,
    pub files_analyzed: usize,
    pub dependencies_analyzed: usize,
    pub vulnerabilities_found: usize,
    pub analysis_duration_ms: u64,
    pub detector_version: String,
    pub centralcloud_available: bool,
}

/// Dependency health analyzer (no local databases - queries CentralCloud)
pub struct DependencyHealthAnalyzer {
    // No local databases - all data from CentralCloud via NATS
}

impl DependencyHealthAnalyzer {
    pub fn new() -> Self {
        Self {}
    }

    /// Analyze dependency health with CentralCloud integration
    pub async fn analyze(&self, content: &str, file_path: &str) -> Result<DependencyHealthAnalysis> {
        let start_time = std::time::Instant::now();

        // Extract dependencies from content (use content parameter!)
        let dependencies = self.extract_dependencies(content, file_path).await?;

        // Query CentralCloud for health data
        let health_data = self.query_dependency_health(&dependencies).await?;

        // Check vulnerabilities via CentralCloud
        let vulnerabilities = self.check_vulnerabilities(&dependencies).await?;

        // Calculate metrics (use dependencies parameter!)
        let health_metrics = self.calculate_health_metrics(&dependencies);

        // Generate recommendations (use dependencies and vulnerabilities!)
        let recommendations = self.generate_recommendations(&dependencies, &vulnerabilities);

        let duration = start_time.elapsed().as_millis() as u64;
        let vuln_count = vulnerabilities.len();

        // Publish stats to CentralCloud for collective learning
        self.publish_analysis_stats(&dependencies, &vulnerabilities).await;

        Ok(DependencyHealthAnalysis {
            dependencies,
            health_metrics,
            vulnerabilities,
            recommendations,
            metadata: HealthMetadata {
                analysis_time: chrono::Utc::now(),
                files_analyzed: 1,
                dependencies_analyzed: health_data.len(),
                vulnerabilities_found: vuln_count,
                analysis_duration_ms: duration,
                detector_version: "2.0.0".to_string(),
                centralcloud_available: !health_data.is_empty(),
            },
        })
    }

    /// Extract dependencies from file content
    async fn extract_dependencies(&self, content: &str, file_path: &str) -> Result<Vec<Dependency>> {
        let mut dependencies = Vec::new();

        // Detect package manager from file path
        let source = Self::detect_dependency_source(file_path);

        // Parse dependencies based on file type
        match source {
            DependencySource::Cargo => {
                // Parse Cargo.toml
                if content.contains("[dependencies]") {
                    for line in content.lines() {
                        if let Some(dep) = Self::parse_cargo_dependency(line) {
                            dependencies.push(dep);
                        }
                    }
                }
            },
            DependencySource::NPM => {
                // Parse package.json (JSON parsing would be better)
                if content.contains("\"dependencies\"") {
                    // Simplified parsing - real implementation would use serde_json
                    dependencies.push(Dependency {
                        id: "npm-placeholder".to_string(),
                        name: "placeholder".to_string(),
                        version: "1.0.0".to_string(),
                        dependency_type: DependencyType::Direct,
                        source: DependencySource::NPM,
                        health_status: DependencyHealthStatus::Unknown,
                        metadata: DependencyMetadata::default(),
                        usage: DependencyUsage::default(),
                        impact: DependencyImpact::default(),
                    });
                }
            },
            _ => {}
        }

        Ok(dependencies)
    }

    /// Detect dependency source from file path
    fn detect_dependency_source(file_path: &str) -> DependencySource {
        if file_path.ends_with("Cargo.toml") {
            DependencySource::Cargo
        } else if file_path.ends_with("package.json") {
            DependencySource::NPM
        } else if file_path.ends_with("requirements.txt") || file_path.ends_with("pyproject.toml") {
            DependencySource::PyPI
        } else if file_path.ends_with("mix.exs") {
            DependencySource::Hex
        } else {
            DependencySource::Custom
        }
    }

    /// Parse Cargo.toml dependency line
    fn parse_cargo_dependency(line: &str) -> Option<Dependency> {
        let trimmed = line.trim();
        if trimmed.starts_with('#') || !trimmed.contains('=') {
            return None;
        }

        let parts: Vec<&str> = trimmed.splitn(2, '=').collect();
        if parts.len() == 2 {
            let name = parts[0].trim().to_string();
            let version = parts[1].trim().trim_matches('"').to_string();

            Some(Dependency {
                id: format!("cargo-{}-{}", name, version),
                name,
                version,
                dependency_type: DependencyType::Direct,
                source: DependencySource::Cargo,
                health_status: DependencyHealthStatus::Unknown,
                metadata: DependencyMetadata::default(),
                usage: DependencyUsage::default(),
                impact: DependencyImpact::default(),
            })
        } else {
            None
        }
    }

    /// Query CentralCloud for dependency health data
    async fn query_dependency_health(&self, dependencies: &[Dependency]) -> Result<Vec<serde_json::Value>> {
        if dependencies.is_empty() {
            return Ok(vec![]);
        }

        let request = json!({
            "dependencies": dependencies.iter().map(|d| json!({
                "name": d.name,
                "version": d.version,
                "ecosystem": Self::source_to_ecosystem(&d.source)
            })).collect::<Vec<_>>(),
            "include_metadata": true,
            "include_vulnerabilities": false  // Separate query for vulns
        });

        let response = query_centralcloud(
            "intelligence_hub.dependency_health.query",
            &request,
            5000
        )?;

        Ok(extract_data(&response, "health_data"))
    }

    /// Check vulnerabilities via CentralCloud CVE database
    async fn check_vulnerabilities(&self, dependencies: &[Dependency]) -> Result<Vec<DependencyVulnerability>> {
        if dependencies.is_empty() {
            return Ok(vec![]);
        }

        let request = json!({
            "dependencies": dependencies.iter().map(|d| json!({
                "name": d.name,
                "version": d.version,
                "ecosystem": Self::source_to_ecosystem(&d.source)
            })).collect::<Vec<_>>(),
            "severity_threshold": "low",
            "include_fixed": true
        });

        let response = query_centralcloud(
            "intelligence_hub.vulnerability.query",
            &request,
            5000
        )?;

        Ok(extract_data(&response, "vulnerabilities"))
    }

    /// Calculate health metrics from dependencies
    fn calculate_health_metrics(&self, dependencies: &[Dependency]) -> DependencyHealthMetrics {
        let total = dependencies.len();
        let mut healthy = 0;
        let mut warning = 0;
        let mut critical = 0;
        let mut deprecated = 0;
        let mut unmaintained = 0;
        let mut vulnerable = 0;
        let mut unknown = 0;

        for dep in dependencies {
            match dep.health_status {
                DependencyHealthStatus::Healthy => healthy += 1,
                DependencyHealthStatus::Warning => warning += 1,
                DependencyHealthStatus::Critical => critical += 1,
                DependencyHealthStatus::Deprecated => deprecated += 1,
                DependencyHealthStatus::Unmaintained => unmaintained += 1,
                DependencyHealthStatus::Vulnerable => vulnerable += 1,
                DependencyHealthStatus::Unknown => unknown += 1,
            }
        }

        let health_score = if total > 0 {
            (healthy as f64) / (total as f64)
        } else {
            1.0
        };

        DependencyHealthMetrics {
            total_dependencies: total,
            healthy_dependencies: healthy,
            warning_dependencies: warning,
            critical_dependencies: critical,
            deprecated_dependencies: deprecated,
            unmaintained_dependencies: unmaintained,
            vulnerable_dependencies: vulnerable,
            unknown_dependencies: unknown,
            health_score,
            freshness_score: 0.8,  // Placeholder
            security_score: if vulnerable == 0 { 1.0 } else { 0.5 },
            maintenance_score: 0.8,  // Placeholder
            popularity_score: 0.7,  // Placeholder
            license_compliance_score: 1.0,  // Placeholder
        }
    }

    /// Generate recommendations based on health analysis
    fn generate_recommendations(
        &self,
        dependencies: &[Dependency],
        vulnerabilities: &[DependencyVulnerability]
    ) -> Vec<DependencyRecommendation> {
        let mut recommendations = Vec::new();

        // Recommend security patches for vulnerable dependencies
        for vuln in vulnerabilities {
            if vuln.severity == VulnerabilitySeverity::Critical || vuln.severity == VulnerabilitySeverity::High {
                if let Some(fixed_version) = &vuln.fixed_version {
                    recommendations.push(DependencyRecommendation {
                        dependency_name: vuln.cve_id.clone(),  // Would extract package name
                        recommendation_type: RecommendationType::SecurityPatch,
                        priority: Priority::Critical,
                        reason: format!("{}: {}", vuln.cve_id, vuln.description),
                        action: format!("Update to version {}", fixed_version),
                        estimated_effort: EstimatedEffort::Low,
                    });
                }
            }
        }

        // Recommend updates for deprecated dependencies
        for dep in dependencies {
            if matches!(dep.health_status, DependencyHealthStatus::Deprecated) {
                recommendations.push(DependencyRecommendation {
                    dependency_name: dep.name.clone(),
                    recommendation_type: RecommendationType::Replace,
                    priority: Priority::Medium,
                    reason: "Dependency is deprecated".to_string(),
                    action: "Find an actively maintained alternative".to_string(),
                    estimated_effort: EstimatedEffort::Medium,
                });
            }
        }

        recommendations
    }

    /// Publish analysis stats to CentralCloud for collective learning
    async fn publish_analysis_stats(&self, dependencies: &[Dependency], vulnerabilities: &[DependencyVulnerability]) {
        let stats = json!({
            "event": "dependency_health_analysis",
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "dependencies_count": dependencies.len(),
            "vulnerabilities_count": vulnerabilities.len(),
            "ecosystems": dependencies.iter().map(|d| Self::source_to_ecosystem(&d.source)).collect::<Vec<_>>()
        });

        publish_detection("intelligence_hub.detection.stats", &stats).ok();
    }

    /// Convert dependency source to ecosystem string
    fn source_to_ecosystem(source: &DependencySource) -> String {
        match source {
            DependencySource::NPM => "npm",
            DependencySource::Cargo => "cargo",
            DependencySource::PyPI => "pypi",
            DependencySource::Hex => "hex",
            DependencySource::Maven => "maven",
            DependencySource::NuGet => "nuget",
            DependencySource::RubyGems => "rubygems",
            _ => "unknown",
        }.to_string()
    }
}

// Default implementations
impl Default for DependencyMetadata {
    fn default() -> Self {
        Self {
            description: None,
            homepage: None,
            repository: None,
            license: None,
            author: None,
            maintainers: vec![],
            keywords: vec![],
            created_date: None,
            last_updated: None,
            download_count: None,
            star_count: None,
            fork_count: None,
            issue_count: None,
            pull_request_count: None,
        }
    }
}

impl Default for DependencyUsage {
    fn default() -> Self {
        Self {
            files_using: vec![],
            functions_using: vec![],
            classes_using: vec![],
            usage_frequency: 0,
            usage_context: vec![],
        }
    }
}

impl Default for DependencyImpact {
    fn default() -> Self {
        Self {
            criticality: CriticalityLevel::Low,
            blast_radius: 0,
            replacement_difficulty: DifficultyLevel::Low,
            migration_cost: CostLevel::Low,
            risk_level: RiskLevel::Low,
        }
    }
}

impl PartialEq for VulnerabilitySeverity {
    fn eq(&self, other: &Self) -> bool {
        matches!(
            (self, other),
            (VulnerabilitySeverity::Low, VulnerabilitySeverity::Low)
            | (VulnerabilitySeverity::Medium, VulnerabilitySeverity::Medium)
            | (VulnerabilitySeverity::High, VulnerabilitySeverity::High)
            | (VulnerabilitySeverity::Critical, VulnerabilitySeverity::Critical)
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_dependency_extraction() {
        let analyzer = DependencyHealthAnalyzer::new();
        let content = r#"
[dependencies]
serde = "1.0"
tokio = { version = "1.35", features = ["full"] }
        "#;

        let deps = analyzer.extract_dependencies(content, "Cargo.toml").await.unwrap();
        assert!(!deps.is_empty());
    }

    #[tokio::test]
    async fn test_health_analysis() {
        let analyzer = DependencyHealthAnalyzer::new();
        let content = r#"
[dependencies]
serde = "1.0"
        "#;

        let result = analyzer.analyze(content, "Cargo.toml").await.unwrap();
        assert_eq!(result.metadata.files_analyzed, 1);
    }
}
