//! Code Scanner Module
//!
//! Core scanning functionality for the CLI

use std::collections::HashMap;
use std::sync::Mutex;
use std::path::Path;
use anyhow::Result;
use code_quality_engine::orchestrators::{AnalysisOrchestrator, AnalysisInput};
use code_quality_engine::registry::MetaRegistry;
use code_quality_engine::analysis::architecture::PatternDetectorRegistry;

use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub quality_score: f64,
    pub issues_count: usize,
    pub recommendations: Vec<Recommendation>,
    pub metrics: HashMap<String, f64>,
    pub patterns_detected: Vec<String>,
    pub intelligence_collected: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Recommendation {
    pub r#type: String,
    pub severity: String,
    pub message: String,
    pub file: Option<String>,
    pub line: Option<usize>,
}

pub struct CodeScanner {
    orchestrator: AnalysisOrchestrator,
    registry: MetaRegistry,
    // Minimal local?server run ID map for correlation; TODO(minimal): persist with redb
    run_id_map: Mutex<HashMap<String, String>>, 
}

impl CodeScanner {
    pub fn new() -> Self {
        let registry = PatternDetectorRegistry::new();
        let orchestrator = AnalysisOrchestrator::new(registry);
        Self {
            orchestrator,
            registry: MetaRegistry::new(),
            run_id_map: Mutex::new(HashMap::new()),
        }
    }

    pub async fn scan(&self, path: &Path) -> Result<AnalysisResult> {
        // Generate monotonic-ish run ID (UUIDv7)
        let run_id = Uuid::now_v7().to_string();

        // Ask CentralCloud to start a run and assign canonical server_run_id
        let server_run_id = self.begin_remote_run(&run_id).await?;

        // Create analysis input
        let mut det_opts = code_quality_engine::analysis::architecture::DetectionOptions::default();
        det_opts.use_learned_patterns = true; // Enable cache/learned patterns by default in Pro

        let input = AnalysisInput {
            path: path.to_path_buf(),
            pattern_types: None, // Run all pattern types
            detection_options: det_opts,
            analysis_options: Default::default(),
            context: {
                let mut map: HashMap<String, serde_json::Value> = HashMap::new();
                // Use server_run_id as canonical; keep local for correlation
                map.insert("run_id".to_string(), serde_json::Value::String(server_run_id.clone()));
                map.insert("local_run_id".to_string(), serde_json::Value::String(run_id));
                map
            },
        };

        // Run comprehensive analysis (includes pattern detection internally)
        let analysis_results = self.orchestrator.analyze_all(&input, None).await?;

        // Extract detected patterns from analysis results (no extra scanning)
        let patterns_detected = Self::extract_detected_patterns(&analysis_results);

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

    /// Begin a remote run and get canonical server_run_id.
    /// TODO(minimal): Replace with real CentralCloud API/pgmq handshake and error mapping.
    async fn begin_remote_run(&self, local_run_id: &str) -> Result<String> {
        // Minimal placeholder: generate a distinct UUIDv7 to represent server-issued ID
        let server_run_id = Uuid::now_v7().to_string();

        // Record mapping for later lookups (e.g., on result upload)
        if let Ok(mut guard) = self.run_id_map.lock() {
            guard.insert(local_run_id.to_string(), server_run_id.clone());
        }

        Ok(server_run_id)
    }

    fn extract_detected_patterns(analysis_results: &code_quality_engine::orchestrators::AnalysisResults) -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        if let Some(map) = &analysis_results.pattern_results {
            for (ptype, detections) in map {
                // Minimal: record one entry per detection using pattern type name
                let name = format!("{:?}", ptype).to_lowercase();
                for _d in detections {
                    out.push(name.clone());
                }
            }
        }
        out
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

fn main() {}

pub async fn analyze_local(path: &Path) -> Result<AnalysisResult> {
    let scanner = CodeScanner::new();
    scanner.scan(path).await
}