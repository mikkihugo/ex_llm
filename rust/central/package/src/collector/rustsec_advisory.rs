//! RustSec Advisory Collector
//!
//! Collects vulnerability data from RustSec Advisory Database
//! Source: https://github.com/rustsec/advisory-db

use crate::storage::SecurityVulnerability;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

/// RustSec Advisory Collector
pub struct RustSecAdvisoryCollector {
  /// HTTP client for GitHub API
  client: reqwest::Client,

  /// Optional GitHub token for higher rate limits
  github_token: Option<String>,
}

/// RustSec Advisory TOML format
///
/// Advisory structure from RustSec database
/// See: https://github.com/rustsec/advisory-db
#[derive(Debug, Deserialize, Serialize)]
struct RustSecAdvisory {
  advisory: AdvisoryMetadata,

  #[serde(default)]
  versions: Option<VersionInfo>,

  #[serde(default)]
  affected: Option<AffectedInfo>,
}

#[derive(Debug, Deserialize, Serialize)]
struct AdvisoryMetadata {
  id: String,

  package: String,

  #[serde(default)]
  title: Option<String>,

  #[serde(default)]
  description: Option<String>,

  date: String,

  #[serde(default)]
  url: Option<String>,

  #[serde(default)]
  categories: Vec<String>,

  #[serde(default)]
  keywords: Vec<String>,

  #[serde(default)]
  cvss: Option<String>,

  #[serde(default)]
  aliases: Vec<String>,

  #[serde(default)]
  related: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize)]
struct VersionInfo {
  #[serde(default)]
  patched: Vec<String>,

  #[serde(default)]
  unaffected: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize)]
struct AffectedInfo {
  #[serde(default)]
  functions: Vec<String>,

  #[serde(default)]
  arch: Vec<String>,

  #[serde(default)]
  os: Vec<String>,
}

/// GitHub API response for file content
#[derive(Debug, Deserialize, Serialize)]
struct GitHubFileResponse {
  content: String,
  encoding: String,
}

impl RustSecAdvisoryCollector {
  /// Create new RustSec advisory collector
  ///
  /// # Arguments
  /// * `github_token` - Optional GitHub token for higher rate limits
  pub fn new(github_token: Option<String>) -> Self {
    let client = reqwest::Client::builder()
      .user_agent("sparc-engine-fact-collector/1.0")
      .build()
      .expect("Failed to create HTTP client");

    Self {
      client,
      github_token,
    }
  }

  /// Create collector from environment variable
  pub fn from_env() -> Self {
    let github_token = std::env::var("GITHUB_TOKEN").ok();
    Self::new(github_token)
  }

  /// Collect security advisories for a Rust crate
  ///
  /// # Arguments
  /// * `crate_name` - Crate name (e.g., "tokio", "serde")
  ///
  /// # Returns
  /// List of security vulnerabilities from RustSec Advisory Database
  pub async fn collect_advisories(
    &self,
    crate_name: &str,
  ) -> Result<Vec<SecurityVulnerability>> {
    log::info!("Collecting RustSec advisories for: {}", crate_name);

    // Query GitHub for advisory files
    let advisories = self
      .query_rustsec_database(crate_name)
      .await
      .context("Failed to query RustSec database")?;

    log::info!(
      "Found {} RustSec advisories for {}",
      advisories.len(),
      crate_name
    );

    Ok(advisories)
  }

  /// Query RustSec advisory database via GitHub API
  ///
  /// RustSec advisories are stored in GitHub: rustsec/advisory-db
  /// Structure: crates/{crate_name}/RUSTSEC-*.toml
  async fn query_rustsec_database(
    &self,
    crate_name: &str,
  ) -> Result<Vec<SecurityVulnerability>> {
    // GitHub API to list files in crate directory
    let api_url = format!(
      "https://api.github.com/repos/rustsec/advisory-db/contents/crates/{}",
      crate_name
    );

    let mut request = self
      .client
      .get(&api_url)
      .header("Accept", "application/vnd.github.v3+json");

    if let Some(ref token) = self.github_token {
      request = request.bearer_auth(token);
    }

    let response = request.send().await.context("Failed to fetch RustSec directory")?;

    if !response.status().is_success() {
      // If 404, crate has no advisories
      if response.status().as_u16() == 404 {
        log::debug!("No RustSec advisories found for {}", crate_name);
        return Ok(vec![]);
      }

      let status = response.status();
      let body = response.text().await.unwrap_or_default();
      anyhow::bail!(
        "GitHub API error for RustSec: {} - {}",
        status,
        body
      );
    }

    // Parse directory listing
    let files: Vec<GitHubFileEntry> = response
      .json()
      .await
      .context("Failed to parse GitHub API response")?;

    // Download and parse each advisory file
    let mut vulnerabilities = Vec::new();

    for file in files {
      if file.name.starts_with("RUSTSEC-") && file.name.ends_with(".toml") {
        log::debug!("Fetching advisory: {}", file.name);

        match self.fetch_and_parse_advisory(&file.download_url).await {
          Ok(vuln) => vulnerabilities.push(vuln),
          Err(e) => {
            log::warn!("Failed to parse advisory {}: {}", file.name, e);
          }
        }
      }
    }

    Ok(vulnerabilities)
  }

  /// Fetch and parse a single RustSec advisory TOML file
  async fn fetch_and_parse_advisory(
    &self,
    download_url: &str,
  ) -> Result<SecurityVulnerability> {
    let mut request = self.client.get(download_url);

    if let Some(ref token) = self.github_token {
      request = request.bearer_auth(token);
    }

    let response = request
      .send()
      .await
      .context("Failed to download advisory")?;

    if !response.status().is_success() {
      anyhow::bail!("Failed to download advisory: {}", response.status());
    }

    let toml_content = response
      .text()
      .await
      .context("Failed to read advisory content")?;

    // Parse TOML
    let advisory: RustSecAdvisory = toml::from_str(&toml_content)
      .context("Failed to parse RustSec advisory TOML")?;

    // Convert to SecurityVulnerability
    Ok(self.convert_rustsec_advisory(advisory))
  }

  /// Convert RustSec advisory to SecurityVulnerability
  fn convert_rustsec_advisory(
    &self,
    advisory: RustSecAdvisory,
  ) -> SecurityVulnerability {
    let metadata = advisory.advisory;

    // Extract CVSS score if available
    let cvss_score = metadata
      .cvss
      .as_ref()
      .and_then(|cvss_str| self.parse_cvss_score(cvss_str));

    // Determine severity based on categories
    let severity = if metadata.categories.contains(&"denial-of-service".to_string()) {
      "MODERATE"
    } else if metadata.categories.contains(&"memory-corruption".to_string()) {
      "HIGH"
    } else if metadata.categories.contains(&"code-execution".to_string()) {
      "CRITICAL"
    } else {
      "MODERATE"
    };

    // Extract affected and patched versions
    let (affected_versions, patched_versions) = if let Some(versions) = advisory.versions {
      (
        vec!["*".to_string()], // RustSec doesn't specify exact affected ranges in simple format
        versions.patched,
      )
    } else {
      (vec![], vec![])
    };

    // Build references
    let mut references = Vec::new();
    if let Some(url) = metadata.url {
      references.push(url);
    }
    for alias in &metadata.aliases {
      if alias.starts_with("CVE-") {
        references.push(format!("https://nvd.nist.gov/vuln/detail/{}", alias));
      } else if alias.starts_with("GHSA-") {
        references.push(format!(
          "https://github.com/advisories/{}",
          alias
        ));
      }
    }

    // Build description
    let description = format!(
      "{}\n\n{}",
      metadata.title.as_deref().unwrap_or("RustSec Advisory"),
      metadata.description.as_deref().unwrap_or("")
    );

    // Get primary ID (prefer CVE, fallback to RUSTSEC)
    let id = metadata
      .aliases
      .iter()
      .find(|alias| alias.starts_with("CVE-"))
      .cloned()
      .unwrap_or_else(|| metadata.id.clone());

    SecurityVulnerability {
      id,
      vuln_type: "rustsec".to_string(),
      severity: severity.to_string(),
      cvss_score,
      description,
      affected_versions,
      patched_versions,
      references,
      published_at: Some(metadata.date),
      cwe_ids: vec![], // RustSec doesn't provide CWE IDs directly
    }
  }

  /// Parse CVSS score from string (e.g., "CVSS:3.1/AV:N/AC:L/...")
  fn parse_cvss_score(&self, cvss_str: &str) -> Option<f32> {
    // Simple extraction - look for score in CVSS vector
    // In production, use a proper CVSS parser
    if cvss_str.contains("CVSS:") {
      // For now, return None - proper CVSS parsing needs dedicated library
      None
    } else {
      // Try to parse as direct number
      cvss_str.parse::<f32>().ok()
    }
  }
}

/// GitHub API directory entry
#[derive(Debug, Deserialize, Serialize)]
struct GitHubFileEntry {
  name: String,
  download_url: String,
}

impl Default for RustSecAdvisoryCollector {
  fn default() -> Self {
    Self::from_env()
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  #[ignore] // Requires GitHub API access
  async fn test_collect_rustsec_advisories() {
    let collector = RustSecAdvisoryCollector::from_env();

    // Test with a crate known to have advisories
    let advisories = collector
      .collect_advisories("openssl")
      .await
      .expect("Failed to collect advisories");

    println!("Found {} advisories for openssl", advisories.len());

    if !advisories.is_empty() {
      // Check structure
      for vuln in &advisories {
        assert!(!vuln.id.is_empty());
        assert!(!vuln.severity.is_empty());
        println!("Advisory: {} - {}", vuln.id, vuln.severity);
      }
    }
  }

  #[tokio::test]
  #[ignore] // Requires GitHub API access
  async fn test_collect_advisories_no_vulnerabilities() {
    let collector = RustSecAdvisoryCollector::from_env();

    // Test with a crate that likely has no advisories
    let advisories = collector
      .collect_advisories("nonexistent-crate-xyz-12345")
      .await
      .expect("Failed to collect advisories");

    // Should return empty list, not error
    assert_eq!(advisories.len(), 0);
  }

  #[test]
  fn test_parse_cvss_score() {
    let collector = RustSecAdvisoryCollector::new(None);

    // Test direct number
    assert_eq!(collector.parse_cvss_score("7.5"), Some(7.5));
    assert_eq!(collector.parse_cvss_score("9.8"), Some(9.8));

    // Test CVSS vector (not implemented yet)
    assert_eq!(
      collector.parse_cvss_score("CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H"),
      None
    );
  }
}
