//! Template Validator
//!
//! Validates technology detection templates against schema and tests patterns

use anyhow::{Context, Result};
use serde_json::Value;
use std::path::Path;
use regex::Regex;

/// Validate a template JSON file
pub fn validate_template(template_path: &Path) -> Result<ValidationResult> {
    let content = std::fs::read_to_string(template_path)
        .context("Failed to read template file")?;

    let template: Value = serde_json::from_str(&content)
        .context("Failed to parse template JSON")?;

    let mut result = ValidationResult {
        is_valid: true,
        errors: Vec::new(),
        warnings: Vec::new(),
        template_name: template_path.file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("unknown")
            .to_string(),
    };

    // Required fields validation
    validate_required_fields(&template, &mut result);

    // Pattern validation (check if patterns are valid regex)
    validate_patterns(&template, &mut result);

    // Framework hints validation
    validate_framework_hints(&template, &mut result);

    // Code snippets validation
    validate_code_snippets(&template, &mut result);

    // LLM support validation
    validate_llm_support(&template, &mut result);

    result.is_valid = result.errors.is_empty();
    Ok(result)
}

/// Validation result
#[derive(Debug)]
pub struct ValidationResult {
    pub is_valid: bool,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
    pub template_name: String,
}

impl ValidationResult {
    pub fn print(&self) {
        if self.is_valid {
            println!("✅ {} - VALID", self.template_name);
            if !self.warnings.is_empty() {
                for warning in &self.warnings {
                    println!("  ⚠️  {}", warning);
                }
            }
        } else {
            println!("❌ {} - INVALID", self.template_name);
            for error in &self.errors {
                println!("  ❌ {}", error);
            }
            if !self.warnings.is_empty() {
                for warning in &self.warnings {
                    println!("  ⚠️  {}", warning);
                }
            }
        }
    }
}

fn validate_required_fields(template: &Value, result: &mut ValidationResult) {
    let required = ["name", "category", "version", "detector_signatures"];

    for field in &required {
        if template.get(field).is_none() {
            result.errors.push(format!("Missing required field: {}", field));
        }
    }

    // Validate category enum
    if let Some(category) = template.get("category").and_then(|c| c.as_str()) {
        let valid_categories = [
            "language", "framework", "database", "messaging",
            "security", "monitoring", "cloud", "build_tool"
        ];
        if !valid_categories.contains(&category) {
            result.errors.push(format!(
                "Invalid category '{}'. Must be one of: {:?}",
                category, valid_categories
            ));
        }
    }
}

fn validate_patterns(template: &Value, result: &mut ValidationResult) {
    if let Some(signatures) = template.get("detector_signatures") {
        if let Some(patterns) = signatures.get("patterns").and_then(|p| p.as_array()) {
            if patterns.is_empty() {
                result.errors.push("detector_signatures.patterns cannot be empty".to_string());
            }

            for (idx, pattern) in patterns.iter().enumerate() {
                if let Some(pattern_str) = pattern.as_str() {
                    match Regex::new(pattern_str) {
                        Ok(_) => {
                            // Valid regex
                        }
                        Err(e) => {
                            result.errors.push(format!(
                                "Invalid regex pattern at index {}: {} - Error: {}",
                                idx, pattern_str, e
                            ));
                        }
                    }
                } else {
                    result.errors.push(format!(
                        "Pattern at index {} is not a string", idx
                    ));
                }
            }
        } else {
            result.errors.push("detector_signatures.patterns is required and must be an array".to_string());
        }
    }
}

fn validate_framework_hints(template: &Value, result: &mut ValidationResult) {
    if let Some(hints) = template.get("framework_hints").and_then(|h| h.as_object()) {
        for (framework_name, hint) in hints {
            // Validate patterns array
            if let Some(patterns) = hint.get("patterns").and_then(|p| p.as_array()) {
                if patterns.is_empty() {
                    result.warnings.push(format!(
                        "framework_hints.{}.patterns is empty", framework_name
                    ));
                }
            } else {
                result.errors.push(format!(
                    "framework_hints.{}.patterns is required", framework_name
                ));
            }

            // Validate confidence_boost
            if let Some(boost) = hint.get("confidence_boost").and_then(|b| b.as_f64()) {
                if boost < 0.0 || boost > 1.0 {
                    result.errors.push(format!(
                        "framework_hints.{}.confidence_boost must be between 0 and 1, got {}",
                        framework_name, boost
                    ));
                }
            } else {
                result.errors.push(format!(
                    "framework_hints.{}.confidence_boost is required", framework_name
                ));
            }
        }
    }
}

fn validate_code_snippets(template: &Value, result: &mut ValidationResult) {
    if let Some(llm) = template.get("llm_support") {
        if let Some(snippets) = llm.get("code_snippets").and_then(|s| s.as_object()) {
            for (snippet_name, snippet) in snippets {
                // Required fields in snippets
                let required = ["description", "code", "patterns"];
                for field in &required {
                    if snippet.get(field).is_none() {
                        result.errors.push(format!(
                            "code_snippets.{}.{} is required", snippet_name, field
                        ));
                    }
                }

                // Validate code is not empty
                if let Some(code) = snippet.get("code").and_then(|c| c.as_str()) {
                    if code.trim().is_empty() {
                        result.warnings.push(format!(
                            "code_snippets.{}.code is empty", snippet_name
                        ));
                    }
                }

                // Validate patterns array
                if let Some(patterns) = snippet.get("patterns").and_then(|p| p.as_array()) {
                    if patterns.is_empty() {
                        result.warnings.push(format!(
                            "code_snippets.{}.patterns is empty", snippet_name
                        ));
                    }
                }

                // Validate github_examples URLs
                if let Some(examples) = snippet.get("github_examples").and_then(|e| e.as_array()) {
                    for (idx, url) in examples.iter().enumerate() {
                        if let Some(url_str) = url.as_str() {
                            if !url_str.starts_with("https://github.com/") {
                                result.warnings.push(format!(
                                    "code_snippets.{}.github_examples[{}] should be a GitHub URL",
                                    snippet_name, idx
                                ));
                            }
                        }
                    }
                }
            }
        }
    }
}

fn validate_llm_support(template: &Value, result: &mut ValidationResult) {
    if let Some(llm) = template.get("llm_support") {
        // Validate prompt_bits structure
        if let Some(bits) = llm.get("prompt_bits") {
            if bits.get("context").is_none() {
                result.warnings.push("llm_support.prompt_bits.context is recommended".to_string());
            }

            if bits.get("best_practices").is_none() {
                result.warnings.push("llm_support.prompt_bits.best_practices is recommended".to_string());
            }
        }

        // Validate fact_sources
        if let Some(sources) = llm.get("fact_sources") {
            // Validate GitHub repos format
            if let Some(repos) = sources.get("github_repos").and_then(|r| r.as_array()) {
                for (idx, repo) in repos.iter().enumerate() {
                    if let Some(repo_str) = repo.as_str() {
                        // Should be in format "owner/repo"
                        if !repo_str.contains('/') {
                            result.warnings.push(format!(
                                "fact_sources.github_repos[{}] should be in 'owner/repo' format",
                                idx
                            ));
                        }
                    }
                }
            }

            // Validate documentation URLs
            if let Some(docs) = sources.get("documentation").and_then(|d| d.as_array()) {
                for (idx, url) in docs.iter().enumerate() {
                    if let Some(url_str) = url.as_str() {
                        if !url_str.starts_with("http://") && !url_str.starts_with("https://") {
                            result.warnings.push(format!(
                                "fact_sources.documentation[{}] should be a valid URL",
                                idx
                            ));
                        }
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn test_validate_rust_template() {
        let template_path = PathBuf::from("templates/language/rust.json");
        if template_path.exists() {
            let result = validate_template(&template_path).unwrap();
            assert!(result.is_valid, "Rust template should be valid");
        }
    }

    #[test]
    fn test_validate_all_templates() {
        let templates_dir = PathBuf::from("templates");
        if templates_dir.exists() {
            let mut all_valid = true;

            for entry in walkdir::WalkDir::new(templates_dir)
                .into_iter()
                .filter_map(|e| e.ok())
                .filter(|e| e.path().extension().and_then(|s| s.to_str()) == Some("json"))
            {
                if let Ok(result) = validate_template(entry.path()) {
                    result.print();
                    if !result.is_valid {
                        all_valid = false;
                    }
                }
            }

            assert!(all_valid, "All templates should be valid");
        }
    }
}
