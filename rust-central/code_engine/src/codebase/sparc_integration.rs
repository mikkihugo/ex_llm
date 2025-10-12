//! SPARC Integration Layer - Dual-Source Knowledge Query
//!
//! SPARC queries TWO separate systems:
//! 1. analysis-suite: Capabilities (what OUR code can do)
//! 2. fact-system: External facts (GitHub, npm, CVEs)
//!
//! This provides complete context for AI-driven development.

use super::capability::{CodeCapability, CapabilitySearchResult};
use super::capability_storage::CapabilityStorage;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Unified knowledge interface for SPARC
pub struct SparcKnowledge {
    /// Our code capabilities (from analysis-suite)
    capabilities: CapabilityStorage,

    /// External facts (from fact-system) - currently a stub
    facts: FactSystemBridge,
}

impl SparcKnowledge {
    /// Create new SPARC knowledge interface
    pub fn new(project_id: impl Into<String>) -> Result<Self> {
        Ok(Self {
            capabilities: CapabilityStorage::new(project_id)?,
            facts: FactSystemBridge::new()?,
        })
    }

    /// Query: "How do I do X?"
    /// Returns capabilities from OUR code + examples from GitHub
    pub async fn how_to(&self, task: &str) -> Result<HowToResult> {
        // Query our capabilities
        let our_capabilities = self.capabilities.search(task).await?;

        // Query external examples
        let github_examples = self.facts.search_github_examples(task).await?;
        let npm_packages = self.facts.search_npm_packages(task).await?;

        Ok(HowToResult {
            task: task.to_string(),
            our_capabilities,
            github_examples,
            npm_packages,
            security_considerations: self.facts.search_vulnerabilities(task).await?,
        })
    }

    /// Query: "Show me authentication code"
    /// Returns authentication capabilities + security advisories
    pub async fn understand(&self, concept: &str) -> Result<UnderstandingResult> {
        // Find our capabilities
        let capabilities = self.capabilities.search(concept).await?;

        // Get related facts
        let related_examples = self.facts.search_github_examples(concept).await?;
        let security_advisories = self.facts.search_vulnerabilities(concept).await?;

        // Extract usage patterns
        let usage_patterns: Vec<String> = capabilities
            .iter()
            .flat_map(|c| c.capability.usage_examples.clone())
            .collect();

        Ok(UnderstandingResult {
            concept: concept.to_string(),
            our_implementation: capabilities,
            usage_patterns,
            external_examples: related_examples,
            security_advisories,
        })
    }

    /// Query: "What can this codebase do?"
    /// Returns all capabilities organized by category
    pub async fn capabilities_overview(&self) -> Result<CapabilitiesOverview> {
        let stats = self.capabilities.stats().await?;
        let all_caps = self.capabilities.get_all().await?;

        let by_category: HashMap<String, Vec<CodeCapability>> = all_caps
            .into_iter()
            .fold(HashMap::new(), |mut acc, cap| {
                let category = format!("{:?}", cap.kind);
                acc.entry(category).or_default().push(cap);
                acc
            });

        Ok(CapabilitiesOverview {
            total_capabilities: stats.total_capabilities,
            by_category,
            top_capabilities: self.get_top_capabilities(10).await?,
        })
    }

    /// Get most-used or highest-rated capabilities
    async fn get_top_capabilities(&self, limit: usize) -> Result<Vec<CodeCapability>> {
        let all_caps = self.capabilities.get_all().await?;

        // Simple implementation: return first N capabilities
        // Future: Implement usage tracking and rating based on:
        // - Frequency of use
        // - Test coverage
        // - Documentation quality
        Ok(all_caps.into_iter().take(limit).collect())
    }

    /// Find where to add new functionality
    pub async fn suggest_extension_point(&self, new_feature: &str) -> Result<ExtensionSuggestion> {
        // Find similar capabilities
        let similar = self.capabilities.search(new_feature).await?;

        if similar.is_empty() {
            return Ok(ExtensionSuggestion {
                suggestion: "No similar capabilities found. Consider creating new module.".to_string(),
                similar_capabilities: Vec::new(),
                suggested_location: None,
                pattern_to_follow: None,
            });
        }

        // Extract common patterns
        let most_similar = &similar[0].capability;
        let suggested_location = format!(
            "Add to crate: {}, module: {}",
            most_similar.location.crate_name,
            most_similar.location.module_path
        );

        Ok(ExtensionSuggestion {
            suggestion: format!(
                "Add near {} which has similar functionality",
                most_similar.name
            ),
            similar_capabilities: similar.into_iter().take(3).collect(),
            suggested_location: Some(suggested_location),
            pattern_to_follow: Some(most_similar.signature.clone()),
        })
    }
}

/// Result of "how to" query
#[derive(Debug, Serialize, Deserialize)]
pub struct HowToResult {
    pub task: String,
    /// Our code that can do this
    pub our_capabilities: Vec<CapabilitySearchResult>,
    /// Examples from GitHub
    pub github_examples: Vec<GitHubExample>,
    /// npm packages that can help
    pub npm_packages: Vec<NpmPackage>,
    /// Security issues to watch out for
    pub security_considerations: Vec<SecurityAdvisory>,
}

/// Result of "understand" query
#[derive(Debug, Serialize, Deserialize)]
pub struct UnderstandingResult {
    pub concept: String,
    /// How WE implement this
    pub our_implementation: Vec<CapabilitySearchResult>,
    /// How to use it
    pub usage_patterns: Vec<String>,
    /// Examples from others
    pub external_examples: Vec<GitHubExample>,
    /// Security considerations
    pub security_advisories: Vec<SecurityAdvisory>,
}

/// Overview of all capabilities
#[derive(Debug, Serialize, Deserialize)]
pub struct CapabilitiesOverview {
    pub total_capabilities: usize,
    pub by_category: HashMap<String, Vec<CodeCapability>>,
    pub top_capabilities: Vec<CodeCapability>,
}

/// Suggestion for where to add new code
#[derive(Debug, Serialize, Deserialize)]
pub struct ExtensionSuggestion {
    pub suggestion: String,
    pub similar_capabilities: Vec<CapabilitySearchResult>,
    pub suggested_location: Option<String>,
    pub pattern_to_follow: Option<String>,
}

/// Bridge to fact-system
///
/// This is a stub implementation that returns empty results.
/// To enable fact-system integration:
/// 1. Add `fact-system` crate dependency
/// 2. Replace this stub with actual fact-system queries
/// 3. Use fact-system's FactDatabase to query external facts
struct FactSystemBridge;

impl FactSystemBridge {
    fn new() -> Result<Self> {
        Ok(Self)
    }

    async fn search_github_examples(&self, _query: &str) -> Result<Vec<GitHubExample>> {
        // Stub: Returns empty results
        // Real implementation would query fact-system's GitHub repository facts
        Ok(Vec::new())
    }

    async fn search_npm_packages(&self, _query: &str) -> Result<Vec<NpmPackage>> {
        // Stub: Returns empty results
        // Real implementation would query fact-system's npm package facts
        Ok(Vec::new())
    }

    async fn search_vulnerabilities(&self, _query: &str) -> Result<Vec<SecurityAdvisory>> {
        // Stub: Returns empty results
        // Real implementation would query fact-system's security advisory facts
        Ok(Vec::new())
    }
}

/// GitHub example from fact-system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitHubExample {
    pub repo: String,
    pub file_path: String,
    pub snippet: String,
    pub url: String,
    pub stars: u32,
}

/// npm package from fact-system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NpmPackage {
    pub name: String,
    pub version: String,
    pub description: String,
    pub weekly_downloads: u64,
}

/// Security advisory from fact-system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityAdvisory {
    pub id: String,
    pub severity: String,
    pub description: String,
    pub affected_package: String,
}

/// Example usage of SparcKnowledge
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_sparc_knowledge_how_to() {
        // This test demonstrates the intended usage
        // Actual implementation requires both analysis-suite and fact-system

        // Create SPARC knowledge interface
        let knowledge = SparcKnowledge::new("test-project").unwrap();

        // Ask: "How do I parse TypeScript?"
        let result = knowledge.how_to("parse TypeScript").await.unwrap();

        // Result contains:
        // - our_capabilities: TypescriptParser from our codebase
        // - github_examples: Examples from GitHub
        // - npm_packages: @typescript-eslint/parser, etc.
        // - security_considerations: Known CVEs

        assert_eq!(result.task, "parse TypeScript");
    }

    #[tokio::test]
    async fn test_sparc_knowledge_understand() {
        let knowledge = SparcKnowledge::new("test-project").unwrap();

        // Ask: "Show me authentication code"
        let result = knowledge.understand("authentication").await.unwrap();

        // Result contains:
        // - our_implementation: Our auth capabilities
        // - usage_patterns: How to use them
        // - external_examples: Auth examples from GitHub
        // - security_advisories: Auth-related CVEs

        assert_eq!(result.concept, "authentication");
    }
}
