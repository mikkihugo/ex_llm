//! Core types for Smart Package Context
//!
//! These types define the data structures that flow through the system.

use serde::{Deserialize, Serialize};

/// Package ecosystem (npm, cargo, hex, pypi, etc.)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Ecosystem {
    /// JavaScript/TypeScript packages
    Npm,
    /// Rust packages
    Cargo,
    /// Elixir packages
    Hex,
    /// Python packages
    Pypi,
    /// Go packages
    Go,
    /// Java packages
    Maven,
    /// .NET packages
    Nuget,
}

impl Ecosystem {
    /// Parse ecosystem from string
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "npm" => Some(Ecosystem::Npm),
            "cargo" => Some(Ecosystem::Cargo),
            "hex" => Some(Ecosystem::Hex),
            "pypi" => Some(Ecosystem::Pypi),
            "python" => Some(Ecosystem::Pypi),
            "go" => Some(Ecosystem::Go),
            "maven" => Some(Ecosystem::Maven),
            "java" => Some(Ecosystem::Maven),
            "nuget" => Some(Ecosystem::Nuget),
            ".net" => Some(Ecosystem::Nuget),
            _ => None,
        }
    }

    /// String representation
    pub fn as_str(&self) -> &'static str {
        match self {
            Ecosystem::Npm => "npm",
            Ecosystem::Cargo => "cargo",
            Ecosystem::Hex => "hex",
            Ecosystem::Pypi => "pypi",
            Ecosystem::Go => "go",
            Ecosystem::Maven => "maven",
            Ecosystem::Nuget => "nuget",
        }
    }
}

/// Complete information about a package
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageInfo {
    /// Package name
    pub name: String,
    /// Package ecosystem
    pub ecosystem: Ecosystem,
    /// Current version
    pub version: String,
    /// Package description
    pub description: Option<String>,
    /// Repository URL
    pub repository: Option<String>,
    /// Documentation URL
    pub documentation: Option<String>,
    /// Homepage URL
    pub homepage: Option<String>,
    /// License
    pub license: Option<String>,
    /// Number of dependents
    pub dependents: Option<usize>,
    /// Download statistics
    pub downloads: Option<DownloadStats>,
    /// Quality score (0.0-100.0)
    pub quality_score: f32,
}

/// Download statistics for a package
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadStats {
    /// Downloads per week
    pub per_week: usize,
    /// Downloads per month
    pub per_month: usize,
    /// Downloads per year
    pub per_year: usize,
}

/// A code example from the package documentation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeExample {
    /// Example title
    pub title: String,
    /// Example description
    pub description: Option<String>,
    /// Code content
    pub code: String,
    /// Programming language
    pub language: String,
    /// Source URL (documentation link)
    pub source_url: Option<String>,
}

/// A consensus pattern (what community agrees works)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternConsensus {
    /// Pattern name/title
    pub name: String,
    /// Pattern description
    pub description: String,
    /// Pattern type (initialization, error_handling, testing, etc.)
    pub pattern_type: String,
    /// Confidence score (0.0-1.0) based on consensus
    pub confidence: f32,
    /// Number of observations
    pub observation_count: usize,
    /// Recommended for this package
    pub recommended: bool,
    /// Embedding vector (for semantic search)
    pub embedding: Option<Vec<f32>>,
}

/// Result from pattern search
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternMatch {
    /// Package this pattern applies to
    pub package: String,
    /// Ecosystem
    pub ecosystem: Ecosystem,
    /// Pattern details
    pub pattern: PatternConsensus,
    /// Relevance score (0.0-1.0)
    pub relevance: f32,
}

/// File types for analysis
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum FileType {
    /// JavaScript/TypeScript
    JavaScript,
    /// Python
    Python,
    /// Rust
    Rust,
    /// Elixir
    Elixir,
    /// Go
    Go,
    /// Java
    Java,
    /// YAML (config)
    Yaml,
    /// TOML (config)
    Toml,
}

impl FileType {
    /// Detect from file extension
    pub fn from_extension(ext: &str) -> Option<Self> {
        match ext.to_lowercase().as_str() {
            "js" | "jsx" | "ts" | "tsx" => Some(FileType::JavaScript),
            "py" => Some(FileType::Python),
            "rs" => Some(FileType::Rust),
            "ex" | "exs" => Some(FileType::Elixir),
            "go" => Some(FileType::Go),
            "java" => Some(FileType::Java),
            "yaml" | "yml" => Some(FileType::Yaml),
            "toml" => Some(FileType::Toml),
            _ => None,
        }
    }
}

/// Suggestion for code improvement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Suggestion {
    /// Suggestion title
    pub title: String,
    /// Detailed description
    pub description: String,
    /// Severity (info, warning, error)
    pub severity: SeverityLevel,
    /// Suggested pattern or fix
    pub pattern: PatternConsensus,
    /// Code snippet example
    pub example: Option<String>,
}

/// Severity levels for suggestions
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SeverityLevel {
    /// Informational only
    Info,
    /// Warning (should fix)
    Warning,
    /// Error (must fix)
    Error,
}

/// Health check response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthCheck {
    /// Is the service healthy
    pub healthy: bool,
    /// Service version
    pub version: String,
    /// Status message
    pub message: String,
}
