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
use code_quality_engine::orchestrators::{Analyzer, AnalysisError, AnalysisType};
use sha2::{Sha256, Digest};
#[path = "scanner/scan_cache.rs"]
mod scan_cache;

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub quality_score: f64,
    pub issues_count: usize,
    pub recommendations: Vec<Recommendation>,
    pub metrics: HashMap<String, f64>,
    pub patterns_detected: Vec<String>,
    pub intelligence_collected: bool,
    pub per_file_metrics: Vec<PerFileMetric>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Recommendation {
    pub r#type: String,
    pub severity: String,
    pub message: String,
    pub file: Option<String>,
    pub line: Option<usize>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PerFileMetric {
    pub file: String,
    pub mi: Option<f64>,
    pub cc: Option<f64>,
}

pub struct CodeScanner {
    orchestrator: AnalysisOrchestrator,
    registry: MetaRegistry,
    // Minimal local?server run ID map for correlation; TODO(minimal): persist with redb
    run_id_map: Mutex<HashMap<String, String>>, 
}

impl CodeScanner {
    pub fn new() -> Self {
        let mut registry = PatternDetectorRegistry::new();
        // Register default detectors (framework, technology, service architecture)
        registry.register(code_quality_engine::analysis::architecture::framework_detector::FrameworkDetector::new());
        registry.register(code_quality_engine::analysis::architecture::technology_detector::TechnologyDetector::new());
        registry.register(code_quality_engine::analysis::architecture::service_architecture_detector::ServiceArchitectureDetector::new());
        let mut orchestrator = AnalysisOrchestrator::new(registry);
        // Register a default quality analyzer so results are non-empty
        orchestrator.register_analyzer(DefaultQualityAnalyzer);
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

        let mut result = AnalysisResult {
            quality_score,
            issues_count: recommendations.len(),
            recommendations,
            metrics,
            patterns_detected,
            intelligence_collected,
            per_file_metrics: Self::extract_per_file_metrics(&analysis_results),
        };

        // Minimal fallback suggestion if no analyzers provided findings
        if result.issues_count == 0 {
            result.recommendations.push(Recommendation {
                r#type: "guidance".to_string(),
                severity: "info".to_string(),
                message: "Enable analyzers or CentralCloud policies to receive actionable recommendations.".to_string(),
                file: None,
                line: None,
            });
            result.issues_count = 1;
        }

        Ok(result)
    }

    fn extract_per_file_metrics(analysis_results: &code_quality_engine::orchestrators::AnalysisResults) -> Vec<PerFileMetric> {
        let mut out = Vec::new();
        for (_t, res) in &analysis_results.analysis_results {
            if let Some(v) = res.metadata.get("per_file_metrics") {
                if let Some(arr) = v.as_array() {
                    for item in arr {
                        let file = item.get("file").and_then(|s| s.as_str()).unwrap_or("").to_string();
                        let mi = item.get("mi").and_then(|n| n.as_f64());
                        let cc = item.get("cc").and_then(|n| n.as_f64());
                        if !file.is_empty() {
                            out.push(PerFileMetric { file, mi, cc });
                        }
                    }
                }
            }
        }
        out
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
                let type_name = format!("{:?}", ptype).to_lowercase();
                for d in detections {
                    out.push(format!("{}:{}", type_name, d.name.to_lowercase()));
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

// Minimal default analyzer to provide baseline findings and score
struct DefaultQualityAnalyzer;

#[async_trait::async_trait]
impl Analyzer for DefaultQualityAnalyzer {
    async fn analyze(&self, _input: &code_quality_engine::orchestrators::AnalysisInput) -> Result<code_quality_engine::orchestrators::AnalysisResult, AnalysisError> {
        use walkdir::WalkDir;
        use std::fs;

        // Collect candidate source files
        let mut files: Vec<std::path::PathBuf> = Vec::new();
        for entry in WalkDir::new(".").max_depth(6).into_iter().filter_map(|e| e.ok()) {
            let p = entry.path();
            if !p.is_file() { continue; }
            // Skip generated/build and vendor directories
            if p.to_string_lossy().contains(".cargo-build")
                || p.to_string_lossy().contains("target/")
                || p.to_string_lossy().contains("node_modules/")
                || p.to_string_lossy().contains("dist/")
                || p.to_string_lossy().contains("build/")
            { continue; }
            if let Some(ext) = p.extension().and_then(|s| s.to_str()) {
                if matches!(ext, "rs" | "ex" | "exs" | "js" | "ts" | "tsx" | "py" | "go" | "java") {
                    files.push(p.to_path_buf());
                }
            }
            if files.len() >= 200 { break; }
        }

        // Try parser on files (best-effort) and generate file-level findings
        let mut findings = Vec::new();
        let mut big_files = 0usize;
        let mut files_with_metrics = 0usize;
        let mut worst_mi_val: f64 = 101.0;
        let mut worst_mi_file: Option<String> = None;
        let mut per_file_metrics: Vec<serde_json::Value> = Vec::new();

        let mut parser = parser_core::PolyglotCodeParser::new().ok();
        let cache_db = scan_cache::open();
        for path in files {
        if let Some(parser) = parser.as_mut() {
            let _ = parser.analyze_file(&path); // Use parser to validate/prime metrics (ignored if fails)
        }
            // Simple heuristic: flag very long files
            if let Ok(content) = fs::read_to_string(&path) {
                // Pull MI/CC/Halstead via CodebaseAnalyzer
                let path_str = path.to_string_lossy().to_string();
                let mut hasher = Sha256::new();
                hasher.update(content.as_bytes());
                let hash_hex = format!("{:x}", hasher.finalize());

                let mut file_mi: Option<f64> = None;
                let mut file_cc: Option<f64> = None;
                if let Some(db) = cache_db.as_ref() {
                    if let Some((h, mi, cc)) = scan_cache::get(db, &path_str) {
                        if h == hash_hex { file_mi = Some(mi); file_cc = Some(cc); }
                    }
                }
                if file_mi.is_none() || file_cc.is_none() {
                    if let Ok(analyzer) = code_quality_engine::analyzer::CodebaseAnalyzer::new() {
                        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
                            if let Ok(metrics) = analyzer.get_rca_metrics(&content, ext) {
                                if let Ok(mi) = metrics.maintainability_index.parse::<f64>() { file_mi = Some(mi); }
                                if let Ok(cc) = metrics.cyclomatic_complexity.parse::<f64>() { file_cc = Some(cc); }
                            }
                        }
                    }
                    if let (Some(mi), Some(cc), Some(db)) = (file_mi, file_cc, cache_db.as_ref()) {
                        scan_cache::put(db, &path_str, &hash_hex, mi, cc);
                    }
                }

                if let Some(mi) = file_mi {
                    files_with_metrics += 1;
                    if mi < worst_mi_val {
                        worst_mi_val = mi;
                        worst_mi_file = Some(path_str.clone());
                    }
                    if mi < 65.0 {
                        findings.push(code_quality_engine::orchestrators::AnalysisFinding {
                            category: "maintainability".to_string(),
                            severity: code_quality_engine::orchestrators::FindingSeverity::Medium,
                            description: format!("Low Maintainability Index ({:.1})", mi),
                            location: Some(path_str.clone()),
                            suggestion: Some("Refactor to reduce complexity and improve comments".to_string()),
                        });
                    }
                }
                if let Some(cc) = file_cc {
                    if cc > 20.0 {
                        findings.push(code_quality_engine::orchestrators::AnalysisFinding {
                            category: "complexity".to_string(),
                            severity: code_quality_engine::orchestrators::FindingSeverity::High,
                            description: format!("High cyclomatic complexity ({:.0})", cc),
                            location: Some(path_str.clone()),
                            suggestion: Some("Break down large functions and reduce branching".to_string()),
                        });
                    }
                }

                // Record per-file metrics if available
                if file_mi.is_some() || file_cc.is_some() {
                    per_file_metrics.push(serde_json::json!({
                        "file": path_str,
                        "mi": file_mi,
                        "cc": file_cc,
                    }));
                }
                let line_count = content.lines().count();
                if line_count > 500 {
                    big_files += 1;
                    findings.push(code_quality_engine::orchestrators::AnalysisFinding {
                        category: "size".to_string(),
                        severity: code_quality_engine::orchestrators::FindingSeverity::Low,
                        description: format!("File exceeds 500 lines ({} lines)", line_count),
                        location: Some(path.to_string_lossy().to_string()),
                        suggestion: Some("Consider splitting into smaller modules".to_string()),
                    });
                }

                // Long line detection
                for (idx, line) in content.lines().enumerate() {
                    if line.len() > 160 {
                        findings.push(code_quality_engine::orchestrators::AnalysisFinding {
                            category: "style".to_string(),
                            severity: code_quality_engine::orchestrators::FindingSeverity::Low,
                            description: format!("Line longer than 160 characters ({} chars)", line.len()),
                            location: Some(path.to_string_lossy().to_string()),
                            suggestion: Some("Wrap or refactor overly long lines".to_string()),
                        });
                        // One finding per file for long lines is enough
                        break;
                    }
                }
            }
        }

        // Baseline documentation suggestion
        findings.push(code_quality_engine::orchestrators::AnalysisFinding {
            category: "documentation".to_string(),
            severity: code_quality_engine::orchestrators::FindingSeverity::Medium,
            description: "Improve README and module docs for key components.".to_string(),
            location: Some("README.md".to_string()),
            suggestion: Some("Add architecture overview and setup steps.".to_string()),
        });

        // Score heuristic penalizing large files
        let mut score = 8.5 - (big_files as f64 * 0.05);
        if score < 5.0 { score = 5.0; }

        let mut metadata = HashMap::new();
        metadata.insert("long_files_flagged".to_string(), serde_json::json!(big_files as f64));
        metadata.insert("files_with_metrics".to_string(), serde_json::json!(files_with_metrics as f64));
        if let Some(f) = worst_mi_file {
            metadata.insert("worst_mi_file".to_string(), serde_json::json!(f));
            metadata.insert("worst_mi".to_string(), serde_json::json!(worst_mi_val));
        }
        // Attach populated per-file metrics array for downstream consumers (formatter will expose in JSON)
        metadata.insert("per_file_metrics".to_string(), serde_json::json!(per_file_metrics));

        Ok(code_quality_engine::orchestrators::AnalysisResult {
            analysis_type: AnalysisType::Quality,
            score,
            findings,
            recommendations: vec![
                "Adopt a CONTRIBUTING guide and CODEOWNERS for clearer workflow.".to_string(),
            ],
            metadata,
        })
    }

    async fn learn(&self, _result: &code_quality_engine::orchestrators::AnalysisResult) -> Result<(), AnalysisError> {
        Ok(())
    }

    fn analysis_type(&self) -> AnalysisType { AnalysisType::Quality }
    fn description(&self) -> &'static str { "Default quality analyzer (baseline heuristics)" }
}

fn main() {}

pub async fn analyze_local(path: &Path) -> Result<AnalysisResult> {
    let scanner = CodeScanner::new();
    scanner.scan(path).await
}