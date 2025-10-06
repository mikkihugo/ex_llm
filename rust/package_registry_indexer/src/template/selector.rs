//! Multi-technology template selector
//!
//! Intelligently selects the right template based on:
//! - Context (which directory/file being edited)
//! - User request
//! - Detected technologies

use tech_detector::{DetectionResults, FrameworkDetection};
use crate::template::{RegistryTemplate, Template, TemplateLoader};
use anyhow::{Context, Result};
use std::path::{Path, PathBuf};

/// Select template based on multi-tech context
pub struct TemplateSelector {
    registry: RegistryTemplate,
    loader: TemplateLoader,
}

impl TemplateSelector {
    pub fn new() -> Self {
        // Default to templates/ directory in current crate
        let templates_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("templates");

        Self {
            registry: RegistryTemplate::new(),
            loader: TemplateLoader::new(templates_dir),
        }
    }

    /// Create selector with custom templates directory
    pub fn with_templates_dir(templates_dir: impl Into<PathBuf>) -> Self {
        Self {
            registry: RegistryTemplate::new(),
            loader: TemplateLoader::new(templates_dir),
        }
    }

    /// Select best template for the task
    ///
    /// Strategy:
    /// 1. Check file path context (e.g., rust/db_service → use Rust template)
    /// 2. Check user request (e.g., "FastAPI endpoint" → use python-fastapi)
    /// 3. Match against detection results
    /// 4. Rank by confidence and relevance
    pub fn select_template(
        &self,
        detection: &DetectionResult,
        context_path: Option<&Path>,
        user_request: Option<&str>,
    ) -> Result<Template> {
        // 1. Context-based selection (highest priority)
        if let Some(path) = context_path {
            if let Some(template) = self.select_by_path(path, detection)? {
                return Ok(template);
            }
        }

        // 2. User request-based selection
        if let Some(request) = user_request {
            if let Some(template) = self.select_by_request(request, detection)? {
                return Ok(template);
            }
        }

        // 3. Primary framework fallback
        if let Some(primary) = &detection.primary_framework {
            return self.select_by_framework(primary);
        }

        anyhow::bail!("No suitable template found")
    }

    /// Select template based on file path context
    ///
    /// Examples:
    /// - rust/db_service/src/main.rs → rust-microservice
    /// - singularity_app/lib/foo.ex → elixir (GenServer or Phoenix)
    /// - ai-server/src/routes/api.ts → typescript-api-endpoint
    fn select_by_path(
        &self,
        path: &Path,
        detection: &DetectionResult,
    ) -> Result<Option<Template>> {
        let path_str = path.to_string_lossy().to_lowercase();

        // Rust projects
        if path_str.contains("rust/") || path_str.ends_with(".rs") {
            // Check for NATS patterns
            if path_str.contains("nats") || path_str.contains("consumer") {
                // Try new composable template first
                if let Ok(template) = self.loader.load("languages/rust/nats-consumer.json") {
                    return Ok(Some(template));
                }
                // Fallback to registry
                return self.registry.get("rust-nats-consumer")
                    .map(Some)
                    .context("rust-nats-consumer template not found");
            }
            // Default to microservice - use composable template
            if let Ok(template) = self.loader.load("languages/rust/microservice.json") {
                return Ok(Some(template));
            }
            // Fallback to registry
            return self.registry.get("rust-microservice-generator")
                .map(Some)
                .context("rust-microservice template not found");
        }

        // Elixir projects
        if path_str.contains("singularity_app/") || path_str.ends_with(".ex") {
            if path_str.contains("consumer") || path_str.contains("nats") {
                return self.registry.get("elixir-nats-consumer")
                    .map(Some)
                    .context("elixir-nats-consumer template not found");
            }
            // Default to GenServer or Phoenix context
            // TODO: Add more Elixir templates
        }

        // Gleam projects
        if path_str.contains("gleam") || path_str.ends_with(".gleam") {
            if path_str.contains("consumer") || path_str.contains("nats") {
                return self.registry.get("gleam-nats-consumer")
                    .map(Some)
                    .context("gleam-nats-consumer template not found");
            }
        }

        // Python projects
        if path_str.ends_with(".py") {
            // Check for FastAPI - use composable template
            if detection.frameworks.iter().any(|f| f.name == "fastapi") {
                if let Ok(template) = self.loader.load("languages/python/fastapi/crud.json") {
                    return Ok(Some(template));
                }
                // Fallback to registry
                return self.registry.get("python-fastapi-endpoint")
                    .map(Some)
                    .context("python-fastapi template not found");
            }
            // Check for Django
            if detection.frameworks.iter().any(|f| f.name == "django") {
                return self.registry.get("python-django-view")
                    .map(Some)
                    .context("python-django template not found");
            }
        }

        // TypeScript projects
        if path_str.ends_with(".ts") || path_str.ends_with(".tsx") {
            // Check for NATS
            if path_str.contains("nats") {
                // TODO: Add typescript-nats-consumer template
            }
            // Default to API endpoint
            return self.registry.get("typescript-api-endpoint")
                .map(Some)
                .context("typescript-api template not found");
        }

        Ok(None)
    }

    /// Select template based on user request keywords
    fn select_by_request(
        &self,
        request: &str,
        detection: &DetectionResult,
    ) -> Result<Option<Template>> {
        let request_lower = request.to_lowercase();

        // NATS consumers (cross-language)
        if request_lower.contains("nats") || request_lower.contains("consumer") {
            // Determine language from detection
            if detection.frameworks.iter().any(|f| f.name == "rust") {
                return self.registry.get("rust-nats-consumer").map(Some)
                    .context("rust-nats-consumer not found");
            }
            if detection.frameworks.iter().any(|f| f.name == "elixir") {
                return self.registry.get("elixir-nats-consumer").map(Some)
                    .context("elixir-nats-consumer not found");
            }
            if detection.frameworks.iter().any(|f| f.name == "gleam") {
                return self.registry.get("gleam-nats-consumer").map(Some)
                    .context("gleam-nats-consumer not found");
            }
        }

        // FastAPI - use composable template
        if request_lower.contains("fastapi") || request_lower.contains("python api") {
            if let Ok(template) = self.loader.load("languages/python/fastapi/crud.json") {
                return Ok(Some(template));
            }
            // Fallback
            return self.registry.get("python-fastapi-endpoint").map(Some)
                .context("python-fastapi not found");
        }

        // Django
        if request_lower.contains("django") {
            return self.registry.get("python-django-view").map(Some)
                .context("python-django not found");
        }

        Ok(None)
    }

    /// Select template by framework
    fn select_by_framework(&self, framework: &FrameworkInfo) -> Result<Template> {
        // Try composable templates first
        let composable_path = match framework.name.as_str() {
            "rust" => "languages/rust/microservice.json",
            "fastapi" => "languages/python/fastapi/crud.json",
            "django" => "languages/python/django/view.json",
            "typescript" | "nextjs" => "languages/typescript/api-endpoint.json",
            _ => "",
        };

        if !composable_path.is_empty() {
            if let Ok(template) = self.loader.load(composable_path) {
                return Ok(template);
            }
        }

        // Fallback to registry
        let template_id = match framework.name.as_str() {
            "rust" => "rust-microservice-generator",
            "fastapi" => "python-fastapi-endpoint",
            "django" => "python-django-view",
            "nextjs" => "typescript-api-endpoint",
            _ => anyhow::bail!("No template for framework: {}", framework.name),
        };

        self.registry.get(template_id)
            .context(format!("Template {} not found", template_id))
    }
}

impl Default for TemplateSelector {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rust_path_selection() {
        let selector = TemplateSelector::new();
        let detection = DetectionResult {
            frameworks: vec![],
            primary_framework: None,
            build_tools: vec![],
            package_managers: vec![],
            total_confidence: 0.9,
            detection_time_ms: 100,
            methods_used: vec![],
        };

        let path = Path::new("rust/db_service/src/nats_consumer.rs");
        let template = selector.select_by_path(path, &detection).unwrap();

        assert!(template.is_some());
        assert_eq!(template.unwrap().id, "rust-nats-consumer");
    }

    #[test]
    fn test_python_fastapi_request() {
        let selector = TemplateSelector::new();
        let detection = DetectionResult {
            frameworks: vec![
                FrameworkInfo {
                    name: "fastapi".to_string(),
                    version: None,
                    confidence: 0.9,
                    build_command: None,
                    output_directory: None,
                    dev_command: None,
                    install_command: None,
                    framework_type: "backend".to_string(),
                    detected_files: vec![],
                    dependencies: vec![],
                    detection_method: crate::detection::DetectionMethod::FileCodePattern,
                    metadata: std::collections::HashMap::new(),
                },
            ],
            primary_framework: None,
            build_tools: vec![],
            package_managers: vec![],
            total_confidence: 0.9,
            detection_time_ms: 100,
            methods_used: vec![],
        };

        let template = selector.select_by_request(
            "Create a FastAPI endpoint for users",
            &detection
        ).unwrap();

        assert!(template.is_some());
        assert_eq!(template.unwrap().id, "python-fastapi-endpoint");
    }
}
