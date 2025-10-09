use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Framework detector with LLM fallback for low confidence cases
#[derive(Debug, Clone)]
pub struct FrameworkDetector {
    nats_client: async_nats::Client,
    confidence_threshold: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DetectionResult {
    pub framework: String,
    pub version: Option<String>,
    pub confidence: f64,
    pub method: DetectionMethod,
    pub sub_frameworks: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum DetectionMethod {
    RuleBased,        // High confidence from pattern matching
    LLMAssisted,      // Low confidence, used LLM
    LLMOnly,          // Unknown framework, LLM identified it
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CodebaseSnapshot {
    pub file_tree: Vec<String>,
    pub dependencies: serde_json::Value,
    pub sample_files: Vec<FileContent>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FileContent {
    pub path: String,
    pub content: String,
}

impl FrameworkDetector {
    pub fn new(nats_client: async_nats::Client, confidence_threshold: f64) -> Self {
        Self {
            nats_client,
            confidence_threshold,
        }
    }

    /// Detects framework with automatic LLM fallback
    pub async fn detect(&self, codebase: &CodebaseSnapshot) -> Result<DetectionResult> {
        // Step 1: Try rule-based detection
        let rule_based_result = self.detect_with_rules(codebase).await?;

        if rule_based_result.confidence >= self.confidence_threshold {
            // High confidence - return immediately
            return Ok(rule_based_result);
        }

        // Step 2: Low confidence - use LLM for verification/enhancement
        tracing::info!(
            "Low confidence ({:.2}) for framework detection, using LLM assistance",
            rule_based_result.confidence
        );

        let llm_result = self.detect_with_llm(codebase, Some(rule_based_result)).await?;

        Ok(llm_result)
    }

    /// Rule-based detection using framework JSON patterns
    async fn detect_with_rules(&self, codebase: &CodebaseSnapshot) -> Result<DetectionResult> {
        let mut best_match = DetectionResult {
            framework: "unknown".to_string(),
            version: None,
            confidence: 0.0,
            method: DetectionMethod::RuleBased,
            sub_frameworks: vec![],
        };

        // Load framework detection rules from templates_data/frameworks/
        let frameworks = self.load_framework_rules().await?;

        for framework in frameworks {
            let confidence = self.calculate_confidence(codebase, &framework);

            if confidence > best_match.confidence {
                best_match = DetectionResult {
                    framework: framework.name.clone(),
                    version: framework.version.clone(),
                    confidence,
                    method: DetectionMethod::RuleBased,
                    sub_frameworks: self.detect_sub_frameworks(codebase, &framework),
                };
            }
        }

        Ok(best_match)
    }

    /// LLM-assisted detection for low confidence or unknown frameworks
    async fn detect_with_llm(
        &self,
        codebase: &CodebaseSnapshot,
        hint: Option<DetectionResult>,
    ) -> Result<DetectionResult> {
        // Build LLM prompt
        let prompt = self.build_detection_prompt(codebase, hint.as_ref());

        // Call LLM service via NATS
        let request = serde_json::json!({
            "prompt": prompt,
            "task_type": "framework_detection",
            "complexity": "simple",
            "max_tokens": 500
        });

        let response = self
            .nats_client
            .request("ai.llm.request", serde_json::to_vec(&request)?.into())
            .await?;

        let llm_response: LLMResponse = serde_json::from_slice(&response.payload)?;

        // Parse LLM response
        Ok(DetectionResult {
            framework: llm_response.framework,
            version: llm_response.version,
            confidence: llm_response.confidence,
            method: if hint.is_some() {
                DetectionMethod::LLMAssisted
            } else {
                DetectionMethod::LLMOnly
            },
            sub_frameworks: llm_response.sub_frameworks,
        })
    }

    fn calculate_confidence(&self, codebase: &CodebaseSnapshot, framework: &FrameworkRule) -> f64 {
        let mut total_weight = 0.0;
        let mut matched_weight = 0.0;

        // Check dependencies (30% weight)
        if self.check_dependencies(codebase, &framework.dependencies) {
            matched_weight += 0.3;
        }
        total_weight += 0.3;

        // Check file structure (20% weight)
        if self.check_file_structure(codebase, &framework.directory_patterns) {
            matched_weight += 0.2;
        }
        total_weight += 0.2;

        // Check code patterns (30% weight)
        if self.check_code_patterns(codebase, &framework.patterns) {
            matched_weight += 0.3;
        }
        total_weight += 0.3;

        // Check config files (20% weight)
        if self.check_config_files(codebase, &framework.config_files) {
            matched_weight += 0.2;
        }
        total_weight += 0.2;

        matched_weight / total_weight
    }

    fn build_detection_prompt(&self, codebase: &CodebaseSnapshot, hint: Option<&DetectionResult>) -> String {
        let mut prompt = String::from("Analyze this codebase and identify the web framework being used.\n\n");

        prompt.push_str("File structure:\n");
        for file in codebase.file_tree.iter().take(20) {
            prompt.push_str(&format!("  {}\n", file));
        }

        prompt.push_str("\nDependencies:\n");
        prompt.push_str(&serde_json::to_string_pretty(&codebase.dependencies).unwrap_or_default());

        prompt.push_str("\n\nSample code files:\n");
        for file in codebase.sample_files.iter().take(3) {
            prompt.push_str(&format!("\n--- {} ---\n{}\n", file.path, &file.content[..file.content.len().min(500)]));
        }

        if let Some(h) = hint {
            prompt.push_str(&format!(
                "\n\nPreliminary detection suggests {} (confidence: {:.2}). Verify or correct this assessment.\n",
                h.framework, h.confidence
            ));
        }

        prompt.push_str("\n\nProvide JSON response with: {\"framework\": \"name\", \"version\": \"x.y\", \"confidence\": 0.95, \"sub_frameworks\": [\"list\"], \"reasoning\": \"explanation\"}");

        prompt
    }

    fn check_dependencies(&self, _codebase: &CodebaseSnapshot, _deps: &[String]) -> bool {
        // TODO: Check if dependencies match
        false
    }

    fn check_file_structure(&self, _codebase: &CodebaseSnapshot, _patterns: &[String]) -> bool {
        // TODO: Check if file patterns match
        false
    }

    fn check_code_patterns(&self, _codebase: &CodebaseSnapshot, _patterns: &[String]) -> bool {
        // TODO: Check if code patterns match
        false
    }

    fn check_config_files(&self, _codebase: &CodebaseSnapshot, _configs: &[String]) -> bool {
        // TODO: Check if config files exist
        false
    }

    fn detect_sub_frameworks(&self, _codebase: &CodebaseSnapshot, _framework: &FrameworkRule) -> Vec<String> {
        // TODO: Detect LiveView, Channels, etc.
        vec![]
    }

    async fn load_framework_rules(&self) -> Result<Vec<FrameworkRule>> {
        // TODO: Load from templates_data/frameworks/*.json
        Ok(vec![])
    }
}

#[derive(Debug, Deserialize)]
struct FrameworkRule {
    name: String,
    version: Option<String>,
    dependencies: Vec<String>,
    directory_patterns: Vec<String>,
    patterns: Vec<String>,
    config_files: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct LLMResponse {
    framework: String,
    version: Option<String>,
    confidence: f64,
    sub_frameworks: Vec<String>,
    reasoning: String,
}
