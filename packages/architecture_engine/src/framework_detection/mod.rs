//! Framework Detection - Detects frameworks in codebase
//!
//! Detects frameworks by file patterns and signatures:
//! - Next.js (next.config.js)
//! - React (package.json with react)
//! - Vue (package.json with vue)
//! - Phoenix (mix.exs with phoenix)
//! - Django (manage.py, settings.py)
//! - Rails (Gemfile with rails)
//! - Spring Boot (pom.xml with spring-boot)
//! - Express (package.json with express)

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// Framework detection result
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Framework {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f64,
    pub evidence: Vec<PathBuf>,
}

impl Framework {
    pub fn new(name: impl Into<String>, evidence: Vec<PathBuf>) -> Self {
        Self {
            name: name.into(),
            version: None,
            confidence: 0.9,
            evidence,
        }
    }
}

/// Detect frameworks in a directory
pub fn detect_frameworks(root: &Path) -> Vec<Framework> {
    let mut frameworks = Vec::new();

    // Check for package.json first (covers many JS/TS frameworks)
    if let Some(package_json) = find_file(root, "package.json") {
        // Read package.json to detect React, Vue, Next.js, etc.
        if let Ok(content) = std::fs::read_to_string(&package_json) {
            if content.contains("\"next\"") || content.contains("\"@next/") {
                frameworks.push(Framework::new("Next.js", vec![package_json.clone()]));
            }
            if content.contains("\"react\"") || content.contains("\"@react/") {
                frameworks.push(Framework::new("React", vec![package_json.clone()]));
            }
            if content.contains("\"vue\"") || content.contains("\"@vue/") {
                frameworks.push(Framework::new("Vue", vec![package_json.clone()]));
            }
            if content.contains("\"express\"") {
                frameworks.push(Framework::new("Express", vec![package_json.clone()]));
            }
        }
    }

    // Check for mix.exs (Elixir/Phoenix)
    if let Some(mix_exs) = find_file(root, "mix.exs") {
        if let Ok(content) = std::fs::read_to_string(&mix_exs) {
            if content.contains(":phoenix") {
                frameworks.push(Framework::new("Phoenix", vec![mix_exs]));
            }
        }
    }

    // Check for Cargo.toml (Rust)
    if let Some(cargo_toml) = find_file(root, "Cargo.toml") {
        if let Ok(content) = std::fs::read_to_string(&cargo_toml) {
            if content.contains("actix-web") {
                frameworks.push(Framework::new("Actix", vec![cargo_toml.clone()]));
            }
            if content.contains("rocket") {
                frameworks.push(Framework::new("Rocket", vec![cargo_toml.clone()]));
            }
            if content.contains("axum") {
                frameworks.push(Framework::new("Axum", vec![cargo_toml]));
            }
        }
    }

    // Check for Django (Python)
    if find_file(root, "manage.py").is_some() {
        let evidence = find_files(root, "settings.py");
        if !evidence.is_empty() {
            frameworks.push(Framework::new("Django", evidence));
        }
    }

    // Check for Rails (Ruby)
    if let Some(gemfile) = find_file(root, "Gemfile") {
        if let Ok(content) = std::fs::read_to_string(&gemfile) {
            if content.contains("rails") {
                frameworks.push(Framework::new("Rails", vec![gemfile]));
            }
        }
    }

    // Check for Spring Boot (Java)
    if let Some(pom_xml) = find_file(root, "pom.xml") {
        if let Ok(content) = std::fs::read_to_string(&pom_xml) {
            if content.contains("spring-boot") {
                frameworks.push(Framework::new("Spring Boot", vec![pom_xml]));
            }
        }
    }

    frameworks
}

/// Find first occurrence of a file
fn find_file(root: &Path, filename: &str) -> Option<PathBuf> {
    WalkDir::new(root)
        .follow_links(false)
        .max_depth(5) // Limit depth for performance
        .into_iter()
        .filter_map(|e| e.ok())
        .find(|e| {
            e.path().is_file()
                && e.path()
                    .file_name()
                    .and_then(|n| n.to_str())
                    .map(|n| n == filename)
                    .unwrap_or(false)
        })
        .map(|e| e.path().to_path_buf())
}

/// Find all occurrences of a file
fn find_files(root: &Path, filename: &str) -> Vec<PathBuf> {
    WalkDir::new(root)
        .follow_links(false)
        .max_depth(5)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| {
            e.path().is_file()
                && e.path()
                    .file_name()
                    .and_then(|n| n.to_str())
                    .map(|n| n == filename)
                    .unwrap_or(false)
        })
        .map(|e| e.path().to_path_buf())
        .collect()
}

/// Get framework statistics (name, count)
pub fn framework_stats(root: &Path) -> Vec<(String, usize)> {
    let frameworks = detect_frameworks(root);
    let mut stats: std::collections::HashMap<String, usize> = std::collections::HashMap::new();

    for fw in frameworks {
        *stats.entry(fw.name).or_insert(0) += 1;
    }

    let mut result: Vec<_> = stats.into_iter().collect();
    result.sort_by(|a, b| b.1.cmp(&a.1));
    result
}
