//! Dependency Parser
//!
//! Extracts dependency manifests across ecosystems. Hardcoded templates are used by
//! default and act as the final fallback; remote providers (ETS, NATS) can be
//! introduced later without changing the parsing surface.

use anyhow::{anyhow, Result};
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use std::collections::HashSet;
use std::path::Path;
use std::sync::Arc;
use toml::Value as TomlValue;

/// A dependency extracted from a package file.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct PackageDependency {
    pub name: String,
    pub version: String,
    pub ecosystem: String,
}

/// Configuration template that can be delivered via ETS or NATS.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigTemplate {
    pub id: String,
    pub file_patterns: Vec<String>,
    pub parsing_rules: ParsingRules,
    pub metadata: TemplateMetadata,
}

/// Parsing rules describing how to extract dependencies.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsingRules {
    pub dependency_paths: Vec<String>,
    pub config_extractions: Vec<ConfigExtraction>,
    pub file_type: String,
}

/// Supplemental configuration extraction rules.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigExtraction {
    pub path: String,
    pub key: String,
    pub value_type: String,
}

/// Metadata about the template.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetadata {
    pub name: String,
    pub description: String,
    pub ecosystem: String,
    pub version: String,
}

/// Contract for template providers (hardcoded, ETS, NATS, etc).
trait TemplateProvider: Send + Sync {
    fn name(&self) -> &'static str;
    fn load(&self, file_pattern: &str) -> Result<Vec<ConfigTemplate>>;
}

/// Local hardcoded templates used as a final fallback.
#[derive(Debug, Default)]
struct HardcodedTemplateProvider;

impl TemplateProvider for HardcodedTemplateProvider {
    fn name(&self) -> &'static str {
        "hardcoded"
    }

    fn load(&self, file_pattern: &str) -> Result<Vec<ConfigTemplate>> {
        Ok(match file_pattern {
            "package.json" => vec![ConfigTemplate {
                id: "npm".to_string(),
                file_patterns: vec!["package.json".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec![
                        "dependencies".to_string(),
                        "devDependencies".to_string(),
                        "peerDependencies".to_string(),
                    ],
                    config_extractions: vec![],
                    file_type: "json".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "NPM Package".to_string(),
                    description: "Node.js package manifest".to_string(),
                    ecosystem: "npm".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "package-lock.json" => vec![ConfigTemplate {
                id: "npm-lock".to_string(),
                file_patterns: vec!["package-lock.json".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec!["dependencies".to_string()],
                    config_extractions: vec![],
                    file_type: "json".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "NPM Lockfile".to_string(),
                    description: "npm lockfile manifest".to_string(),
                    ecosystem: "npm".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "Cargo.toml" => vec![ConfigTemplate {
                id: "cargo".to_string(),
                file_patterns: vec!["Cargo.toml".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec![
                        "dependencies".to_string(),
                        "dev-dependencies".to_string(),
                        "build-dependencies".to_string(),
                    ],
                    config_extractions: vec![],
                    file_type: "toml".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "Cargo Manifest".to_string(),
                    description: "Rust crate manifest".to_string(),
                    ecosystem: "crates".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "mix.exs" => vec![ConfigTemplate {
                id: "mix".to_string(),
                file_patterns: vec!["mix.exs".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec![],
                    config_extractions: vec![],
                    file_type: "elixir-ex".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "Mix Manifest".to_string(),
                    description: "Elixir Mix manifest".to_string(),
                    ecosystem: "hex".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "requirements.txt" => vec![ConfigTemplate {
                id: "pip-req".to_string(),
                file_patterns: vec!["requirements.txt".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec![],
                    config_extractions: vec![],
                    file_type: "pip-requirements".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "Pip Requirements".to_string(),
                    description: "Python requirements file".to_string(),
                    ecosystem: "pypi".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "pyproject.toml" => vec![ConfigTemplate {
                id: "pyproject".to_string(),
                file_patterns: vec!["pyproject.toml".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec![
                        "project.dependencies".to_string(),
                        "project.optional-dependencies".to_string(),
                        "tool.poetry.dependencies".to_string(),
                        "tool.poetry.dev-dependencies".to_string(),
                    ],
                    config_extractions: vec![],
                    file_type: "toml".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "PyProject".to_string(),
                    description: "Python pyproject manifest".to_string(),
                    ecosystem: "pypi".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "go.mod" => vec![ConfigTemplate {
                id: "gomod".to_string(),
                file_patterns: vec!["go.mod".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec![],
                    config_extractions: vec![],
                    file_type: "go-mod".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "Go Modules".to_string(),
                    description: "Go module manifest".to_string(),
                    ecosystem: "go".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            "composer.json" => vec![ConfigTemplate {
                id: "composer".to_string(),
                file_patterns: vec!["composer.json".to_string()],
                parsing_rules: ParsingRules {
                    dependency_paths: vec!["require".to_string(), "require-dev".to_string()],
                    config_extractions: vec![],
                    file_type: "json".to_string(),
                },
                metadata: TemplateMetadata {
                    name: "Composer Manifest".to_string(),
                    description: "PHP Composer manifest".to_string(),
                    ecosystem: "composer".to_string(),
                    version: "1.0".to_string(),
                },
            }],
            _ => vec![],
        })
    }
}

/// Placeholder provider for ETS-backed templates (currently unimplemented).
#[derive(Debug, Clone)]
struct EtsTemplateProvider {
    _cache_name: String,
}

impl TemplateProvider for EtsTemplateProvider {
    fn name(&self) -> &'static str {
        "ets"
    }

    fn load(&self, _file_pattern: &str) -> Result<Vec<ConfigTemplate>> {
        // TODO: integrate ETS lookup.
        Ok(vec![])
    }
}

/// Placeholder provider for NATS-backed templates (currently unimplemented).
#[derive(Debug, Clone)]
struct NatsTemplateProvider {
    _connection: String,
}

impl TemplateProvider for NatsTemplateProvider {
    fn name(&self) -> &'static str {
        "nats"
    }

    fn load(&self, _file_pattern: &str) -> Result<Vec<ConfigTemplate>> {
        // TODO: integrate NATS JetStream lookup.
        Ok(vec![])
    }
}

/// Builder to configure template providers before constructing a parser.
#[derive(Default)]
pub struct DependencyParserBuilder {
    providers: Vec<Arc<dyn TemplateProvider>>,
}

impl DependencyParserBuilder {
    pub fn with_hardcoded(mut self) -> Self {
        self.providers
            .push(Arc::new(HardcodedTemplateProvider::default()));
        self
    }

    pub fn with_ets(mut self, cache: String) -> Self {
        self.providers
            .push(Arc::new(EtsTemplateProvider { _cache_name: cache }));
        self
    }

    pub fn with_nats(mut self, connection: String) -> Self {
        self.providers.push(Arc::new(NatsTemplateProvider {
            _connection: connection,
        }));
        self
    }

    pub fn with_provider<P>(mut self, provider: P) -> Self
    where
        P: TemplateProvider + 'static,
    {
        self.providers.push(Arc::new(provider));
        self
    }

    pub fn build(mut self) -> DependencyParser {
        if !self
            .providers
            .iter()
            .any(|provider| provider.name() == HardcodedTemplateProvider::default().name())
        {
            self.providers
                .push(Arc::new(HardcodedTemplateProvider::default()));
        }

        DependencyParser {
            providers: self.providers,
        }
    }
}

/// Parser for extracting dependencies from package files.
#[derive(Debug, Clone)]
pub struct DependencyParser {
    providers: Vec<Arc<dyn TemplateProvider>>,
}

impl DependencyParser {
    /// Create a parser with hardcoded fallback templates only.
    #[must_use]
    pub fn new() -> Self {
        DependencyParser::builder().with_hardcoded().build()
    }

    /// Start building a parser with custom providers.
    pub fn builder() -> DependencyParserBuilder {
        DependencyParserBuilder::default()
    }

    /// Create a parser configured with an ETS provider (future integration).
    #[must_use]
    pub fn new_with_cache(ets_cache: String) -> Self {
        DependencyParser::builder()
            .with_ets(ets_cache)
            .with_hardcoded()
            .build()
    }

    /// Create a parser configured with a NATS provider (future integration).
    #[must_use]
    pub fn new_with_nats(nats_connection: String) -> Self {
        DependencyParser::builder()
            .with_nats(nats_connection)
            .with_hardcoded()
            .build()
    }

    /// Create a parser configured with both ETS and NATS providers (future integration).
    #[must_use]
    pub fn new_with_cache_and_nats(ets_cache: String, nats_connection: String) -> Self {
        DependencyParser::builder()
            .with_ets(ets_cache)
            .with_nats(nats_connection)
            .with_hardcoded()
            .build()
    }

    /// Parse a package file, automatically resolving templates.
    pub fn parse_package_file(&self, file_path: &Path) -> Result<Vec<PackageDependency>> {
        self.parse_package_file_with_templates(file_path, None)
    }

    /// Parse a package file using provided templates or resolving them if absent.
    pub fn parse_package_file_with_templates(
        &self,
        file_path: &Path,
        templates: Option<&[ConfigTemplate]>,
    ) -> Result<Vec<PackageDependency>> {
        let content = std::fs::read_to_string(file_path)
            .map_err(|e| anyhow!("failed to read {}: {e}", file_path.display()))?;

        let file_name = file_path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("unknown");

        let resolved_templates = match templates {
            Some(t) => t.to_vec(),
            None => self.resolve_templates(file_name)?,
        };

        let mut dependencies = self.parse_using_specialized_rules(file_name, &content)?;

        let template_dependencies = self.extract_with_templates(&content, &resolved_templates)?;

        if dependencies.is_empty() {
            dependencies = template_dependencies;
        } else {
            dependencies.extend(template_dependencies);
            deduplicate_dependencies(&mut dependencies);
        }

        Ok(dependencies)
    }

    fn resolve_templates(&self, file_pattern: &str) -> Result<Vec<ConfigTemplate>> {
        for provider in &self.providers {
            let templates = provider.load(file_pattern)?;
            if !templates.is_empty() {
                return Ok(templates);
            }
        }
        Ok(vec![])
    }

    fn parse_using_specialized_rules(
        &self,
        file_name: &str,
        content: &str,
    ) -> Result<Vec<PackageDependency>> {
        Ok(match file_name {
            "package.json" => parse_npm_dependencies(content),
            "package-lock.json" => parse_npm_lock_dependencies(content),
            "Cargo.toml" => parse_cargo_dependencies(content),
            "mix.exs" => parse_mix_dependencies(content),
            "requirements.txt" => parse_pip_dependencies(content),
            "pyproject.toml" => parse_pyproject_dependencies(content),
            "go.mod" => parse_go_dependencies(content),
            "composer.json" => parse_composer_dependencies(content),
            _ => Vec::new(),
        })
    }

    fn extract_with_templates(
        &self,
        content: &str,
        templates: &[ConfigTemplate],
    ) -> Result<Vec<PackageDependency>> {
        let mut results = Vec::new();
        for template in templates {
            let mut deps = match template.parsing_rules.file_type.as_str() {
                "json" => extract_dependencies_from_json(content, template)?,
                "toml" => extract_dependencies_from_toml(content, template)?,
                // Domain-specific formats still rely on specialized parsers.
                _ => Vec::new(),
            };
            results.append(&mut deps);
        }
        deduplicate_dependencies(&mut results);
        Ok(results)
    }
}

fn deduplicate_dependencies(entries: &mut Vec<PackageDependency>) {
    let mut seen = HashSet::new();
    entries
        .retain(|dep| seen.insert((dep.name.clone(), dep.version.clone(), dep.ecosystem.clone())));
}

fn extract_dependencies_from_json(
    content: &str,
    template: &ConfigTemplate,
) -> Result<Vec<PackageDependency>> {
    let json: JsonValue = serde_json::from_str(content)?;
    let mut deps = Vec::new();
    for path in &template.parsing_rules.dependency_paths {
        if let Some(value) = json_lookup(&json, path) {
            if let Some(obj) = value.as_object() {
                for (name, version_value) in obj {
                    let version = match version_value {
                        JsonValue::String(s) => s.clone(),
                        JsonValue::Object(obj) => obj
                            .get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown")
                            .to_string(),
                        _ => "unknown".to_string(),
                    };
                    deps.push(PackageDependency {
                        name: name.clone(),
                        version,
                        ecosystem: template.metadata.ecosystem.clone(),
                    });
                }
            }
        }
    }
    Ok(deps)
}

fn extract_dependencies_from_toml(
    content: &str,
    template: &ConfigTemplate,
) -> Result<Vec<PackageDependency>> {
    let toml: TomlValue = toml::from_str(content)?;
    let mut deps = Vec::new();
    for path in &template.parsing_rules.dependency_paths {
        if let Some(value) = toml_lookup(&toml, path) {
            if let Some(table) = value.as_table() {
                for (name, version_value) in table {
                    let version = match version_value {
                        TomlValue::String(s) => s.clone(),
                        TomlValue::Table(t) => t
                            .get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown")
                            .to_string(),
                        TomlValue::Array(arr) => arr
                            .iter()
                            .filter_map(|v| v.as_str())
                            .collect::<Vec<_>>()
                            .join(","),
                        _ => "unknown".to_string(),
                    };

                    deps.push(PackageDependency {
                        name: name.clone(),
                        version,
                        ecosystem: template.metadata.ecosystem.clone(),
                    });
                }
            } else if let Some(array) = value.as_array() {
                for item in array {
                    if let Some(spec) = item.as_str() {
                        let (name, version) = split_spec(spec);
                        deps.push(PackageDependency {
                            name,
                            version,
                            ecosystem: template.metadata.ecosystem.clone(),
                        });
                    }
                }
            }
        }
    }
    Ok(deps)
}

fn json_lookup<'a>(value: &'a JsonValue, path: &str) -> Option<&'a JsonValue> {
    let mut current = value;
    for segment in path.split('.') {
        if segment.is_empty() {
            continue;
        }
        current = match current {
            JsonValue::Object(obj) => obj.get(segment)?,
            JsonValue::Array(arr) => {
                let mut matches = Vec::new();
                for element in arr {
                    if let Some(next) = json_lookup(element, segment) {
                        matches.push(next);
                    }
                }
                return matches.into_iter().next();
            }
            _ => return None,
        };
    }
    Some(current)
}

fn toml_lookup<'a>(value: &'a TomlValue, path: &str) -> Option<&'a TomlValue> {
    let mut current = value;
    for segment in path.split('.') {
        if segment.is_empty() {
            continue;
        }
        current = match current {
            TomlValue::Table(table) => table.get(segment)?,
            _ => return None,
        };
    }
    Some(current)
}

fn split_spec(spec: &str) -> (String, String) {
    const OPERATORS: [&str; 7] = ["==", ">=", "<=", "~=", "!=", ">", "<"];
    let trimmed = spec.trim();
    for op in OPERATORS {
        if let Some((name, version)) = trimmed.split_once(op) {
            return (name.trim().to_string(), format!("{}{}", op, version.trim()));
        }
    }
    if let Some((name, version)) = trimmed.split_once(' ') {
        return (name.trim().to_string(), version.trim().to_string());
    }
    (trimmed.to_string(), "unknown".to_string())
}

// --- Specialized dependency extractors (largely unchanged from previous iteration) ---

fn parse_npm_dependencies(content: &str) -> Vec<PackageDependency> {
    serde_json::from_str::<JsonValue>(content).map_or_else(
        |_| vec![],
        |package_json| {
            let mut dependencies = Vec::new();

            if let Some(deps) = package_json.get("dependencies").and_then(|d| d.as_object()) {
                for (name, version) in deps {
                    dependencies.push(PackageDependency {
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
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version.as_str().unwrap_or("unknown").to_string(),
                        ecosystem: "npm".to_string(),
                    });
                }
            }

            dependencies
        },
    )
}

fn parse_npm_lock_dependencies(content: &str) -> Vec<PackageDependency> {
    fn collect_dependencies(
        deps: &serde_json::Map<String, JsonValue>,
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

    serde_json::from_str::<JsonValue>(content).map_or_else(
        |_| vec![],
        |lock| {
            let mut dependencies = Vec::new();
            if let Some(deps) = lock.get("dependencies").and_then(|d| d.as_object()) {
                collect_dependencies(deps, &mut dependencies);
            }
            dependencies
        },
    )
}

fn parse_cargo_dependencies(content: &str) -> Vec<PackageDependency> {
    toml::from_str::<TomlValue>(content).map_or_else(
        |_| vec![],
        |cargo_toml| {
            let mut dependencies = Vec::new();

            if let Some(deps) = cargo_toml.get("dependencies").and_then(|d| d.as_table()) {
                for (name, version) in deps {
                    let version_str = match version {
                        TomlValue::String(s) => s.clone(),
                        TomlValue::Table(t) => t
                            .get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown")
                            .to_string(),
                        _ => "unknown".to_string(),
                    };
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version_str,
                        ecosystem: "crates".to_string(),
                    });
                }
            }

            if let Some(dev_deps) = cargo_toml
                .get("dev-dependencies")
                .and_then(|d| d.as_table())
            {
                for (name, version) in dev_deps {
                    let version_str = match version {
                        TomlValue::String(s) => s.clone(),
                        TomlValue::Table(t) => t
                            .get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown")
                            .to_string(),
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
        },
    )
}

fn parse_mix_dependencies(content: &str) -> Vec<PackageDependency> {
    let mut dependencies = Vec::new();
    if let Ok(dep_pattern) = Regex::new(r#":(\w+),\s*"([^"]+)""#) {
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

fn parse_pip_dependencies(content: &str) -> Vec<PackageDependency> {
    let mut dependencies = Vec::new();

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

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
            dependencies.push(PackageDependency {
                name: line.to_string(),
                version: "unknown".to_string(),
                ecosystem: "pypi".to_string(),
            });
        }
    }

    dependencies
}

fn parse_pyproject_dependencies(content: &str) -> Vec<PackageDependency> {
    let mut dependencies = Vec::new();
    let Ok(pyproject) = toml::from_str::<TomlValue>(content) else {
        return dependencies;
    };

    if let Some(project) = pyproject.get("project") {
        if let Some(items) = project.get("dependencies").and_then(|deps| deps.as_array()) {
            for item in items {
                if let Some(spec) = item.as_str() {
                    let (name, version) = split_spec(spec);
                    dependencies.push(PackageDependency {
                        name,
                        version,
                        ecosystem: "pypi".to_string(),
                    });
                }
            }
        }

        if let Some(optional) = project
            .get("optional-dependencies")
            .and_then(|deps| deps.as_table())
        {
            for items in optional.values().filter_map(|v| v.as_array()) {
                for item in items {
                    if let Some(spec) = item.as_str() {
                        let (name, version) = split_spec(spec);
                        dependencies.push(PackageDependency {
                            name,
                            version,
                            ecosystem: "pypi".to_string(),
                        });
                    }
                }
            }
        }
    }

    if let Some(tool) = pyproject.get("tool").and_then(|t| t.as_table()) {
        if let Some(poetry) = tool.get("poetry").and_then(|p| p.as_table()) {
            if let Some(table) = poetry.get("dependencies").and_then(|t| t.as_table()) {
                for (name, value) in table {
                    if name.eq_ignore_ascii_case("python") {
                        continue;
                    }
                    let version = match value {
                        TomlValue::String(s) => s.clone(),
                        TomlValue::Table(t) => t
                            .get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown")
                            .to_string(),
                        _ => "unknown".to_string(),
                    };
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version,
                        ecosystem: "pypi".to_string(),
                    });
                }
            }

            if let Some(table) = poetry.get("dev-dependencies").and_then(|t| t.as_table()) {
                for (name, value) in table {
                    let version = match value {
                        TomlValue::String(s) => s.clone(),
                        TomlValue::Table(t) => t
                            .get("version")
                            .and_then(|v| v.as_str())
                            .unwrap_or("unknown")
                            .to_string(),
                        _ => "unknown".to_string(),
                    };
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version,
                        ecosystem: "pypi".to_string(),
                    });
                }
            }
        }
    }

    dependencies
}

fn parse_go_dependencies(content: &str) -> Vec<PackageDependency> {
    let mut dependencies = Vec::new();

    for line in content.lines() {
        let line = line.trim();
        if line.starts_with("require") {
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

fn parse_composer_dependencies(content: &str) -> Vec<PackageDependency> {
    serde_json::from_str::<JsonValue>(content).map_or_else(
        |_| vec![],
        |composer_json| {
            let mut dependencies = Vec::new();

            if let Some(require) = composer_json.get("require").and_then(|r| r.as_object()) {
                for (name, version) in require {
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version.as_str().unwrap_or("unknown").to_string(),
                        ecosystem: "composer".to_string(),
                    });
                }
            }

            if let Some(require_dev) = composer_json.get("require-dev").and_then(|r| r.as_object())
            {
                for (name, version) in require_dev {
                    dependencies.push(PackageDependency {
                        name: name.clone(),
                        version: version.as_str().unwrap_or("unknown").to_string(),
                        ecosystem: "composer".to_string(),
                    });
                }
            }

            dependencies
        },
    )
}

// --- Tests ---

#[cfg(test)]
mod tests {
    use super::*;

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
        assert!(dependencies
            .iter()
            .any(|d| d.name == "tokio" && d.ecosystem == "crates"));
        assert!(dependencies
            .iter()
            .any(|d| d.name == "serde" && d.ecosystem == "crates"));
        assert!(dependencies
            .iter()
            .any(|d| d.name == "tempfile" && d.ecosystem == "crates"));
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

        assert!(dependencies
            .iter()
            .any(|d| d.name == "react" && d.version == "18.2.0"));
        assert!(dependencies
            .iter()
            .any(|d| d.name == "loose-envify" && d.version == "1.4.0"));
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

        assert!(dependencies
            .iter()
            .any(|d| d.name == "requests" && d.version.contains(">=")));
        assert!(dependencies
            .iter()
            .any(|d| d.name == "numpy" && d.version.contains("==1.26.0")));
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

        assert!(dependencies
            .iter()
            .any(|d| d.name == "laravel/framework" && d.ecosystem == "composer"));
        assert!(dependencies
            .iter()
            .any(|d| d.name == "phpunit/phpunit" && d.ecosystem == "composer"));
        assert!(dependencies.iter().any(|d| d.name == "php"));
    }
}
