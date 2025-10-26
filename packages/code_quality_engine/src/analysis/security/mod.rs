//! Security Analysis Module
//!
//! Comprehensive security analysis for codebases including vulnerability detection,
//! compliance checking, and security best practices validation.

pub mod detector;
pub mod compliance;
pub mod vulnerabilities;

// Core security analysis (from detector)
pub use detector::{
    SecurityAnalysis, Vulnerability, VulnerabilitySeverity, VulnerabilityCategory,
    VulnerabilityLocation, SecurityRecommendation, RecommendationPriority, SecurityCategory,
    SecurityMetadata, SecurityDetectorTrait, SecurityPatternRegistry, SecurityPattern,
    ComplianceIssue, ComplianceSeverity,
};

// Compliance-specific types (from compliance, excluding duplicates)
pub use compliance::{
    ComplianceAnalysis, ComplianceViolation, ViolationLocation,
    ComplianceRecommendation, ComplianceFramework, ComplianceRequirement,
    ComplianceStatus, ComplianceAnalyzer,
};

// Vulnerability-specific types (from vulnerabilities, excluding duplicates)
pub use vulnerabilities::{
    VulnerabilityAnalysis, VulnerabilityRecommendation,
    VulnerabilityMetadata, VulnerabilityPattern, VulnerabilityAnalyzer,
};