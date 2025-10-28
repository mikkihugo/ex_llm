//! Package Collectors - Download and analyze packages from registries
//!
//! Data Source Hierarchy (best to fallback):
//! 1. GitHub - Official repo with examples/tests
//! 2. Package Source - Downloaded package analyzed locally
//! 3. Registry Metadata - README + API metadata
//! 4. LLM Generated - AI-generated examples (last resort)

use crate::storage::{CodeSnippet, PackageMetadata};
use anyhow::Result;

#[cfg(feature = "cargo-collector")]
pub mod cargo;

#[cfg(feature = "npm-collector")]
pub mod npm;

#[cfg(feature = "hex-collector")]
pub mod hex;

#[cfg(feature = "npm-collector")]
pub mod npm_advisory;

#[cfg(feature = "cargo-collector")]
pub mod rustsec_advisory;

pub mod github_advisory;

/// Trait for collecting package data from different registries
#[async_trait::async_trait]
pub trait PackageCollector: Send + Sync {
  /// Ecosystem name (cargo, npm, hex, pypi, gem)
  fn ecosystem(&self) -> &str;

  /// Collect fact data for a specific package version
  ///
  /// # Arguments
  /// * `package` - Package name (e.g., "tokio", "react", "phoenix")
  /// * `version` - Semantic version (e.g., "1.35.0")
  ///
  /// # Returns
  /// Complete PackageMetadata with source code analysis
  async fn collect(
    &self,
    package: &str,
    version: &str,
  ) -> Result<PackageMetadata>;

  /// Check if package exists in registry
  async fn exists(&self, package: &str, version: &str) -> Result<bool>;

  /// Get latest version of a package
  async fn latest_version(&self, package: &str) -> Result<String>;

  /// Get all available versions for a package
  async fn available_versions(&self, package: &str) -> Result<Vec<String>>;
}

/// Data source priority for fact collection
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DataSourcePriority {
  /// Official GitHub repository (highest quality)
  GitHub = 100,

  /// Package source code analysis (high quality)
  PackageSource = 80,

  /// Registry metadata only (medium quality)
  RegistryMetadata = 50,

  /// LLM-generated content (fallback)
  LLMGenerated = 20,
}

impl DataSourcePriority {
  /// Get priority as integer for comparison
  pub fn as_int(&self) -> i32 {
    match self {
      DataSourcePriority::GitHub => 100,
      DataSourcePriority::PackageSource => 80,
      DataSourcePriority::RegistryMetadata => 50,
      DataSourcePriority::LLMGenerated => 20,
    }
  }
}

/// Statistics about collection process
#[derive(Debug, Clone)]
pub struct CollectionStats {
  pub source: String,
  pub priority: DataSourcePriority,
  pub files_analyzed: usize,
  pub snippets_extracted: usize,
  pub functions_found: usize,
  pub types_found: usize,
  pub examples_found: usize,
  pub duration_ms: u64,
}

impl CollectionStats {
  pub fn new(source: String, priority: DataSourcePriority) -> Self {
    Self {
      source,
      priority,
      files_analyzed: 0,
      snippets_extracted: 0,
      functions_found: 0,
      types_found: 0,
      examples_found: 0,
      duration_ms: 0,
    }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_data_source_priority() {
    assert!(
      DataSourcePriority::GitHub.as_int()
        > DataSourcePriority::PackageSource.as_int()
    );
    assert!(
      DataSourcePriority::PackageSource.as_int()
        > DataSourcePriority::RegistryMetadata.as_int()
    );
    assert!(
      DataSourcePriority::RegistryMetadata.as_int()
        > DataSourcePriority::LLMGenerated.as_int()
    );
  }
}
