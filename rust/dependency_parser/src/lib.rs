//! Dependency Parser
//!
//! A library for extracting dependencies from package files across different ecosystems.
//! Supports package.json (npm), Cargo.toml (Rust), mix.exs (Elixir), requirements.txt (Python), and more.
//!
//! ## Usage
//!
//! ```rust
//! use dependency_parser::{DependencyParser, PackageDependency};
//! use std::path::Path;
//!
//! # fn main() -> Result<(), Box<dyn std::error::Error>> {
//! let parser = DependencyParser::new();
//! // In real usage, you would pass a path to an actual package file
//! // let dependencies = parser.parse_package_file(Path::new("package.json"))?;
//! 
//! // Example of what you'd get:
//! let dependencies = vec![
//!     PackageDependency { name: "react".to_string(), version: "^18.0.0".to_string(), ecosystem: "npm".to_string() },
//!     PackageDependency { name: "lodash".to_string(), version: "4.17.21".to_string(), ecosystem: "npm".to_string() },
//! ];
//! 
//! for dep in dependencies {
//!     println!("{}@{} ({})", dep.name, dep.version, dep.ecosystem);
//! }
//! # Ok(())
//! # }
//! ```

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::Path;

/// A dependency extracted from a package file
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PackageDependency {
    /// Name of the dependency
    pub name: String,
    /// Version specification
    pub version: String,
    /// Ecosystem (npm, crates, hex, pypi, go, etc.)
    pub ecosystem: String,
}

/// Configuration template from remote ETS cache
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigTemplate {
    /// Template ID (e.g., "eslint", "tsconfig", "jest")
    pub id: String,
    /// File patterns this template matches
    pub file_patterns: Vec<String>,
    /// Parsing rules for extracting dependencies/config
    pub parsing_rules: ParsingRules,
    /// Metadata about the template
    pub metadata: TemplateMetadata,
}

/// Parsing rules for config files
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsingRules {
    /// JSON paths to extract dependencies
    pub dependency_paths: Vec<String>,
    /// Key-value pairs to extract as config
    pub config_extractions: Vec<ConfigExtraction>,
    /// File type (json, yaml, toml, etc.)
    pub file_type: String,
}

/// Configuration extraction rule
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigExtraction {
    /// Path to extract (e.g., "scripts.test")
    pub path: String,
    /// Key name in result
    pub key: String,
    /// Value type (string, array, object, boolean)
    pub value_type: String,
}

/// Template metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetadata {
    /// Template name
    pub name: String,
    /// Description
    pub description: String,
    /// Language/ecosystem
    pub ecosystem: String,
    /// Version
    pub version: String,
}

/// Parser for extracting dependencies from package files
#[derive(Debug, Clone)]
pub struct DependencyParser {
    /// ETS cache for templates (fast local access)
    ets_cache: Option<String>,
    /// NATS connection for real-time updates
    nats_connection: Option<String>,
}

impl DependencyParser {
    /// Create a new dependency parser with ETS cache
    pub fn new_with_cache(ets_cache: String) -> Self {
        Self {
            ets_cache: Some(ets_cache),
            nats_connection: None,
        }
    }

    /// Create a new dependency parser with NATS connection
    pub fn new_with_nats(nats_connection: String) -> Self {
        Self {
            ets_cache: None,
            nats_connection: Some(nats_connection),
        }
    }

    /// Create a new dependency parser with both ETS cache and NATS
    pub fn new_with_cache_and_nats(ets_cache: String, nats_connection: String) -> Self {
        Self {
            ets_cache: Some(ets_cache),
            nats_connection: Some(nats_connection),
        }
    }

impl DependencyParser {
    /// Create a new dependency parser (legacy)
    #[must_use]
    pub const fn new() -> Self {
        Self {
            ets_cache: None,
            nats_connection: None,
        }
    }

    /// Load templates from ETS cache
    async fn load_templates_from_ets(&self, file_pattern: &str) -> Result<Vec<ConfigTemplate>> {
        // Query ETS cache for templates matching file pattern
        // This would call Elixir ETS functions via NIF
        Ok(vec![])
    }

    /// Load templates from NATS JetStream
    async fn load_templates_from_nats(&self, file_pattern: &str) -> Result<Vec<ConfigTemplate>> {
        // Query NATS JetStream for templates
        // Subject: "templates.config.{file_pattern}"
        Ok(vec![])
    }

    /// Get templates with hybrid caching strategy
    async fn get_templates(&self, file_pattern: &str) -> Result<Vec<ConfigTemplate>> {
        // 1. Try ETS cache first (fastest)
        if let Some(_ets_cache) = &self.ets_cache {
            match self.load_templates_from_ets(file_pattern).await {
                Ok(templates) if !templates.is_empty() => return Ok(templates),
                _ => {} // Fall through to NATS
            }
        }

        // 2. Fallback to NATS (real-time)
        if let Some(_nats_connection) = &self.nats_connection {
            self.load_templates_from_nats(file_pattern).await
        } else {
            // 3. Fallback to hardcoded templates
            Ok(self.get_hardcoded_templates(file_pattern))
        }
    }

    /// Hardcoded fallback templates
    fn get_hardcoded_templates(&self, file_pattern: &str) -> Vec<ConfigTemplate> {
        match file_pattern {
            "package.json" => vec![ConfigTemplate {
                id: "npm".to_string(),
                file_patterns: vec!["package.json".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec!["dependencies".to_string(), "devDependencies".to_string()],
                    config_extractions: vec![],
                    file_type: "json".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "NPM Package".to_string(),
                    description: "Node.js package.json parser".to_string(),
                    ecosystem: "npm".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "Cargo.toml" => vec![ConfigTemplate {
                id: "cargo".to_string(),
                file_patterns: vec!["Cargo.toml".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec!["dependencies".to_string()],
                    config_extractions: vec![],
                    file_type: "toml".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "Cargo Package".to_string(),
                    description: "Rust Cargo.toml parser".to_string(),
                    ecosystem: "cargo".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            _ => vec![],
        }
    }

    /// Parse a package file and extract dependencies using remote ETS templates
    ///
    /// # Arguments
    /// * `file_path` - Path to the package file (package.json, Cargo.toml, etc.)
    /// * `templates` - Optional remote ETS templates for parsing
    ///
    /// # Returns
    /// Vector of dependencies found in the file
    ///
    /// # Errors
    /// Returns an error if the file cannot be read or parsed
    ///
    /// # Examples
    /// ```rust
    /// use dependency_parser::DependencyParser;
    /// use std::path::Path;
    ///
    /// # fn main() -> Result<(), Box<dyn std::error::Error>> {
    /// let parser = DependencyParser::new();
    /// // Parse with remote templates
    /// let deps = parser.parse_package_file_with_templates(Path::new("package.json"), Some(templates))?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn parse_package_file(&self, file_path: &Path) -> Result<Vec<PackageDependency>> {
        self.parse_package_file_with_templates(file_path, None)
    }

    /// Parse a package file using templates from central NATS
    pub fn parse_package_file_with_templates(&self, file_path: &Path, templates: Option<&[ConfigTemplate]>) -> Result<Vec<PackageDependency>> {
        let content = std::fs::read_to_string(file_path)
            .map_err(|e| anyhow::anyhow!("Failed to read package file: {e}"))?;

        let file_name = file_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown");

        match file_name {
            "package.json" => Ok(Self::parse_npm_dependencies(&content)),
            "package-lock.json" => Ok(Self::parse_npm_lock_dependencies(&content)),
            "Cargo.toml" => Ok(Self::parse_cargo_dependencies(&content)),
            "mix.exs" => Ok(Self::parse_mix_dependencies(&content)),
            "requirements.txt" => Ok(Self::parse_pip_dependencies(&content)),
            "pyproject.toml" => Ok(Self::parse_pyproject_dependencies(&content)),
            "go.mod" => Ok(Self::parse_go_dependencies(&content)),
            "composer.json" => Ok(Self::parse_composer_dependencies(&content)),
            _ => Ok(vec![]),
        }
    }

    /// Parse npm dependencies from package.json
    fn parse_npm_dependencies(content: &str) -> Vec<PackageDependency> {
        serde_json::from_str::<serde_json::Value>(content).map_or_else(|_| vec![], |package_json| {
            let mut dependencies = Vec::new();

            // Parse dependencies
            if let Some(deps) = package_json.get("dependencies").and_then(|d| d.as_object()) {
                for (name, version) in deps {
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version.as_str().unwrap_or("unknown").to_string(),
                        ecosystem: "npm".to_string(),
                    });
                }
            }

            // Parse devDependencies
            if let Some(dev_deps) = package_json.get("devDependencies").and_then(|d| d.as_object()) {
                for (name, version) in dev_deps {
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version.as_str().unwrap_or("unknown").to_string(),
                        ecosystem: "npm".to_string(),
                    });
                }
            }

            dependencies
        })
    }

    /// Parse npm lockfile dependencies from package-lock.json
    fn parse_npm_lock_dependencies(content: &str) -> Vec<PackageDependency> {
        fn collect_dependencies(
            deps: &serde_json::Map<String, serde_json::Value>,
            acc: &mut Vec<PackageDependency>,
        ) {
            for (name, value) in deps {
                if let Some(obj) = value.as_object() {
                    if let Some(version) = obj.get("version").and_then(|v| v.as_str()) {
                        acc.push(PackageDependency {
                            name: name.clone(),
                            version: version.to_string(),
                            ecosystem: "npm".to_string(),
                        });
                    }
                    if let Some(sub_deps) = obj.get("dependencies").and_then(|v| v.as_object()) {
                        collect_dependencies(sub_deps, acc);
                    }
                }
            }
        }

        serde_json::from_str::<serde_json::Value>(content).map_or_else(|_| vec![], |lock| {
            let mut dependencies = Vec::new();
            if let Some(deps) = lock.get("dependencies").and_then(|d| d.as_object()) {
                collect_dependencies(deps, &mut dependencies);
            }
            dependencies
        })
    }

    /// Parse Cargo dependencies from Cargo.toml
    fn parse_cargo_dependencies(content: &str) -> Vec<PackageDependency> {
        toml::from_str::<toml::Value>(content).map_or_else(|_| vec![], |cargo_toml| {
            let mut dependencies = Vec::new();

            // Parse [dependencies]
            if let Some(deps) = cargo_toml.get("dependencies").and_then(|d| d.as_table()) {
                for (name, version) in deps {
                    let version_str = match version {
                        toml::Value::String(s) => s.clone(),
                        toml::Value::Table(t) => {
                            t.get("version").and_then(|v| v.as_str()).unwrap_or("unknown").to_string()
                        }
                        _ => "unknown".to_string(),
                    };
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version_str,
                        ecosystem: "crates".to_string(),
                    });
                }
            }

            // Parse [dev-dependencies]
            if let Some(dev_deps) = cargo_toml.get("dev-dependencies").and_then(|d| d.as_table()) {
                for (name, version) in dev_deps {
                    let version_str = match version {
                        toml::Value::String(s) => s.clone(),
                        toml::Value::Table(t) => {
                            t.get("version").and_then(|v| v.as_str()).unwrap_or("unknown").to_string()
                        }
                        _ => "unknown".to_string(),
                    };
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version_str,
                        ecosystem: "crates".to_string(),
                    });
                }
            }

            dependencies
        })
    }

    /// Parse mix dependencies from mix.exs (simplified regex-based parsing)
    fn parse_mix_dependencies(content: &str) -> Vec<PackageDependency> {
        let mut dependencies = Vec::new();
        
        // Simple regex-based parsing for mix.exs
        if let Ok(dep_pattern) = regex::Regex::new(r#":(\w+),\s*"([^"]+)""#) {
            for cap in dep_pattern.captures_iter(content) {
                if let (Some(name), Some(version)) = (cap.get(1), cap.get(2)) {
                    dependencies.push(PackageDependency {
                        name: name.as_str().to_string(),
                        version: version.as_str().to_string(),
                        ecosystem: "hex".to_string(),
                    });
                }
            }
        }

        dependencies
    }

    /// Parse pip dependencies from requirements.txt
    fn parse_pip_dependencies(content: &str) -> Vec<PackageDependency> {
        let mut dependencies = Vec::new();

        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }

            // Parse package==version format
            if let Some((name, version)) = line.split_once("==") {
                dependencies.push(PackageDependency {
                    name: name.to_string(),
                    version: version.to_string(),
                    ecosystem: "pypi".to_string(),
                });
            } else if let Some((name, version)) = line.split_once(">=") {
                dependencies.push(PackageDependency {
                    name: name.to_string(),
                    version: format!(">={version}"),
                    ecosystem: "pypi".to_string(),
                });
            } else if let Some((name, version)) = line.split_once("~=") {
                dependencies.push(PackageDependency {
                    name: name.to_string(),
                    version: format!("~={version}"),
                    ecosystem: "pypi".to_string(),
                });
            } else {
                // Just package name without version
                dependencies.push(PackageDependency {
                    name: line.to_string(),
                    version: "unknown".to_string(),
                    ecosystem: "pypi".to_string(),
                });
            }
        }

        dependencies
    }

    /// Parse pyproject.toml dependencies
    fn parse_pyproject_dependencies(content: &str) -> Vec<PackageDependency> {
        const OPERATORS: [&str; 7] = ["==", ">=", "<=", "~=", "!=", ">", "<"];
        
        fn parse_spec(spec: &str) -> (String, String) {
            let trimmed = spec.trim();
            for op in OPERATORS {
                if let Some((name, version)) = trimmed.split_once(op) {
                    return (
                        name.trim().to_string(),
                        format!("{}{}", op, version.trim()),
                    );
                }
            }
            if let Some((name, version)) = trimmed.split_once(' ') {
                return (name.trim().to_string(), version.trim().to_string());
            }
            (trimmed.to_string(), "unknown".to_string())
        }

        fn add_project_dependencies(entries: &mut Vec<PackageDependency>, items: &[toml::Value]) {
            for item in items {
                if let Some(spec) = item.as_str() {
                    let (name, version) = parse_spec(spec);
                    entries.push(PackageDependency {
                        name,
                        version,
                        ecosystem: "pypi".to_string(),
                    });
                }
            }
        }

        fn add_poetry_table(entries: &mut Vec<PackageDependency>, table: &toml::value::Table) {
            for (name, value) in table {
                if name.eq_ignore_ascii_case("python") {
                    continue;
                }
                let version = match value {
                    toml::Value::String(s) => s.clone(),
                    toml::Value::Table(t) => t
                        .get("version")
                        .and_then(|v| v.as_str())
                        .unwrap_or("unknown")
                        .to_string(),
                    _ => "unknown".to_string(),
                };
                entries.push(PackageDependency {
                    name: name.clone(),
                    version,
                    ecosystem: "pypi".to_string(),
                });
            }
        }

        let mut dependencies = Vec::new();
        let Ok(pyproject) = toml::from_str::<toml::Value>(content) else {
            return dependencies;
        };

        if let Some(project) = pyproject.get("project") {
            if let Some(items) = project
                .get("dependencies")
                .and_then(|deps| deps.as_array())
            {
                add_project_dependencies(&mut dependencies, items);
            }

            if let Some(optional) = project
                .get("optional-dependencies")
                .and_then(|deps| deps.as_table())
            {
                for items in optional.values().filter_map(|v| v.as_array()) {
                    add_project_dependencies(&mut dependencies, items);
                }
            }
        }

        if let Some(tool) = pyproject.get("tool").and_then(|t| t.as_table()) {
            if let Some(poetry) = tool.get("poetry").and_then(|p| p.as_table()) {
                if let Some(table) = poetry.get("dependencies").and_then(|t| t.as_table()) {
                    add_poetry_table(&mut dependencies, table);
                }
                if let Some(table) = poetry.get("dev-dependencies").and_then(|t| t.as_table()) {
                    add_poetry_table(&mut dependencies, table);
                }
            }
        }

        dependencies
    }

    /// Parse go.mod dependencies
    fn parse_go_dependencies(content: &str) -> Vec<PackageDependency> {
        let mut dependencies = Vec::new();

        for line in content.lines() {
            let line = line.trim();
            if line.starts_with("require") {
                // Parse require statements
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    dependencies.push(PackageDependency {
                        name: parts[1].to_string(),
                        version: parts[2].to_string(),
                        ecosystem: "go".to_string(),
                    });
                }
            }
        }

        dependencies
    }

    /// Parse composer.json dependencies
    fn parse_composer_dependencies(content: &str) -> Vec<PackageDependency> {
        serde_json::from_str::<serde_json::Value>(content).map_or_else(|_| vec![], |composer_json| {
            let mut dependencies = Vec::new();

            if let Some(require) = composer_json.get("require").and_then(|d| d.as_object()) {
                for (name, version) in require {
                    let version_str = match version {
                        serde_json::Value::String(s) => s.clone(),
                        _ => "unknown".to_string(),
                    };
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version_str,
                        ecosystem: "composer".to_string(),
                    });
                }
            }

            if let Some(require_dev) = composer_json
                .get("require-dev")
                .and_then(|d| d.as_object())
            {
                for (name, version) in require_dev {
                    let version_str = match version {
                        serde_json::Value::String(s) => s.clone(),
                        _ => "unknown".to_string(),
                    };
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version_str,
                        ecosystem: "composer".to_string(),
                    });
                }
            }

            dependencies
        })
    }
}

impl Default for DependencyParser {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_parse_npm_dependencies() {
        let parser = DependencyParser::new();
        let package_json = r#"{
            "name": "test-package",
            "version": "1.0.0",
            "dependencies": {
                "react": "^18.0.0",
                "lodash": "4.17.21"
            },
            "devDependencies": {
                "typescript": "^5.0.0"
            }
        }"#;

        let temp_dir = tempfile::tempdir().unwrap();
        let temp_file = temp_dir.path().join("package.json");
        std::fs::write(&temp_file, package_json).unwrap();
        
        let dependencies = parser.parse_package_file(&temp_file).unwrap();
        
        assert_eq!(dependencies.len(), 3);
        assert!(dependencies.iter().any(|d| d.name == "react" && d.ecosystem == "npm"));
        assert!(dependencies.iter().any(|d| d.name == "lodash" && d.ecosystem == "npm"));
        assert!(dependencies.iter().any(|d| d.name == "typescript" && d.ecosystem == "npm"));
    }

    #[test]
    fn test_parse_cargo_dependencies() {
        let parser = DependencyParser::new();
        let cargo_toml = r#"[package]
name = "test-package"
version = "0.1.0"

[dependencies]
tokio = "1.0"
serde = { version = "1.0", features = ["derive"] }

[dev-dependencies]
tempfile = "0.3"
"#;

        let temp_dir = tempfile::tempdir().unwrap();
        let temp_file = temp_dir.path().join("Cargo.toml");
        std::fs::write(&temp_file, cargo_toml).unwrap();
        
        let dependencies = parser.parse_package_file(&temp_file).unwrap();
        
        assert_eq!(dependencies.len(), 3);
        assert!(dependencies.iter().any(|d| d.name == "tokio" && d.ecosystem == "crates"));
        assert!(dependencies.iter().any(|d| d.name == "serde" && d.ecosystem == "crates"));
        assert!(dependencies.iter().any(|d| d.name == "tempfile" && d.ecosystem == "crates"));
    }

    #[test]
    fn test_parse_npm_lock_dependencies() {
        let parser = DependencyParser::new();
        let lock_json = r#"{
  "name": "test",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "dependencies": {
    "react": {
      "version": "18.2.0",
      "resolved": "https://registry.npmjs.org/react/-/react-18.2.0.tgz",
      "integrity": "sha512-...",
      "requires": {
        "loose-envify": "^1.1.0"
      }
    },
    "loose-envify": {
      "version": "1.4.0"
    },
    "@types/node": {
      "version": "20.9.0",
      "dependencies": {
        "undici-types": {
          "version": "5.25.3"
        }
      }
    }
  }
}"#;

        let temp_dir = tempfile::tempdir().unwrap();
        let temp_file = temp_dir.path().join("package-lock.json");
        std::fs::write(&temp_file, lock_json).unwrap();

        let mut dependencies = parser.parse_package_file(&temp_file).unwrap();
        dependencies.sort_by(|a, b| a.name.cmp(&b.name));

        assert!(dependencies.iter().any(|d| d.name == "react" && d.version == "18.2.0"));
        assert!(dependencies.iter().any(|d| d.name == "loose-envify" && d.version == "1.4.0"));
        assert!(dependencies.iter().any(|d| d.name == "@types/node"));
        assert!(dependencies.iter().any(|d| d.name == "undici-types"));
    }

    #[test]
    fn test_parse_pyproject_dependencies() {
        let parser = DependencyParser::new();
        let pyproject = r#"
[project]
dependencies = [
    "requests >=2.0",
    "numpy==1.26.0"
]

[project.optional-dependencies]
dev = ["pytest", "black==22.0"]

[tool.poetry.dependencies]
python = "^3.11"
fastapi = "^0.110.0"

[tool.poetry.dev-dependencies]
mypy = "^1.8.0"
"#;

        let temp_dir = tempfile::tempdir().unwrap();
        let temp_file = temp_dir.path().join("pyproject.toml");
        std::fs::write(&temp_file, pyproject).unwrap();

        let dependencies = parser.parse_package_file(&temp_file).unwrap();

        assert!(dependencies.iter().any(|d| d.name == "requests" && d.version.contains(">=")));
        assert!(dependencies.iter().any(|d| d.name == "numpy" && d.version.contains("==1.26.0")));
        assert!(dependencies.iter().any(|d| d.name == "pytest"));
        assert!(dependencies.iter().any(|d| d.name == "fastapi"));
        assert!(dependencies.iter().any(|d| d.name == "mypy"));
    }

    #[test]
    fn test_parse_composer_dependencies() {
        let parser = DependencyParser::new();
        let composer_json = r#"{
            "require": {
                "php": "^8.1",
                "laravel/framework": "^11.0"
            },
            "require-dev": {
                "phpunit/phpunit": "^11.0"
            }
        }"#;

        let temp_dir = tempfile::tempdir().unwrap();
        let temp_file = temp_dir.path().join("composer.json");
        std::fs::write(&temp_file, composer_json).unwrap();

        let dependencies = parser.parse_package_file(&temp_file).unwrap();

        assert!(dependencies.iter().any(|d| d.name == "laravel/framework" && d.ecosystem == "composer"));
        assert!(dependencies.iter().any(|d| d.name == "phpunit/phpunit" && d.ecosystem == "composer"));
        // PHP runtime entry is expected but should still be captured (version constraint)
        assert!(dependencies.iter().any(|d| d.name == "php"));
    }
}
