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
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PackageDependency {
    /// Name of the dependency
    pub name: String,
    /// Version specification
    pub version: String,
    /// Ecosystem (npm, crates, hex, pypi, go, etc.)
    pub ecosystem: String,
}

/// Parser for extracting dependencies from package files
#[derive(Debug, Clone)]
pub struct DependencyParser;

impl DependencyParser {
    /// Create a new dependency parser
    pub fn new() -> Self {
        Self
    }

    /// Parse a package file and extract dependencies
    ///
    /// # Arguments
    /// * `file_path` - Path to the package file (package.json, Cargo.toml, etc.)
    ///
    /// # Returns
    /// Vector of dependencies found in the file
    ///
    /// # Examples
    /// ```rust
    /// use dependency_parser::DependencyParser;
    /// use std::path::Path;
    ///
    /// # fn main() -> Result<(), Box<dyn std::error::Error>> {
    /// let parser = DependencyParser::new();
    /// // In real usage, you would pass a path to an actual package file
    /// // let deps = parser.parse_package_file(Path::new("package.json"))?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn parse_package_file(&self, file_path: &Path) -> Result<Vec<PackageDependency>> {
        let content = std::fs::read_to_string(file_path)
            .map_err(|e| anyhow::anyhow!("Failed to read package file: {}", e))?;

        let file_name = file_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown");

        match file_name {
            "package.json" => Ok(self.parse_npm_dependencies(&content)),
            "Cargo.toml" => Ok(self.parse_cargo_dependencies(&content)),
            "mix.exs" => Ok(self.parse_mix_dependencies(&content)),
            "requirements.txt" => Ok(self.parse_pip_dependencies(&content)),
            "pyproject.toml" => Ok(self.parse_pyproject_dependencies(&content)),
            "go.mod" => Ok(self.parse_go_dependencies(&content)),
            "composer.json" => Ok(self.parse_composer_dependencies(&content)),
            _ => Ok(vec![]),
        }
    }

    /// Parse npm dependencies from package.json
    fn parse_npm_dependencies(&self, content: &str) -> Vec<PackageDependency> {
        match serde_json::from_str::<serde_json::Value>(content) {
            Ok(package_json) => {
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
            }
            Err(_) => vec![],
        }
    }

    /// Parse Cargo dependencies from Cargo.toml
    fn parse_cargo_dependencies(&self, content: &str) -> Vec<PackageDependency> {
        match toml::from_str::<toml::Value>(content) {
            Ok(cargo_toml) => {
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
            }
            Err(_) => vec![],
        }
    }

    /// Parse mix dependencies from mix.exs (simplified regex-based parsing)
    fn parse_mix_dependencies(&self, content: &str) -> Vec<PackageDependency> {
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
    fn parse_pip_dependencies(&self, content: &str) -> Vec<PackageDependency> {
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
                    version: format!(">={}", version),
                    ecosystem: "pypi".to_string(),
                });
            } else if let Some((name, version)) = line.split_once("~=") {
                dependencies.push(PackageDependency {
                    name: name.to_string(),
                    version: format!("~={}", version),
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
    fn parse_pyproject_dependencies(&self, _content: &str) -> Vec<PackageDependency> {
        // TODO: Implement pyproject.toml parsing
        vec![]
    }

    /// Parse go.mod dependencies
    fn parse_go_dependencies(&self, content: &str) -> Vec<PackageDependency> {
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
    fn parse_composer_dependencies(&self, _content: &str) -> Vec<PackageDependency> {
        // TODO: Implement composer.json parsing
        vec![]
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
    use std::path::Path;

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
}
