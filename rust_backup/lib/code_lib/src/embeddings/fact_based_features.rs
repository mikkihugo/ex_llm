//! Fact-Based Feature Extraction
//!
//! Uses EXISTING detector outputs (linked to fact-system) to create rich embeddings.
//! NO re-detection - just vectorize what detectors already found!

use super::EMBEDDING_DIM;
use crate::analysis::{
    framework::detector::FrameworkDetection,
    architecture::patterns::ArchitecturalPatternAnalysis,
    security::detector::SecurityAnalysis,
    performance::detector::PerformanceAnalysis,
    quality::detector::QualityAnalysis,
};
use crate::codebase::metadata::CodebaseMetadata;
use anyhow::Result;

// Import fact-system types for security features
#[cfg(feature = "fact-system-integration")]
use fact_system::storage::{FactData, SecurityVulnerability};

/// Extract framework features from fact-system detection results
pub fn extract_framework_features(detection: &FrameworkDetection) -> Vec<f32> {
    let mut features = vec![0.0; 32];

    // Framework categories (one-hot encoding)
    for (i, framework) in detection.frameworks.iter().take(16).enumerate() {
        features[i] = framework.confidence as f32;
    }

    // Ecosystem indicators (weighted)
    for (i, hint) in detection.ecosystem_hints.iter().take(8).enumerate() {
        features[16 + i] = 1.0;
    }

    // Overall confidence scores
    if !detection.confidence_scores.is_empty() {
        let avg_confidence: f64 = detection.confidence_scores.values().sum::<f64>()
            / detection.confidence_scores.len() as f64;
        features[24] = avg_confidence as f32;
    }

    features
}

/// Extract architectural pattern features from fact-system analysis
pub fn extract_architecture_features(analysis: &ArchitecturalPatternAnalysis) -> Vec<f32> {
    let mut features = vec![0.0; 64];

    // Pattern types (one-hot with confidence)
    for (i, pattern) in analysis.patterns.iter().take(32).enumerate() {
        features[i] = pattern.confidence as f32;
    }

    // Violations (negative indicators)
    for (i, violation) in analysis.violations.iter().take(16).enumerate() {
        features[32 + i] = violation.severity as f32;
    }

    // Recommendations count (quality indicator)
    features[48] = (analysis.recommendations.len() as f32).min(10.0) / 10.0;

    features
}

/// Extract security features from fact-system detection
pub fn extract_security_features(analysis: &SecurityAnalysis) -> Vec<f32> {
    let mut features = vec![0.0; 32];

    // Security score (normalized 0-1)
    features[0] = analysis.security_score as f32 / 100.0;

    // Vulnerability indicators
    features[1] = if analysis.has_vulnerabilities { 1.0 } else { 0.0 };
    features[2] = (analysis.vulnerability_count as f32).ln() / 10.0;

    // Compliance (one-hot per framework)
    for (i, framework) in analysis.compliance_frameworks.iter().take(8).enumerate() {
        features[3 + i] = framework.compliance_score;
    }

    // Security patterns detected
    for (i, pattern) in analysis.security_patterns.iter().take(16).enumerate() {
        features[11 + i] = pattern.confidence;
    }

    // Encryption/auth indicators
    features[27] = if analysis.uses_encryption { 1.0 } else { 0.0 };
    features[28] = if analysis.has_authentication { 1.0 } else { 0.0 };
    features[29] = if analysis.has_authorization { 1.0 } else { 0.0 };

    features
}

/// Extract performance features from fact-system analysis
pub fn extract_performance_features(analysis: &PerformanceAnalysis) -> Vec<f32> {
    let mut features = vec![0.0; 32];

    // Performance score
    features[0] = analysis.performance_score as f32 / 100.0;

    // Bottleneck indicators
    features[1] = (analysis.bottleneck_count as f32).ln() / 10.0;

    // Optimization opportunities
    features[2] = (analysis.optimization_opportunities.len() as f32).min(10.0) / 10.0;

    // Performance patterns detected
    for (i, pattern) in analysis.performance_patterns.iter().take(16).enumerate() {
        features[3 + i] = pattern.confidence;
    }

    // Caching/concurrency indicators
    features[19] = if analysis.has_caching { 1.0 } else { 0.0 };
    features[20] = if analysis.has_async { 1.0 } else { 0.0 };
    features[21] = if analysis.has_parallelism { 1.0 } else { 0.0 };

    features
}

/// Extract quality features from fact-system analysis
pub fn extract_quality_features(analysis: &QualityAnalysis) -> Vec<f32> {
    let mut features = vec![0.0; 32];

    // Quality metrics (from fact-system rules)
    features[0] = analysis.maintainability_index / 100.0;
    features[1] = analysis.technical_debt_ratio;
    features[2] = analysis.test_coverage / 100.0;
    features[3] = analysis.documentation_coverage / 100.0;

    // Code smells (from fact-system patterns)
    for (i, smell) in analysis.code_smells.iter().take(16).enumerate() {
        features[4 + i] = smell.severity;
    }

    // Quality gates
    features[20] = if analysis.passes_quality_gates { 1.0 } else { 0.0 };

    features
}

/// Extract security features directly from FactData (from fact-system)
///
/// Uses actual vulnerability data collected from npm advisories, GitHub Security Database, RustSec
#[cfg(feature = "fact-system-integration")]
pub fn extract_factdata_security_features(fact_data: &FactData) -> Vec<f32> {
    let mut features = vec![0.0; 32];

    // Security score (from fact-system)
    if let Some(score) = fact_data.security_score {
        features[0] = score / 100.0;
    }

    // Vulnerability count and severity distribution
    let vuln_count = fact_data.vulnerabilities.len();
    features[1] = if vuln_count > 0 { 1.0 } else { 0.0 };
    features[2] = (vuln_count as f32).ln().max(0.0) / 10.0;

    // Count vulnerabilities by severity
    let critical_count = fact_data
        .vulnerabilities
        .iter()
        .filter(|v| v.severity.to_uppercase() == "CRITICAL")
        .count();
    let high_count = fact_data
        .vulnerabilities
        .iter()
        .filter(|v| v.severity.to_uppercase() == "HIGH")
        .count();
    let medium_count = fact_data
        .vulnerabilities
        .iter()
        .filter(|v| v.severity.to_uppercase() == "MEDIUM" || v.severity.to_uppercase() == "MODERATE")
        .count();

    features[3] = (critical_count as f32).min(5.0) / 5.0;
    features[4] = (high_count as f32).min(10.0) / 10.0;
    features[5] = (medium_count as f32).min(20.0) / 20.0;

    // CVSS score distribution (average of all vulnerabilities with CVSS)
    let cvss_scores: Vec<f32> = fact_data
        .vulnerabilities
        .iter()
        .filter_map(|v| v.cvss_score)
        .collect();

    if !cvss_scores.is_empty() {
        let avg_cvss = cvss_scores.iter().sum::<f32>() / cvss_scores.len() as f32;
        features[6] = avg_cvss / 10.0; // Normalize CVSS (0-10 scale)
    }

    // Vulnerability types (one-hot encoding for common types)
    for (i, vuln) in fact_data.vulnerabilities.iter().take(10).enumerate() {
        // Use vulnerability type as feature
        features[7 + i] = match vuln.vuln_type.as_str() {
            "npm-advisory" => 0.9,
            "github-npm" => 0.8,
            "rustsec" => 0.85,
            "github-rust" => 0.75,
            _ => 0.5,
        };
    }

    // CWE categories (common weakness enumerations)
    let has_injection = fact_data.vulnerabilities.iter().any(|v| {
        v.cwe_ids.iter().any(|cwe| {
            cwe.contains("CWE-89") || // SQL Injection
            cwe.contains("CWE-79") || // XSS
            cwe.contains("CWE-78")    // OS Command Injection
        })
    });

    let has_memory_issues = fact_data.vulnerabilities.iter().any(|v| {
        v.cwe_ids.iter().any(|cwe| {
            cwe.contains("CWE-787") || // Out-of-bounds Write
            cwe.contains("CWE-119") || // Buffer Overflow
            cwe.contains("CWE-416")    // Use After Free
        })
    });

    let has_crypto_issues = fact_data.vulnerabilities.iter().any(|v| {
        v.cwe_ids.iter().any(|cwe| {
            cwe.contains("CWE-327") || // Weak Crypto
            cwe.contains("CWE-326")    // Inadequate Encryption Strength
        })
    });

    features[17] = if has_injection { 1.0 } else { 0.0 };
    features[18] = if has_memory_issues { 1.0 } else { 0.0 };
    features[19] = if has_crypto_issues { 1.0 } else { 0.0 };

    // License compliance info
    if let Some(ref license) = fact_data.license_info {
        features[20] = if license.is_copyleft { 1.0 } else { 0.0 };
        features[21] = if license.commercial_use { 1.0 } else { 0.0 };
        features[22] = if license.requires_attribution { 1.0 } else { 0.0 };
        features[23] = (license.restrictions.len() as f32).min(5.0) / 5.0;
    }

    // Has patches available
    let patched_count = fact_data
        .vulnerabilities
        .iter()
        .filter(|v| !v.patched_versions.is_empty())
        .count();

    features[24] = if vuln_count > 0 {
        patched_count as f32 / vuln_count as f32
    } else {
        1.0
    };

    // Recency of vulnerabilities (has recent published advisories)
    let has_recent_vulns = fact_data.vulnerabilities.iter().any(|v| {
        v.published_at.is_some()
        // TODO: Parse date and check if within last 6 months
    });
    features[25] = if has_recent_vulns { 1.0 } else { 0.0 };

    features
}

/// Extract business context from metadata (enriched by fact-system)
pub fn extract_business_features(metadata: &CodebaseMetadata) -> Vec<f32> {
    let mut features = vec![0.0; 64];

    // Domain TF-IDF (from fact-system domain classification)
    // Just use simple frequency for now
    for (i, domain) in metadata.domains.iter().take(32).enumerate() {
        features[i] = 1.0 / (i + 1) as f32; // Decreasing weight
    }

    // Business context indicators
    for (i, context) in metadata.business_context.iter().take(32).enumerate() {
        features[32 + i] = 1.0 / (i + 1) as f32;
    }

    features
}

/// PSEUDO: These structs match fact-system detector outputs
/// In real implementation, these come from the actual detectors

pub struct SecurityAnalysis {
    pub security_score: f64,
    pub has_vulnerabilities: bool,
    pub vulnerability_count: usize,
    pub compliance_frameworks: Vec<ComplianceFramework>,
    pub security_patterns: Vec<SecurityPattern>,
    pub uses_encryption: bool,
    pub has_authentication: bool,
    pub has_authorization: bool,
}

pub struct ComplianceFramework {
    pub name: String,
    pub compliance_score: f32,
}

pub struct SecurityPattern {
    pub name: String,
    pub confidence: f32,
}

pub struct PerformanceAnalysis {
    pub performance_score: f64,
    pub bottleneck_count: usize,
    pub optimization_opportunities: Vec<String>,
    pub performance_patterns: Vec<PerformancePattern>,
    pub has_caching: bool,
    pub has_async: bool,
    pub has_parallelism: bool,
}

pub struct PerformancePattern {
    pub name: String,
    pub confidence: f32,
}

pub struct QualityAnalysis {
    pub maintainability_index: f32,
    pub technical_debt_ratio: f32,
    pub test_coverage: f32,
    pub documentation_coverage: f32,
    pub code_smells: Vec<CodeSmell>,
    pub passes_quality_gates: bool,
}

pub struct CodeSmell {
    pub name: String,
    pub severity: f32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_fact_based_features() {
        // Test that we correctly vectorize fact-system outputs
        let detection = FrameworkDetection {
            frameworks: vec![],
            confidence_scores: std::collections::HashMap::new(),
            ecosystem_hints: vec!["React".to_string()],
            metadata: crate::analysis::framework::detector::DetectionMetadata {
                detection_time: chrono::Utc::now(),
                file_count: 1,
                total_patterns_checked: 10,
                detector_version: "1.0.0".to_string(),
            },
        };

        let features = extract_framework_features(&detection);
        assert_eq!(features.len(), 32);
        assert_eq!(features[16], 1.0); // First ecosystem hint
    }
}
