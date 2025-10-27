//! NPM Package Collector
//!
//! Downloads and analyzes npm packages from registry.npmjs.org
//! Extracts: public API, functions, classes, interfaces, types, examples

use super::{CollectionStats, DataSourcePriority, PackageCollector};
use crate::extractor::{SourceCodeExtractor, create_extractor};
use crate::storage::{PackageMetadata, CodeSnippet};
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use tokio::fs;

#[cfg(feature = "npm-collector")]
use super::npm_advisory::NpmAdvisoryCollector;

/// NPM package collector for registry.npmjs.org
pub struct NpmCollector {
  /// Cache directory for downloaded packages
  cache_dir: PathBuf,

  /// Whether to keep downloaded packages after analysis
  keep_cache: bool,

  /// HTTP client for registry API
  client: reqwest::Client,

  /// Security advisory collector
  #[cfg(feature = "npm-collector")]
  advisory_collector: NpmAdvisoryCollector,

  /// Code extractor (delegates to source code parser)
  extractor: SourceCodeExtractor,
}

/// NPM registry package metadata
#[derive(Debug, Deserialize, Serialize)]
struct NpmPackageMetadata {
  name: String,
  #[serde(rename = "dist-tags")]
  dist_tags: std::collections::HashMap<String, String>,
  versions: std::collections::HashMap<String, NpmVersionMetadata>,
}

/// NPM version-specific metadata
#[derive(Debug, Deserialize, Serialize)]
struct NpmVersionMetadata {
  name: String,
  version: String,
  description: Option<String>,
  license: Option<String>,  // SPDX license identifier
  dist: NpmDist,
  dependencies: Option<std::collections::HashMap<String, String>>,
  #[serde(rename = "devDependencies")]
  dev_dependencies: Option<std::collections::HashMap<String, String>>,
}

/// NPM distribution metadata
#[derive(Debug, Deserialize, Serialize)]
struct NpmDist {
  tarball: String,
  shasum: String,
}

impl NpmCollector {
  /// Classify SPDX license identifier into license type and properties
  fn classify_license(license_id: &str) -> (String, String, bool, bool, bool) {
    let license_lower = license_id.to_lowercase();

    // Determine license type and properties based on SPDX identifier
    match license_lower.as_str() {
      // Permissive licenses
      "mit" | "bsd-2-clause" | "bsd-3-clause" | "apache-2.0" | "apache" |
      "mpl-2.0" | "isc" | "wtfpl" | "0bsd" | "zlib" => {
        ("permissive".to_string(), license_id.to_string(), true, true, false)
      },
      // Copyleft licenses
      "gpl-3.0" | "gpl-3.0-or-later" | "gpl-3.0-only" |
      "gpl-2.0" | "gpl-2.0-or-later" | "gpl-2.0-only" |
      "agpl-3.0" | "agpl-3.0-or-later" | "agpl-3.0-only" => {
        ("copyleft".to_string(), license_id.to_string(), false, true, true)
      },
      // Weak copyleft
      "lgpl-3.0" | "lgpl-3.0-or-later" | "lgpl-3.0-only" |
      "lgpl-2.1" | "lgpl-2.1-or-later" | "lgpl-2.1-only" => {
        ("weak-copyleft".to_string(), license_id.to_string(), true, true, true)
      },
      // Proprietary
      "proprietary" | "unlicense" => {
        ("proprietary".to_string(), license_id.to_string(), false, false, false)
      },
      // Unknown or other
      _ => {
        // Default: assume permissive if not in exclusion list
        if license_lower.contains("gpl") || license_lower.contains("agpl") {
          ("copyleft".to_string(), license_id.to_string(), false, true, true)
        } else if license_lower.contains("lgpl") {
          ("weak-copyleft".to_string(), license_id.to_string(), true, true, true)
        } else {
          ("unknown".to_string(), license_id.to_string(), true, false, false)
        }
      }
    }
  }

  /// Create new npm collector
  ///
  /// # Arguments
  /// * `cache_dir` - Directory to store downloaded packages
  /// * `keep_cache` - Keep packages after analysis (default: false for space)
  pub fn new(cache_dir: PathBuf, keep_cache: bool) -> Result<Self> {
    let client = reqwest::Client::builder()
      .user_agent("sparc-engine-fact-collector/1.0")
      .build()
      .expect("Failed to create HTTP client");

    Ok(Self {
      cache_dir,
      keep_cache,
      client,
      #[cfg(feature = "npm-collector")]
      advisory_collector: NpmAdvisoryCollector::new(),
      extractor: create_extractor()?,
    })
  }

  /// Create collector with default cache directory
  pub fn default_cache() -> Result<Self> {
    let cache_dir = dirs::cache_dir()
      .context("Failed to get cache directory")?
      .join("sparc-engine")
      .join("npm");

    Self::new(cache_dir, false)
  }

  /// Get package metadata from npm registry
  async fn get_package_metadata(
    &self,
    package: &str,
  ) -> Result<NpmPackageMetadata> {
    let registry_url = format!("https://registry.npmjs.org/{}", package);

    log::debug!("Fetching npm metadata: {}", registry_url);

    let response = self
      .client
      .get(&registry_url)
      .send()
      .await
      .context("Failed to fetch package metadata")?;

    if !response.status().is_success() {
      anyhow::bail!(
        "Package not found: {} (status: {})",
        package,
        response.status()
      );
    }

    response
      .json::<NpmPackageMetadata>()
      .await
      .context("Failed to parse package metadata")
  }

  /// Download package tarball from npm registry
  ///
  /// # Arguments
  /// * `package` - Package name
  /// * `version` - Semantic version
  ///
  /// # Returns
  /// Path to extracted package directory
  async fn download_package(
    &self,
    package: &str,
    version: &str,
  ) -> Result<PathBuf> {
    let package_dir = self.cache_dir.join(format!("{}-{}", package, version));

    // Check if already downloaded
    if package_dir.exists() {
      log::debug!("Using cached package: {}", package_dir.display());
      return Ok(package_dir);
    }

    // Get package metadata to find tarball URL
    let metadata = self.get_package_metadata(package).await?;
    let version_meta = metadata.versions.get(version).context(format!(
      "Version {} not found for package {}",
      version, package
    ))?;

    // Create cache directory
    fs::create_dir_all(&self.cache_dir).await?;

    log::info!("Downloading npm package {} v{}", package, version);

    // Download tarball
    let tarball_url = &version_meta.dist.tarball;
    let response = self
      .client
      .get(tarball_url)
      .send()
      .await
      .context("Failed to download package tarball")?;

    if !response.status().is_success() {
      anyhow::bail!("Failed to download tarball: status {}", response.status());
    }

    let tarball_bytes = response.bytes().await?;

    // Save tarball temporarily
    let tarball_path =
      self.cache_dir.join(format!("{}-{}.tgz", package, version));
    fs::write(&tarball_path, &tarball_bytes).await?;

    // Extract tarball
    self.extract_tarball(&tarball_path, &package_dir).await?;

    // Cleanup tarball
    fs::remove_file(&tarball_path).await?;

    Ok(package_dir)
  }

  /// Extract npm tarball (.tgz)
  async fn extract_tarball(
    &self,
    tarball_path: &Path,
    dest_dir: &Path,
  ) -> Result<()> {
    use flate2::read::GzDecoder;
    use std::fs::File;
    use tar::Archive;

    fs::create_dir_all(dest_dir).await?;

    let tarball = File::open(tarball_path)?;
    let gz = GzDecoder::new(tarball);
    let mut archive = Archive::new(gz);

    // Extract (npm packages have "package/" prefix)
    archive.unpack(dest_dir)?;

    log::debug!("Extracted tarball to: {}", dest_dir.display());

    Ok(())
  }
  /// Cleanup downloaded package
  async fn cleanup_package(&self, package_dir: &Path) -> Result<()> {
    if !self.keep_cache && package_dir.exists() {
      fs::remove_dir_all(package_dir).await?;
      log::debug!("Cleaned up package: {}", package_dir.display());
    }
    Ok(())
  }
}

#[async_trait::async_trait]
impl PackageCollector for NpmCollector {
  fn ecosystem(&self) -> &str {
    "npm"
  }

  async fn collect(&self, package: &str, version: &str) -> Result<PackageMetadata> {
    let start_time = std::time::Instant::now();

    log::info!("Collecting npm package: {} v{}", package, version);

    // Get package metadata to extract license info
    let metadata = self.get_package_metadata(package).await?;
    let version_meta = metadata.versions.get(version).context(format!(
      "Version {} not found for package {}",
      version, package
    ))?;

    // Extract license information
    let license_info = if let Some(license_str) = &version_meta.license {
      let (license_type, license_id, commercial_use, requires_attribution, is_copyleft) =
        Self::classify_license(license_str);

      Some(crate::storage::LicenseInfo {
        license: license_id,
        license_type,
        commercial_use,
        requires_attribution,
        is_copyleft,
      })
    } else {
      None
    };

    // Download package
    let package_dir = self
      .download_package(package, version)
      .await
      .context("Failed to download package")?;

    // Extract snippets using tree-sitter extractor
    let extracted = self
      .extractor
      .extract_from_directory(&package_dir.join("package"))
      .await
      .context("Failed to extract code snippets")?;

    // Cleanup if needed
    self.cleanup_package(&package_dir).await?;

    // Collect security advisories
    #[cfg(feature = "npm-collector")]
    let vulnerabilities = self
      .advisory_collector
      .collect_advisories(package)
      .await
      .unwrap_or_else(|e| {
        log::warn!("Failed to collect security advisories: {}", e);
        vec![]
      });

    #[cfg(not(feature = "npm-collector"))]
    let vulnerabilities = vec![];

    // Calculate security score based on vulnerabilities
    let security_score = if vulnerabilities.is_empty() {
      Some(100.0)
    } else {
      let critical_count = vulnerabilities
        .iter()
        .filter(|v| v.severity == "CRITICAL")
        .count();
      let high_count = vulnerabilities
        .iter()
        .filter(|v| v.severity == "HIGH")
        .count();

      // Simple scoring: start at 100, deduct points for vulnerabilities
      let score = 100.0
        - (critical_count as f32 * 25.0)
        - (high_count as f32 * 10.0)
        - ((vulnerabilities.len() - critical_count - high_count) as f32 * 5.0);

      Some(score.max(0.0))
    };

    let duration = start_time.elapsed();

    log::info!(
      "Collected {} snippets, {} examples, {} vulnerabilities in {:?}",
      extracted.snippets.len(),
      extracted.examples.len(),
      vulnerabilities.len(),
      duration
    );

    Ok(PackageMetadata {
      tool: package.to_string(),
      version: version.to_string(),
      ecosystem: "npm".to_string(),
      documentation: format!("Analyzed from npm package source"),
      snippets: extracted.snippets,
      examples: extracted.examples,
      best_practices: vec![],
      troubleshooting: vec![],
      github_sources: vec![], // No GitHub - using package source
      dependencies: vec![],
      tags: vec!["javascript".to_string(), "npm".to_string()],
      last_updated: SystemTime::now(),
      source: "npm:package".to_string(),
      detected_framework: None,
      prompt_templates: vec![],
      quick_starts: vec![],
      migration_guides: vec![],
      usage_patterns: vec![],
      cli_commands: vec![],
      semantic_embedding: None,
      code_embedding: None,
      graph_embedding: None,
      relationships: vec![],
      usage_stats: Default::default(),
      execution_history: vec![],
      learning_data: Default::default(),
      vulnerabilities,
      security_score,
      license_info,
    })
  }

  async fn exists(&self, package: &str, version: &str) -> Result<bool> {
    let metadata = self.get_package_metadata(package).await?;
    Ok(metadata.versions.contains_key(version))
  }

  async fn latest_version(&self, package: &str) -> Result<String> {
    let metadata = self.get_package_metadata(package).await?;
    metadata
      .dist_tags
      .get("latest")
      .cloned()
      .context("No latest version found")
  }

  async fn available_versions(&self, package: &str) -> Result<Vec<String>> {
    let metadata = self.get_package_metadata(package).await?;
    let mut versions: Vec<String> = metadata.versions.keys().cloned().collect();
    versions.sort();
    Ok(versions)
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use tempfile::TempDir;

  #[tokio::test]
  async fn test_npm_collector_creation() {
    let temp_dir = TempDir::new().unwrap();
    let collector = NpmCollector::new(temp_dir.path().to_path_buf(), false);
    assert_eq!(collector.ecosystem(), "npm");
  }

  #[test]
  fn test_extract_function_name() {
    let collector = NpmCollector::new(PathBuf::from("/tmp"), false);

    assert_eq!(
      collector.extract_function_name("export function helloWorld() {"),
      Some("helloWorld")
    );

    assert_eq!(
      collector.extract_function_name("export async function fetchData() {"),
      Some("fetchData")
    );

    assert_eq!(
      collector.extract_function_name("function privateFunction() {"),
      None
    );
  }

  #[test]
  fn test_extract_class_name() {
    let collector = NpmCollector::new(PathBuf::from("/tmp"), false);

    assert_eq!(
      collector.extract_class_name("export class MyClass {"),
      Some("MyClass")
    );

    assert_eq!(
      collector
        .extract_class_name("export class UserService extends BaseService {"),
      Some("UserService")
    );

    assert_eq!(collector.extract_class_name("class PrivateClass {"), None);
  }

  #[test]
  fn test_extract_const_name() {
    let collector = NpmCollector::new(PathBuf::from("/tmp"), false);

    assert_eq!(
      collector.extract_const_name("export const myConst = 42;"),
      Some("myConst")
    );

    assert_eq!(
      collector.extract_const_name("export let myVar = 'hello';"),
      Some("myVar")
    );
  }

  #[test]
  fn test_extract_type_name() {
    let collector = NpmCollector::new(PathBuf::from("/tmp"), false);

    assert_eq!(
      collector.extract_type_name("export interface User {"),
      Some("User")
    );

    assert_eq!(
      collector
        .extract_type_name("export type Status = 'active' | 'inactive';"),
      Some("Status")
    );
  }
}
