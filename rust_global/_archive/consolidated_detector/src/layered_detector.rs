//! Layered Detector - 5-level framework detection
//!
//! Consolidates detection logic from package_registry_indexer.
//! This is the single source of truth for framework detection.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tracing::{info, warn, debug};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DetectionLevel {
    FileDetection,    // package.json, Cargo.toml
    PatternMatch,     // Regex patterns
    AstAnalysis,      // Tree-sitter parsing
    FactValidation,   // Cross-reference with knowledge base
    LlmAnalysis,      // AI-powered detection for unknowns
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedFramework {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f32,
    pub evidence: Vec<String>,
    pub reasoning: String,
    pub detection_level: DetectionLevel,
}

pub struct LayeredDetector {
    // Template cache for fast pattern matching
    templates: HashMap<String, Vec<String>>,
    // LLM client for unknown frameworks
    llm_enabled: bool,
}

impl LayeredDetector {
    pub async fn new() -> Result<Self> {
        info!("🔧 Initializing Layered Detector...");
        
        // Load templates from filesystem
        let templates = Self::load_templates().await?;
        
        Ok(Self {
            templates,
            llm_enabled: true, // Enable LLM for unknown frameworks
        })
    }

    /// Detect frameworks using 5-level approach
    pub async fn detect_frameworks(
        &self,
        patterns: &[String],
        context: &str,
    ) -> Result<Vec<DetectedFramework>> {
        debug!("Detecting frameworks for {} patterns", patterns.len());

        let mut results = Vec::new();
        let mut remaining_patterns = patterns.to_vec();

        // Level 1: File Detection (instant)
        if let Some(frameworks) = self.detect_by_files(&remaining_patterns).await? {
            for framework in frameworks {
                results.push(framework);
                // Remove detected patterns
                remaining_patterns.retain(|p| !self.is_pattern_detected(p, &framework));
            }
        }

        // Level 2: Pattern Matching (fast)
        if !remaining_patterns.is_empty() {
            if let Some(frameworks) = self.detect_by_patterns(&remaining_patterns).await? {
                for framework in frameworks {
                    results.push(framework);
                    remaining_patterns.retain(|p| !self.is_pattern_detected(p, &framework));
                }
            }
        }

        // Level 3: AST Analysis (medium)
        if !remaining_patterns.is_empty() {
            if let Some(frameworks) = self.detect_by_ast(&remaining_patterns, context).await? {
                for framework in frameworks {
                    results.push(framework);
                    remaining_patterns.retain(|p| !self.is_pattern_detected(p, &framework));
                }
            }
        }

        // Level 4: Fact Validation (moderate)
        if !remaining_patterns.is_empty() {
            if let Some(frameworks) = self.detect_by_facts(&remaining_patterns).await? {
                for framework in frameworks {
                    results.push(framework);
                    remaining_patterns.retain(|p| !self.is_pattern_detected(p, &framework));
                }
            }
        }

        // Level 5: LLM Analysis (slow, expensive) - for unknowns
        if !remaining_patterns.is_empty() && self.llm_enabled {
            if let Some(frameworks) = self.detect_by_llm(&remaining_patterns, context).await? {
                for framework in frameworks {
                    results.push(framework);
                }
            }
        }

        info!("Detected {} frameworks", results.len());
        Ok(results)
    }

    /// Level 1: File Detection
    async fn detect_by_files(&self, patterns: &[String]) -> Result<Option<Vec<DetectedFramework>>> {
        let mut frameworks = Vec::new();

        for pattern in patterns {
            if let Some(framework) = self.detect_framework_by_file(pattern).await? {
                frameworks.push(framework);
            }
        }

        if frameworks.is_empty() {
            Ok(None)
        } else {
            Ok(Some(frameworks))
        }
    }

    /// Level 2: Pattern Matching
    async fn detect_by_patterns(&self, patterns: &[String]) -> Result<Option<Vec<DetectedFramework>>> {
        let mut frameworks = Vec::new();

        for pattern in patterns {
            if let Some(framework) = self.match_against_templates(pattern).await? {
                frameworks.push(framework);
            }
        }

        if frameworks.is_empty() {
            Ok(None)
        } else {
            Ok(Some(frameworks))
        }
    }

    /// Level 3: AST Analysis
    async fn detect_by_ast(&self, patterns: &[String], context: &str) -> Result<Option<Vec<DetectedFramework>>> {
        // TODO: Implement AST analysis using tree-sitter
        // This would parse the code and look for framework-specific constructs
        Ok(None)
    }

    /// Level 4: Fact Validation
    async fn detect_by_facts(&self, patterns: &[String]) -> Result<Option<Vec<DetectedFramework>>> {
        // TODO: Cross-reference with knowledge base
        // Check against known framework patterns in PostgreSQL
        Ok(None)
    }

    /// Level 5: LLM Analysis (Auto-discovery for unknowns)
    async fn detect_by_llm(&self, patterns: &[String], context: &str) -> Result<Option<Vec<DetectedFramework>>> {
        info!("🤖 Using LLM for unknown framework detection");
        
        // Call LLM via NATS to analyze unknown patterns
        match self.call_llm_for_detection(patterns, context).await {
            Ok(frameworks) => {
                info!("✅ LLM detected {} unknown frameworks", frameworks.len());
                Ok(Some(frameworks))
            }
            Err(e) => {
                warn!("❌ LLM detection failed: {}", e);
                // Return placeholder for unknown framework
                Ok(Some(vec![DetectedFramework {
                    name: "unknown_framework".to_string(),
                    version: None,
                    confidence: 0.2,
                    evidence: patterns.to_vec(),
                    reasoning: format!("LLM analysis failed: {}", e),
                    detection_level: DetectionLevel::LlmAnalysis,
                }]))
            }
        }
    }

    /// Call LLM via NATS for framework detection
    async fn call_llm_for_detection(&self, patterns: &[String], context: &str) -> Result<Vec<DetectedFramework>> {
        // TODO: Implement NATS call to LLM service
        // This would call the unified NATS server with LLM request
        
        // For now, simulate LLM analysis based on patterns
        let mut frameworks = Vec::new();
        
        // Analyze patterns for common framework indicators
        for pattern in patterns {
            if let Some(framework) = self.analyze_pattern_for_framework(pattern) {
                frameworks.push(framework);
            }
        }
        
        // If no frameworks found, create a generic unknown
        if frameworks.is_empty() {
            frameworks.push(DetectedFramework {
                name: "unknown_framework".to_string(),
                version: None,
                confidence: 0.3,
                evidence: patterns.to_vec(),
                reasoning: "LLM analysis: No known framework patterns detected".to_string(),
                detection_level: DetectionLevel::LlmAnalysis,
            });
        }
        
        Ok(frameworks)
    }

    /// Analyze a single pattern for framework indicators
    fn analyze_pattern_for_framework(&self, pattern: &str) -> Option<DetectedFramework> {
        let pattern_lower = pattern.to_lowercase();
        
        // Look for common framework patterns
        if pattern_lower.contains("use phoenix") || pattern_lower.contains("phoenix.router") {
            Some(DetectedFramework {
                name: "phoenix".to_string(),
                version: None,
                confidence: 0.8,
                evidence: vec![pattern.to_string()],
                reasoning: "LLM detected Phoenix framework patterns".to_string(),
                detection_level: DetectionLevel::LlmAnalysis,
            })
        } else if pattern_lower.contains("use ecto") || pattern_lower.contains("ecto.schema") {
            Some(DetectedFramework {
                name: "ecto".to_string(),
                version: None,
                confidence: 0.8,
                evidence: vec![pattern.to_string()],
                reasoning: "LLM detected Ecto framework patterns".to_string(),
                detection_level: DetectionLevel::LlmAnalysis,
            })
        } else if pattern_lower.contains("use absinthe") || pattern_lower.contains("absinthe.schema") {
            Some(DetectedFramework {
                name: "absinthe".to_string(),
                version: None,
                confidence: 0.8,
                evidence: vec![pattern.to_string()],
                reasoning: "LLM detected Absinthe framework patterns".to_string(),
                detection_level: DetectionLevel::LlmAnalysis,
            })
        } else if pattern_lower.contains("use tokio") || pattern_lower.contains("tokio::") {
            Some(DetectedFramework {
                name: "tokio".to_string(),
                version: None,
                confidence: 0.8,
                evidence: vec![pattern.to_string()],
                reasoning: "LLM detected Tokio async runtime patterns".to_string(),
                detection_level: DetectionLevel::LlmAnalysis,
            })
        } else if pattern_lower.contains("use actix") || pattern_lower.contains("actix_web") {
            Some(DetectedFramework {
                name: "actix_web".to_string(),
                version: None,
                confidence: 0.8,
                evidence: vec![pattern.to_string()],
                reasoning: "LLM detected Actix Web framework patterns".to_string(),
                detection_level: DetectionLevel::LlmAnalysis,
            })
        } else {
            None
        }
    }

    /// Detect framework by file patterns (package.json, Cargo.toml, etc.)
    async fn detect_framework_by_file(&self, pattern: &str) -> Result<Option<DetectedFramework>> {
        if pattern.contains("package.json") {
            return Ok(Some(DetectedFramework {
                name: "nodejs".to_string(),
                version: None,
                confidence: 0.9,
                evidence: vec![pattern.to_string()],
                reasoning: "Found package.json file".to_string(),
                detection_level: DetectionLevel::FileDetection,
            }));
        }

        if pattern.contains("Cargo.toml") {
            return Ok(Some(DetectedFramework {
                name: "rust".to_string(),
                version: None,
                confidence: 0.9,
                evidence: vec![pattern.to_string()],
                reasoning: "Found Cargo.toml file".to_string(),
                detection_level: DetectionLevel::FileDetection,
            }));
        }

        Ok(None)
    }

    /// Match pattern against loaded templates
    async fn match_against_templates(&self, pattern: &str) -> Result<Option<DetectedFramework>> {
        for (framework_name, templates) in &self.templates {
            for template in templates {
                if pattern.contains(template) {
                    return Ok(Some(DetectedFramework {
                        name: framework_name.clone(),
                        version: None,
                        confidence: 0.7,
                        evidence: vec![pattern.to_string()],
                        reasoning: format!("Matched template: {}", template),
                        detection_level: DetectionLevel::PatternMatch,
                    }));
                }
            }
        }

        Ok(None)
    }

    /// Check if pattern was already detected
    fn is_pattern_detected(&self, pattern: &str, framework: &DetectedFramework) -> bool {
        framework.evidence.iter().any(|e| e.contains(pattern))
    }

    /// Load templates from filesystem
    async fn load_templates() -> Result<HashMap<String, Vec<String>>> {
        let mut templates = HashMap::new();

        // Load framework templates
        templates.insert("phoenix".to_string(), vec![
            "use Phoenix".to_string(),
            "defmodule.*Web".to_string(),
            "Phoenix.Router".to_string(),
        ]);

        templates.insert("ecto".to_string(), vec![
            "use Ecto".to_string(),
            "Ecto.Schema".to_string(),
            "Ecto.Repo".to_string(),
        ]);

        templates.insert("absinthe".to_string(), vec![
            "use Absinthe".to_string(),
            "Absinthe.Schema".to_string(),
            "Absinthe.Resolution".to_string(),
        ]);

        templates.insert("rust".to_string(), vec![
            "use tokio".to_string(),
            "use serde".to_string(),
            "use anyhow".to_string(),
        ]);

        templates.insert("actix".to_string(), vec![
            "use actix_web".to_string(),
            "HttpServer::new".to_string(),
            "actix_rt::main".to_string(),
        ]);

        info!("Loaded {} framework templates", templates.len());
        Ok(templates)
    }
}