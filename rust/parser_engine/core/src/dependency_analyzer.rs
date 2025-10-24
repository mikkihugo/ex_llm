//! Dependency Analysis Module
//!
//! Analyzes manifest files (Cargo.toml, package.json, mix.exs, etc.) to extract
//! project dependencies and detect frameworks.

use std::path::{Path, PathBuf};
use anyhow::Result;
use serde::{Serialize, Deserialize};
use serde_json::Value as JsonValue;

/// A detected dependency
#[derive(Debug, Clone)]
pub struct Dependency {
    /// Package name
    pub name: String,
    /// Package version
    pub version: String,
    /// Is this a dev dependency?
    pub is_dev: bool,
    /// Dependency type (direct, indirect)
    pub dependency_type: String,
}

/// A detected framework (populated by CentralCloud pattern lookup)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Framework {
    /// Framework name
    pub name: String,
    /// Version if detected
    pub version: Option<String>,
    /// Framework type (web, build, test, orm, etc.)
    pub framework_type: String,
    /// Confidence score (0.0-1.0)
    pub confidence: f32,
}

/// Dependency analyzer for different languages
pub struct DependencyAnalyzer;

impl DependencyAnalyzer {
    /// Find the project root by searching up for manifest files
    fn find_project_root(start_path: &Path) -> PathBuf {
        let mut current = start_path.to_path_buf();

        // Search up to 5 levels up the directory tree for a manifest file
        for _ in 0..5 {
            if current.join("Cargo.toml").exists()
                || current.join("package.json").exists()
                || current.join("mix.exs").exists()
                || current.join("pyproject.toml").exists()
                || current.join("requirements.txt").exists()
                || current.join("go.mod").exists()
            {
                return current;
            }

            if !current.pop() {
                break; // Reached filesystem root
            }
        }

        start_path.to_path_buf()
    }

    /// Analyze project dependencies from manifest files
    pub fn analyze(project_root: &Path) -> Result<DependencyAnalysisResult> {
        // Find the actual project root by searching up the directory tree
        let project_root = Self::find_project_root(project_root);

        let mut result = DependencyAnalysisResult {
            dependencies: Vec::new(),
            frameworks: Vec::new(),
            manifest_found: None,
        };

        // Try different manifest files in order of preference
        // NOTE: Framework detection happens in Elixir via CentralCloud pattern lookup,
        // not in Rust. This allows patterns to be updated without recompiling Rust.
        if let Ok(deps) = Self::analyze_cargo_toml(&project_root) {
            result.dependencies = deps.clone();
            result.manifest_found = Some("Cargo.toml".to_string());
            // Framework detection will be done in Elixir via CentralCloud
            return Ok(result);
        }

        if let Ok(deps) = Self::analyze_package_json(&project_root) {
            result.dependencies = deps.clone();
            result.manifest_found = Some("package.json".to_string());
            // Framework detection will be done in Elixir via CentralCloud
            return Ok(result);
        }

        if let Ok(deps) = Self::analyze_mix_exs(&project_root) {
            result.dependencies = deps.clone();
            result.manifest_found = Some("mix.exs".to_string());
            // Framework detection will be done in Elixir via CentralCloud
            return Ok(result);
        }

        if let Ok(deps) = Self::analyze_requirements_txt(&project_root) {
            result.dependencies = deps.clone();
            result.manifest_found = Some("requirements.txt".to_string());
            // Framework detection will be done in Elixir via CentralCloud
            return Ok(result);
        }

        if let Ok(deps) = Self::analyze_go_mod(&project_root) {
            result.dependencies = deps.clone();
            result.manifest_found = Some("go.mod".to_string());
            // Framework detection will be done in Elixir via CentralCloud
            return Ok(result);
        }

        Ok(result)
    }

    /// Parse Cargo.toml
    fn analyze_cargo_toml(project_root: &Path) -> Result<Vec<Dependency>> {
        let cargo_path = project_root.join("Cargo.toml");
        if !cargo_path.exists() {
            return Err(anyhow::anyhow!("Cargo.toml not found"));
        }

        let content = std::fs::read_to_string(&cargo_path)?;
        let manifest: toml::Value = toml::from_str(&content)?;

        let mut deps = Vec::new();

        // Parse dependencies
        if let Some(dependencies) = manifest.get("dependencies").and_then(|d| d.as_table()) {
            for (name, version_info) in dependencies {
                let version = match version_info {
                    toml::Value::String(v) => v.clone(),
                    toml::Value::Table(t) => {
                        t.get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("*")
                            .to_string()
                    }
                    _ => "*".to_string(),
                };

                deps.push(Dependency {
                    name: name.clone(),
                    version,
                    is_dev: false,
                    dependency_type: "direct".to_string(),
                });
            }
        }

        // Parse dev-dependencies
        if let Some(dev_deps) = manifest.get("dev-dependencies").and_then(|d| d.as_table()) {
            for (name, version_info) in dev_deps {
                let version = match version_info {
                    toml::Value::String(v) => v.clone(),
                    toml::Value::Table(t) => {
                        t.get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("*")
                            .to_string()
                    }
                    _ => "*".to_string(),
                };

                deps.push(Dependency {
                    name: name.clone(),
                    version,
                    is_dev: true,
                    dependency_type: "direct".to_string(),
                });
            }
        }

        Ok(deps)
    }

    /// Parse package.json
    fn analyze_package_json(project_root: &Path) -> Result<Vec<Dependency>> {
        let package_path = project_root.join("package.json");
        if !package_path.exists() {
            return Err(anyhow::anyhow!("package.json not found"));
        }

        let content = std::fs::read_to_string(&package_path)?;
        let manifest: JsonValue = serde_json::from_str(&content)?;

        let mut deps = Vec::new();

        // Parse dependencies
        if let Some(dependencies) = manifest.get("dependencies").and_then(|d| d.as_object()) {
            for (name, version) in dependencies {
                deps.push(Dependency {
                    name: name.clone(),
                    version: version.as_str().unwrap_or("*").to_string(),
                    is_dev: false,
                    dependency_type: "direct".to_string(),
                });
            }
        }

        // Parse devDependencies
        if let Some(dev_deps) = manifest
            .get("devDependencies")
            .and_then(|d| d.as_object())
        {
            for (name, version) in dev_deps {
                deps.push(Dependency {
                    name: name.clone(),
                    version: version.as_str().unwrap_or("*").to_string(),
                    is_dev: true,
                    dependency_type: "direct".to_string(),
                });
            }
        }

        Ok(deps)
    }

    /// Parse mix.exs (Elixir)
    fn analyze_mix_exs(project_root: &Path) -> Result<Vec<Dependency>> {
        let mix_path = project_root.join("mix.exs");
        if !mix_path.exists() {
            return Err(anyhow::anyhow!("mix.exs not found"));
        }

        let content = std::fs::read_to_string(&mix_path)?;
        let mut deps = Vec::new();

        // Very basic Elixir mix.exs parsing (looks for {:package, "version"} patterns)
        // This is a simplified parser - a full parser would need Elixir AST parsing
        let lines: Vec<&str> = content.lines().collect();

        for (i, line) in lines.iter().enumerate() {
            if line.contains('{') && (line.contains("github") || line.contains('"')) {
                // Try to extract package name and version
                if let Some(start) = line.find('{') {
                    let end = line.find('}').unwrap_or(line.len());
                    let dep_str = &line[start + 1..end];

                    // Extract name and version
                    let parts: Vec<&str> = dep_str.split(',').collect();
                    if !parts.is_empty() {
                        let name = parts[0]
                            .trim()
                            .trim_matches(':')
                            .trim_matches('"')
                            .to_string();

                        let version = if parts.len() > 1 {
                            parts[1]
                                .trim()
                                .trim_matches('"')
                                .to_string()
                        } else {
                            "*".to_string()
                        };

                        if !name.is_empty() && name.len() < 50 {
                            // Simple heuristic: don't trust lines that don't look right
                            let is_dev = lines
                                .iter()
                                .take(i)
                                .rev()
                                .take(5)
                                .any(|l| l.contains("only:") && l.contains("test"));

                            deps.push(Dependency {
                                name,
                                version,
                                is_dev,
                                dependency_type: "direct".to_string(),
                            });
                        }
                    }
                }
            }
        }

        if deps.is_empty() {
            return Err(anyhow::anyhow!("No dependencies found in mix.exs"));
        }

        Ok(deps)
    }

    /// Parse requirements.txt (Python)
    fn analyze_requirements_txt(project_root: &Path) -> Result<Vec<Dependency>> {
        let requirements_path = project_root.join("requirements.txt");
        if !requirements_path.exists() {
            return Err(anyhow::anyhow!("requirements.txt not found"));
        }

        let content = std::fs::read_to_string(&requirements_path)?;
        let mut deps = Vec::new();

        for line in content.lines() {
            let trimmed = line.trim();

            // Skip comments and empty lines
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }

            // Parse different formats: name==version, name>=version, name, etc.
            let (name, version) = if let Some(pos) = trimmed.find("==") {
                (
                    trimmed[..pos].to_string(),
                    trimmed[pos + 2..].to_string(),
                )
            } else if let Some(pos) = trimmed.find(">=") {
                (
                    trimmed[..pos].to_string(),
                    trimmed[pos + 2..].to_string(),
                )
            } else if let Some(pos) = trimmed.find("<=") {
                (
                    trimmed[..pos].to_string(),
                    trimmed[pos + 2..].to_string(),
                )
            } else if let Some(pos) = trimmed.find(">") {
                (
                    trimmed[..pos].to_string(),
                    trimmed[pos + 1..].to_string(),
                )
            } else if let Some(pos) = trimmed.find("<") {
                (
                    trimmed[..pos].to_string(),
                    trimmed[pos + 1..].to_string(),
                )
            } else {
                (trimmed.to_string(), "*".to_string())
            };

            if !name.is_empty() {
                deps.push(Dependency {
                    name: name.trim().to_string(),
                    version: version.trim().to_string(),
                    is_dev: false,
                    dependency_type: "direct".to_string(),
                });
            }
        }

        if deps.is_empty() {
            return Err(anyhow::anyhow!("No dependencies found in requirements.txt"));
        }

        Ok(deps)
    }

    /// Parse go.mod (Go)
    fn analyze_go_mod(project_root: &Path) -> Result<Vec<Dependency>> {
        let go_mod_path = project_root.join("go.mod");
        if !go_mod_path.exists() {
            return Err(anyhow::anyhow!("go.mod not found"));
        }

        let content = std::fs::read_to_string(&go_mod_path)?;
        let mut deps = Vec::new();
        let mut in_require = false;

        for line in content.lines() {
            let trimmed = line.trim();

            if trimmed.starts_with("require (") {
                in_require = true;
                continue;
            }

            if in_require && trimmed == ")" {
                in_require = false;
                continue;
            }

            if trimmed.starts_with("require ") {
                let rest = trimmed.strip_prefix("require ").unwrap_or("");
                let parts: Vec<&str> = rest.split_whitespace().collect();
                if parts.len() >= 2 {
                    deps.push(Dependency {
                        name: parts[0].to_string(),
                        version: parts[1].to_string(),
                        is_dev: false,
                        dependency_type: "direct".to_string(),
                    });
                }
                continue;
            }

            if in_require && !trimmed.is_empty() {
                let parts: Vec<&str> = trimmed.split_whitespace().collect();
                if parts.len() >= 2 {
                    deps.push(Dependency {
                        name: parts[0].to_string(),
                        version: parts[1].to_string(),
                        is_dev: false,
                        dependency_type: "direct".to_string(),
                    });
                }
            }
        }

        if deps.is_empty() {
            return Err(anyhow::anyhow!("No dependencies found in go.mod"));
        }

        Ok(deps)
    }
}

/// Result of dependency analysis
#[derive(Debug, Clone)]
pub struct DependencyAnalysisResult {
    /// Detected dependencies
    pub dependencies: Vec<Dependency>,
    /// Detected frameworks
    pub frameworks: Vec<Framework>,
    /// Which manifest file was used
    pub manifest_found: Option<String>,
}
