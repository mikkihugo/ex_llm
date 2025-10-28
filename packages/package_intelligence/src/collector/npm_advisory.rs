//! NPM Security Advisory Collector
//!
//! Collects vulnerability data from npm security advisories and GitHub Security Database
//! Populates PackageMetadata with CVE, GHSA, and vulnerability information

use crate::storage::SecurityVulnerability;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

/// NPM Security Advisory Collector
pub struct NpmAdvisoryCollector {
  /// HTTP client for advisory APIs
  client: reqwest::Client,
}

/// GitHub Advisory Response for npm ecosystem
#[derive(Debug, Deserialize, Serialize)]
struct GitHubAdvisoryResponse {
  data: GitHubAdvisoryData,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubAdvisoryData {
  #[serde(rename = "securityVulnerabilities")]
  security_vulnerabilities: GitHubSecurityVulnerabilities,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubSecurityVulnerabilities {
  nodes: Vec<GitHubVulnerability>,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubVulnerability {
  #[serde(rename = "vulnerableVersionRange")]
  vulnerable_version_range: String,

  #[serde(rename = "firstPatchedVersion")]
  first_patched_version: Option<GitHubFirstPatchedVersion>,

  severity: String,

  advisory: GitHubAdvisory,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubFirstPatchedVersion {
  identifier: String,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubAdvisory {
  #[serde(rename = "ghsaId")]
  ghsa_id: String,

  summary: String,
  description: String,
  severity: String,

  #[serde(rename = "publishedAt")]
  published_at: String,

  #[serde(rename = "cvss")]
  cvss: Option<GitHubCvss>,

  #[serde(rename = "cwes")]
  cwes: GitHubCwes,

  references: Vec<GitHubReference>,

  identifiers: Vec<GitHubIdentifier>,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubCvss {
  score: f32,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubCwes {
  nodes: Vec<GitHubCwe>,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubCwe {
  #[serde(rename = "cweId")]
  cwe_id: String,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubReference {
  url: String,
}

#[derive(Debug, Deserialize, Serialize)]
struct GitHubIdentifier {
  #[serde(rename = "type")]
  identifier_type: String,
  value: String,
}

impl NpmAdvisoryCollector {
  /// Create new npm advisory collector
  pub fn new() -> Self {
    let client = reqwest::Client::builder()
      .user_agent("sparc-engine-fact-collector/1.0")
      .build()
      .expect("Failed to create HTTP client");

    Self { client }
  }

  /// Collect security advisories for an npm package
  ///
  /// # Arguments
  /// * `package` - Package name (e.g., "lodash", "express")
  ///
  /// # Returns
  /// List of security vulnerabilities from GitHub Security Database
  pub async fn collect_advisories(
    &self,
    package: &str,
  ) -> Result<Vec<SecurityVulnerability>> {
    log::info!("Collecting npm security advisories for: {}", package);

    // Query GitHub Security Database via GraphQL
    let vulnerabilities = self
      .query_github_advisories(package)
      .await
      .context("Failed to query GitHub advisories")?;

    log::info!(
      "Found {} vulnerabilities for {}",
      vulnerabilities.len(),
      package
    );

    Ok(vulnerabilities)
  }

  /// Query GitHub Security Advisories Database via GraphQL
  ///
  /// API: https://docs.github.com/en/graphql/reference/objects#securityadvisory
  async fn query_github_advisories(
    &self,
    package: &str,
  ) -> Result<Vec<SecurityVulnerability>> {
    // GitHub GraphQL API endpoint
    let github_graphql_url = "https://api.github.com/graphql";

    // GraphQL query for npm package vulnerabilities
    let query = format!(
      r#"
      {{
        securityVulnerabilities(
          first: 100,
          ecosystem: NPM,
          package: "{}"
        ) {{
          nodes {{
            vulnerableVersionRange
            firstPatchedVersion {{
              identifier
            }}
            severity
            advisory {{
              ghsaId
              summary
              description
              severity
              publishedAt
              cvss {{
                score
              }}
              cwes(first: 10) {{
                nodes {{
                  cweId
                }}
              }}
              references {{
                url
              }}
              identifiers {{
                type
                value
              }}
            }}
          }}
        }}
      }}
      "#,
      package
    );

    let graphql_body = serde_json::json!({
        "query": query
    });

    // Attempt to get GitHub token from environment (optional)
    let github_token = std::env::var("GITHUB_TOKEN").ok();

    let mut request = self
      .client
      .post(github_graphql_url)
      .header("Content-Type", "application/json")
      .json(&graphql_body);

    if let Some(token) = github_token {
      request = request.bearer_auth(token);
    }

    let response = request
      .send()
      .await
      .context("Failed to send GitHub GraphQL request")?;

    if !response.status().is_success() {
      let status = response.status();
      let body = response.text().await.unwrap_or_default();

      // If no token provided, log warning but continue
      if status.as_u16() == 401 && std::env::var("GITHUB_TOKEN").is_err() {
        log::warn!(
          "GitHub API returned 401 Unauthorized. Set GITHUB_TOKEN environment variable for higher rate limits."
        );
        return Ok(vec![]);
      }

      anyhow::bail!("GitHub GraphQL API error: {} - {}", status, body);
    }

    let advisory_response = response
      .json::<GitHubAdvisoryResponse>()
      .await
      .context("Failed to parse GitHub advisory response")?;

    // Convert GitHub vulnerabilities to SecurityVulnerability
    let vulnerabilities = advisory_response
      .data
      .security_vulnerabilities
      .nodes
      .into_iter()
      .map(|vuln| self.convert_github_vulnerability(vuln))
      .collect();

    Ok(vulnerabilities)
  }

  /// Convert GitHub vulnerability to SecurityVulnerability
  fn convert_github_vulnerability(
    &self,
    vuln: GitHubVulnerability,
  ) -> SecurityVulnerability {
    let advisory = vuln.advisory;

    // Extract CVE ID from identifiers
    let cve_id = advisory
      .identifiers
      .iter()
      .find(|id| id.identifier_type == "CVE")
      .map(|id| id.value.clone());

    // Use CVE if available, otherwise GHSA
    let id = cve_id.unwrap_or_else(|| advisory.ghsa_id.clone());

    // Extract CWE IDs
    let cwe_ids: Vec<String> = advisory
      .cwes
      .nodes
      .into_iter()
      .map(|cwe| cwe.cwe_id)
      .collect();

    // Extract reference URLs
    let references: Vec<String> =
      advisory.references.into_iter().map(|r| r.url).collect();

    // Parse vulnerable and patched versions
    let affected_versions = vec![vuln.vulnerable_version_range.clone()];
    let patched_versions = vuln
      .first_patched_version
      .map(|v| vec![v.identifier])
      .unwrap_or_default();

    // Get CVSS score
    let cvss_score = advisory.cvss.map(|cvss| cvss.score);

    SecurityVulnerability {
      id,
      vuln_type: "npm-advisory".to_string(),
      severity: advisory.severity,
      cvss_score,
      description: format!("{}\n\n{}", advisory.summary, advisory.description),
      affected_versions,
      patched_versions,
      references,
      published_at: Some(advisory.published_at),
      cwe_ids,
    }
  }
}

impl Default for NpmAdvisoryCollector {
  fn default() -> Self {
    Self::new()
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  #[ignore] // Requires GitHub API access
  async fn test_collect_npm_advisories() {
    let collector = NpmAdvisoryCollector::new();

    // Test with lodash (known to have historical vulnerabilities)
    let advisories = collector
      .collect_advisories("lodash")
      .await
      .expect("Failed to collect advisories");

    // Should find some vulnerabilities
    assert!(
      !advisories.is_empty(),
      "Expected lodash to have some security advisories"
    );

    // Check structure
    for vuln in &advisories {
      assert!(!vuln.id.is_empty());
      assert!(!vuln.severity.is_empty());
      assert!(!vuln.description.is_empty());
    }
  }

  #[tokio::test]
  #[ignore] // Requires GitHub API access
  async fn test_collect_advisories_no_vulnerabilities() {
    let collector = NpmAdvisoryCollector::new();

    // Test with a package that likely has no vulnerabilities
    let advisories = collector
      .collect_advisories("nonexistent-package-xyz-12345")
      .await
      .expect("Failed to collect advisories");

    // Should return empty list, not error
    assert_eq!(advisories.len(), 0);
  }
}
