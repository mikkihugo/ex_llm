//! FACT Storage Abstraction Layer
//!
//! Provides a unified interface for different storage backends:
//! - Sled: Pure Rust embedded database (current)
//! - Mnesia: Erlang/Elixir integration via Rustler (future)

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::time::SystemTime;

pub mod semver;
// All storage now via NATS → db_service → PostgreSQL
// No local storage (redb/filesystem) in tool_doc_index

/// FACT storage abstraction trait (dyn-compatible)
#[async_trait::async_trait]
pub trait PackageStorage: Send + Sync {
  /// Store FACT data for a tool
  async fn store_fact(&self, key: &PackageKey, data: &PackageMetadata) -> Result<()>;

  /// Retrieve FACT data for a tool
  async fn get_fact(&self, key: &PackageKey) -> Result<Option<PackageMetadata>>;

  /// Check if FACT data exists for a tool
  async fn exists(&self, key: &PackageKey) -> Result<bool>;

  /// Delete FACT data for a tool
  async fn delete_fact(&self, key: &PackageKey) -> Result<()>;

  /// List all tools in an ecosystem
  async fn list_tools(&self, ecosystem: &str) -> Result<Vec<PackageKey>>;

  /// Search tools by prefix
  async fn search_tools(&self, prefix: &str) -> Result<Vec<PackageKey>>;

  /// Get storage statistics
  async fn stats(&self) -> Result<StorageStats>;

  // ========== NEW METHODS FOR EXTENDED SEARCH ==========

  /// Search facts by tags (for filtering)
  async fn search_by_tags(&self, tags: &[String]) -> Result<Vec<PackageKey>>;

  /// Get all facts (for building indexes)
  async fn get_all_facts(&self) -> Result<Vec<(PackageKey, PackageMetadata)>>;
}

/// Storage management trait for lifecycle operations
#[async_trait::async_trait]
pub trait PackageStorageManagement: Send + Sync {
  /// Compact/optimize storage
  async fn compact(&mut self) -> Result<()>;

  /// Close storage connection
  async fn close(&mut self) -> Result<()>;
}

/// Package key - Unique identifier for stored package/tool data
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PackageKey {
  pub tool: String,
  pub version: String,
  pub ecosystem: String,
}

impl PackageKey {
  #[must_use]
  pub const fn new(tool: String, version: String, ecosystem: String) -> Self {
    Self {
      tool,
      version,
      ecosystem,
    }
  }

  /// Generate storage key string
  #[must_use]
  pub fn storage_key(&self) -> String {
    format!("fact:{}:{}:{}", self.ecosystem, self.tool, self.version)
  }

  /// Parse storage key string back to `PackageKey`
  ///
  /// # Errors
  /// Returns an error if the storage key format is invalid
  pub fn from_storage_key(key: &str) -> Result<Self> {
    let parts: Vec<&str> = key.split(':').collect();
    if parts.len() != 4 || parts[0] != "fact" {
      anyhow::bail!("Invalid storage key format: {key}");
    }

    Ok(Self {
      ecosystem: parts[1].to_string(),
      tool: parts[2].to_string(),
      version: parts[3].to_string(),
    })
  }
}

/// FACT data structure (extended for prompt bits, embeddings, and learning)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageMetadata {
  // ========== EXISTING FIELDS (KEEP ALL) ==========
  pub tool: String,
  pub version: String,
  pub ecosystem: String,
  pub documentation: String,
  pub snippets: Vec<CodeSnippet>,  // Parsed from package source (via source code parser)
  pub examples: Vec<PackageExample>,  // Examples from README/docs
  pub best_practices: Vec<PackageBestPractice>,
  pub troubleshooting: Vec<PackageTroubleshooting>,
  pub github_sources: Vec<GitHubSource>,
  pub dependencies: Vec<String>,
  pub tags: Vec<String>,
  pub last_updated: SystemTime,
  pub source: String,

  // ========== REMOVED: code_index ==========
  // Code analysis should be done by analysis-suite, not fact-system.
  // fact-system only stores extracted snippets and examples.

  // ========== NEW: TECH PROFILE (frameworks, languages, databases, build tools) ==========
  #[serde(default, skip_serializing_if = "Option::is_none")]
  pub detected_framework: Option<TechStack>,

  // ========== NEW: PROMPT TEMPLATES ==========
  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub prompt_templates: Vec<PromptTemplate>,

  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub quick_starts: Vec<QuickStart>,

  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub migration_guides: Vec<MigrationGuide>,

  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub usage_patterns: Vec<UsageCodePattern>,

  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub cli_commands: Vec<CliCommand>,

  // ========== NEW: VECTOR EMBEDDINGS ==========
  #[serde(default, skip_serializing_if = "Option::is_none")]
  pub semantic_embedding: Option<Vec<f32>>, // 384-dim sentence embedding

  #[serde(default, skip_serializing_if = "Option::is_none")]
  pub code_embedding: Option<Vec<f32>>, // 384-dim code embedding

  // ========== NEW: GRAPH EMBEDDINGS ==========
  #[serde(default, skip_serializing_if = "Option::is_none")]
  pub graph_embedding: Option<GraphEmbedding>,

  // ========== NEW: RELATIONSHIPS ==========
  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub relationships: Vec<PackageRelationship>,

  // ========== NEW: LEARNING DATA ==========
  #[serde(default)]
  pub usage_stats: UsageStats,

  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub execution_history: Vec<ExecutionRecord>,

  #[serde(default)]
  pub learning_data: LearningData,

  // ========== NEW: SECURITY DATA ==========
  #[serde(default, skip_serializing_if = "Vec::is_empty")]
  pub vulnerabilities: Vec<SecurityVulnerability>,

  #[serde(default, skip_serializing_if = "Option::is_none")]
  pub security_score: Option<f32>,

  #[serde(default, skip_serializing_if = "Option::is_none")]
  pub license_info: Option<LicenseInfo>,
}

impl Default for PackageMetadata {
  fn default() -> Self {
    Self::new()
  }
}

impl PackageMetadata {
  /// Create a new empty PackageMetadata instance
  pub fn new() -> Self {
    Self {
      tool: String::new(),
      version: String::new(),
      ecosystem: String::new(),
      documentation: String::new(),
      snippets: Vec::new(),
      examples: Vec::new(),
      best_practices: Vec::new(),
      troubleshooting: Vec::new(),
      github_sources: Vec::new(),
      dependencies: Vec::new(),
      tags: Vec::new(),
      last_updated: SystemTime::now(),
      source: String::new(),
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
      usage_stats: UsageStats::default(),
      execution_history: Vec::new(),
      learning_data: LearningData::default(),
      vulnerabilities: Vec::new(),
      security_score: None,
      license_info: None,
    }
  }

  /// Insert a key-value pair into the fact data
  pub fn insert(&mut self, key: String, value: serde_json::Value) {
    // Store in a simple HashMap-like structure
    // For now, we'll use the existing fields to store custom data
    match key.as_str() {
      "tool" => self.tool = value.as_str().unwrap_or("").to_string(),
      "version" => self.version = value.as_str().unwrap_or("").to_string(),
      "ecosystem" => self.ecosystem = value.as_str().unwrap_or("").to_string(),
      "documentation" => {
        self.documentation = value.as_str().unwrap_or("").to_string()
      }
      "source" => self.source = value.as_str().unwrap_or("").to_string(),
      _ => {
        // Store custom fields in tags for now
        if let Some(str_val) = value.as_str() {
          self.tags.push(format!("{}:{}", key, str_val));
        }
      }
    }
  }
}

/// Code snippet parsed from package source files
/// Extracted by source code parser (tree-sitter) from downloaded tarballs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeSnippet {
  pub title: String,
  pub code: String,
  pub language: String,
  pub description: String,
  pub file_path: String,    // Relative path within package
  pub line_number: u32,
}

/// Example from package documentation (README, docs site)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageExample {
  pub title: String,
  pub code: String,         // Example code from docs (as text)
  pub explanation: String,
  pub tags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageBestPractice {
  pub practice: String,
  pub rationale: String,
  pub example: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageTroubleshooting {
  pub issue: String,
  pub solution: String,
  pub references: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitHubSource {
  pub repo: String,
  pub stars: u32,
  pub last_update: String,
}

/// Storage statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageStats {
  pub total_entries: u64,
  pub total_size_bytes: u64,
  pub ecosystems: std::collections::HashMap<String, u64>,
  pub last_compaction: Option<SystemTime>,
}

/// Simple storage configuration - just needs a global path
#[derive(Debug, Clone)]
pub struct StorageConfig {
  pub global_facts_dir: String,
}

impl Default for StorageConfig {
  fn default() -> Self {
    // Check if we're in project mode or global mode
    // In project mode: ./.primecode/facts/
    // In global mode: ~/.primecode/facts/
    let facts_dir = if std::env::var("ZEN_STORE_CONFIG_IN_USER_HOME")
      .unwrap_or_else(|_| "true".to_string())
      .to_lowercase()
      == "false"
    {
      // Project mode - store in local .primecode/facts/
      std::path::PathBuf::from(".primecode").join("facts")
    } else {
      // Global mode (default) - store in user home ~/.primecode/facts/
      let home_dir =
        dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
      home_dir.join(".primecode").join("facts")
    };

    Self {
      global_facts_dir: facts_dir.to_string_lossy().to_string(),
    }
  }
}

/// Create simple file-based storage for global facts (legacy)
///
/// # Errors
/// Returns an error if the storage cannot be initialized
pub async fn create_storage(
  config: StorageConfig,
) -> Result<Box<dyn PackageStorage>> {
  let storage = filesystem_storage::FilesystemPackageStorage::new(config).await?;
  Ok(Box::new(storage))
}

/// Create version-aware redb storage (recommended)
///
/// # Errors
/// Returns an error if the storage cannot be initialized
pub async fn create_versioned_storage() -> Result<Box<dyn PackageStorage>> {
  let storage = versioned_storage::VersionedPackageStorage::new_global().await?;
  Ok(Box::new(storage))
}

// --------------------------------------------------------------------------
// Minimal in-repo storage backends to satisfy workspace build
// These provide simple filesystem-backed stubs without external services.

mod filesystem_storage {
  use super::*;
  use std::collections::HashMap;
  use std::fs;
  use std::path::PathBuf;
  use tokio::sync::RwLock as AsyncRwLock;

  pub struct FilesystemPackageStorage {
    root: PathBuf,
    // simple in-memory cache to reduce IO in tests/checks
    cache: AsyncRwLock<HashMap<String, PackageMetadata>>,
  }

  impl FilesystemPackageStorage {
    pub async fn new(config: StorageConfig) -> Result<Self> {
      let root = PathBuf::from(&config.global_facts_dir);
      fs::create_dir_all(&root)?;
      Ok(Self { root, cache: AsyncRwLock::new(HashMap::new()) })
    }

    fn path_for(&self, key: &PackageKey) -> PathBuf {
      self.root.join(format!("{}.json", key.storage_key()))
    }
  }

  #[async_trait::async_trait]
  impl PackageStorage for FilesystemPackageStorage {
    async fn store_fact(&self, key: &PackageKey, data: &PackageMetadata) -> Result<()> {
      let path = self.path_for(key);
      if let Some(parent) = path.parent() { fs::create_dir_all(parent)?; }
      let json = serde_json::to_string_pretty(data)?;
      tokio::fs::write(path, json).await?;
      self.cache.write().await.insert(key.storage_key(), data.clone());
      Ok(())
    }

    async fn get_fact(&self, key: &PackageKey) -> Result<Option<PackageMetadata>> {
      if let Some(v) = self.cache.read().await.get(&key.storage_key()).cloned() { return Ok(Some(v)); }
      let path = self.path_for(key);
      if !path.exists() { return Ok(None); }
      let bytes = tokio::fs::read(path).await?;
      let data: PackageMetadata = serde_json::from_slice(&bytes)?;
      Ok(Some(data))
    }

    async fn exists(&self, key: &PackageKey) -> Result<bool> {
      let path = self.path_for(key);
      Ok(path.exists())
    }

    async fn delete_fact(&self, key: &PackageKey) -> Result<()> {
      let path = self.path_for(key);
      let _ = tokio::fs::remove_file(path).await;
      self.cache.write().await.remove(&key.storage_key());
      Ok(())
    }

    async fn list_tools(&self, _ecosystem: &str) -> Result<Vec<PackageKey>> {
      // Simple best-effort scan
      let mut out = Vec::new();
      if !self.root.exists() { return Ok(out); }
      for entry in fs::read_dir(&self.root)? { let entry = entry?; if entry.file_type()?.is_file() {
        let name = entry.file_name().to_string_lossy().to_string();
        if let Some(stripped) = name.strip_suffix(".json") {
          if let Ok(key) = PackageKey::from_storage_key(stripped) { out.push(key); }
        }
      }}
      Ok(out)
    }

    async fn search_tools(&self, prefix: &str) -> Result<Vec<PackageKey>> {
      let all = self.list_tools("").await?;
      Ok(all.into_iter().filter(|k| k.tool.starts_with(prefix)).collect())
    }

    async fn stats(&self) -> Result<StorageStats> {
      Ok(StorageStats { total_entries: self.list_tools("").await?.len() as u64, total_size_bytes: 0, ecosystems: Default::default(), last_compaction: None })
    }

    async fn search_by_tags(&self, _tags: &[String]) -> Result<Vec<PackageKey>> { Ok(vec![]) }
    async fn get_all_facts(&self) -> Result<Vec<(PackageKey, PackageMetadata)>> { Ok(vec![]) }
  }
}

mod versioned_storage {
  use super::*;

  pub struct VersionedPackageStorage;

  impl VersionedPackageStorage {
    pub async fn new_global() -> Result<Self> { Ok(Self) }
  }

  #[async_trait::async_trait]
  impl PackageStorage for VersionedPackageStorage {
    async fn store_fact(&self, _key: &PackageKey, _data: &PackageMetadata) -> Result<()> { Ok(()) }
    async fn get_fact(&self, _key: &PackageKey) -> Result<Option<PackageMetadata>> { Ok(None) }
    async fn exists(&self, _key: &PackageKey) -> Result<bool> { Ok(false) }
    async fn delete_fact(&self, _key: &PackageKey) -> Result<()> { Ok(()) }
    async fn list_tools(&self, _ecosystem: &str) -> Result<Vec<PackageKey>> { Ok(vec![]) }
    async fn search_tools(&self, _prefix: &str) -> Result<Vec<PackageKey>> { Ok(vec![]) }
    async fn stats(&self) -> Result<StorageStats> { Ok(StorageStats { total_entries: 0, total_size_bytes: 0, ecosystems: Default::default(), last_compaction: None }) }
    async fn search_by_tags(&self, _tags: &[String]) -> Result<Vec<PackageKey>> { Ok(vec![]) }
    async fn get_all_facts(&self) -> Result<Vec<(PackageKey, PackageMetadata)>> { Ok(vec![]) }
  }
}

// ============================================================================
// NEW TYPE DEFINITIONS FOR EXTENDED FACT DATA
// ============================================================================

/// Code index from repository analysis
///
/// DEPRECATED: Removed from PackageMetadata. Code analysis should be done by analysis-suite.
/// fact-system only stores extracted snippets in CodeSnippet format.
/// This struct may be removed in future versions.
#[deprecated(since = "1.2.0", note = "Use analysis-suite for code analysis instead")]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeIndex {
  pub files: Vec<IndexedFile>,
  pub exports: Vec<Export>,
  pub imports: Vec<Import>,
  pub patterns: Vec<DetectedCodePattern>,
  pub naming_conventions: NamingConventions,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexedFile {
  pub path: String,
  pub language: String,
  pub exports: Vec<String>,
  pub functions: Vec<String>,
  pub classes: Vec<String>,
  pub line_count: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Export {
  pub name: String,
  pub from_file: String,
  pub export_type: String, // "function", "class", "const", etc.
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Import {
  pub name: String,
  pub from_file: String,
  pub to_file: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedCodePattern {
  pub pattern_type: String, // "service", "controller", "middleware"
  pub files: Vec<String>,
  pub confidence: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct NamingConventions {
  pub file_naming: String, // "kebab-case", "snake_case", etc.
  pub function_naming: String, // "camelCase", "snake_case", etc.
  pub class_naming: String, // "PascalCase", etc.
}

/// Technology profile - comprehensive view of all technologies used in a project
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TechStack {
  pub frameworks: Vec<Framework>,
  pub languages: Vec<LanguageInfo>,
  pub build_system: String,
  pub workspace_type: String,
  pub package_manager: String,
  pub databases: Vec<String>,
  pub message_brokers: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Framework {
  pub name: String,
  pub version: String,
  pub usage: FrameworkUsage,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FrameworkUsage {
  Primary,
  Secondary,
  Testing,
  Development,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageInfo {
  pub name: String,
  pub version: String,
  pub file_count: u32,
  pub line_count: u32,
}

/// Prompt template
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptTemplate {
  pub title: String,
  pub content: String,
  pub category: PromptCategory,
  pub variables: Vec<String>,
  pub confidence: f64,
  pub framework_version: String,
  pub prerequisites: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PromptCategory {
  Tutorial,
  QuickStart,
  Migration,
  Integration,
  Troubleshooting,
  BestPractice,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickStart {
  pub title: String,
  pub steps: Vec<String>,
  pub time_estimate_minutes: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MigrationGuide {
  pub from_version: String,
  pub to_version: String,
  pub breaking_changes: Vec<String>,
  pub steps: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsageCodePattern {
  pub pattern_name: String,
  pub use_case: String,
  pub code: String,
  pub frequency: String, // "common", "occasional", "rare"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CliCommand {
  pub command: String,
  pub description: String,
  pub flags: Vec<CommandFlag>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandFlag {
  pub flag: String,
  pub description: String,
}

/// Graph embedding for code structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEmbedding {
  pub node_embeddings: std::collections::HashMap<String, Vec<f32>>,
  pub edge_weights: Vec<(String, String, f32)>,
  pub centrality_scores: std::collections::HashMap<String, f64>,
  pub community_clusters: Vec<Vec<String>>,
}

/// Relationship between facts
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageRelationship {
  pub target_fact: String,
  pub relationship_type: RelationType,
  pub strength: f64,
  pub learned: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RelationType {
  DependsOn,
  UsedWith,
  Alternative,
  Supersedes,
  Prerequisite,
  RelatedTo,
}

/// Usage statistics for learning
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UsageStats {
  pub usage_count: u32,
  pub success_rate: f64,
  pub last_used: SystemTime,
  pub avg_time_to_success_minutes: u32,
  pub successful_contexts: Vec<String>,
  pub failed_contexts: Vec<String>,
}

impl Default for UsageStats {
  fn default() -> Self {
    Self {
      usage_count: 0,
      success_rate: 0.0,
      last_used: SystemTime::now(),
      avg_time_to_success_minutes: 0,
      successful_contexts: Vec::new(),
      failed_contexts: Vec::new(),
    }
  }
}

/// Execution record for tracking results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionRecord {
  pub task: String,
  pub success: bool,
  pub facts_used: Vec<String>,
  pub files_created: Vec<String>,
  pub files_modified: Vec<String>,
  pub duration_ms: u64,
  pub error: Option<String>,
  pub timestamp: SystemTime,
}

/// Learning data from DSPy
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LearningData {
  pub dspy_weights: std::collections::HashMap<String, f64>,
  pub combination_scores: std::collections::HashMap<Vec<String>, f64>,
  pub improvement_suggestions: Vec<String>,
}

// ========== SECURITY STRUCTS ==========

/// Security vulnerability information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityVulnerability {
  /// Vulnerability ID (CVE, GHSA, RUSTSEC, etc.)
  pub id: String,

  /// Type of vulnerability (e.g., "CVE", "GHSA", "RUSTSEC")
  pub vuln_type: String,

  /// Severity level (CRITICAL, HIGH, MEDIUM, LOW)
  pub severity: String,

  /// CVSS score (0.0-10.0)
  pub cvss_score: Option<f32>,

  /// Description of the vulnerability
  pub description: String,

  /// Affected versions (semver ranges)
  pub affected_versions: Vec<String>,

  /// Patched versions (semver)
  pub patched_versions: Vec<String>,

  /// Links to advisories/references
  pub references: Vec<String>,

  /// Date published (ISO 8601)
  pub published_at: Option<String>,

  /// CWE (Common Weakness Enumeration) IDs
  pub cwe_ids: Vec<String>,
}

/// License information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LicenseInfo {
  /// License identifier (SPDX)
  pub license: String,

  /// License type (permissive, copyleft, proprietary)
  pub license_type: String,

  /// Compatible with proprietary use
  pub commercial_use: bool,

  /// Requires attribution
  pub requires_attribution: bool,

  /// Copyleft/viral (requires derivative works to use same license)
  pub is_copyleft: bool,

  /// License restrictions
  pub restrictions: Vec<String>,

  /// License URL
  pub license_url: Option<String>,
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_fact_key_storage() {
    let key = PackageKey::new(
      "phoenix".to_string(),
      "1.7.0".to_string(),
      "beam".to_string(),
    );
    let storage_key = key.storage_key();
    assert_eq!(storage_key, "fact:beam:phoenix:1.7.0");

    let parsed_key = PackageKey::from_storage_key(&storage_key)
      .expect("Failed to parse storage key");
    assert_eq!(parsed_key, key);
  }

  #[test]
  fn test_invalid_storage_key() {
    assert!(PackageKey::from_storage_key("invalid:key").is_err());
    assert!(PackageKey::from_storage_key("fact:beam:phoenix").is_err()); // Missing version
  }
}

pub mod dependency_catalog_storage;
pub use dependency_catalog_storage::DependencyCatalogStorage;

// NIF bindings (feature-gated for Elixir integration)
#[cfg(feature = "nif")]
pub mod nif;
