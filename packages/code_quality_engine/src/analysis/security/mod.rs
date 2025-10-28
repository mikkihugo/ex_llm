//! Security Analysis Module
//!
//! Comprehensive security analysis for codebases including vulnerability detection,
//! compliance checking, and security best practices validation.

pub mod compliance;
pub mod detector;
pub mod vulnerabilities;

// Core security analysis (from detector)
pub use detector::{
    ComplianceIssue, ComplianceSeverity, RecommendationPriority, SecurityAnalysis,
    SecurityCategory, SecurityDetectorTrait, SecurityMetadata, SecurityPattern,
    SecurityPatternRegistry, SecurityRecommendation, Vulnerability, VulnerabilityCategory,
    VulnerabilityLocation, VulnerabilitySeverity,
};

// Compliance-specific types (from compliance, excluding duplicates)
pub use compliance::{
    ComplianceAnalysis, ComplianceAnalyzer, ComplianceFramework, ComplianceRecommendation,
    ComplianceRequirement, ComplianceStatus, ComplianceViolation, ViolationLocation,
};

// Vulnerability-specific types (from vulnerabilities, excluding duplicates)
pub use vulnerabilities::{
    VulnerabilityAnalysis, VulnerabilityAnalyzer, VulnerabilityMetadata, VulnerabilityPattern,
    VulnerabilityRecommendation,
};
