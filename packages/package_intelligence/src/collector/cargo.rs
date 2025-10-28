//! Cargo/crates.io Package Collector
//!
//! Downloads and analyzes Rust crates from crates.io
//! Extracts: public API, functions, types, traits, examples

use super::{CollectionStats, DataSourcePriority, PackageCollector};
use crate::storage::{
  CodeIndex, CodeSnippet, Export, IndexedFile, NamingConventions,
  PackageMetadata,
};
use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use tokio::fs;
use toml::Value;

#[cfg(feature = "cargo-collector")]
use super::rustsec_advisory::RustSecAdvisoryCollector;

/// Cargo package collector for crates.io
pub struct CargoCollector {
  /// Cache directory for downloaded crates
  cache_dir: PathBuf,

  /// Whether to keep downloaded packages after analysis
  keep_cache: bool,

  /// Security advisory collector
  #[cfg(feature = "cargo-collector")]
  advisory_collector: RustSecAdvisoryCollector,
}

impl CargoCollector {
  /// Classify SPDX license identifier into license type and properties
  fn classify_license(license_id: &str) -> (String, String, bool, bool, bool) {
    let license_lower = license_id.to_lowercase();

    // Determine license type and properties based on SPDX identifier
    match license_lower.as_str() {
      // Permissive licenses
      "mit" | "bsd-2-clause" | "bsd-3-clause" | "apache-2.0" | "apache"
      | "mpl-2.0" | "isc" | "wtfpl" | "0bsd" | "zlib" | "unlicense" => (
        "permissive".to_string(),
        license_id.to_string(),
        true,
        true,
        false,
      ),
      // Copyleft licenses
      "gpl-3.0" | "gpl-3.0-or-later" | "gpl-3.0-only" | "gpl-2.0"
      | "gpl-2.0-or-later" | "gpl-2.0-only" | "agpl-3.0"
      | "agpl-3.0-or-later" | "agpl-3.0-only" => (
        "copyleft".to_string(),
        license_id.to_string(),
        false,
        true,
        true,
      ),
      // Weak copyleft
      "lgpl-3.0" | "lgpl-3.0-or-later" | "lgpl-3.0-only" | "lgpl-2.1"
      | "lgpl-2.1-or-later" | "lgpl-2.1-only" => (
        "weak-copyleft".to_string(),
        license_id.to_string(),
        true,
        true,
        true,
      ),
      // Proprietary
      "proprietary" => (
        "proprietary".to_string(),
        license_id.to_string(),
        false,
        false,
        false,
      ),
      // Unknown or other
      _ => {
        // Default: assume permissive if not in exclusion list
        if license_lower.contains("gpl") || license_lower.contains("agpl") {
          (
            "copyleft".to_string(),
            license_id.to_string(),
            false,
            true,
            true,
          )
        } else if license_lower.contains("lgpl") {
          (
            "weak-copyleft".to_string(),
            license_id.to_string(),
            true,
            true,
            true,
          )
        } else {
          (
            "unknown".to_string(),
            license_id.to_string(),
            true,
            false,
            false,
          )
        }
      }
    }
  }

  /// Create new cargo collector
  ///
  /// # Arguments
  /// * `cache_dir` - Directory to store downloaded crates
  /// * `keep_cache` - Keep crates after analysis (default: false for space)
  pub fn new(cache_dir: PathBuf, keep_cache: bool) -> Self {
    Self {
      cache_dir,
      keep_cache,
      #[cfg(feature = "cargo-collector")]
      advisory_collector: RustSecAdvisoryCollector::from_env(),
    }
  }

  /// Create collector with default cache directory
  pub fn default_cache() -> Result<Self> {
    let cache_dir = dirs::cache_dir()
      .context("Failed to get cache directory")?
      .join("sparc-engine")
      .join("crates");

    Ok(Self::new(cache_dir, false))
  }

  /// Download crate from crates.io
  ///
  /// # Arguments
  /// * `crate_name` - Name of the crate
  /// * `version` - Semantic version
  ///
  /// # Returns
  /// Path to extracted crate directory
  async fn download_crate(
    &self,
    crate_name: &str,
    version: &str,
  ) -> Result<PathBuf> {
    let crate_dir = self.cache_dir.join(format!("{}-{}", crate_name, version));

    // Check if already downloaded
    if crate_dir.exists() {
      log::debug!("Using cached crate: {}", crate_dir.display());
      return Ok(crate_dir);
    }

    // Create cache directory
    fs::create_dir_all(&self.cache_dir).await?;

    // Download URL: https://crates.io/api/v1/crates/{crate}/{version}/download
    let download_url = format!(
      "https://crates.io/api/v1/crates/{}/{}/download",
      crate_name, version
    );

    log::info!(
      "Downloading crate {} v{} from crates.io",
      crate_name,
      version
    );

    // Download crate (this would use reqwest in real implementation)
    // For now, return error indicating network dependency
    anyhow::bail!(
      "Crate download not yet implemented - would download from: {}",
      download_url
    );

    // TODO: Implement actual download
    // 1. Download .crate file (gzipped tar)
    // 2. Extract to cache_dir
    // 3. Return extracted path

    // Ok(crate_dir)
  }

  /// Analyze Rust source files in crate
  async fn analyze_crate_source(&self, crate_dir: &Path) -> Result<CodeIndex> {
    let mut files = Vec::new();
    let mut exports = Vec::new();

    // Find lib.rs or main.rs
    let lib_path = crate_dir.join("src").join("lib.rs");
    let main_path = crate_dir.join("src").join("main.rs");

    if lib_path.exists() {
      files.push(self.analyze_rust_file(&lib_path).await?);
      // Extract public exports from lib.rs
      exports.extend(self.extract_exports(&lib_path).await?);
    } else if main_path.exists() {
      files.push(self.analyze_rust_file(&main_path).await?);
    }

    // Analyze all .rs files in src/
    let src_dir = crate_dir.join("src");
    if src_dir.exists() {
      self
        .analyze_directory_recursive(&src_dir, &mut files, &mut exports)
        .await?;
    }

    Ok(CodeIndex {
      files,
      exports,
      imports: vec![],  // TODO: Extract imports
      patterns: vec![], // TODO: Detect patterns
      naming_conventions: self.detect_naming_conventions(&files),
    })
  }

  /// Analyze a single Rust file
  async fn analyze_rust_file(&self, path: &Path) -> Result<IndexedFile> {
    let content = fs::read_to_string(path).await?;
    let lines: Vec<&str> = content.lines().collect();

    // Simple heuristic parsing (would use syn/tree-sitter in production)
    let mut functions = Vec::new();
    let mut classes = Vec::new(); // structs/enums in Rust
    let mut exports = Vec::new();

    for line in &lines {
      let trimmed = line.trim();

      // Find public functions
      if trimmed.starts_with("pub fn ") || trimmed.starts_with("pub async fn ")
      {
        if let Some(name) = self.extract_function_name(trimmed) {
          functions.push(name.to_string());
          exports.push(name.to_string());
        }
      }

      // Find public structs/enums
      if trimmed.starts_with("pub struct ") || trimmed.starts_with("pub enum ")
      {
        if let Some(name) = self.extract_type_name(trimmed) {
          classes.push(name.to_string());
          exports.push(name.to_string());
        }
      }
    }

    Ok(IndexedFile {
      path: path.to_string_lossy().to_string(),
      language: "rust".to_string(),
      exports,
      functions,
      classes,
      line_count: lines.len() as u32,
    })
  }

  /// Recursively analyze directory
  async fn analyze_directory_recursive(
    &self,
    dir: &Path,
    files: &mut Vec<IndexedFile>,
    exports: &mut Vec<Export>,
  ) -> Result<()> {
    let mut entries = fs::read_dir(dir).await?;

    while let Some(entry) = entries.next_entry().await? {
      let path = entry.path();

      if path.is_dir() {
        // Skip target/, tests/ for now (could include tests/ for examples)
        let dir_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
        if dir_name != "target" && !dir_name.starts_with('.') {
          Box::pin(self.analyze_directory_recursive(&path, files, exports))
            .await?;
        }
      } else if path.extension().and_then(|e| e.to_str()) == Some("rs") {
        files.push(self.analyze_rust_file(&path).await?);
        exports.extend(self.extract_exports(&path).await?);
      }
    }

    Ok(())
  }

  /// Extract public exports from a Rust file
  async fn extract_exports(&self, path: &Path) -> Result<Vec<Export>> {
    let content = fs::read_to_string(path).await?;
    let mut exports = Vec::new();

    for line in content.lines() {
      let trimmed = line.trim();

      // Extract pub items
      if let Some(name) = self.extract_function_name(trimmed) {
        exports.push(Export {
          name: name.to_string(),
          from_file: path.to_string_lossy().to_string(),
          export_type: "function".to_string(),
        });
      } else if let Some(name) = self.extract_type_name(trimmed) {
        let export_type = if trimmed.contains("struct") {
          "struct"
        } else if trimmed.contains("enum") {
          "enum"
        } else if trimmed.contains("trait") {
          "trait"
        } else {
          "type"
        };

        exports.push(Export {
          name: name.to_string(),
          from_file: path.to_string_lossy().to_string(),
          export_type: export_type.to_string(),
        });
      }
    }

    Ok(exports)
  }

  /// Extract function name from line
  fn extract_function_name(&self, line: &str) -> Option<&str> {
    if line.starts_with("pub fn ") {
      let name_start = line.find("fn ")? + 3;
      let name_end = line[name_start..].find(|c: char| c == '(' || c == '<')?;
      Some(line[name_start..name_start + name_end].trim())
    } else if line.starts_with("pub async fn ") {
      let name_start = line.find("fn ")? + 3;
      let name_end = line[name_start..].find(|c: char| c == '(' || c == '<')?;
      Some(line[name_start..name_start + name_end].trim())
    } else {
      None
    }
  }

  /// Extract type name from line
  fn extract_type_name(&self, line: &str) -> Option<&str> {
    for keyword in &["pub struct ", "pub enum ", "pub trait ", "pub type "] {
      if line.starts_with(keyword) {
        let name_start = keyword.len();
        let name_end = line[name_start..]
          .find(|c: char| c.is_whitespace() || c == '<' || c == '{')?;
        return Some(line[name_start..name_start + name_end].trim());
      }
    }
    None
  }

  /// Detect naming conventions from analyzed files
  fn detect_naming_conventions(
    &self,
    files: &[IndexedFile],
  ) -> NamingConventions {
    // Rust conventions are standardized
    NamingConventions {
      file_naming: "snake_case".to_string(),
      function_naming: "snake_case".to_string(),
      class_naming: "PascalCase".to_string(),
    }
  }

  /// Extract code snippets from examples/
  async fn extract_examples(
    &self,
    crate_dir: &Path,
  ) -> Result<Vec<CodeSnippet>> {
    let examples_dir = crate_dir.join("examples");
    let mut snippets = Vec::new();

    if !examples_dir.exists() {
      return Ok(snippets);
    }

    let mut entries = fs::read_dir(&examples_dir).await?;

    while let Some(entry) = entries.next_entry().await? {
      let path = entry.path();

      if path.extension().and_then(|e| e.to_str()) == Some("rs") {
        let content = fs::read_to_string(&path).await?;
        let title = path
          .file_stem()
          .and_then(|s| s.to_str())
          .unwrap_or("example")
          .to_string();

        snippets.push(CodeSnippet {
          title: format!("Example: {}", title),
          code: content.clone(),
          language: "rust".to_string(),
          description: format!("From examples/{}.rs", title),
          file_path: path.to_string_lossy().to_string(),
          line_number: 1,
        });
      }
    }

    Ok(snippets)
  }

  /// Extract license information from Cargo.toml
  async fn extract_license_from_manifest(
    &self,
    crate_dir: &Path,
  ) -> Result<Option<crate::storage::LicenseInfo>> {
    let manifest_path = crate_dir.join("Cargo.toml");

    if !manifest_path.exists() {
      return Ok(None);
    }

    let content = fs::read_to_string(&manifest_path).await?;
    let toml: Value =
      toml::from_str(&content).context("Failed to parse Cargo.toml")?;

    // Try to extract license from [package] section
    let license_str = toml
      .get("package")
      .and_then(|p| p.get("license"))
      .and_then(|l| l.as_str())
      .map(|s| s.to_string());

    if let Some(license_id) = license_str {
      let (
        license_type,
        license_id_normalized,
        commercial_use,
        requires_attribution,
        is_copyleft,
      ) = Self::classify_license(&license_id);

      Ok(Some(crate::storage::LicenseInfo {
        license: license_id_normalized,
        license_type,
        commercial_use,
        requires_attribution,
        is_copyleft,
      }))
    } else {
      Ok(None)
    }
  }

  /// Cleanup downloaded crate
  async fn cleanup_crate(&self, crate_dir: &Path) -> Result<()> {
    if !self.keep_cache && crate_dir.exists() {
      fs::remove_dir_all(crate_dir).await?;
      log::debug!("Cleaned up crate: {}", crate_dir.display());
    }
    Ok(())
  }
}

#[async_trait::async_trait]
impl PackageCollector for CargoCollector {
  fn ecosystem(&self) -> &str {
    "cargo"
  }

  async fn collect(
    &self,
    package: &str,
    version: &str,
  ) -> Result<PackageMetadata> {
    let start_time = std::time::Instant::now();

    log::info!("Collecting cargo package: {} v{}", package, version);

    // Download crate
    let crate_dir = self
      .download_crate(package, version)
      .await
      .context("Failed to download crate")?;

    // Analyze source code
    let code_index = self
      .analyze_crate_source(&crate_dir)
      .await
      .context("Failed to analyze crate source")?;

    // Extract examples
    let snippets = self.extract_examples(&crate_dir).await.unwrap_or_default();

    // Extract license information from Cargo.toml
    let license_info = self
      .extract_license_from_manifest(&crate_dir)
      .await
      .unwrap_or_else(|e| {
        log::warn!("Failed to extract license from Cargo.toml: {}", e);
        None
      });

    // Cleanup if needed
    self.cleanup_crate(&crate_dir).await?;

    // Collect security advisories from RustSec
    #[cfg(feature = "cargo-collector")]
    let vulnerabilities = self
      .advisory_collector
      .collect_advisories(package)
      .await
      .unwrap_or_else(|e| {
        log::warn!("Failed to collect RustSec advisories: {}", e);
        vec![]
      });

    #[cfg(not(feature = "cargo-collector"))]
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
      "Collected {} snippets from {} files, {} vulnerabilities in {:?}",
      snippets.len(),
      code_index.files.len(),
      vulnerabilities.len(),
      duration
    );

    Ok(PackageMetadata {
      tool: package.to_string(),
      version: version.to_string(),
      ecosystem: "cargo".to_string(),
      documentation: format!("Analyzed from crates.io package source"),
      snippets,
      examples: vec![],
      best_practices: vec![],
      troubleshooting: vec![],
      github_sources: vec![], // No GitHub - using package source
      dependencies: vec![],
      tags: vec!["rust".to_string(), "cargo".to_string()],
      last_updated: SystemTime::now(),
      source: "cargo:package".to_string(),
      code_index: Some(code_index),
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
    // Would query crates.io API
    // GET https://crates.io/api/v1/crates/{crate}/{version}
    Ok(false) // Placeholder
  }

  async fn latest_version(&self, package: &str) -> Result<String> {
    // Would query crates.io API
    // GET https://crates.io/api/v1/crates/{crate}
    Ok("unknown".to_string()) // Placeholder
  }

  async fn available_versions(&self, package: &str) -> Result<Vec<String>> {
    // Would query crates.io API
    // GET https://crates.io/api/v1/crates/{crate}/versions
    Ok(vec![]) // Placeholder
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use tempfile::TempDir;

  #[tokio::test]
  async fn test_cargo_collector_creation() {
    let temp_dir = TempDir::new().unwrap();
    let collector = CargoCollector::new(temp_dir.path().to_path_buf(), false);
    assert_eq!(collector.ecosystem(), "cargo");
  }

  #[test]
  fn test_extract_function_name() {
    let collector = CargoCollector::new(PathBuf::from("/tmp"), false);

    assert_eq!(
      collector.extract_function_name("pub fn hello_world() {"),
      Some("hello_world")
    );

    assert_eq!(
      collector
        .extract_function_name("pub async fn fetch_data() -> Result<()> {"),
      Some("fetch_data")
    );

    assert_eq!(
      collector.extract_function_name("fn private_function() {"),
      None
    );
  }

  #[test]
  fn test_extract_type_name() {
    let collector = CargoCollector::new(PathBuf::from("/tmp"), false);

    assert_eq!(
      collector.extract_type_name("pub struct MyStruct {"),
      Some("MyStruct")
    );

    assert_eq!(
      collector.extract_type_name("pub enum Status {"),
      Some("Status")
    );

    assert_eq!(
      collector.extract_type_name("pub trait Behavior {"),
      Some("Behavior")
    );
  }
}
