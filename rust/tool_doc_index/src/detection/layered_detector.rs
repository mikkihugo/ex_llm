//! Layered Detection System
//!
//! Implements fast-to-slow, cheap-to-expensive detection strategy:
//! Level 1: File/Config detection (instant, free)
//! Level 2: Pattern matching (fast, cheap)
//! Level 3: AST analysis (medium, moderate)
//! Level 4: Fact validation (medium, moderate)
//! Level 5: LLM analysis (slow, expensive)

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;
use tokio::fs;
use dashmap::DashMap;
use regex::Regex;

/// Detection result with confidence scoring
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayeredDetectionResult {
    pub technology_id: String,
    pub technology_name: String,
    pub category: String,
    pub confidence: f32,
    pub detection_level: DetectionLevel,
    pub evidence: Vec<Evidence>,
    pub metadata: HashMap<String, serde_json::Value>,
    pub sub_technologies: Vec<SubTechnology>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DetectionLevel {
    FileDetection,    // Level 1
    PatternMatch,     // Level 2
    AstAnalysis,      // Level 3
    FactValidation,   // Level 4
    LlmAnalysis,      // Level 5
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Evidence {
    pub source: String,
    pub description: String,
    pub confidence_contribution: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubTechnology {
    pub name: String,
    pub confidence: f32,
    pub patterns: Vec<String>,
}

/// Template loaded from JSON
#[derive(Debug, Clone, Deserialize)]
pub struct DetectionTemplate {
    pub id: String,
    pub name: String,
    pub category: String,
    pub detect: DetectSignatures,
    #[serde(default)]
    pub confidence: ConfidenceConfig,
    #[serde(default)]
    pub llm: Option<LlmConfig>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct DetectSignatures {
    #[serde(rename = "configFiles", default)]
    pub config_files: Vec<String>,
    #[serde(rename = "lockFiles", default)]
    pub lock_files: Vec<String>,
    #[serde(rename = "directoryPatterns", default)]
    pub directory_patterns: Vec<String>,
    #[serde(rename = "fileExtensions", default)]
    pub file_extensions: Vec<String>,
    #[serde(rename = "npmDependencies", default)]
    pub npm_dependencies: Vec<String>,
    #[serde(rename = "cargoDependencies", default)]
    pub cargo_dependencies: Vec<String>,
    #[serde(default)]
    pub patterns: Vec<String>,
    #[serde(rename = "importPatterns", default)]
    pub import_patterns: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ConfidenceConfig {
    #[serde(rename = "baseWeight", default = "default_confidence")]
    pub base_weight: f32,
    #[serde(default)]
    pub boosts: HashMap<String, ConfidenceBoost>,
}

impl Default for ConfidenceConfig {
    fn default() -> Self {
        Self {
            base_weight: default_confidence(),
            boosts: HashMap::new(),
        }
    }
}

fn default_confidence() -> f32 {
    0.7
}

#[derive(Debug, Clone, Deserialize)]
pub struct ConfidenceBoost {
    pub patterns: Vec<String>,
    pub boost: f32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LlmConfig {
    pub trigger: LlmTrigger,
    pub prompts: HashMap<String, String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LlmTrigger {
    #[serde(rename = "minConfidence", default)]
    pub min_confidence: f32,
    #[serde(rename = "maxConfidence", default = "default_max_confidence")]
    pub max_confidence: f32,
}

fn default_max_confidence() -> f32 {
    0.7
}

/// Compiled template with pre-compiled regex patterns
pub struct CompiledTemplate {
    pub template: DetectionTemplate,
    pub compiled_patterns: Vec<Regex>,
    pub compiled_import_patterns: Vec<Regex>,
    pub boost_patterns: HashMap<String, Vec<Regex>>,
}

/// Layered detector with template auto-loading
pub struct LayeredDetector {
    templates: Arc<DashMap<String, CompiledTemplate>>,
    cache: Arc<DashMap<String, LayeredDetectionResult>>,
    nats_client: Option<async_nats::Client>,
}

impl LayeredDetector {
    /// Create new detector and auto-load templates
    pub async fn new() -> Result<Self> {
        let nats_client = Self::connect_nats().await.ok();

        let detector = Self {
            templates: Arc::new(DashMap::new()),
            cache: Arc::new(DashMap::new()),
            nats_client,
        };

        detector.load_templates().await?;
        Ok(detector)
    }

    /// Connect to NATS for LLM requests
    async fn connect_nats() -> Result<async_nats::Client> {
        let nats_url = std::env::var("NATS_URL")
            .unwrap_or_else(|_| "nats://localhost:4222".to_string());

        let client = async_nats::connect(&nats_url).await?;
        tracing::info!("Connected to NATS for LLM calls: {}", nats_url);
        Ok(client)
    }

    /// Auto-discover and load all templates from directories
    async fn load_templates(&self) -> Result<()> {
        let template_dirs = vec![
            "templates/language",
            "templates/framework",
            "templates/database",
            "templates/messaging",
            "templates/security",
        ];

        for dir in template_dirs {
            if let Ok(mut entries) = fs::read_dir(dir).await {
                while let Ok(Some(entry)) = entries.next_entry().await {
                    let path = entry.path();
                    if path.extension().and_then(|s| s.to_str()) == Some("json") {
                        if let Err(e) = self.load_template(&path).await {
                            tracing::warn!("Failed to load template {:?}: {}", path, e);
                        }
                    }
                }
            }
        }

        tracing::info!("Loaded {} templates", self.templates.len());
        Ok(())
    }

    /// Load and compile a single template
    async fn load_template(&self, path: &Path) -> Result<()> {
        let content = fs::read_to_string(path).await?;
        let template: DetectionTemplate = serde_json::from_str(&content)?;

        // Compile regex patterns
        let compiled_patterns: Vec<Regex> = template
            .detect
            .patterns
            .iter()
            .filter_map(|p| Regex::new(p).ok())
            .collect();

        let compiled_import_patterns: Vec<Regex> = template
            .detect
            .import_patterns
            .iter()
            .filter_map(|p| Regex::new(p).ok())
            .collect();

        // Compile boost patterns
        let mut boost_patterns = HashMap::new();
        for (key, boost) in &template.confidence.boosts {
            let patterns: Vec<Regex> = boost
                .patterns
                .iter()
                .filter_map(|p| Regex::new(p).ok())
                .collect();
            boost_patterns.insert(key.clone(), patterns);
        }

        let compiled = CompiledTemplate {
            template: template.clone(),
            compiled_patterns,
            compiled_import_patterns,
            boost_patterns,
        };

        self.templates.insert(template.id.clone(), compiled);
        Ok(())
    }

    /// Detect technologies in a project (layered approach)
    pub async fn detect(&self, project_path: &Path) -> Result<Vec<LayeredDetectionResult>> {
        let mut results = Vec::new();

        // Run all templates in parallel
        let mut handles = Vec::new();
        for entry in self.templates.iter() {
            let template = entry.value().clone();
            let path = project_path.to_path_buf();
            let handle = tokio::spawn(async move {
                Self::detect_with_template(&template, &path).await
            });
            handles.push(handle);
        }

        // Collect results
        for handle in handles {
            if let Ok(Ok(Some(result))) = handle.await {
                results.push(result);
            }
        }

        // Sort by confidence (highest first)
        results.sort_by(|a, b| b.confidence.partial_cmp(&a.confidence).unwrap());

        // Publish results as an event for downstream consumers
        if let Some(nats) = &self.nats_client {
            self.publish_results(project_path, &results, nats).await.ok();
        }

        Ok(results)
    }

    /// Publish detection results to NATS for downstream consumers
    async fn publish_results(
        &self,
        project_path: &Path,
        results: &[LayeredDetectionResult],
        nats: &async_nats::Client,
    ) -> Result<()> {
        let codebase_id = project_path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("unknown");

        let payload = serde_json::json!({
            "codebase_id": codebase_id,
            "codebase_path": project_path.to_string_lossy(),
            "snapshot_id": chrono::Utc::now().timestamp(),
            "detected_technologies": results.iter()
                .map(|r| format!("{}:{}", r.category, r.technology_name))
                .collect::<Vec<_>>(),
            "summary": {
                "technologies": results.iter()
                    .map(|r| serde_json::json!({
                        "id": r.technology_id,
                        "name": r.technology_name,
                        "category": r.category,
                        "confidence": r.confidence,
                    }))
                    .collect::<Vec<_>>(),
            },
            "metadata": {
                "detection_timestamp": chrono::Utc::now().to_rfc3339(),
                "detection_method": "rust_layered",
                "total_detections": results.len(),
            },
            "features": {
                "languages_count": results.iter().filter(|r| r.category == "language").count(),
                "frameworks_count": results.iter().filter(|r| r.category.contains("framework")).count(),
                "databases_count": results.iter().filter(|r| r.category == "database").count(),
            }
        });

        let subject = "events.technology_detected";
        nats.publish(subject.clone(), payload.to_string().into()).await?;

        tracing::info!(
            "Published {} detection results to NATS: {}",
            results.len(),
            subject
        );

        Ok(())
    }

    /// Detect with a single template (runs all levels)
    async fn detect_with_template(
        template: &CompiledTemplate,
        project_path: &Path,
    ) -> Result<Option<LayeredDetectionResult>> {
        let mut confidence = 0.0_f32;
        let mut evidence = Vec::new();
        let mut detection_level = DetectionLevel::FileDetection;

        // Level 1: File Detection (instant)
        let (file_conf, file_evidence) = Self::level1_file_detection(template, project_path).await?;
        confidence += file_conf;
        evidence.extend(file_evidence);

        // Early exit if high confidence
        if confidence >= 0.85 {
            return Ok(Some(Self::build_result(template, confidence, detection_level, evidence)));
        }

        // Level 2: Pattern Matching (fast)
        detection_level = DetectionLevel::PatternMatch;
        let (pattern_conf, pattern_evidence) = Self::level2_pattern_detection(template, project_path).await?;
        confidence += pattern_conf;
        evidence.extend(pattern_evidence);

        // Early exit if high confidence
        if confidence >= 0.85 {
            return Ok(Some(Self::build_result(template, confidence, detection_level, evidence)));
        }

        // Only proceed if we have some confidence
        if confidence < 0.3 {
            return Ok(None);
        }

        // Level 3: AST Analysis (medium cost) - TODO: integrate with universal parser
        // Level 4: Fact Validation (medium cost) - TODO: query fact system

        // Level 5: LLM Analysis (expensive, only if needed)
        if let Some(llm_config) = &template.template.llm {
            if confidence >= llm_config.trigger.min_confidence
                && confidence <= llm_config.trigger.max_confidence {
                detection_level = DetectionLevel::LlmAnalysis;

                if let Some(nats) = &self.nats_client {
                    if let Ok((llm_conf, llm_evidence)) = Self::level5_llm_analysis(
                        template,
                        project_path,
                        confidence,
                        nats
                    ).await {
                        confidence += llm_conf;
                        evidence.extend(llm_evidence);
                    }
                }
            }
        }

        Ok(Some(Self::build_result(template, confidence, detection_level, evidence)))
    }

    /// Level 1: File/Config detection
    async fn level1_file_detection(
        template: &CompiledTemplate,
        project_path: &Path,
    ) -> Result<(f32, Vec<Evidence>)> {
        let mut confidence = 0.0;
        let mut evidence = Vec::new();

        // Check config files
        for config_file in &template.template.detect.config_files {
            let path = project_path.join(config_file);
            if path.exists() {
                confidence += 0.3;
                evidence.push(Evidence {
                    source: "config_file".to_string(),
                    description: format!("Found {}", config_file),
                    confidence_contribution: 0.3,
                });
            }
        }

        // Check lock files
        for lock_file in &template.template.detect.lock_files {
            let path = project_path.join(lock_file);
            if path.exists() {
                confidence += 0.1;
                evidence.push(Evidence {
                    source: "lock_file".to_string(),
                    description: format!("Found {}", lock_file),
                    confidence_contribution: 0.1,
                });
            }
        }

        // Check directory patterns
        for dir_pattern in &template.template.detect.directory_patterns {
            let path = project_path.join(dir_pattern);
            if path.exists() && path.is_dir() {
                confidence += 0.15;
                evidence.push(Evidence {
                    source: "directory".to_string(),
                    description: format!("Found directory {}", dir_pattern),
                    confidence_contribution: 0.15,
                });
            }
        }

        Ok((confidence.min(0.6), evidence))
    }

    /// Level 2: Pattern detection
    async fn level2_pattern_detection(
        template: &CompiledTemplate,
        project_path: &Path,
    ) -> Result<(f32, Vec<Evidence>)> {
        let mut confidence = 0.0;
        let mut evidence = Vec::new();

        // Sample files for pattern matching (limit to 20 files for speed)
        let sample_files = Self::sample_files(project_path, 20).await?;

        for file_path in sample_files {
            if let Ok(content) = fs::read_to_string(&file_path).await {
                // Match code patterns
                for (idx, pattern) in template.compiled_patterns.iter().enumerate() {
                    if pattern.is_match(&content) {
                        confidence += 0.1;
                        evidence.push(Evidence {
                            source: "code_pattern".to_string(),
                            description: format!("Matched pattern {} in {:?}", idx, file_path.file_name()),
                            confidence_contribution: 0.1,
                        });
                    }
                }
            }
        }

        Ok((confidence.min(0.4), evidence))
    }

    /// Sample files from project for analysis
    async fn sample_files(project_path: &Path, max_files: usize) -> Result<Vec<std::path::PathBuf>> {
        let mut files = Vec::new();
        let mut entries = fs::read_dir(project_path).await?;

        while let Ok(Some(entry)) = entries.next_entry().await {
            if files.len() >= max_files {
                break;
            }

            let path = entry.path();
            if path.is_file() {
                files.push(path);
            }
        }

        Ok(files)
    }

    /// Level 5: LLM Analysis via NATS
    async fn level5_llm_analysis(
        template: &CompiledTemplate,
        project_path: &Path,
        current_confidence: f32,
        nats: &async_nats::Client,
    ) -> Result<(f32, Vec<Evidence>)> {
        let mut confidence = 0.0;
        let mut evidence = Vec::new();

        // Build LLM prompt from template
        if let Some(llm_config) = &template.template.llm {
            // Sample some files for context
            let sample_files = Self::sample_files(project_path, 5).await?;
            let mut context_snippets = Vec::new();

            for file_path in sample_files {
                if let Ok(content) = fs::read_to_string(&file_path).await {
                    // Take first 500 chars
                    context_snippets.push(content.chars().take(500).collect::<String>());
                }
            }

            // Build prompt
            let prompt = format!(
                "Technology: {}\nContext: {}\nCode samples:\n{}\n\nQuestion: {}",
                template.template.name,
                llm_config.prompts.get("context").unwrap_or(&"".to_string()),
                context_snippets.join("\n---\n"),
                llm_config.prompts.values().next().unwrap_or(&"Is this technology present?".to_string())
            );

            // Call LLM via NATS
            let request = serde_json::json!({
                "model": "claude-3-5-sonnet-20241022",
                "max_tokens": 200,
                "messages": [{
                    "role": "user",
                    "content": prompt
                }]
            });

            match nats.request("llm.analyze", request.to_string().into()).await {
                Ok(response) => {
                    if let Ok(result) = serde_json::from_slice::<serde_json::Value>(&response.payload) {
                        // Parse LLM response for confidence
                        let response_text = result["content"][0]["text"]
                            .as_str()
                            .unwrap_or("")
                            .to_lowercase();

                        if response_text.contains("yes") || response_text.contains("confirmed") {
                            confidence += 0.2;
                            evidence.push(Evidence {
                                source: "llm_analysis".to_string(),
                                description: "LLM confirmed technology presence".to_string(),
                                confidence_contribution: 0.2,
                            });
                        } else if response_text.contains("likely") || response_text.contains("probably") {
                            confidence += 0.1;
                            evidence.push(Evidence {
                                source: "llm_analysis".to_string(),
                                description: "LLM suggests likely presence".to_string(),
                                confidence_contribution: 0.1,
                            });
                        }

                        tracing::info!(
                            "LLM analysis for {}: confidence boost = {}",
                            template.template.name,
                            confidence
                        );
                    }
                }
                Err(e) => {
                    tracing::warn!("LLM NATS request failed: {}", e);
                }
            }
        }

        Ok((confidence.min(0.3), evidence))
    }

    /// Build final result
    fn build_result(
        template: &CompiledTemplate,
        confidence: f32,
        detection_level: DetectionLevel,
        evidence: Vec<Evidence>,
    ) -> LayeredDetectionResult {
        LayeredDetectionResult {
            technology_id: template.template.id.clone(),
            technology_name: template.template.name.clone(),
            category: template.template.category.clone(),
            confidence: confidence.min(1.0),
            detection_level,
            evidence,
            metadata: HashMap::new(),
            sub_technologies: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_detector_creation() {
        let detector = LayeredDetector::new().await;
        assert!(detector.is_ok());
    }
}
