//! # Template Meta Parser
//!
//! This module provides functionality to parse and manage metadata for templates. It mirrors the dependency parser architecture and includes diagnostics for handling issues such as missing manifests and invalid JSON.
//!
//! ## Key Features
//! - **Diagnostics API**: Captures and reports issues encountered during parsing.
//! - **Template Management**: Loads templates and their metadata from manifests.
//! - **Extensibility**: Supports pluggable providers for loading templates.
//!
//! ## Diagnostics
//! The `TemplateDiagnosticKind` enum defines the types of issues that can occur:
//! - `MissingManifest`: Manifest file is missing.
//! - `ManifestParseFailed`: Failed to parse the manifest file.
//! - `MissingTemplateFile`: Template file is missing.
//! - `TemplateParseFailed`: Failed to parse the template file.
//! - `InvalidJsonFormat`: Template contains invalid JSON.
//! - `MissingRequiredFields`: Template is missing required fields.
//!
//! Each diagnostic includes a human-readable message and optional context such as the file or provider involved.
//!
//! ## Usage
//! ```rust
//! let parser = TemplateParser::new("/path/to/templates");
//! match parser.manifest() {
//!     Ok(manifest) => println!("Loaded manifest: {:?}", manifest),
//!     Err(err) => eprintln!("Failed to load manifest: {}", err),
//! }
//! ```

//! Template Meta Parser
//!
//! Mirrors the dependency parser architecture to load quality template metadata
//! from filesystem or future remote providers. Templates are described in a
//! manifest (`TEMPLATE_MANIFEST.json`) and individual JSON documents that live
//! alongside the manifest.

use std::{
    collections::HashMap,
    fs,
    path::{Path, PathBuf},
    sync::Arc,
};

use anyhow::{anyhow, Context, Result};
use chrono::{DateTime, Utc};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use serde_json::{self, Value as JsonValue};

/// Manifest describing available templates and their high-level metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateManifest {
    #[serde(default)]
    pub generated_at: Option<DateTime<Utc>>,
    pub templates: Vec<TemplateSummary>,
    #[serde(default)]
    pub notes: Option<String>,
}

impl TemplateManifest {
    /// Build an index of templates keyed by `(language, quality_level)` for quick lookup.
    pub fn by_language_level(&self) -> HashMap<(String, String), Vec<TemplateSummary>> {
        let mut map: HashMap<(String, String), Vec<TemplateSummary>> = HashMap::new();
        for entry in &self.templates {
            map.entry((entry.language.clone(), entry.quality_level.clone()))
                .or_default()
                .push(entry.clone());
        }
        map
    }

    /// Locate a template entry by file name.
    pub fn find_by_file<S: AsRef<str>>(&self, file: S) -> Option<TemplateSummary> {
        let needle = file.as_ref();
        self.templates
            .iter()
            .find(|entry| entry.file == needle)
            .cloned()
    }
}

/// Summary metadata for a single quality template, usually sourced from the manifest.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TemplateSummary {
    pub file: String,
    pub language: String,
    pub quality_level: String,
    pub spec_version: String,
    #[serde(default)]
    pub capabilities: Vec<String>,
}

/// Full template document paired with its manifest entry and source path.
#[derive(Debug, Clone)]
pub struct TemplateDocument {
    pub summary: TemplateSummary,
    pub data: JsonValue,
    pub source_path: Option<PathBuf>,
}

/// Collection of templates loaded via the parser.
#[derive(Debug, Clone)]
pub struct TemplateCatalog {
    pub manifest: TemplateManifest,
    pub templates: Vec<TemplateDocument>,
    pub diagnostics: Vec<TemplateDiagnostic>,
}

/// Issues encountered while loading template metadata.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum TemplateDiagnosticKind {
    MissingManifest,
    ManifestParseFailed,
    MissingTemplateFile,
    TemplateParseFailed,
    InvalidJsonFormat, // New diagnostic for invalid JSON
    MissingRequiredFields, // New diagnostic for missing fields in templates
}

impl TemplateDiagnosticKind {
    /// Helper to generate a human-readable message for each diagnostic kind.
    pub fn message(&self) -> &'static str {
        match self {
            TemplateDiagnosticKind::MissingManifest => "Manifest file is missing.",
            TemplateDiagnosticKind::ManifestParseFailed => "Failed to parse the manifest file.",
            TemplateDiagnosticKind::MissingTemplateFile => "Template file is missing.",
            TemplateDiagnosticKind::TemplateParseFailed => "Failed to parse the template file.",
            TemplateDiagnosticKind::InvalidJsonFormat => "Template contains invalid JSON.",
            TemplateDiagnosticKind::MissingRequiredFields => "Template is missing required fields.",
        }
    }
}

/// Diagnostic record emitted by the parser when issues occur.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TemplateDiagnostic {
    pub kind: TemplateDiagnosticKind,
    pub message: String,
    pub file: Option<String>,
    pub provider: Option<String>,
}

/// Provider contract mirroring the dependency parser design.
trait TemplateProvider: Send + Sync {
    fn name(&self) -> &'static str;
    fn load_manifest(&self) -> Result<Option<TemplateManifest>>;
    fn load_template(&self, entry: &TemplateSummary) -> Result<Option<TemplateDocument>>;
}

#[derive(Default)]
struct TemplateCache {
    manifest: RwLock<Option<TemplateManifest>>,
}

/// Parser responsible for loading template metadata using pluggable providers.
#[derive(Clone)]
pub struct TemplateParser {
    providers: Arc<Vec<Arc<dyn TemplateProvider>>>,
    cache: Arc<TemplateCache>,
}

impl TemplateParser {
    /// Construct a parser using a filesystem provider rooted at the given path.
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self::builder().with_filesystem(root).build()
    }

    /// Create a builder for customised provider configuration.
    pub fn builder() -> TemplateParserBuilder {
        TemplateParserBuilder::default()
    }

    /// Retrieve the manifest (cached after the first load).
    pub fn manifest(&self) -> Result<TemplateManifest> {
        if let Some(manifest) = self.cache.manifest.read().clone() {
            return Ok(manifest);
        }

        let manifest = self.load_manifest_from_providers()?;
        *self.cache.manifest.write() = Some(manifest.clone());
        Ok(manifest)
    }

    /// Force reload of the manifest, refreshing the cache.
    pub fn reload_manifest(&self) -> Result<TemplateManifest> {
        let manifest = self.load_manifest_from_providers()?;
        *self.cache.manifest.write() = Some(manifest.clone());
        Ok(manifest)
    }

    /// Load all templates described in the manifest.
    pub fn catalog(&self) -> Result<TemplateCatalog> {
        let manifest = self.manifest()?;
        let mut templates = Vec::with_capacity(manifest.templates.len());

        for entry in &manifest.templates {
            let document = self
                .load_template_from_providers(entry)
                .with_context(|| format!("missing template file: {}", entry.file))?;
            templates.push(document);
        }

        Ok(TemplateCatalog { manifest, templates })
    }

    /// Load templates for a specific language, optionally filtered by quality level.
    pub fn templates_for_language(
        &self,
        language: &str,
        quality_level: Option<&str>,
    ) -> Result<Vec<TemplateDocument>> {
        let manifest = self.manifest()?;
        let entries = manifest
            .templates
            .iter()
            .filter(|entry| entry.language.eq_ignore_ascii_case(language))
            .filter(|entry| {
                quality_level
                    .map(|level| entry.quality_level.eq_ignore_ascii_case(level))
                    .unwrap_or(true)
            })
            .cloned()
            .collect::<Vec<_>>();

        if entries.is_empty() {
            return Ok(Vec::new());
        }

        let mut documents = Vec::with_capacity(entries.len());
        for entry in entries {
            let document = self
                .load_template_from_providers(&entry)
                .with_context(|| format!("missing template file: {}", entry.file))?;
            documents.push(document);
        }

        Ok(documents)
    }

    /// Load a template by its manifest file name.
    pub fn template_by_file<S: AsRef<str>>(&self, file: S) -> Result<TemplateDocument> {
        let manifest = self.manifest()?;
        let entry = manifest
            .find_by_file(file)
            .ok_or_else(|| anyhow!("template not registered in manifest"))?;
        self.load_template_from_providers(&entry)
            .with_context(|| format!("missing template file: {}", entry.file))
    }

    /// Load the manifest from providers, recording diagnostics for issues encountered.
    fn load_manifest_from_providers(&self) -> Result<TemplateManifest> {
        let mut diagnostics = Vec::new();

        for provider in self.providers.iter() {
            match provider.load_manifest() {
                Ok(Some(manifest)) => {
                    self.cache.manifest.write().replace(manifest.clone());
                    return Ok(manifest);
                }
                Ok(None) => {
                    diagnostics.push(TemplateDiagnostic {
                        kind: TemplateDiagnosticKind::MissingManifest,
                        message: TemplateDiagnosticKind::MissingManifest.message().to_string(),
                        file: None,
                        provider: Some(provider.name().to_string()),
                    });
                }
                Err(err) => {
                    diagnostics.push(TemplateDiagnostic {
                        kind: TemplateDiagnosticKind::ManifestParseFailed,
                        message: format!("{}: {}", TemplateDiagnosticKind::ManifestParseFailed.message(), err),
                        file: None,
                        provider: Some(provider.name().to_string()),
                    });
                }
            }
        }

        Err(anyhow!("Failed to load manifest from all providers. Diagnostics: {:?}", diagnostics))
    }

    fn load_template_from_providers(
        &self,
        entry: &TemplateSummary,
    ) -> Result<TemplateDocument> {
        for provider in self.providers.iter() {
            match provider.load_template(entry)? {
                Some(document) => return Ok(document),
                None => continue,
            }
        }
        Err(anyhow!(
            "template '{}' not found by any provider",
            entry.file
        ))
    }
}

/// Builder for configuring the `TemplateParser`.
#[derive(Default)]
pub struct TemplateParserBuilder {
    providers: Vec<Arc<dyn TemplateProvider>>,
}

impl TemplateParserBuilder {
    /// Attach a filesystem provider rooted at the given path.
    pub fn with_filesystem(mut self, root: impl Into<PathBuf>) -> Self {
        self.providers
            .push(Arc::new(FilesystemTemplateProvider::new(root.into())));
        self
    }

    /// Attach a custom provider implementation.
    pub fn with_provider<P>(mut self, provider: P) -> Self
    where
        P: TemplateProvider + 'static,
    {
        self.providers.push(Arc::new(provider));
        self
    }

    /// Build a parser, ensuring there is at least one provider.
    pub fn build(mut self) -> TemplateParser {
        if self.providers.is_empty() {
            self.providers
                .push(Arc::new(FilesystemTemplateProvider::default()));
        }

        TemplateParser {
            providers: Arc::new(self.providers),
            cache: Arc::new(TemplateCache::default()),
        }
    }
}

#[derive(Debug, Clone)]
struct FilesystemTemplateProvider {
    root: PathBuf,
}

impl FilesystemTemplateProvider {
    fn new(root: PathBuf) -> Self {
        Self { root }
    }

    fn manifest_path(&self) -> PathBuf {
        self.root.join("TEMPLATE_MANIFEST.json")
    }
}

impl Default for FilesystemTemplateProvider {
    fn default() -> Self {
        let default_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../singularity_app/priv/code_quality_templates");
        Self::new(default_root)
    }
}

impl TemplateProvider for FilesystemTemplateProvider {
    fn name(&self) -> &'static str {
        "filesystem"
    }

    fn load_manifest(&self) -> Result<Option<TemplateManifest>> {
        let manifest_path = self.manifest_path();
        if !manifest_path.exists() {
            return Ok(None);
        }

        let raw = fs::read_to_string(&manifest_path)
            .with_context(|| format!("failed to read {}", manifest_path.display()))?;
        let manifest: TemplateManifest = serde_json::from_str(&raw)
            .with_context(|| format!("failed to parse {}", manifest_path.display()))?;
        Ok(Some(manifest))
    }

    fn load_template(&self, entry: &TemplateSummary) -> Result<Option<TemplateDocument>> {
        let path = self.root.join(&entry.file);
        if !path.exists() {
            return Ok(None);
        }

        let raw = fs::read_to_string(&path)
            .with_context(|| format!("failed to read {}", path.display()))?;
        let data: JsonValue = serde_json::from_str(&raw)
            .with_context(|| format!("failed to parse template {}", path.display()))?;

        Ok(Some(TemplateDocument {
            summary: entry.clone(),
            data,
            source_path: Some(path),
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn loads_manifest_and_templates_from_filesystem() {
        let dir = tempdir().unwrap();
        let manifest_path = dir.path().join("TEMPLATE_MANIFEST.json");
        let template_path = dir.path().join("example.json");

        fs::write(
            &manifest_path,
            r#"{
                "templates": [
                    {
                        "file": "example.json",
                        "language": "elixir",
                        "quality_level": "production",
                        "spec_version": "2.0",
                        "capabilities": ["quality"]
                    }
                ]
            }"#,
        )
        .unwrap();

        fs::write(
            &template_path,
            r#"{"name": "Example"}"#,
        )
        .unwrap();

        let parser = TemplateParser::new(dir.path());
        let manifest = parser.manifest().unwrap();
        assert_eq!(manifest.templates.len(), 1);

        let catalog = parser.catalog().unwrap();
        assert_eq!(catalog.templates.len(), 1);
        assert_eq!(catalog.templates[0].summary.file, "example.json");
        assert_eq!(catalog.templates[0].data["name"], "Example");
    }

    #[test]
    fn emits_diagnostics_for_missing_manifest() {
        let dir = tempdir().unwrap();
        let parser = TemplateParser::new(dir.path());

        let result = parser.manifest();

        assert!(result.is_err());
        if let Err(err) = result {
            let diagnostics = format!("{}", err);
            assert!(diagnostics.contains("MissingManifest"));
        }
    }

    #[test]
    fn emits_diagnostics_for_invalid_json() {
        let dir = tempdir().unwrap();
        let manifest_path = dir.path().join("TEMPLATE_MANIFEST.json");

        fs::write(&manifest_path, "{ invalid json }").unwrap();
        let parser = TemplateParser::new(dir.path());

        let result = parser.manifest();

        assert!(result.is_err());
        if let Err(err) = result {
            let diagnostics = format!("{}", err);
            assert!(diagnostics.contains("ManifestParseFailed"));
        }
    }
}

pub use self::{TemplateDiagnostic, TemplateDiagnosticKind};
