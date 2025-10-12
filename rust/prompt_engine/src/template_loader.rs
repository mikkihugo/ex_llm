//! Template Loader for Prompt Engine
//!
//! Loads templates from tool_doc_index - the single source of truth!
//! No duplication, just references.

use anyhow::{Context, Result};
use serde_json::Value;
use std::path::PathBuf;
use walkdir::{DirEntry, WalkDir};

/// Template loader that references tool_doc_index templates
pub struct TemplateLoader {
    /// Path to tool_doc_index templates (source of truth)
    tool_doc_path: PathBuf,
}

impl TemplateLoader {
    /// Create loader pointing to tool_doc_index
    pub fn new() -> Self {
        // Always use tool_doc_index as source of truth
        let tool_doc_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("tool_doc_index")
            .join("templates");

        Self { tool_doc_path }
    }

    /// Load template from tool_doc_index
    pub fn load_template(&self, template_name: &str) -> Result<Value> {
        let template_path = self.find_template(template_name)?;

        let content = std::fs::read_to_string(&template_path)
            .with_context(|| format!("Failed to read template: {:?}", template_path))?;

        serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse template: {}", template_name))
    }

    /// Find template file in tool_doc_index structure
    fn find_template(&self, name: &str) -> Result<PathBuf> {
        // Check direct file
        let direct_path = self.tool_doc_path.join(format!("{}.json", name));
        if direct_path.exists() {
            return Ok(direct_path);
        }

        // Check in subdirectories
        let search_dirs = vec![
            "ai",
            "bits",
            "cloud",
            "framework",
            "languages",
            "messaging",
            "monitoring",
            "security",
            "system",
            "workflows",
        ];

        for dir in search_dirs {
            let subdir_path = self.tool_doc_path.join(dir).join(format!("{}.json", name));
            if subdir_path.exists() {
                return Ok(subdir_path);
            }

            // Check nested workflows/sparc
            if dir == "workflows" {
                let sparc_path = self
                    .tool_doc_path
                    .join("workflows")
                    .join("sparc")
                    .join(format!("{}.json", name));
                if sparc_path.exists() {
                    return Ok(sparc_path);
                }
            }
        }

        anyhow::bail!("Template not found: {}", name)
    }

    /// List all available templates
    pub fn list_templates(&self) -> Result<Vec<String>> {
        let mut templates = Vec::new();

        // Walk the tool_doc_index template directory
        for entry in WalkDir::new(&self.tool_doc_path)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|e: &DirEntry| e.path().extension().map_or(false, |ext| ext == "json"))
        {
            if let Some(stem) = entry.path().file_stem() {
                templates.push(stem.to_string_lossy().to_string());
            }
        }

        templates.sort();
        templates.dedup();
        Ok(templates)
    }

    /// Get template path (for DSPy to reference)
    pub fn get_template_path(&self, template_name: &str) -> Result<PathBuf> {
        self.find_template(template_name)
    }

    /// Load template with metadata
    pub fn load_with_metadata(&self, template_name: &str) -> Result<TemplateWithMeta> {
        let template = self.load_template(template_name)?;
        let path = self.find_template(template_name)?;

        Ok(TemplateWithMeta {
            name: template_name.to_string(),
            path,
            content: template,
            source: "tool_doc_index".to_string(),
        })
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
