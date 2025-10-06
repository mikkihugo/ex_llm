//! Hex.pm Package Collector
//!
//! Downloads and analyzes Elixir/Erlang packages from hex.pm
//! Extracts: public API, functions, modules, types, examples

use super::{CollectionStats, DataSourcePriority, PackageCollector};
use crate::extractor::{SourceCodeExtractor, create_extractor};
use crate::storage::PackageMetadata;
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use tokio::fs;

/// Hex.pm package collector for hex.pm registry
pub struct HexCollector {
    /// Cache directory for downloaded packages
    cache_dir: PathBuf,

    /// Whether to keep downloaded packages after analysis
    keep_cache: bool,

    /// HTTP client for registry API
    client: reqwest::Client,

    /// Code extractor (delegates to source code parser)
    extractor: SourceCodeExtractor,
}

/// Hex.pm API package metadata
#[derive(Debug, Deserialize, Serialize)]
struct HexPackageMetadata {
    name: String,
    releases: Vec<HexRelease>,
}

/// Hex.pm release metadata
#[derive(Debug, Deserialize, Serialize)]
struct HexRelease {
    version: String,
    has_docs: bool,
    inserted_at: String,
}

/// Hex.pm release detail (from /api/packages/{name}/releases/{version})
#[derive(Debug, Deserialize, Serialize)]
struct HexReleaseDetail {
    version: String,
    has_docs: bool,
    meta: HexReleaseMeta,
    downloads: i64,
}

#[derive(Debug, Deserialize, Serialize)]
struct HexReleaseMeta {
    description: Option<String>,
    licenses: Vec<String>,
    links: std::collections::HashMap<String, String>,
    app: Option<String>,
}

impl HexCollector {
    /// Create new hex collector
    ///
    /// # Arguments
    /// * `cache_dir` - Directory to store downloaded packages
    /// * `keep_cache` - Keep packages after analysis (default: false for space)
    pub fn new(cache_dir: PathBuf, keep_cache: bool) -> Result<Self> {
        let client = reqwest::Client::builder()
            .user_agent("package-registry-indexer/1.0")
            .build()
            .expect("Failed to create HTTP client");

        Ok(Self {
            cache_dir,
            keep_cache,
            client,
            extractor: create_extractor()?,
        })
    }

    /// Create collector with default cache directory
    pub fn default_cache() -> Result<Self> {
        let cache_dir = dirs::cache_dir()
            .context("Failed to get cache directory")?
            .join("package-registry-indexer")
            .join("hex");

        Self::new(cache_dir, false)
    }

    /// Get package metadata from hex.pm API
    async fn get_package_metadata(&self, package: &str) -> Result<HexPackageMetadata> {
        let api_url = format!("https://hex.pm/api/packages/{}", package);

        log::debug!("Fetching hex.pm metadata: {}", api_url);

        let response = self
            .client
            .get(&api_url)
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
            .json::<HexPackageMetadata>()
            .await
            .context("Failed to parse package metadata")
    }

    /// Get release detail from hex.pm API
    async fn get_release_detail(
        &self,
        package: &str,
        version: &str,
    ) -> Result<HexReleaseDetail> {
        let api_url = format!(
            "https://hex.pm/api/packages/{}/releases/{}",
            package, version
        );

        log::debug!("Fetching hex.pm release detail: {}", api_url);

        let response = self
            .client
            .get(&api_url)
            .send()
            .await
            .context("Failed to fetch release detail")?;

        if !response.status().is_success() {
            anyhow::bail!(
                "Release not found: {}@{} (status: {})",
                package,
                version,
                response.status()
            );
        }

        response
            .json::<HexReleaseDetail>()
            .await
            .context("Failed to parse release detail")
    }

    /// Download package tarball from hex.pm
    ///
    /// # Arguments
    /// * `package` - Package name
    /// * `version` - Semantic version
    ///
    /// # Returns
    /// Path to extracted package directory
    async fn download_package(&self, package: &str, version: &str) -> Result<PathBuf> {
        let package_dir = self.cache_dir.join(format!("{}-{}", package, version));

        // Check if already downloaded
        if package_dir.exists() {
            log::debug!("Using cached package: {}", package_dir.display());
            return Ok(package_dir);
        }

        // Download tarball from repo.hex.pm
        let tarball_url = format!("https://repo.hex.pm/tarballs/{}-{}.tar", package, version);

        log::info!(
            "Downloading hex package {} v{} from {}",
            package,
            version,
            tarball_url
        );

        let response = self
            .client
            .get(&tarball_url)
            .send()
            .await
            .context("Failed to download tarball")?;

        if !response.status().is_success() {
            anyhow::bail!(
                "Failed to download tarball: {} (status: {})",
                tarball_url,
                response.status()
            );
        }

        let tarball_bytes = response
            .bytes()
            .await
            .context("Failed to read tarball bytes")?;

        // Create cache directory
        fs::create_dir_all(&self.cache_dir)
            .await
            .context("Failed to create cache directory")?;

        // Extract tarball
        self.extract_tarball(&tarball_bytes, &package_dir).await?;

        log::info!("Extracted package to: {}", package_dir.display());

        Ok(package_dir)
    }

    /// Extract hex.pm tarball (tar format)
    async fn extract_tarball(&self, tarball_bytes: &[u8], dest_dir: &Path) -> Result<()> {
        use flate2::read::GzDecoder;
        use std::io::Cursor;
        use tar::Archive;

        // Create destination directory
        fs::create_dir_all(dest_dir)
            .await
            .context("Failed to create extraction directory")?;

        // Hex.pm tarballs are tar (not gzip) format
        let cursor = Cursor::new(tarball_bytes);
        let mut archive = Archive::new(cursor);

        // Extract to destination (blocking I/O in spawn_blocking)
        let dest_path = dest_dir.to_path_buf();
        tokio::task::spawn_blocking(move || -> Result<()> {
            archive
                .unpack(&dest_path)
                .context("Failed to extract tarball")?;
            Ok(())
        })
        .await
        .context("Failed to spawn extraction task")??;

        Ok(())
    }

    /// Analyze downloaded package
    async fn analyze_package(&self, package_dir: &Path) -> Result<PackageMetadata> {
        // Extract code snippets from package source
        let extracted = self.extractor.extract_from_directory(package_dir).await?;

        // Build PackageMetadata
        let mut fact = PackageMetadata {
            tool: package_dir
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("")
                .to_string(),
            version: String::new(),
            ecosystem: "hex".to_string(),
            documentation: String::new(),
            snippets: extracted.snippets,
            examples: extracted.examples,
            best_practices: Vec::new(),
            troubleshooting: Vec::new(),
            github_sources: Vec::new(),
            dependencies: Vec::new(),
            tags: vec!["elixir".to_string()],
            last_updated: SystemTime::now(),
            source: "hex.pm".to_string(),
            detected_framework: None,
            prompt_templates: Vec::new(),
            quick_starts: Vec::new(),
            migration_guides: Vec::new(),
            usage_patterns: Vec::new(),
            cli_commands: Vec::new(),
            semantic_embedding: None,
            code_embedding: None,
            graph_embedding: None,
            relationships: Vec::new(),
            usage_stats: Default::default(),
            execution_history: Vec::new(),
            learning_data: Default::default(),
            vulnerabilities: Vec::new(),
            security_score: None,
            license_info: None,
        };

        // Add exports from extracted code
        for export in extracted.exports {
            fact.dependencies.push(export);
        }

        Ok(fact)
    }
}

#[async_trait::async_trait]
impl PackageCollector for HexCollector {
    fn ecosystem(&self) -> &str {
        "hex"
    }

    async fn collect(&self, package: &str, version: &str) -> Result<PackageMetadata> {
        log::info!("Collecting hex package: {}@{}", package, version);

        // Get package metadata
        let release_detail = self.get_release_detail(package, version).await?;

        // Download and extract package
        let package_dir = self.download_package(package, version).await?;

        // Analyze package
        let mut fact = self.analyze_package(&package_dir).await?;

        // Fill in metadata
        fact.tool = package.to_string();
        fact.version = version.to_string();
        fact.documentation = release_detail
            .meta
            .description
            .unwrap_or_else(|| format!("Elixir package {}", package));

        // Add GitHub link if available
        if let Some(github_url) = release_detail.meta.links.get("GitHub") {
            fact.tags.push(format!("github:{}", github_url));
        }

        // Cleanup if not keeping cache
        if !self.keep_cache {
            let _ = fs::remove_dir_all(&package_dir).await;
        }

        log::info!(
            "Collected {} snippets for {}@{}",
            fact.snippets.len(),
            package,
            version
        );

        Ok(fact)
    }

    async fn exists(&self, package: &str, version: &str) -> Result<bool> {
        match self.get_release_detail(package, version).await {
            Ok(_) => Ok(true),
            Err(_) => Ok(false),
        }
    }

    async fn latest_version(&self, package: &str) -> Result<String> {
        let metadata = self.get_package_metadata(package).await?;

        metadata
            .releases
            .first()
            .map(|r| r.version.clone())
            .context("No releases found")
    }

    async fn available_versions(&self, package: &str) -> Result<Vec<String>> {
        let metadata = self.get_package_metadata(package).await?;
        Ok(metadata.releases.iter().map(|r| r.version.clone()).collect())
    }
}

/// Statistics about data collection
#[derive(Debug, Clone)]
pub struct CollectionStats {
    pub total_files: usize,
    pub analyzed_files: usize,
    pub snippets_extracted: usize,
    pub examples_found: usize,
}

/// Priority of data sources
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum DataSourcePriority {
    GitHub = 1,
    PackageSource = 2,
    RegistryMetadata = 3,
    LlmGenerated = 4,
}
