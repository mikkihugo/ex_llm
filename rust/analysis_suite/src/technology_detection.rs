//! Technology Detection Integration
//!
//! Bridges analysis_suite with tool_doc_index's LayeredDetector

use anyhow::Result;
use std::path::Path;
use tool_doc_index::detection::{LayeredDetector, LayeredDetectionResult};

/// Technology detection facade for analysis suite
pub struct TechnologyDetection {
    detector: LayeredDetector,
}

impl TechnologyDetection {
    /// Create new technology detection
    pub async fn new() -> Result<Self> {
        let detector = LayeredDetector::new().await?;
        Ok(Self { detector })
    }

    /// Detect technologies in a codebase
    pub async fn detect_technologies(&self, codebase_path: &Path) -> Result<Vec<LayeredDetectionResult>> {
        self.detector.detect(codebase_path).await
    }

    /// Detect and return summary
    pub async fn detect_summary(&self, codebase_path: &Path) -> Result<TechnologySummary> {
        let results = self.detect_technologies(codebase_path).await?;

        let mut summary = TechnologySummary {
            languages: Vec::new(),
            frameworks: Vec::new(),
            databases: Vec::new(),
            total_confidence: 0.0,
            detection_count: results.len(),
        };

        for result in results {
            match result.category.as_str() {
                "language" => summary.languages.push(result.technology_name.clone()),
                "frontend_framework" | "backend_framework" | "fullstack_framework" => {
                    summary.frameworks.push(result.technology_name.clone())
                }
                "database" => summary.databases.push(result.technology_name.clone()),
                _ => {}
            }
            summary.total_confidence += result.confidence;
        }

        if !results.is_empty() {
            summary.total_confidence /= results.len() as f32;
        }

        Ok(summary)
    }
}

/// Technology detection summary
#[derive(Debug, Clone)]
pub struct TechnologySummary {
    pub languages: Vec<String>,
    pub frameworks: Vec<String>,
    pub databases: Vec<String>,
    pub total_confidence: f32,
    pub detection_count: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_technology_detection() {
        let detection = TechnologyDetection::new().await;
        assert!(detection.is_ok());
    }
}
