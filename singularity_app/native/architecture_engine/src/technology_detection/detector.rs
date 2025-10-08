//! Framework Detection
//!
//! Extensible framework detection system with pluggable detectors and patterns.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Framework detection result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkDetection {
    pub frameworks: Vec<DetectedFramework>,
    pub confidence_scores: HashMap<String, f64>,
    pub ecosystem_hints: Vec<String>,
    pub metadata: DetectionMetadata,
}

/// Detected framework information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectedFramework {
    pub name: String,
    pub category: FrameworkCategory,
    pub version_hints: Vec<String>,
    pub usage_patterns: Vec<String>,
    pub confidence: f64,
    pub detector_source: String,
}

/// Framework categories (extensible)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FrameworkCategory {
    WebFramework,
    Database,
    Testing,
    BuildTool,
    Deployment,
    Monitoring,
    Security,
    UI,
    Mobile,
    ML,
    DataProcessing,
    Messaging,
    Caching,
    Search,
    Other(String), // Extensible category
}

/// Detection metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionMetadata {
    pub detection_time: chrono::DateTime<chrono::Utc>,
    pub file_count: usize,
    pub total_patterns_checked: usize,
    pub detector_version: String,
}

/// Framework pattern definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkPattern {
    pub name: String,
    pub patterns: Vec<String>,
    pub category: FrameworkCategory,
    pub weight: f64,
    pub version_patterns: Vec<String>,
}

/// Trait for framework detectors
pub trait FrameworkDetectorTrait {
    fn detect(&self, content: &str, file_path: &str) -> Result<FrameworkDetection>;
    fn get_name(&self) -> &str;
    fn get_version(&self) -> &str;
}

/// Registry for framework patterns
pub struct FrameworkPatternRegistry {
    patterns: HashMap<String, FrameworkPattern>,
    detectors: Vec<Box<dyn FrameworkDetectorTrait>>,
}

// Fact system interface removed - NIF should not have external system dependencies

impl FrameworkPatternRegistry {
    pub fn new() -> Self {
        Self {
            patterns: HashMap::new(),
            detectors: Vec::new(),
        }
    }

    /// Register a framework pattern
    pub fn register_pattern(&mut self, pattern: FrameworkPattern) {
        self.patterns.insert(pattern.name.clone(), pattern);
    }

    /// Register a custom detector
    pub fn register_detector(&mut self, detector: Box<dyn FrameworkDetectorTrait>) {
        self.detectors.push(detector);
    }

    /// Load patterns from configuration
    pub fn load_from_config(&mut self, _config_path: &str) -> Result<()> {
        // Load patterns from JSON/YAML config file
        // This allows external configuration of patterns
        Ok(())
    }

    /// Detect frameworks using all registered detectors
    pub fn detect_frameworks(&self, content: &str, file_path: &str) -> Result<FrameworkDetection> {
        let mut all_frameworks = Vec::new();
        let mut confidence_scores = HashMap::new();
        let mut ecosystem_hints = Vec::new();
        let mut total_patterns_checked = 0;

        // Use built-in pattern detector
        let pattern_detection = self.detect_with_patterns(content)?;
        all_frameworks.extend(pattern_detection.frameworks);
        confidence_scores.extend(pattern_detection.confidence_scores);
        ecosystem_hints.extend(pattern_detection.ecosystem_hints);
        total_patterns_checked += self.patterns.len();

        // Use custom detectors
        for detector in &self.detectors {
            let detection = detector.detect(content, file_path)?;
            all_frameworks.extend(detection.frameworks);
            confidence_scores.extend(detection.confidence_scores);
            ecosystem_hints.extend(detection.ecosystem_hints);
        }

        Ok(FrameworkDetection {
            frameworks: all_frameworks,
            confidence_scores,
            ecosystem_hints,
            metadata: DetectionMetadata {
                detection_time: chrono::Utc::now(),
                file_count: 1,
                total_patterns_checked,
                detector_version: "1.0.0".to_string(),
            },
        })
    }

    fn detect_with_patterns(&self, content: &str) -> Result<FrameworkDetection> {
        let mut frameworks = Vec::new();
        let mut confidence_scores = HashMap::new();
        let ecosystem_hints = Vec::new();

        for (name, pattern) in &self.patterns {
            let mut matches = 0;
            let total_patterns = pattern.patterns.len();

            for regex_pattern in &pattern.patterns {
                if let Ok(regex) = regex::Regex::new(regex_pattern) {
                    if regex.is_match(content) {
                        matches += 1;
                    }
                }
            }

            let confidence = matches as f64 / total_patterns as f64;
            if confidence > 0.3 {
                confidence_scores.insert(name.clone(), confidence);

                frameworks.push(DetectedFramework {
                    name: name.clone(),
                    category: pattern.category.clone(),
                    version_hints: self.extract_version_hints(content, &pattern.version_patterns),
                    usage_patterns: pattern.patterns.clone(),
                    confidence,
                    detector_source: "pattern_registry".to_string(),
                });
            }
        }

        Ok(FrameworkDetection {
            frameworks,
            confidence_scores,
            ecosystem_hints,
            metadata: DetectionMetadata {
                detection_time: chrono::Utc::now(),
                file_count: 1,
                total_patterns_checked: self.patterns.len(),
                detector_version: "1.0.0".to_string(),
            },
        })
    }

    fn extract_version_hints(&self, content: &str, version_patterns: &[String]) -> Vec<String> {
        let mut versions = Vec::new();

        for pattern in version_patterns {
            if let Ok(regex) = regex::Regex::new(pattern) {
                for cap in regex.captures_iter(content) {
                    if let Some(version) = cap.get(1) {
                        versions.push(version.as_str().to_string());
                    }
                }
            }
        }

        versions
    }
}

// Fact system implementation removed - NIF should not have external system dependencies

/// Get historical framework decisions
/// Framework decision from fact-system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkDecision {
    pub decision_id: String,
    pub framework: String,
    pub context: String,
    pub decision: String,
    pub rationale: String,
    pub outcome: String,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// Ecosystem knowledge from fact-system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EcosystemKnowledge {
    pub ecosystem: String,
    pub frameworks: Vec<String>,
    pub patterns: Vec<String>,
    pub best_practices: Vec<String>,
}
