//! Template Loader for Prompt Engine
//!
//! Loads templates from tool_doc_index - the single source of truth!
//! Supports local template variants with DSPy integration.

use anyhow::{Context, Result};
use nats::{Connection, Message};
use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use walkdir::{DirEntry, WalkDir};

/// Template loader that references tool_doc_index templates
pub struct TemplateLoader {
    /// Path to tool_doc_index templates (source of truth)
    tool_doc_path: PathBuf,
    /// Path to local templates
    local_template_path: PathBuf,
    pub prompt_engine: PromptEngine,
}

impl TemplateLoader {
    /// Create loader pointing to tool_doc_index and local templates
    pub fn new() -> Self {
        let tool_doc_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("tool_doc_index")
            .join("templates");

        let local_template_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("local_templates");

        Self {
            tool_doc_path,
            local_template_path,
            prompt_engine: PromptEngine {}, // Initialize PromptEngine
        }
    }

    /// Load template, prioritizing local variants
    pub fn load_template(&self, template_name: &str) -> Result<Value> {
        // Check for local variant first
        if let Ok(local_template) = self.find_local_template(template_name) {
            return self.parse_template(&local_template);
        }

        // Fallback to global template
        let global_template = self.find_template(template_name)?;
        self.parse_template(&global_template)
    }

    /// Load template, prioritizing local variants with metadata
    pub fn load_template_with_metadata(
        &self,
        template_name: &str,
    ) -> Result<(Value, Option<LocalTemplateMetadata>)> {
        // Check for local variant first
        let local_path = self.local_template_path.join(format!("{}.json", template_name));
        let meta_path = self.local_template_path.join(format!("{}.meta.json", template_name));
        if local_path.exists() {
            let template = self.parse_template(&local_path)?;
            let metadata = LocalTemplateMetadata::from_file(&meta_path);
            return Ok((template, metadata));
        }
        // Fallback to global template
        let global_path = self.tool_doc_path.join(format!("{}.json", template_name));
        let template = self.parse_template(&global_path)?;
        Ok((template, None))
    }

    /// Find local template
    fn find_local_template(&self, template_name: &str) -> Result<PathBuf> {
        let local_path = self.local_template_path.join(format!("{}.json", template_name));
        if local_path.exists() {
            Ok(local_path)
        } else {
            anyhow::bail!("Local template not found: {}", template_name)
        }
    }

    /// Find global template
    fn find_template(&self, template_name: &str) -> Result<PathBuf> {
        let global_path = self.tool_doc_path.join(format!("{}.json", template_name));
        if global_path.exists() {
            Ok(global_path)
        } else {
            anyhow::bail!("Global template not found: {}", template_name)
        }
    }

    /// Parse template file
    fn parse_template(&self, template_path: &PathBuf) -> Result<Value> {
        let content = std::fs::read_to_string(template_path)
            .with_context(|| format!("Failed to read template: {:?}", template_path))?;

        serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse template: {:?}", template_path))
    }

    /// Load and optimize template using PromptEngine
    pub fn load_and_optimize_template(&self, template_name: &str) -> Result<serde_json::Value> {
        let (template, _) = self.load_template_with_metadata(template_name)?;
        Ok(self.prompt_engine.optimize_prompt(&template))
    }

    /// Generate prompt from template using PromptEngine
    pub fn generate_prompt_from_template(
        &self,
        template_name: &str,
        input: &serde_json::Value,
    ) -> Result<String> {
        let optimized = self.load_and_optimize_template(template_name)?;
        Ok(self.prompt_engine.generate_prompt(&optimized, input))
    }
}

/// Metadata for local template variants
#[derive(Debug, Clone)]
pub struct LocalTemplateMetadata {
    /// Name of the global template this variant is based on
    pub global_template: String,
    /// Variant name (if any)
    pub variant: Option<String>,
    /// Additional stats (usage, performance, etc.)
    pub stats: HashMap<String, usize>,
}

impl LocalTemplateMetadata {
    pub fn from_file(meta_path: &PathBuf) -> Option<Self> {
        if meta_path.exists() {
            if let Ok(content) = fs::read_to_string(meta_path) {
                if let Ok(meta) = serde_json::from_str::<LocalTemplateMetadata>(&content) {
                    return Some(meta);
                }
            }
        }
        None
    }
}

/// Template with metadata
#[derive(Debug, Clone)]
pub struct TemplateWithMeta {
    pub name: String,
    pub path: PathBuf,
    pub content: Value,
    pub source: String,
}

/// Ensure templates stay in tool_doc_index
pub fn ensure_single_source_of_truth() -> Result<()> {
    let prompt_engine_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let templates_in_prompt_engine = prompt_engine_dir.join("templates");

    // If someone accidentally created templates in prompt_engine, warn
    if templates_in_prompt_engine.exists() {
        eprintln!(
            "WARNING: Templates found in prompt_engine! \
            Templates should only be in tool_doc_index/templates/"
        );

        // Don't auto-delete, just warn
        return Err(anyhow::anyhow!(
            "Templates should be in tool_doc_index, not prompt_engine"
        ));
    }

    Ok(())
}

pub struct TemplateCacheController {
    pub cache: HashMap<String, Value>,
    pub nats_conn: Option<Connection>,
}

impl TemplateCacheController {
    pub fn new(nats_url: Option<&str>) -> Self {
        let nats_conn = nats_url.map(|url| nats::connect(url).expect("Failed to connect to NATS"));
        Self {
            cache: HashMap::new(),
            nats_conn,
        }
    }

    /// Get template from cache or load and cache it
    pub fn get_or_load_template(&mut self, loader: &TemplateLoader, template_name: &str) -> Result<Value> {
        if let Some(template) = self.cache.get(template_name) {
            return Ok(template.clone());
        }
        let (template, _) = loader.load_template_with_metadata(template_name)?;
        self.cache.insert(template_name.to_string(), template.clone());
        Ok(template)
    }

    /// Sync template from global knowledge cache via NATS
    pub fn sync_template_from_global(&mut self, template_name: &str) -> Result<Value> {
        if let Some(conn) = &self.nats_conn {
            let subject = format!("knowledge_cache.templates.{}", template_name);
            let msg = conn.request(&subject, b"{}").expect("NATS request failed");
            let template: Value = serde_json::from_slice(&msg.data)
                .with_context(|| format!("Failed to parse NATS template for {}", template_name))?;
            self.cache.insert(template_name.to_string(), template.clone());
            Ok(template)
        } else {
            anyhow::bail!("NATS connection not available")
        }
    }

    /// Invalidate cache for a template
    pub fn invalidate_template(&mut self, template_name: &str) {
        self.cache.remove(template_name);
    }
}

/// Placeholder for PromptEngine integration
pub struct PromptEngine {
    // DSPy optimizer, metrics, etc.
    // Placeholder for actual DSPy integration
}

impl PromptEngine {
    pub fn optimize_prompt(&self, template: &serde_json::Value) -> serde_json::Value {
        // Call DSPy or other optimization logic here
        template.clone() // Placeholder
    }
    pub fn generate_prompt(&self, template: &serde_json::Value, input: &serde_json::Value) -> String {
        // Generate prompt text from template and input
        // Placeholder logic
        format!("{}", template)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_loader_points_to_tool_doc() {
        let loader = TemplateLoader::new();
        assert!(loader.tool_doc_path.ends_with("tool_doc_index/templates"));
    }

    #[test]
    fn test_no_duplicate_templates() {
        assert!(ensure_single_source_of_truth().is_ok());
    }
}
