//! Code Scanner Module
//!
//! Core scanning functionality for the CLI

use std::collections::HashMap;
use std::path::Path;
use anyhow::Result;
use code_quality_engine::orchestrators::{AnalysisOrchestrator, AnalysisInput};
use code_quality_engine::registry::MetaRegistry;
use code_quality_engine::analysis::architecture::PatternDetectorRegistry;

use super::{AnalysisResult, Recommendation};

pub struct CodeScanner {
    orchestrator: AnalysisOrchestrator,
    registry: MetaRegistry,
}

impl CodeScanner {
    pub fn new() -> Self {
        let registry = PatternDetectorRegistry::new();
        let orchestrator = AnalysisOrchestrator::new(registry);
        Self {
            orchestrator,
            registry: MetaRegistry::new(),
        }
    }

    pub async fn scan(&self, path: &Path) -> Result<AnalysisResult> {
        // Create analysis input
        let input = AnalysisInput {
            path: path.to_path_buf(),
            pattern_types: None, // Run all pattern types
            detection_options: Default::default(),
            analysis_options: Default::default(),
            context: HashMap::new(),
        };

        // Run comprehensive analysis
        let analysis_results = self.orchestrator.analyze_all(&input, None).await?;

        // Extract patterns
        let patterns_detected = self.detect_patterns(path).await?;

        // Calculate quality score from analysis results
        let quality_score = self.calculate_quality_score(&analysis_results);

        // Generate recommendations from analysis results
        let recommendations = self.generate_recommendations(&analysis_results);

        // Extract metrics from analysis results
        let metrics = self.extract_metrics(&analysis_results);

        // Collect intelligence (if enabled)
        let intelligence_collected = false; // TODO: Implement intelligence collection

        Ok(AnalysisResult {
            quality_score,
            issues_count: recommendations.len(),
            recommendations,
            metrics,
            patterns_detected,
            intelligence_collected,
        })
    }

    async fn detect_patterns(&self, _path: &Path) -> Result<Vec<String>> {
        // TODO: Implement pattern detection using available modules
        let patterns = vec![
            "rust".to_string(),
            "async".to_string(),
        ];
        Ok(patterns)
    }

    fn calculate_quality_score(&self, analysis_results: &code_quality_engine::orchestrators::AnalysisResults) -> f64 {
        // Calculate overall quality score from all analysis results
        let mut total_score = 0.0;
        let mut count = 0;

        for result in analysis_results.analysis_results.values() {
            total_score += result.score;
            count += 1;
        }

        if count > 0 {
            total_score / count as f64
        } else {
            7.5 // Default score if no analyses ran
        }
    }

    fn generate_recommendations(&self, analysis_results: &code_quality_engine::orchestrators::AnalysisResults) -> Vec<Recommendation> {
        let mut recommendations = Vec::new();

        // Convert analysis findings to recommendations
        for result in analysis_results.analysis_results.values() {
            for finding in &result.findings {
                recommendations.push(Recommendation {
                    r#type: finding.category.clone(),
                    severity: match finding.severity {
                        code_quality_engine::orchestrators::FindingSeverity::Critical => "critical".to_string(),
                        code_quality_engine::orchestrators::FindingSeverity::High => "high".to_string(),
                        code_quality_engine::orchestrators::FindingSeverity::Medium => "medium".to_string(),
                        code_quality_engine::orchestrators::FindingSeverity::Low => "low".to_string(),
                        code_quality_engine::orchestrators::FindingSeverity::Info => "info".to_string(),
                    },
                    message: finding.description.clone(),
                    file: finding.location.clone(),
                    line: None, // TODO: Extract line numbers from location
                });
            }

            // Add recommendations from analysis
            for rec in &result.recommendations {
                recommendations.push(Recommendation {
                    r#type: format!("{:?}", result.analysis_type).to_lowercase(),
                    severity: "medium".to_string(),
                    message: rec.clone(),
                    file: None,
                    line: None,
                });
            }
        }

        recommendations
    }

    fn extract_metrics(&self, analysis_results: &code_quality_engine::orchestrators::AnalysisResults) -> HashMap<String, f64> {
        let mut metrics = HashMap::new();

        // Extract metrics from analysis results
        for (analysis_type, result) in &analysis_results.analysis_results {
            let key = format!("{:?}", analysis_type).to_lowercase();
            metrics.insert(key, result.score);

            // Add any metadata metrics
            if let Some(complexity) = result.metadata.get("complexity") {
                if let Some(val) = complexity.as_f64() {
                    metrics.insert("complexity".to_string(), val);
                }
            }
            if let Some(coverage) = result.metadata.get("test_coverage") {
                if let Some(val) = coverage.as_f64() {
                    metrics.insert("test_coverage".to_string(), val);
                }
            }
        }

        metrics
    }
}

pub async fn analyze_local(path: &Path) -> Result<AnalysisResult> {
    let scanner = CodeScanner::new();
    scanner.scan(path).await
}