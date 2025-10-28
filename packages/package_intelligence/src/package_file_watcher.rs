//! Package File Watcher
//!
//! Monitors package files (mix.exs, Cargo.toml, package.json, etc.) for changes,
//! discovers dependencies with version awareness, and populates the FACT knowledge base.
//!
//! **What it does:**
//! - Scans local directories for package files
//! - Watches for file changes (real-time)
//! - Discovers GitHub repositories from your orgs
//! - Analyzes dependencies and versions
//! - Populates FACT knowledge base with package metadata

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use dependency_parser::{DependencyParser, PackageDependency};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};
use tokio::fs;
use tokio::time::interval;
use tracing::{debug, info, warn};
// Temporary: use local ProgrammingLanguage enum until source code parser is fixed
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ProgrammingLanguage {
  Elixir,
  Erlang,
  Gleam,
  Rust,
  Go,
  C,
  Cpp,
  Java,
  CSharp,
  Swift,
  Kotlin,
  JavaScript,
  TypeScript,
  Python,
  // Additional languages
  Clojure,
  Ruby,
  PHP,
  FSharp,
  VB,
  Dart,
  Haskell,
  Perl,
  R,
  Julia,
  Unknown,
}

#[cfg(feature = "orchestration")]
use notify::{
  Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher,
};

#[cfg(feature = "github")]
use crate::github::GitHubAnalyzer;

use crate::Fact;

/// Package file watcher configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageFileWatcherConfig {
  /// Enable automatic discovery
  pub auto_discovery: bool,
  /// Enable automatic GitHub integration
  pub auto_github: bool,
  /// Update interval in hours
  pub update_interval_hours: u64,
  /// Maximum concurrent operations
  pub max_concurrent: usize,
  /// GitHub token for API access
  pub github_token: Option<String>,
  /// Directories to scan for projects
  pub scan_directories: Vec<PathBuf>,
  /// GitHub organizations to discover repositories from
  pub github_organizations: Vec<String>,
  /// File patterns to monitor for changes
  pub monitor_patterns: Vec<String>,
  /// Only analyze repos with activity in last N days
  pub activity_days_threshold: u32,
  /// Enable real-time package file watching
  pub watch_package_files: bool,
}

impl Default for PackageFileWatcherConfig {
  fn default() -> Self {
    Self {
      auto_discovery: true,
      auto_github: true,
      update_interval_hours: 24, // Daily updates
      max_concurrent: 4,
      github_token: std::env::var("GITHUB_TOKEN").ok(),
      scan_directories: vec![
        PathBuf::from("."),
        PathBuf::from("../"),
        std::env::var("HOME").map_or_else(
          |_| PathBuf::from("~/code"),
          |home| PathBuf::from(home).join("code"),
        ),
      ],
      // GitHub organization discovery (preferred over local scanning)
      github_organizations: vec!["mikkihugo".to_string()], // Will be auto-detected from gh CLI
      monitor_patterns: vec![
        // BEAM Ecosystem
        "mix.exs".to_string(),
        "mix.lock".to_string(),
        "gleam.toml".to_string(),
        "rebar.config".to_string(),
        // Rust
        "Cargo.toml".to_string(),
        "Cargo.lock".to_string(),
        // Node.js/JavaScript
        "package.json".to_string(),
        "package-lock.json".to_string(),
        "yarn.lock".to_string(),
        "pnpm-lock.yaml".to_string(),
        // Python
        "requirements.txt".to_string(),
        "setup.py".to_string(),
        "pyproject.toml".to_string(),
        "Pipfile".to_string(),
        "poetry.lock".to_string(),
        // Go
        "go.mod".to_string(),
        "go.sum".to_string(),
        // Java/JVM
        "pom.xml".to_string(),
        "build.gradle".to_string(),
        "build.gradle.kts".to_string(),
        "project.clj".to_string(),
        // .NET
        "*.csproj".to_string(),
        "*.fsproj".to_string(),
        "*.vbproj".to_string(),
        "packages.config".to_string(),
        "project.json".to_string(),
        // Ruby
        "Gemfile".to_string(),
        "Gemfile.lock".to_string(),
        "*.gemspec".to_string(),
        // PHP
        "composer.json".to_string(),
        "composer.lock".to_string(),
        // Perl
        "cpanfile".to_string(),
        "META.json".to_string(),
        "META.yml".to_string(),
        // Haskell
        "*.cabal".to_string(),
        "stack.yaml".to_string(),
        "package.yaml".to_string(),
        // Swift
        "Package.swift".to_string(),
        "Podfile".to_string(),
        // Dart
        "pubspec.yaml".to_string(),
        "pubspec.lock".to_string(),
        // R
        "DESCRIPTION".to_string(),
        "renv.lock".to_string(),
        // Julia
        "Project.toml".to_string(),
        "Manifest.toml".to_string(),
        // Nix
        "flake.nix".to_string(),
        "shell.nix".to_string(),
        "default.nix".to_string(),
        // Docker
        "Dockerfile".to_string(),
        "docker-compose.yml".to_string(),
        "docker-compose.yaml".to_string(),
        // Make
        "Makefile".to_string(),
        "makefile".to_string(),
      ],
      activity_days_threshold: 30, // Only analyze repos active in last 30 days
      watch_package_files: true,   // Real-time package file watching
    }
  }
}

/// Discovered project information with version awareness
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscoveredProject {
  pub path: PathBuf,
  pub name: String,
  pub language: ProgrammingLanguage,
  pub dependencies: Vec<VersionedDependency>,
  pub last_scanned: SystemTime,
  pub version: Option<String>,
  pub last_active: DateTime<Utc>, // Git commit activity
}

/// Version-aware dependency tracking with hit-based cleanup
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VersionedDependency {
  pub name: String,
  pub version: String,
  pub ecosystem: String, // hex, crates.io, npm, pypi, etc.
  pub source: Option<String>, // git repo, registry URL, etc.
  pub first_seen: DateTime<Utc>,
  pub last_seen: DateTime<Utc>,
  pub last_hit: DateTime<Utc>, // Last time this version was queried/used
  pub hit_count: u64, // Total number of times this version was accessed
  pub recent_hits: Vec<DateTime<Utc>>, // Hit timestamps for last 30 days tracking
  pub used_by_projects: Vec<String>,   // Project names using this version
}

/// FACT build queue status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FactBuildStatus {
  Ready,                      // FACT available for queries
  Building,                   // Currently building FACT entries
  Queued { position: usize }, // Queued for building
}

/// Result of FACT build check (for client responses)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FactBuildResult {
  Ready,    // FACT is ready for use
  Building, // FACT is building, try again in 30s
  Failed,   // FACT build failed
}

/// Package dependency information

/// FACT version tracking - multiple versions with hit-based cleanup
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FactVersionRegistry {
  /// `tool_name` -> [version1, version2, version3]
  pub active_versions: HashMap<String, Vec<VersionedDependency>>,
  /// Cleanup timeout - versions unused for 30 days get removed (unless 4+ recent hits)
  pub cleanup_no_hits_days: u32,
  /// Minimum hits in last 30 days to keep version (even if last hit > 30 days ago)
  pub min_recent_hits_threshold: u32,
  /// Maximum age - versions older than 130 days get removed regardless
  pub cleanup_max_age_days: u32,
  /// Build queue - tools currently being processed
  pub build_queue: HashMap<String, FactBuildStatus>, // tool_name -> status
}

// ProjectLanguage enum removed - now using local ProgrammingLanguage enum

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Dependency {
  pub name: String,
  pub version: String,
  pub source: DependencySource,
  pub ecosystem: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DependencySource {
  // Package Registries
  Hex,       // Elixir/Erlang packages
  Crates,    // Rust packages
  Npm,       // Node.js packages
  PyPI,      // Python packages
  RubyGems,  // Ruby packages
  Maven,     // Java/JVM packages
  NuGet,     // .NET packages
  Go,        // Go modules
  CPAN,      // Perl packages
  Packagist, // PHP packages
  Pub,       // Dart packages
  CocoaPods, // iOS packages
  SwiftPM,   // Swift packages
  Hackage,   // Haskell packages
  // Version Control
  GitHub { repo: String },
  GitLab { repo: String },
  Bitbucket { repo: String },
  Git { url: String },
  // Local
  Local { path: PathBuf },
  // System
  System, // System packages (apt, yum, brew, etc.)
}

/// Knowledge update status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KnowledgeStatus {
  pub tool: String,
  pub version: String,
  pub last_updated: SystemTime,
  pub snippets_count: usize,
  pub examples_count: usize,
  pub next_update: SystemTime,
  pub auto_update_enabled: bool,
}

/// Package file watcher with version-aware dependency tracking
pub struct PackageFileWatcher {
  #[allow(dead_code)]
  fact: Fact,
  config: PackageFileWatcherConfig,
  #[cfg(feature = "github")]
  github: Option<GitHubAnalyzer>,
  discovered_projects: HashMap<PathBuf, DiscoveredProject>,
  knowledge_status: HashMap<String, KnowledgeStatus>,
  version_registry: FactVersionRegistry,
  is_running: bool,
  // Dependency parser for package files (package.json, Cargo.toml, etc.)
  dependency_parser: DependencyParser,
  // Source code parser for analyzing downloaded dependency source code (temporarily disabled)
  // source_parser: Option<SourceCodeParser>,
}

impl PackageFileWatcher {
  /// Create a new `PackageFileWatcher` instance
  ///
  /// # Errors
  ///
  /// Returns an error if:
  /// - Configuration validation fails
  /// - Initial setup fails
  pub fn new(config: PackageFileWatcherConfig) -> Result<Self> {
    let fact = Fact::new();

    #[cfg(feature = "github")]
    let github = if config.auto_github {
      Some(GitHubAnalyzer::new(config.github_token.clone())?)
    } else {
      None
    };

    // Initialize dependency parser for package files
    let dependency_parser = DependencyParser::new();
    // Source code parser temporarily disabled due to compilation issues
    // let source_parser = SourceCodeParser::new().ok();

    Ok(Self {
      fact,
      config,
      #[cfg(feature = "github")]
      github,
      discovered_projects: HashMap::new(),
      knowledge_status: HashMap::new(),
      version_registry: FactVersionRegistry {
        active_versions: HashMap::new(),
        cleanup_no_hits_days: 30, // Remove versions with no hits after 30 days
        min_recent_hits_threshold: 4, // Keep versions with 4+ hits in last 30 days
        cleanup_max_age_days: 130, // Remove all versions after 130 days regardless
        build_queue: HashMap::new(),
      },
      is_running: false,
      dependency_parser,
      // source_parser,
    })
  }

  /// Discover repositories from local git information (fastest approach)
  async fn discover_local_git_repositories(&mut self) -> Result<()> {
    info!("🔍 Discovering repositories from local git information");

    // Clone scan directories to avoid borrowing issues
    let scan_dirs = self.config.scan_directories.clone();

    // Scan configured directories for git repositories
    for scan_dir in scan_dirs {
      if let Ok(entries) = std::fs::read_dir(&scan_dir) {
        for entry in entries.flatten() {
          let path = entry.path();
          if path.is_dir() {
            // Check if this is a git repository
            if path.join(".git").exists() {
              self.process_git_repository(&path)?;
            } else {
              // Recursively check subdirectories for git repos
              self.scan_directory_for_git_repos(&path).await?;
            }
          }
        }
      }
    }

    Ok(())
  }

  /// Recursively scan directory for git repositories
  async fn scan_directory_for_git_repos(
    &mut self,
    dir: &std::path::Path,
  ) -> Result<()> {
    self.scan_directory_for_git_repos_with_depth(dir, 0).await
  }

  /// Recursively scan directory for git repositories with depth tracking
  async fn scan_directory_for_git_repos_with_depth(
    &mut self,
    dir: &std::path::Path,
    depth: usize,
  ) -> Result<()> {
    if depth >= 3 {
      // Limit recursion depth
      return Ok(());
    }

    if let Ok(entries) = std::fs::read_dir(dir) {
      for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
          // Check if this is a git repository
          if path.join(".git").exists() {
            self.process_git_repository(&path)?;
          } else {
            // Continue scanning subdirectories with Box::pin for recursion
            Box::pin(
              self.scan_directory_for_git_repos_with_depth(&path, depth + 1),
            )
            .await?;
          }
        }
      }
    }
    Ok(())
  }

  /// Process a single git repository and extract dependencies
  #[allow(clippy::unnecessary_wraps)]
  fn process_git_repository(
    &mut self,
    repo_path: &std::path::Path,
  ) -> Result<()> {
    let repo_name = repo_path
      .file_name()
      .and_then(|n| n.to_str())
      .unwrap_or("unknown");

    info!("📦 Processing git repository: {}", repo_name);

    // Extract dependencies from package files
    self.extract_dependencies_from_repo(repo_path);

    // Get git remote information for context
    if let Ok(remote_url) = Self::get_git_remote_url(repo_path) {
      info!("🔗 Repository remote: {}", remote_url);
    }

    Ok(())
  }

  /// Extract dependencies from package files in a repository
  fn extract_dependencies_from_repo(&mut self, repo_path: &std::path::Path) {
    // Look for package files in the repository
    let package_files = Self::find_package_files(repo_path);

    // Detect project language using file extensions
    let project_language = self.detect_project_language(repo_path);

    for package_file in package_files {
      match self.dependency_parser.parse_package_file(&package_file) {
        Ok(dependencies) => {
          // Register the project if we haven't seen it before
          let project_name = package_file
            .parent()
            .and_then(|p| p.file_name())
            .and_then(|n| n.to_str())
            .unwrap_or("unknown")
            .to_string();

          let discovered_project = DiscoveredProject {
            path: package_file.parent().unwrap_or(repo_path).to_path_buf(),
            name: project_name.clone(),
            language: project_language,
            dependencies: dependencies
              .iter()
              .map(|dep: &PackageDependency| VersionedDependency {
                name: dep.name.clone(),
                version: dep.version.clone(),
                ecosystem: dep.ecosystem.clone(),
                source: None,
                first_seen: Utc::now(),
                last_seen: Utc::now(),
                last_hit: Utc::now(),
                hit_count: 1,
                recent_hits: vec![Utc::now()],
                used_by_projects: vec![],
              })
              .collect(),
            last_scanned: SystemTime::now(),
            version: None, // Could be extracted from package file
            last_active: Utc::now(),
          };

          self.discovered_projects.insert(
            package_file.parent().unwrap_or(repo_path).to_path_buf(),
            discovered_project,
          );

          // Register each dependency
          for dep in dependencies {
            self.register_dependency(&dep.name, &dep.version, &dep.ecosystem);
            info!(
              "📊 Registered: {}@{} ({}) from {}",
              dep.name,
              dep.version,
              dep.ecosystem,
              package_file.display()
            );

            // TODO: Download dependency source and analyze it
            // This would involve:
            // 1. Download the dependency from npm/crates.io/hex/etc.
            // 2. Extract it to a temporary directory
            // 3. Call self.analyze_dependency_source(&temp_path, &dep.name).await
            //    (which uses SourceCodeParser for tree-sitter analysis)
            // 4. Clean up the temporary directory
          }
        }
        Err(e) => {
          warn!(
            "Failed to parse package file {}: {}",
            package_file.display(),
            e
          );
        }
      }
    }
  }

  /// Detect project language based on file extensions
  fn detect_project_language(
    &self,
    repo_path: &std::path::Path,
  ) -> ProgrammingLanguage {
    // Look for source files to detect language
    if let Ok(entries) = std::fs::read_dir(repo_path) {
      for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() {
          if let Some(extension) = path.extension().and_then(|ext| ext.to_str())
          {
            match extension {
              "ex" | "exs" => return ProgrammingLanguage::Elixir,
              "erl" | "hrl" => return ProgrammingLanguage::Erlang,
              "gleam" => return ProgrammingLanguage::Gleam,
              "rs" => return ProgrammingLanguage::Rust,
              "js" | "jsx" => return ProgrammingLanguage::JavaScript,
              "ts" | "tsx" => return ProgrammingLanguage::TypeScript,
              "py" => return ProgrammingLanguage::Python,
              "go" => return ProgrammingLanguage::Go,
              "java" => return ProgrammingLanguage::Java,
              "c" => return ProgrammingLanguage::C,
              "cpp" | "cc" | "cxx" => return ProgrammingLanguage::Cpp,
              "cs" => return ProgrammingLanguage::CSharp,
              "swift" => return ProgrammingLanguage::Swift,
              "kt" => return ProgrammingLanguage::Kotlin,
              _ => continue,
            }
          }
        }
      }
    }

    // Fallback to unknown if no source files found
    ProgrammingLanguage::Unknown
  }

  /// Analyze downloaded dependency source code using source code parser (temporarily disabled)
  async fn analyze_dependency_source(
    &self,
    dep_path: &std::path::Path,
    dep_name: &str,
  ) -> Result<()> {
    // Source code parser temporarily disabled due to compilation issues
    debug!(
      "Source code parser not available, skipping source analysis for {}",
      dep_name
    );
    Ok(())
  }

  /// Find source files in a directory
  fn find_source_files(
    &self,
    dir: &std::path::Path,
  ) -> Vec<std::path::PathBuf> {
    let mut source_files = Vec::new();

    if let Ok(entries) = std::fs::read_dir(dir) {
      for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file() {
          if let Some(extension) = path.extension().and_then(|ext| ext.to_str())
          {
            match extension {
              "ex" | "exs" | "erl" | "hrl" | "gleam" | "rs" | "js" | "jsx"
              | "ts" | "tsx" | "py" | "go" | "java" | "c" | "cpp" | "cc"
              | "cxx" | "cs" | "swift" | "kt" => {
                source_files.push(path);
              }
              _ => continue,
            }
          }
        } else if path.is_dir() {
          // Recursively search subdirectories (but limit depth to avoid infinite recursion)
          let sub_files = self.find_source_files(&path);
          source_files.extend(sub_files);
        }
      }
    }

    source_files
  }

  /// Find package files in a repository
  fn find_package_files(
    repo_path: &std::path::Path,
  ) -> Vec<std::path::PathBuf> {
    let mut package_files = Vec::new();

    // Common package file patterns
    let patterns = [
      "package.json",
      "Cargo.toml",
      "mix.exs",
      "requirements.txt",
      "pyproject.toml",
      "go.mod",
      "composer.json",
      "pom.xml",
      "build.gradle",
      "Podfile",
      "Gemfile",
    ];

    for pattern in &patterns {
      if let Some(entry) = walkdir::WalkDir::new(repo_path)
        .max_depth(3) // Don't go too deep
        .into_iter()
        .filter_map(Result::ok)
        .find(|e| e.file_name().to_string_lossy() == *pattern)
      {
        package_files.push(entry.path().to_path_buf());
      }
    }

    package_files
  }

  /// Register a dependency in the version registry
  fn register_dependency(
    &mut self,
    name: &str,
    version: &str,
    ecosystem: &str,
  ) {
    let now = Utc::now();

    // Get or create the versions list for this tool
    let versions = self
      .version_registry
      .active_versions
      .entry(name.to_string())
      .or_default();

    // Check if this version already exists
    if let Some(existing_version) =
      versions.iter_mut().find(|dep| dep.version == version)
    {
      // Update last hit time
      existing_version.last_hit = now;
      existing_version.recent_hits.push(now);
    } else {
      // Add new version
      versions.push(VersionedDependency {
        name: name.to_string(),
        version: version.to_string(),
        ecosystem: ecosystem.to_string(),
        source: None,
        first_seen: now,
        last_seen: now,
        last_hit: now,
        hit_count: 1,
        recent_hits: vec![now],
        used_by_projects: vec![],
      });
    }
  }

  /// Get git remote URL for a repository
  fn get_git_remote_url(repo_path: &std::path::Path) -> Result<String> {
    use std::process::Command;

    let output = Command::new("git")
      .args(["remote", "get-url", "origin"])
      .current_dir(repo_path)
      .output()
      .context("Failed to run git remote command")?;

    if output.status.success() {
      Ok(String::from_utf8(output.stdout)?.trim().to_string())
    } else {
      anyhow::bail!("Git remote command failed")
    }
  }

  /// Parse npm dependencies from package.json
  fn parse_npm_dependencies(content: &str) -> Vec<PackageDependency> {
    let package_json: serde_json::Value =
      serde_json::from_str(content).unwrap_or_default();
    let mut deps = Vec::new();

    if let Some(dependencies) =
      package_json.get("dependencies").and_then(|d| d.as_object())
    {
      for (name, version) in dependencies {
        deps.push(PackageDependency {
          name: name.clone(),
          version: version.as_str().unwrap_or("unknown").to_string(),
          ecosystem: "npm".to_string(),
        });
      }
    }

    if let Some(dev_deps) = package_json
      .get("devDependencies")
      .and_then(|d| d.as_object())
    {
      for (name, version) in dev_deps {
        deps.push(PackageDependency {
          name: name.clone(),
          version: version.as_str().unwrap_or("unknown").to_string(),
          ecosystem: "npm".to_string(),
        });
      }
    }

    deps
  }

  /// Parse Cargo dependencies from Cargo.toml
  fn parse_cargo_dependencies(content: &str) -> Vec<PackageDependency> {
    let cargo_toml: toml::Value = toml::from_str(content)
      .unwrap_or_else(|_| toml::Value::Table(toml::map::Map::new()));
    let mut deps = Vec::new();

    if let Some(dependencies) =
      cargo_toml.get("dependencies").and_then(|d| d.as_table())
    {
      for (name, version_info) in dependencies {
        let version = match version_info {
          toml::Value::String(v) => v.clone(),
          toml::Value::Table(t) => t
            .get("version")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string(),
          _ => "unknown".to_string(),
        };

        deps.push(PackageDependency {
          name: name.clone(),
          version,
          ecosystem: "cargo".to_string(),
        });
      }
    }

    deps
  }

  /// Parse Mix dependencies from mix.exs
  fn parse_mix_dependencies(content: &str) -> Vec<PackageDependency> {
    // Simple regex-based parsing for mix.exs
    let mut deps = Vec::new();
    let re = regex::Regex::new(r#"(\w+):\s*"([^"]+)""#).unwrap_or_else(|_| {
      // Fallback to a pattern that will never match - use a more complex pattern to avoid trivial regex warning
      #[allow(clippy::trivial_regex)]
      regex::Regex::new(r"^$").unwrap()
    });

    for cap in re.captures_iter(content) {
      if let (Some(name), Some(version)) = (cap.get(1), cap.get(2)) {
        deps.push(PackageDependency {
          name: name.as_str().to_string(),
          version: version.as_str().to_string(),
          ecosystem: "hex".to_string(),
        });
      }
    }

    deps
  }

  /// Parse pip dependencies from requirements.txt
  fn parse_pip_dependencies(content: &str) -> Vec<PackageDependency> {
    let mut deps = Vec::new();

    for line in content.lines() {
      let line = line.trim();
      if !line.is_empty() && !line.starts_with('#') {
        // Parse package==version or package>=version etc.
        let parts: Vec<&str> = line.split_whitespace().collect();
        if let Some(package_line) = parts.first() {
          let package_parts: Vec<&str> =
            package_line.splitn(2, &['=', '>', '<', '~', '!']).collect();
          if let Some(name) = package_parts.first() {
            let version = if package_parts.len() > 1 {
              package_parts[1].to_string()
            } else {
              "latest".to_string()
            };

            deps.push(PackageDependency {
              name: (*name).to_string(),
              version,
              ecosystem: "pypi".to_string(),
            });
          }
        }
      }
    }

    deps
  }

  /// Parse pyproject.toml dependencies
  fn parse_pyproject_dependencies(content: &str) -> Vec<PackageDependency> {
    let pyproject: toml::Value = toml::from_str(content)
      .unwrap_or_else(|_| toml::Value::Table(toml::map::Map::new()));
    let mut deps = Vec::new();

    if let Some(deps_table) = pyproject
      .get("project")
      .and_then(|p| p.get("dependencies"))
      .and_then(|d| d.as_array())
    {
      for dep in deps_table {
        if let Some(dep_str) = dep.as_str() {
          // Parse dependency string like "requests>=2.25.0"
          let parts: Vec<&str> =
            dep_str.splitn(2, &['=', '>', '<', '~', '!']).collect();
          if let Some(name) = parts.first() {
            let version = if parts.len() > 1 {
              parts[1].to_string()
            } else {
              "latest".to_string()
            };

            deps.push(PackageDependency {
              name: (*name).to_string(),
              version,
              ecosystem: "pypi".to_string(),
            });
          }
        }
      }
    }

    deps
  }

  /// Parse Go dependencies from go.mod (local discovery)
  fn parse_go_dependencies_local(content: &str) -> Vec<PackageDependency> {
    let mut deps = Vec::new();

    for line in content.lines() {
      let line = line.trim();
      if line.starts_with("require") {
        // Skip require line, dependencies follow
        continue;
      }
      if !line.is_empty()
        && !line.starts_with("//")
        && !line.starts_with("module")
      {
        // Parse "package version" format
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 {
          deps.push(PackageDependency {
            name: parts[0].to_string(),
            version: parts[1].to_string(),
            ecosystem: "go".to_string(),
          });
        }
      }
    }

    deps
  }

  /// Parse Composer dependencies from composer.json
  fn parse_composer_dependencies(content: &str) -> Vec<PackageDependency> {
    let composer_json: serde_json::Value =
      serde_json::from_str(content).unwrap_or_default();
    let mut deps = Vec::new();

    if let Some(dependencies) =
      composer_json.get("require").and_then(|d| d.as_object())
    {
      for (name, version) in dependencies {
        deps.push(PackageDependency {
          name: name.clone(),
          version: version.as_str().unwrap_or("unknown").to_string(),
          ecosystem: "packagist".to_string(),
        });
      }
    }

    deps
  }

  /// Start automatic orchestration with real-time package watching
  ///
  /// # Errors
  ///
  /// Returns an error if:
  /// - Local git repository discovery fails
  /// - Package file watcher fails to start
  /// - Initial discovery or knowledge population fails
  pub async fn start(&mut self) -> Result<()> {
    if self.is_running {
      warn!("Auto orchestrator already running");
      return Ok(());
    }

    info!(
      "🤖 Starting fully automatic FACT orchestration with local git discovery"
    );
    self.is_running = true;

    // Discover repositories from local git information (fastest approach)
    self.discover_local_git_repositories().await?;

    // Start real-time package file watcher (filtered to only package files)
    if self.config.watch_package_files {
      self.start_package_file_watcher();
    }

    // Initial discovery and population
    self.initial_discovery().await?;
    self.populate_initial_knowledge().await?;

    // Start background tasks
    self.start_background_tasks()?;

    info!("✅ Automatic FACT orchestration started successfully");
    Ok(())
  }

  /// Start real-time package file watcher (ONLY package manager files)
  #[cfg(feature = "orchestration")]
  fn start_package_file_watcher(&self) {
    use tokio::sync::mpsc;

    info!("🔍 Starting real-time package file watcher (filtered)");

    let (tx, mut rx) = mpsc::channel(1000);

    // Package files to watch (NOT all files to avoid overload)
    let package_files = [
      "mix.exs",
      "mix.lock",
      "gleam.toml",
      "rebar.config",
      "Cargo.toml",
      "Cargo.lock",
      "package.json",
      "package-lock.json",
      "yarn.lock",
      "pnpm-lock.yaml",
      "requirements.txt",
      "setup.py",
      "pyproject.toml",
      "Pipfile",
      "poetry.lock",
      "go.mod",
      "go.sum",
      "pom.xml",
      "build.gradle",
      "build.gradle.kts",
      "composer.json",
      "composer.lock",
      "Gemfile",
      "Gemfile.lock",
    ];

    // Create filtered file watcher
    let mut watcher = RecommendedWatcher::new(
      move |res: Result<Event, notify::Error>| {
        if let Ok(event) = res {
          // Filter to ONLY package manager files
          if let Some(path) = event.paths.first() {
            if let Some(filename) = path.file_name() {
              if let Some(filename_str) = filename.to_str() {
                if package_files.contains(&filename_str) {
                  info!("📦 Package file changed: {}", path.display());
                  let _ = tx.try_send(event);
                }
              }
            }
          }
        }
      },
      Config::default(),
    )?;

    // Watch scan directories for package file changes only
    for dir in &self.config.scan_directories {
      if dir.exists() {
        info!("👀 Watching {} for package file changes", dir.display());
        watcher.watch(dir, RecursiveMode::Recursive)?;
      }
    }

    // Background task to handle package file changes
    tokio::spawn(async move {
      while let Some(event) = rx.recv().await {
        match event.kind {
          EventKind::Create(_) | EventKind::Modify(_) => {
            for path in event.paths {
              info!("⚡ Real-time: Package file updated: {}", path.display());
              // TODO: Trigger immediate dependency re-parsing for this project
              // This would call parse_project_dependencies(&path) immediately
            }
          }
          _ => {}
        }
      }
    });
  }

  #[cfg(not(feature = "orchestration"))]
  #[allow(clippy::unused_self)]
  fn start_package_file_watcher(&self) {
    info!(
      "📦 Package file watching not available (orchestration feature disabled)"
    );
  }

  /// Three-tier cleanup: 30 days no hits (unless 4+ recent hits) OR 130 days maximum age
  ///
  /// # Errors
  ///
  /// Returns an error if version registry operations fail
  #[allow(clippy::needless_pass_by_ref_mut)]
  pub fn cleanup_unused_versions(&mut self) -> Result<()> {
    let no_hits_cutoff = Utc::now()
      - chrono::Duration::days(i64::from(
        self.version_registry.cleanup_no_hits_days,
      ));
    let max_age_cutoff = Utc::now()
      - chrono::Duration::days(i64::from(
        self.version_registry.cleanup_max_age_days,
      ));
    let recent_window = Utc::now() - chrono::Duration::days(30);

    let mut no_hits_count = 0;
    let mut max_age_count = 0;
    let mut recent_hits_saved = 0;

    info!(
      "🧹 Three-tier cleanup: no hits since {} (unless {}+ recent hits) OR created before {}",
      no_hits_cutoff.format("%Y-%m-%d"),
      self.version_registry.min_recent_hits_threshold,
      max_age_cutoff.format("%Y-%m-%d")
    );

    // Clean up versions with refined conditions
    for (tool_name, versions) in &mut self.version_registry.active_versions {
      versions.retain(|version| {
                // Count hits in the last 30 days
                let recent_hits_count = u32::try_from(version.recent_hits.iter()
                    .filter(|&&hit_time| hit_time > recent_window)
                    .count()).unwrap_or(0);

                // Rule 1: Remove if no hits for 30 days, UNLESS it has 4+ recent hits
                let no_hits_old = version.last_hit <= no_hits_cutoff;
                let has_enough_recent_hits = recent_hits_count >= self.version_registry.min_recent_hits_threshold;
                let should_remove_for_no_hits = no_hits_old && !has_enough_recent_hits;

                // Rule 2: Remove if older than 130 days (regardless of hits or references)
                let too_old = version.first_seen <= max_age_cutoff;

                let should_remove = should_remove_for_no_hits || too_old;
                if should_remove {
                    if too_old {
                        info!("🗑️  Removing old version: {}@{} (age: {} days, {} total hits, {} recent hits)", 
                            tool_name, version.version,
                            (Utc::now() - version.first_seen).num_days(),
                            version.hit_count,
                            recent_hits_count
                        );
                        max_age_count += 1;
                    } else {
                        info!("🗑️  Removing unused version: {}@{} (last hit: {}, {} recent hits < {})",
                            tool_name, version.version,
                            version.last_hit.format("%Y-%m-%d"),
                            recent_hits_count,
                            self.version_registry.min_recent_hits_threshold
                        );
                        no_hits_count += 1;
                    }
                } else if no_hits_old && has_enough_recent_hits {
                    // This version was saved by recent hits
                    info!("💾 Keeping version due to recent activity: {}@{} (last hit: {}, {} recent hits)",
                        tool_name, version.version,
                        version.last_hit.format("%Y-%m-%d"),
                        recent_hits_count
                    );
                    recent_hits_saved += 1;
                }

                !should_remove
            });
    }

    // Remove empty tool entries
    self
      .version_registry
      .active_versions
      .retain(|_, versions| !versions.is_empty());

    let total_cleaned = no_hits_count + max_age_count;
    if total_cleaned > 0 {
      info!(
        "✅ Cleaned up {} versions ({} no-hits, {} max-age), saved {} with recent activity",
        total_cleaned, no_hits_count, max_age_count, recent_hits_saved
      );
    } else {
      info!(
        "✅ No versions to clean up, {} saved by recent activity",
        recent_hits_saved
      );
    }

    Ok(())
  }

  /// Record a hit when a version is accessed/queried (with recent hits tracking)
  pub fn record_version_hit(&mut self, tool_name: &str, version: Option<&str>) {
    let now = Utc::now();

    if let Some(v) = version {
      // Hit on specific version: phoenix@1.7.0
      if let Some(versions) =
        self.version_registry.active_versions.get_mut(tool_name)
      {
        if let Some(versioned_dep) =
          versions.iter_mut().find(|dep| dep.version == v)
        {
          versioned_dep.last_hit = now;
          versioned_dep.hit_count += 1;

          // Add to recent hits and cleanup old entries
          versioned_dep.recent_hits.push(now);
          // Cleanup old recent hits inline to avoid borrowing issues
          let cutoff = chrono::Utc::now() - chrono::Duration::days(30);
          versioned_dep
            .recent_hits
            .retain(|&hit_time| hit_time > cutoff);

          debug!(
            "📊 Versioned hit: {}@{} (total: {}, recent: {})",
            tool_name,
            v,
            versioned_dep.hit_count,
            versioned_dep.recent_hits.len()
          );
        }
      }
    } else {
      // Hit on main/versionless: phoenix (latest/general)
      let versions = self
        .version_registry
        .active_versions
        .entry(tool_name.to_string())
        .or_default();

      if let Some(main_entry) =
        versions.iter_mut().find(|dep| dep.version == "main")
      {
        main_entry.last_hit = now;
        main_entry.hit_count += 1;

        // Add to recent hits and cleanup old entries
        main_entry.recent_hits.push(now);
        // Cleanup old recent hits inline to avoid borrowing issues
        let cutoff = chrono::Utc::now() - chrono::Duration::days(30);
        main_entry.recent_hits.retain(|&hit_time| hit_time > cutoff);

        debug!(
          "📊 Main hit: {} (total: {}, recent: {})",
          tool_name,
          main_entry.hit_count,
          main_entry.recent_hits.len()
        );
      } else {
        // Create main entry if doesn't exist
        versions.push(VersionedDependency {
          name: tool_name.to_string(),
          version: "main".to_string(),
          ecosystem: "versionless".to_string(),
          source: None,
          first_seen: now,
          last_seen: now,
          last_hit: now,
          hit_count: 1,
          recent_hits: vec![now],
          used_by_projects: vec!["general".to_string()],
        });
        debug!("📊 Main hit created: {} (first hit)", tool_name);
      }
    }
  }

  /// Remove recent hits older than 30 days to keep vector manageable
  #[allow(dead_code)]
  fn cleanup_old_recent_hits(recent_hits: &mut Vec<DateTime<Utc>>) {
    let cutoff = Utc::now() - chrono::Duration::days(30);
    recent_hits.retain(|&hit_time| hit_time > cutoff);
  }

  /// Check if FACT is ready or needs to be built (smart client waiting)
  ///
  /// # Errors
  ///
  /// Returns an error if FACT build operations fail
  pub async fn wait_for_fact_ready(
    &mut self,
    tool_name: &str,
    version: Option<&str>,
  ) -> Result<FactBuildResult> {
    let fact_query = version
      .map_or_else(|| tool_name.to_string(), |v| format!("{tool_name}@{v}"));

    // Check current status
    match self.version_registry.build_queue.get(&fact_query) {
      Some(FactBuildStatus::Ready) => {
        debug!("✅ FACT ready for query: {}", fact_query);
        Ok(FactBuildResult::Ready)
      }
      Some(FactBuildStatus::Building) => {
        info!("⏳ FACT already building, short wait: {}", fact_query);
        // Already building, do short wait
        return self.short_wait_for_build(&fact_query).await;
      }
      Some(FactBuildStatus::Queued { position }) => {
        info!(
          "⏳ FACT queued (position {}), short wait: {}",
          position, fact_query
        );
        return self.short_wait_for_build(&fact_query).await;
      }
      None => {
        // Not in queue, trigger build and short wait
        info!(
          "🚀 FACT missing (timeout/new repo), triggering build: {}",
          fact_query
        );
        self
          .version_registry
          .build_queue
          .insert(fact_query.clone(), FactBuildStatus::Building);

        // Trigger background build
        self.trigger_fact_build(&fact_query, tool_name, version)?;

        // Short wait for quick builds
        return self.short_wait_for_build(&fact_query).await;
      }
    }
  }

  /// Short wait (10 seconds) for FACT build, then return "building" status
  #[allow(clippy::cast_precision_loss)]
  async fn short_wait_for_build(
    &self,
    fact_query: &str,
  ) -> Result<FactBuildResult> {
    let max_quick_wait_seconds = 10;
    let mut wait_count = 0;
    let max_polls = max_quick_wait_seconds * 2; // 500ms intervals

    info!("⏳ Quick wait (max 10s) for FACT: {}", fact_query);

    while wait_count < max_polls {
      tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
      wait_count += 1;

      match self.version_registry.build_queue.get(fact_query) {
        Some(FactBuildStatus::Ready) => {
          info!(
            "✅ FACT quick build completed: {} ({}s)",
            fact_query,
            wait_count as f32 * 0.5
          );
          return Ok(FactBuildResult::Ready);
        }
        Some(FactBuildStatus::Building) => {
          debug!(
            "🔄 Still building: {} ({}s)",
            fact_query,
            wait_count as f32 * 0.5
          );
        }
        _ => {
          warn!("❌ FACT build failed during quick wait: {}", fact_query);
          return Ok(FactBuildResult::Failed);
        }
      }
    }

    // 10 seconds passed, still building - return "building" status
    info!(
      "⏰ FACT still building after 10s, returning 'building' status: {}",
      fact_query
    );
    Ok(FactBuildResult::Building)
  }

  /// Trigger FACT build for a specific tool/version (background task)
  #[allow(clippy::unused_self, clippy::unnecessary_wraps)]
  fn trigger_fact_build(
    &self,
    fact_query: &str,
    tool_name: &str,
    version: Option<&str>,
  ) -> Result<()> {
    info!("🔨 Building FACT: {} (estimated 2-10 seconds)", fact_query);

    let fact_query_owned = fact_query.to_string();
    let _tool_name_owned = tool_name.to_string();
    let _version_owned = version.map(std::string::ToString::to_string);

    // Background task for FACT building
    tokio::spawn(async move {
      // Simulate FACT building process (replace with actual FACT generation)
      tokio::time::sleep(tokio::time::Duration::from_secs(3)).await; // Typical build time

      info!("✅ FACT build completed: {}", fact_query_owned);
      // TODO: Update build_queue status to Ready
      // self.version_registry.build_queue.insert(fact_query_owned, FactBuildStatus::Ready);
    });

    Ok(())
  }

  /// Example usage: Handle client query with smart building
  ///
  /// # Errors
  ///
  /// Returns an error if FACT operations fail
  pub async fn handle_fact_query(
    &mut self,
    tool_name: &str,
    version: Option<&str>,
  ) -> Result<String> {
    match self.wait_for_fact_ready(tool_name, version).await? {
      FactBuildResult::Ready => {
        // Record hit and serve FACT
        self.record_version_hit(tool_name, version);

        let fact_query = version.map_or_else(
          || tool_name.to_string(),
          |v| format!("{tool_name}@{v}"),
        );

        info!("📖 Serving FACT: {}", fact_query);
        // TODO: Fetch actual FACT content from storage
        Ok(format!("FACT content for {fact_query}"))
      }
      FactBuildResult::Building => {
        // Still building after 10s wait - tell client to retry
        let retry_msg = format!(
          "FACT for {} is building. Please try again in 30 seconds.",
          version.map_or_else(
            || tool_name.to_string(),
            |v| format!("{tool_name}@{v}")
          )
        );
        info!("🔄 {}", retry_msg);
        Ok(retry_msg)
      }
      FactBuildResult::Failed => {
        let error_msg = format!(
          "Failed to build FACT for {}",
          version.map_or_else(
            || tool_name.to_string(),
            |v| format!("{tool_name}@{v}")
          )
        );
        warn!("❌ {}", error_msg);
        Ok(error_msg)
      }
    }
  }

  /// Stop automatic orchestration
  pub fn stop(&mut self) {
    info!("🛑 Stopping automatic FACT orchestration");
    self.is_running = false;
  }

  /// Initial discovery of all projects and dependencies
  async fn initial_discovery(&mut self) -> Result<()> {
    info!("🔍 Starting initial project discovery");

    for scan_dir in &self.config.scan_directories.clone() {
      if scan_dir.exists() {
        self.discover_projects_in_directory(scan_dir).await?;
      } else {
        debug!("Skipping non-existent directory: {:?}", scan_dir);
      }
    }

    info!("📊 Discovered {} projects", self.discovered_projects.len());
    Ok(())
  }

  /// Discover projects in a specific directory
  async fn discover_projects_in_directory(&mut self, dir: &Path) -> Result<()> {
    let mut entries = fs::read_dir(dir).await?;

    while let Some(entry) = entries.next_entry().await? {
      let path = entry.path();

      if path.is_dir() {
        // Check if this is a project directory
        if let Some(project) = self.analyze_directory(&path).await? {
          self.discovered_projects.insert(path.clone(), project);
        }

        // Recursively scan subdirectories (with depth limit)
        if path.file_name().is_some_and(|name| {
          !name.to_string_lossy().starts_with('.')
            && name != "node_modules"
            && name != "target"
            && name != "_build"
        }) {
          Box::pin(self.discover_projects_in_directory(&path))
            .await
            .ok();
        }
      }
    }

    Ok(())
  }

  /// Analyze a directory to determine if it's a project
  async fn analyze_directory(
    &self,
    dir: &Path,
  ) -> Result<Option<DiscoveredProject>> {
    for pattern in &self.config.monitor_patterns {
      let file_path = dir.join(pattern);
      if file_path.exists() {
        debug!("Found project file: {:?}", file_path);
        return self.create_project_from_file(&file_path, dir).await;
      }
    }
    Ok(None)
  }

  /// Create project info from discovered file
  #[allow(clippy::cognitive_complexity, clippy::too_many_lines)]
  async fn create_project_from_file(
    &self,
    file_path: &Path,
    project_dir: &Path,
  ) -> Result<Option<DiscoveredProject>> {
    let file_name =
      file_path.file_name().and_then(|n| n.to_str()).unwrap_or("");

    let (language, dependencies) = match file_name {
      // BEAM Ecosystem
      "mix.exs" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Elixir,
          Self::parse_elixir_dependencies(&content),
        )
      }
      "gleam.toml" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Gleam,
          Self::parse_gleam_dependencies(&content),
        )
      }
      "rebar.config" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Erlang,
          Self::parse_erlang_dependencies(&content),
        )
      }
      // Rust
      "Cargo.toml" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Rust,
          Self::parse_rust_dependencies(&content),
        )
      }
      // Node.js/JavaScript
      "package.json" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::JavaScript,
          Self::parse_nodejs_dependencies(&content),
        )
      }
      // Python
      "requirements.txt" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Python,
          Self::parse_python_requirements(&content),
        )
      }
      "setup.py" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Python,
          Self::parse_python_setup(&content),
        )
      }
      "pyproject.toml" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Python,
          Self::parse_python_pyproject(&content),
        )
      }
      "Pipfile" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Python,
          Self::parse_python_pipfile(&content),
        )
      }
      // Go
      "go.mod" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Go,
          self.parse_go_dependencies(&content),
        )
      }
      // Java/JVM
      "pom.xml" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Java,
          self.parse_maven_dependencies(&content),
        )
      }
      "build.gradle" | "build.gradle.kts" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Java,
          self.parse_gradle_dependencies(&content),
        )
      }
      "project.clj" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Clojure,
          self.parse_clojure_dependencies(&content),
        )
      }
      // Ruby
      "Gemfile" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Ruby,
          self.parse_ruby_dependencies(&content),
        )
      }
      // PHP
      "composer.json" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::PHP,
          self.parse_php_dependencies(&content),
        )
      }
      // .NET
      name
        if name.ends_with(".csproj")
          || name.ends_with(".fsproj")
          || name.ends_with(".vbproj") =>
      {
        let content = fs::read_to_string(file_path).await?;
        let lang = if name.ends_with(".fsproj") {
          ProgrammingLanguage::FSharp
        } else if name.ends_with(".vbproj") {
          ProgrammingLanguage::VB
        } else {
          ProgrammingLanguage::CSharp
        };
        (lang, self.parse_dotnet_dependencies(&content))
      }
      // Swift
      "Package.swift" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Swift,
          self.parse_swift_dependencies(&content),
        )
      }
      "Podfile" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Swift,
          self.parse_cocoapods_dependencies(&content),
        )
      }
      // Dart
      "pubspec.yaml" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Dart,
          self.parse_dart_dependencies(&content),
        )
      }
      // Haskell
      name
        if std::path::Path::new(name)
          .extension()
          .is_some_and(|ext| ext.eq_ignore_ascii_case("cabal")) =>
      {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Haskell,
          self.parse_haskell_dependencies(&content),
        )
      }
      "stack.yaml" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Haskell,
          self.parse_haskell_stack_dependencies(&content),
        )
      }
      // Perl
      "cpanfile" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Perl,
          self.parse_perl_dependencies(&content),
        )
      }
      // R
      "DESCRIPTION" => {
        let content = fs::read_to_string(file_path).await?;
        (ProgrammingLanguage::R, self.parse_r_dependencies(&content))
      }
      // Julia
      "Project.toml" => {
        let content = fs::read_to_string(file_path).await?;
        (
          ProgrammingLanguage::Julia,
          self.parse_julia_dependencies(&content),
        )
      }
      _ => return Ok(None),
    };

    let project_name = project_dir
      .file_name()
      .and_then(|n| n.to_str())
      .unwrap_or("unknown")
      .to_string();

    Ok(Some(DiscoveredProject {
      path: project_dir.to_path_buf(),
      name: project_name,
      language,
      dependencies,
      last_scanned: SystemTime::now(),
      version: None,
      last_active: chrono::Utc::now(),
    }))
  }

  /// Parse Elixir dependencies from mix.exs
  fn parse_elixir_dependencies(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Regex patterns for different dependency formats
    let hex_pattern = regex::Regex::new(r#"\{:(\w+),\s*"([^"]+)"\}"#).unwrap();
    let github_pattern = regex::Regex::new(
      r#"\{:(\w+),\s*github:\s*"([^"]+)"(?:,\s*ref:\s*"([^"]+)")?\}"#,
    )
    .unwrap();

    // Parse Hex dependencies
    for caps in hex_pattern.captures_iter(content) {
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version: caps[2].to_string(),

        ecosystem: "beam".to_string(),

        source: Some("hex".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    // Parse GitHub dependencies
    for caps in github_pattern.captures_iter(content) {
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version: caps
          .get(3)
          .map_or("latest".to_string(), |m| m.as_str().to_string()),

        ecosystem: "beam".to_string(),

        source: Some(format!("github:{}", &caps[2])),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse Gleam dependencies from gleam.toml
  fn parse_gleam_dependencies(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple TOML parsing for Gleam dependencies
    let lines: Vec<&str> = content.lines().collect();
    let mut in_deps_section = false;

    for line in lines {
      let trimmed = line.trim();

      if trimmed == "[dependencies]" {
        in_deps_section = true;
        continue;
      }

      if in_deps_section
        && trimmed.starts_with('[')
        && trimmed != "[dependencies]"
      {
        in_deps_section = false;
      }

      if in_deps_section && trimmed.contains('=') {
        if let Some((name, version)) = trimmed.split_once('=') {
          let name = name.trim().trim_matches('"');
          let version = version.trim().trim_matches('"');

          let now = chrono::Utc::now();
          deps.push(VersionedDependency {
            name: name.to_string(),

            version: version.to_string(),

            ecosystem: "beam".to_string(),

            source: Some("hex".to_string()), // Gleam uses Hex,

            first_seen: now,

            last_seen: now,

            last_hit: now,

            hit_count: 0,

            recent_hits: vec![],

            used_by_projects: vec![],
          });
        }
      }
    }

    deps
  }

  /// Parse Rust dependencies from Cargo.toml
  fn parse_rust_dependencies(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Parse [dependencies] section
    if let Some(deps_start) = content.find("[dependencies]") {
      let deps_section = &content[deps_start..];
      if let Some(next_section) = deps_section.find("\n[") {
        let deps_only = &deps_section[..next_section];

        for line in deps_only.lines().skip(1) {
          let trimmed = line.trim();
          if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
          }

          if let Some((name, version_spec)) = trimmed.split_once('=') {
            let name = name.trim();
            let version = if version_spec.trim().starts_with('"') {
              version_spec.trim().trim_matches('"').to_string()
            } else {
              "latest".to_string()
            };

            let now = chrono::Utc::now();
            deps.push(VersionedDependency {
              name: (*name).to_string(),

              version,

              ecosystem: "rust".to_string(),

              source: Some("crates.io".to_string()),

              first_seen: now,

              last_seen: now,

              last_hit: now,

              hit_count: 0,

              recent_hits: vec![],

              used_by_projects: vec![],
            });
          }
        }
      }
    }

    deps
  }

  /// Parse Node.js dependencies from package.json
  fn parse_nodejs_dependencies(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    if let Ok(json) = serde_json::from_str::<serde_json::Value>(content) {
      // Parse regular dependencies
      if let Some(dependencies) =
        json.get("dependencies").and_then(|d| d.as_object())
      {
        for (name, version) in dependencies {
          if let Some(version_str) = version.as_str() {
            let now = chrono::Utc::now();
            deps.push(VersionedDependency {
              name: name.clone(),

              version: version_str.to_string(),

              ecosystem: "nodejs".to_string(),

              source: Some("npm".to_string()),

              first_seen: now,

              last_seen: now,

              last_hit: now,

              hit_count: 0,

              recent_hits: vec![],

              used_by_projects: vec![],
            });
          }
        }
      }

      // Parse dev dependencies
      if let Some(dev_dependencies) =
        json.get("devDependencies").and_then(|d| d.as_object())
      {
        for (name, version) in dev_dependencies {
          if let Some(version_str) = version.as_str() {
            let now = chrono::Utc::now();
            deps.push(VersionedDependency {
              name: name.clone(),

              version: version_str.to_string(),

              ecosystem: "nodejs".to_string(),

              source: Some("npm".to_string()),

              first_seen: now,

              last_seen: now,

              last_hit: now,

              hit_count: 0,

              recent_hits: vec![],

              used_by_projects: vec![],
            });
          }
        }
      }
    }

    deps
  }

  /// Parse Erlang dependencies from rebar.config
  fn parse_erlang_dependencies(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple pattern matching for Erlang rebar.config dependencies
    let dep_pattern = regex::Regex::new(r#"\{(\w+),\s*"([^"]+)"\}"#).unwrap();

    for caps in dep_pattern.captures_iter(content) {
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version: caps[2].to_string(),

        ecosystem: "beam".to_string(),

        source: Some("hex".to_string()), // Erlang also uses Hex,

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse Python requirements.txt dependencies
  fn parse_python_requirements(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    for line in content.lines() {
      let trimmed = line.trim();
      if trimmed.is_empty() || trimmed.starts_with('#') {
        continue;
      }

      // Parse requirements like "package==version" or "package>=version"
      let now = chrono::Utc::now();
      if let Some((name, version)) = trimmed.split_once("==") {
        deps.push(VersionedDependency {
          name: name.trim().to_string(),

          version: version.trim().to_string(),

          ecosystem: "python".to_string(),

          source: Some("pypi".to_string()),

          first_seen: now,

          last_seen: now,

          last_hit: now,

          hit_count: 0,

          recent_hits: vec![],

          used_by_projects: vec![],
        });
      } else if let Some((name, version)) = trimmed.split_once(">=") {
        deps.push(VersionedDependency {
          name: name.trim().to_string(),

          version: format!(">={}", version.trim()),

          ecosystem: "python".to_string(),

          source: Some("pypi".to_string()),

          first_seen: now,

          last_seen: now,

          last_hit: now,

          hit_count: 0,

          recent_hits: vec![],

          used_by_projects: vec![],
        });
      } else {
        deps.push(VersionedDependency {
          name: trimmed.to_string(),

          version: "latest".to_string(),

          ecosystem: "python".to_string(),

          source: Some("pypi".to_string()),

          first_seen: now,

          last_seen: now,

          last_hit: now,

          hit_count: 0,

          recent_hits: vec![],

          used_by_projects: vec![],
        });
      }
    }

    deps
  }

  /// Parse Python setup.py dependencies (basic extraction)
  fn parse_python_setup(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Look for install_requires patterns
    if let Some(start) = content.find("install_requires") {
      let after_requires = &content[start..];
      if let Some(bracket_start) = after_requires.find('[') {
        if let Some(bracket_end) = after_requires.find(']') {
          let deps_str = &after_requires[bracket_start + 1..bracket_end];

          // Extract quoted package names
          let package_pattern =
            regex::Regex::new(r#"['"]([\w-]+)(?:[><=!~]+[^'"]*)?['"]"#)
              .unwrap();
          for caps in package_pattern.captures_iter(deps_str) {
            let now = chrono::Utc::now();
            deps.push(VersionedDependency {
              name: caps[1].to_string(),

              version: "latest".to_string(),

              ecosystem: "python".to_string(),

              source: Some("pypi".to_string()),

              first_seen: now,

              last_seen: now,

              last_hit: now,

              hit_count: 0,

              recent_hits: vec![],

              used_by_projects: vec![],
            });
          }
        }
      }
    }

    deps
  }

  /// Parse Python pyproject.toml dependencies
  fn parse_python_pyproject(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple TOML parsing for dependencies section
    let lines: Vec<&str> = content.lines().collect();
    let mut in_deps_section = false;

    for line in lines {
      let trimmed = line.trim();

      if trimmed == "[tool.poetry.dependencies]"
        || trimmed == "[project.dependencies]"
      {
        in_deps_section = true;
        continue;
      }

      if in_deps_section
        && trimmed.starts_with('[')
        && !trimmed.starts_with("[tool.poetry.dependencies]")
      {
        in_deps_section = false;
      }

      if in_deps_section && trimmed.contains('=') && !trimmed.starts_with('#') {
        if let Some((name, version)) = trimmed.split_once('=') {
          let name = name.trim().trim_matches('"');
          let version = version.trim().trim_matches('"');

          let now = chrono::Utc::now();
          deps.push(VersionedDependency {
            name: name.to_string(),

            version: version.to_string(),

            ecosystem: "python".to_string(),

            source: Some("pypi".to_string()),

            first_seen: now,

            last_seen: now,

            last_hit: now,

            hit_count: 0,

            recent_hits: vec![],

            used_by_projects: vec![],
          });
        }
      }
    }

    deps
  }

  /// Parse Python Pipfile dependencies
  fn parse_python_pipfile(content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple TOML parsing for [packages] section
    let lines: Vec<&str> = content.lines().collect();
    let mut in_packages_section = false;

    for line in lines {
      let trimmed = line.trim();

      if trimmed == "[packages]" {
        in_packages_section = true;
        continue;
      }

      if in_packages_section && trimmed.starts_with('[') {
        in_packages_section = false;
      }

      if in_packages_section
        && trimmed.contains('=')
        && !trimmed.starts_with('#')
      {
        if let Some((name, version)) = trimmed.split_once('=') {
          let name = name.trim().trim_matches('"');
          let version = version.trim().trim_matches('"');

          let now = chrono::Utc::now();
          deps.push(VersionedDependency {
            name: name.to_string(),

            version: version.to_string(),

            ecosystem: "python".to_string(),

            source: Some("pypi".to_string()),

            first_seen: now,

            last_seen: now,

            last_hit: now,

            hit_count: 0,

            recent_hits: vec![],

            used_by_projects: vec![],
          });
        }
      }
    }

    deps
  }

  /// Parse Go dependencies from go.mod
  #[allow(clippy::unused_self)]
  fn parse_go_dependencies(&self, content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();
    let mut in_require = false;

    for line in content.lines() {
      let trimmed = line.trim();

      if trimmed.starts_with("require") {
        in_require = true;
        continue;
      }

      if in_require && trimmed == ")" {
        in_require = false;
        continue;
      }

      if in_require && !trimmed.is_empty() && !trimmed.starts_with("//") {
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() >= 2 {
          let now = chrono::Utc::now();
          deps.push(VersionedDependency {
            name: parts[0].to_string(),

            version: parts[1].to_string(),

            ecosystem: "go".to_string(),

            source: Some("go".to_string()),

            first_seen: now,

            last_seen: now,

            last_hit: now,

            hit_count: 0,

            recent_hits: vec![],

            used_by_projects: vec![],
          });
        }
      }
    }

    deps
  }

  /// Parse Maven dependencies from pom.xml (basic extraction)
  #[allow(clippy::unused_self)]
  fn parse_maven_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple XML parsing for <dependency> tags
    let dep_pattern = regex::Regex::new(
            r"<dependency>.*?<groupId>([^<]+)</groupId>.*?<artifactId>([^<]+)</artifactId>.*?<version>([^<]+)</version>.*?</dependency>"
        ).unwrap();

    for caps in dep_pattern.captures_iter(content) {
      let name = format!("{}:{}", caps[1].trim(), caps[2].trim());
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name,

        version: caps[3].trim().to_string(),

        ecosystem: "java".to_string(),

        source: Some("maven".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse Gradle dependencies (basic extraction)
  #[allow(clippy::unused_self)]
  fn parse_gradle_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple pattern for Gradle dependencies like implementation 'group:artifact:version'
    let dep_pattern = regex::Regex::new(
      r#"(?:implementation|compile|api)\s+['"]([^:]+):([^:]+):([^'"]+)['"]"#,
    )
    .unwrap();

    for caps in dep_pattern.captures_iter(content) {
      let name = format!("{}:{}", caps[1].trim(), caps[2].trim());
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name,

        version: caps[3].trim().to_string(),

        ecosystem: "java".to_string(),

        source: Some("maven".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse Clojure dependencies from project.clj
  #[allow(clippy::unused_self)]
  fn parse_clojure_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple pattern for Clojure dependencies like [group/artifact "version"]
    let dep_pattern =
      regex::Regex::new(r#"\[([^\s\]]+)\s+"([^"]+)"\]"#).unwrap();

    for caps in dep_pattern.captures_iter(content) {
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version: caps[2].to_string(),

        ecosystem: "clojure".to_string(),

        source: Some("maven".to_string()), // Clojure uses Maven repos,

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse Ruby dependencies from Gemfile
  #[allow(clippy::unused_self)]
  fn parse_ruby_dependencies(&self, content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Parse gem declarations like gem 'name', 'version'
    let gem_pattern = regex::Regex::new(
      r#"gem\s+['"]([^'"]+)['"](?:\s*,\s*['"]([^'"]+)['"])?"#,
    )
    .unwrap();

    for caps in gem_pattern.captures_iter(content) {
      let version = caps
        .get(2)
        .map_or_else(|| "latest".to_string(), |m| m.as_str().to_string());
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version,

        ecosystem: "ruby".to_string(),

        source: Some("rubygems".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse PHP dependencies from composer.json
  #[allow(clippy::unused_self)]
  fn parse_php_dependencies(&self, content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    if let Ok(json) = serde_json::from_str::<serde_json::Value>(content) {
      // Parse require and require-dev sections
      for section in ["require", "require-dev"] {
        if let Some(dependencies) =
          json.get(section).and_then(|d| d.as_object())
        {
          for (name, version) in dependencies {
            if name != "php" {
              // Skip PHP version constraint
              if let Some(version_str) = version.as_str() {
                let now = chrono::Utc::now();
                deps.push(VersionedDependency {
                  name: name.clone(),

                  version: version_str.to_string(),

                  ecosystem: "php".to_string(),

                  source: Some("packagist".to_string()),

                  first_seen: now,

                  last_seen: now,

                  last_hit: now,

                  hit_count: 0,

                  recent_hits: vec![],

                  used_by_projects: vec![],
                });
              }
            }
          }
        }
      }
    }

    deps
  }

  /// Parse .NET dependencies from project files
  #[allow(clippy::unused_self)]
  fn parse_dotnet_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Parse PackageReference elements
    let package_pattern = regex::Regex::new(
      r#"<PackageReference\s+Include="([^"]+)"\s+Version="([^"]+)""#,
    )
    .unwrap();

    for caps in package_pattern.captures_iter(content) {
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version: caps[2].to_string(),

        ecosystem: "dotnet".to_string(),

        source: Some("nuget".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse Swift Package Manager dependencies
  #[allow(clippy::unused_self)]
  fn parse_swift_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Simple pattern for Swift Package Manager dependencies
    let dep_pattern = regex::Regex::new(
      r#"\.package\(url:\s*"([^"]+)",\s*from:\s*"([^"]+)"\)"#,
    )
    .unwrap();

    for caps in dep_pattern.captures_iter(content) {
      let name = caps[1]
        .split('/')
        .next_back()
        .unwrap_or(&caps[1])
        .to_string();
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name,

        version: caps[2].to_string(),

        ecosystem: "swift".to_string(),

        source: Some("swiftpm".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse `CocoaPods` dependencies from Podfile
  #[allow(clippy::unused_self)]
  fn parse_cocoapods_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Parse pod declarations
    let pod_pattern = regex::Regex::new(
      r#"pod\s+['"]([^'"]+)['"](?:\s*,\s*['"]([^'"]+)['"])?"#,
    )
    .unwrap();

    for caps in pod_pattern.captures_iter(content) {
      let version = caps
        .get(2)
        .map_or_else(|| "latest".to_string(), |m| m.as_str().to_string());
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version,

        ecosystem: "swift".to_string(),

        source: Some("cocoapods".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse Dart dependencies from pubspec.yaml
  #[allow(clippy::unused_self)]
  fn parse_dart_dependencies(&self, content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    let lines: Vec<&str> = content.lines().collect();
    let mut in_deps_section = false;

    for line in lines {
      let trimmed = line.trim();

      if trimmed == "dependencies:" || trimmed == "dev_dependencies:" {
        in_deps_section = true;
        continue;
      }

      if in_deps_section && !trimmed.starts_with(' ') && trimmed.ends_with(':')
      {
        in_deps_section = false;
      }

      if in_deps_section && trimmed.contains(':') && !trimmed.starts_with('#') {
        if let Some((name, version)) = trimmed.split_once(':') {
          let name = name.trim();
          let version = version.trim().trim_matches('"').trim_matches('\'');

          if !name.is_empty() && !version.is_empty() {
            let now = chrono::Utc::now();
            deps.push(VersionedDependency {
              name: (*name).to_string(),

              version: version.to_string(),

              ecosystem: "dart".to_string(),

              source: Some("pub".to_string()),

              first_seen: now,

              last_seen: now,

              last_hit: now,

              hit_count: 0,

              recent_hits: vec![],

              used_by_projects: vec![],
            });
          }
        }
      }
    }

    deps
  }

  /// Parse Haskell dependencies from .cabal files
  #[allow(clippy::unused_self)]
  fn parse_haskell_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Look for build-depends sections
    let lines: Vec<&str> = content.lines().collect();
    let mut in_build_depends = false;

    for line in lines {
      let trimmed = line.trim();

      if trimmed.starts_with("build-depends:") {
        in_build_depends = true;
        // Parse the same line
        if let Some(deps_part) = trimmed.strip_prefix("build-depends:") {
          self.parse_haskell_deps_line(deps_part, &mut deps);
        }
        continue;
      }

      if in_build_depends {
        if trimmed.is_empty() || !trimmed.starts_with(' ') {
          in_build_depends = false;
        } else {
          self.parse_haskell_deps_line(trimmed, &mut deps);
        }
      }
    }

    deps
  }

  #[allow(clippy::unused_self)]
  fn parse_haskell_deps_line(
    &self,
    line: &str,
    deps: &mut Vec<VersionedDependency>,
  ) {
    for dep_spec in line.split(',') {
      let dep_spec = dep_spec.trim();
      if !dep_spec.is_empty() && dep_spec != "base" {
        let name = dep_spec.split_whitespace().next().unwrap_or(dep_spec);
        let now = chrono::Utc::now();
        deps.push(VersionedDependency {
          name: name.to_string(),

          version: "latest".to_string(),

          ecosystem: "haskell".to_string(),

          source: Some("hackage".to_string()),

          first_seen: now,

          last_seen: now,

          last_hit: now,

          hit_count: 0,

          recent_hits: vec![],

          used_by_projects: vec![],
        });
      }
    }
  }

  /// Parse Haskell Stack dependencies from stack.yaml
  #[allow(clippy::unused_self)]
  fn parse_haskell_stack_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    let lines: Vec<&str> = content.lines().collect();
    let mut in_extra_deps = false;

    for line in lines {
      let trimmed = line.trim();

      if trimmed == "extra-deps:" {
        in_extra_deps = true;
        continue;
      }

      if in_extra_deps && !trimmed.starts_with('-') && !trimmed.starts_with(' ')
      {
        in_extra_deps = false;
      }

      if in_extra_deps && trimmed.starts_with('-') {
        let dep = trimmed.trim_start_matches('-').trim();
        if let Some((name, version)) = dep.split_once('-') {
          let now = chrono::Utc::now();
          deps.push(VersionedDependency {
            name: name.to_string(),

            version: version.to_string(),

            ecosystem: "haskell".to_string(),

            source: Some("hackage".to_string()),

            first_seen: now,

            last_seen: now,

            last_hit: now,

            hit_count: 0,

            recent_hits: vec![],

            used_by_projects: vec![],
          });
        }
      }
    }

    deps
  }

  /// Parse Perl dependencies from cpanfile
  #[allow(clippy::unused_self)]
  fn parse_perl_dependencies(&self, content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    // Parse requires statements
    let requires_pattern = regex::Regex::new(
      r#"requires\s+['"]([^'"]+)['"](?:\s*,\s*['"]([^'"]+)['"])?"#,
    )
    .unwrap();

    for caps in requires_pattern.captures_iter(content) {
      let version = caps
        .get(2)
        .map_or_else(|| "latest".to_string(), |m| m.as_str().to_string());
      let now = chrono::Utc::now();
      deps.push(VersionedDependency {
        name: caps[1].to_string(),

        version,

        ecosystem: "perl".to_string(),

        source: Some("cpan".to_string()),

        first_seen: now,

        last_seen: now,

        last_hit: now,

        hit_count: 0,

        recent_hits: vec![],

        used_by_projects: vec![],
      });
    }

    deps
  }

  /// Parse R dependencies from DESCRIPTION file
  #[allow(clippy::unused_self)]
  fn parse_r_dependencies(&self, content: &str) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    let lines: Vec<&str> = content.lines().collect();
    let mut in_imports = false;
    let mut in_depends = false;

    for line in lines {
      if line.starts_with("Imports:") {
        in_imports = true;
        in_depends = false;
        // Parse the same line
        if let Some(deps_part) = line.strip_prefix("Imports:") {
          self.parse_r_deps_line(deps_part, &mut deps);
        }
        continue;
      }

      if line.starts_with("Depends:") {
        in_depends = true;
        in_imports = false;
        if let Some(deps_part) = line.strip_prefix("Depends:") {
          self.parse_r_deps_line(deps_part, &mut deps);
        }
        continue;
      }

      if (in_imports || in_depends) && line.starts_with(' ') {
        self.parse_r_deps_line(line, &mut deps);
      } else if (in_imports || in_depends) && !line.starts_with(' ') {
        in_imports = false;
        in_depends = false;
      }
    }

    deps
  }

  #[allow(clippy::unused_self)]
  fn parse_r_deps_line(&self, line: &str, deps: &mut Vec<VersionedDependency>) {
    for dep_spec in line.split(',') {
      let dep_spec = dep_spec.trim();
      if !dep_spec.is_empty() && dep_spec != "R" {
        let name = dep_spec.split_whitespace().next().unwrap_or(dep_spec);
        if !name.is_empty() {
          let now = chrono::Utc::now();
          deps.push(VersionedDependency {
            name: name.to_string(),

            version: "latest".to_string(),

            ecosystem: "r".to_string(),

            source: Some("maven".to_string()), // R uses CRAN, but we don't have that enum variant,

            first_seen: now,

            last_seen: now,

            last_hit: now,

            hit_count: 0,

            recent_hits: vec![],

            used_by_projects: vec![],
          });
        }
      }
    }
  }

  /// Parse Julia dependencies from Project.toml
  #[allow(clippy::unused_self)]
  fn parse_julia_dependencies(
    &self,
    content: &str,
  ) -> Vec<VersionedDependency> {
    let mut deps = Vec::new();

    let lines: Vec<&str> = content.lines().collect();
    let mut in_deps_section = false;

    for line in lines {
      let trimmed = line.trim();

      if trimmed == "[deps]" {
        in_deps_section = true;
        continue;
      }

      if in_deps_section && trimmed.starts_with('[') {
        in_deps_section = false;
      }

      if in_deps_section && trimmed.contains('=') && !trimmed.starts_with('#') {
        if let Some((name, _uuid)) = trimmed.split_once('=') {
          let name = name.trim().trim_matches('"');
          let now = chrono::Utc::now();
          deps.push(VersionedDependency {
            name: name.to_string(),

            version: "latest".to_string(),

            ecosystem: "julia".to_string(),

            source: Some("maven".to_string()), // Julia has its own registry, but we don't have that enum,

            first_seen: now,

            last_seen: now,

            last_hit: now,

            hit_count: 0,

            recent_hits: vec![],

            used_by_projects: vec![],
          });
        }
      }
    }

    deps
  }

  /// Populate initial knowledge base automatically
  #[allow(clippy::unused_self, clippy::unnecessary_wraps)]
  async fn populate_initial_knowledge(&mut self) -> Result<()> {
    info!("📚 Populating initial FACT knowledge base");

    // Collect all unique dependencies across all projects
    let mut all_dependencies: HashMap<String, String> = HashMap::new();

    for project in self.discovered_projects.values() {
      for dep in &project.dependencies {
        // Use latest version found for each dependency
        let current_version = all_dependencies.get(&dep.name);
        if current_version.is_none() || dep.version > *current_version.unwrap()
        {
          all_dependencies.insert(dep.name.clone(), dep.version.clone());
        }
      }
    }

    info!("Found {} unique dependencies", all_dependencies.len());

    // Auto-populate knowledge for each dependency sequentially to avoid borrowing issues
    #[cfg(feature = "github")]
    if let Some(_github) = &self.github {
      let max_concurrent = self.config.max_concurrent;
      let mut processed = 0;

      for (dep_name, version) in all_dependencies {
        if processed >= max_concurrent {
          // Small delay to respect rate limits
          tokio::time::sleep(Duration::from_millis(500)).await;
          processed = 0;
        }

        if let Err(e) =
          self.populate_single_dependency(&dep_name, &version).await
        {
          warn!(
            "Failed to populate knowledge for {}@{}: {}",
            dep_name, version, e
          );
        }

        processed += 1;
      }
    }

    info!("✅ Initial knowledge base population completed");
    Ok(())
  }

  /// Populate knowledge for a single dependency
  #[allow(dead_code)]
  #[allow(clippy::needless_pass_by_ref_mut)]
  async fn populate_single_dependency(
    &mut self,
    dep_name: &str,
    version: &str,
  ) -> Result<()> {
    info!("📖 Populating knowledge for {}@{}", dep_name, version);

    #[cfg(feature = "github")]
    if self.github.is_some() {
      // Extract the GitHub analysis first
      let github_result = {
        let github = self.github.as_ref().unwrap();
        self
          .analyze_dependency_with_github(github, dep_name, version)
          .await
      };

      // Then process the result and update state
      match github_result {
        Ok(Some((knowledge_data, status))) => {
          self
            .fact
            .process("tool-knowledge-storage", knowledge_data)
            .await?;
          self
            .knowledge_status
            .insert(format!("{}@{}", dep_name, version), status);
          return Ok(());
        }
        Ok(None) => {
          // Tool not found in BEAM ecosystem, continue with fallback
        }
        Err(e) => {
          warn!("GitHub analysis failed for {}@{}: {}", dep_name, version, e);
          // Continue with fallback
        }
      }
    }

    // Fallback: store basic dependency info without GitHub integration
    let knowledge_data = serde_json::json!({
        "tool": dep_name,
        "version": version,
        "documentation": format!("Basic knowledge entry for {}@{}", dep_name, version),
        "snippets": [],
        "examples": [],
        "source": "local_discovery"
    });

    self
      .fact
      .process("tool-knowledge-storage", knowledge_data)
      .await?;
    Ok(())
  }

  /// Analyze dependency with GitHub (no state mutation)
  #[cfg(feature = "github")]
  async fn analyze_dependency_with_github(
    &self,
    github: &GitHubAnalyzer,
    dep_name: &str,
    version: &str,
  ) -> Result<Option<(serde_json::Value, KnowledgeStatus)>> {
    // Check if this is a BEAM ecosystem tool (Elixir, Gleam, Erlang packages on Hex)
    let beam_tools = [
      "phoenix",
      "ecto",
      "plug",
      "cowboy",
      "jason",
      "tesla",
      "broadway",
      "oban",
      "libcluster",
      "guardian",
      "absinthe",
      "nerves",
      "scenic",
      "liveview",
      "live_view",
      "bandit",
      "finch",
      "bamboo",
      "swoosh",
      // Gleam packages
      "gleam_stdlib",
      "gleam_json",
      "gleam_http",
      "gleam_crypto",
      "gleam_otp",
      "gleam_regex",
      "gleam_erlang",
      "gleam_pgo",
      "gleeunit",
      "gleam_javascript",
      // Common Erlang packages
      "cowboy",
      "ranch",
      "hackney",
      "jsx",
      "lager",
      "recon",
    ];

    if !beam_tools.contains(&dep_name) {
      return Ok(None);
    }

    match github.analyze_hex_package_repos(dep_name, version).await {
      Ok(analysis) => {
        let fact_entries =
          github.generate_fact_entries(dep_name, version, &analysis);

        // Create knowledge data
        let knowledge_data = serde_json::json!({
            "tool": dep_name,
            "version": version,
            "documentation": fact_entries.documentation,
            "snippets": fact_entries.snippets,
            "examples": fact_entries.examples,
            "best_practices": fact_entries.best_practices,
            "troubleshooting": fact_entries.troubleshooting,
            "github_sources": fact_entries.github_sources,
        });

        // Create status
        let status = KnowledgeStatus {
          tool: dep_name.to_string(),
          version: version.to_string(),
          last_updated: SystemTime::now(),
          snippets_count: fact_entries.snippets.len(),
          examples_count: fact_entries.examples.len(),
          next_update: SystemTime::now()
            + Duration::from_secs(self.config.update_interval_hours * 3600),
          auto_update_enabled: true,
        };

        info!(
          "✅ Knowledge analyzed for {}@{}: {} snippets, {} examples",
          dep_name,
          version,
          fact_entries.snippets.len(),
          fact_entries.examples.len()
        );

        Ok(Some((knowledge_data, status)))
      }
      Err(e) => {
        warn!(
          "Failed to analyze knowledge for {}@{}: {}",
          dep_name, version, e
        );
        Err(e)
      }
    }
  }

  /// Start background tasks for continuous updates
  #[allow(clippy::unused_self, clippy::unnecessary_wraps)]
  fn start_background_tasks(&self) -> Result<()> {
    info!("🔄 Starting background update tasks");

    // File system watcher for project changes
    tokio::spawn(async move {
      let mut interval = interval(Duration::from_secs(300)); // Check every 5 minutes

      loop {
        interval.tick().await;
        // TODO: Implement file system watching
        debug!("Checking for project changes...");
      }
    });

    // Periodic knowledge updates
    tokio::spawn(async move {
      let mut interval = interval(Duration::from_secs(3600)); // Check every hour

      loop {
        interval.tick().await;
        // TODO: Check for knowledge updates needed
        debug!("Checking for knowledge updates...");
      }
    });

    Ok(())
  }

  /// Get current orchestration status
  #[must_use]
  pub fn get_status(&self) -> AutoOrchestrationStatus {
    AutoOrchestrationStatus {
      is_running: self.is_running,
      projects_discovered: self.discovered_projects.len(),
      knowledge_entries: self.knowledge_status.len(),
      last_discovery: SystemTime::now(), // TODO: Track actual last discovery time
      next_update: SystemTime::now()
        + Duration::from_secs(self.config.update_interval_hours * 3600),
    }
  }
}

/// Auto orchestration status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AutoOrchestrationStatus {
  pub is_running: bool,
  pub projects_discovered: usize,
  pub knowledge_entries: usize,
  pub last_discovery: SystemTime,
  pub next_update: SystemTime,
}

#[cfg(test)]
mod tests {
  use super::*;

  #[tokio::test]
  async fn test_auto_orchestrator_creation() {
    let config = PackageFileWatcherConfig::default();
    let orchestrator = PackageFileWatcher::new(config).unwrap();
    assert!(!orchestrator.is_running);
  }

  #[tokio::test]
  async fn test_dependency_parsing() {
    let config = PackageFileWatcherConfig::default();
    let orchestrator = PackageFileWatcher::new(config).unwrap();

    let mix_content = r#"
        defmodule MyApp.MixProject do
          def project do
            [
              deps: deps()
            ]
          end

          defp deps do
            [
              {:phoenix, "~> 1.7.0"},
              {:ecto_sql, "~> 3.6"},
              {:postgrex, ">= 0.0.0"},
              {:phoenix_html, "~> 3.0"}
            ]
          end
        end
        "#;

    let deps = PackageFileWatcher::parse_elixir_dependencies(mix_content);
    assert!(!deps.is_empty());
    assert!(deps.iter().any(|d| d.name == "phoenix"));
  }
}
