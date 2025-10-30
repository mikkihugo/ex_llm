//! Analysis Orchestrator
//!
//! Config-driven orchestration of all analyzers (feedback, quality, refactoring).
//! Coordinates pattern detection and analysis with CentralCloud integration.

use std::collections::HashMap;
use std::sync::Arc;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::analysis::architecture::{PatternDetectorRegistry, PatternDetectorOrchestrator, PatternDetection, PatternType};
use crate::registry::MetaRegistry;
use patterns_store::PatternStore;

/// Analysis orchestrator for coordinating all analysis types
pub struct AnalysisOrchestrator {
    pattern_orchestrator: PatternDetectorOrchestrator,
    analyzers: HashMap<AnalysisType, Box<dyn Analyzer>>,
}

impl AnalysisOrchestrator {
    pub fn new(registry: PatternDetectorRegistry) -> Self {
        Self {
            pattern_orchestrator: PatternDetectorOrchestrator::new(registry),
            analyzers: HashMap::new(),
        }
    }

    /// Register an analyzer
    pub fn register_analyzer<A: Analyzer + 'static>(&mut self, analyzer: A) {
        let analysis_type = analyzer.analysis_type();
        self.analyzers.insert(analysis_type, Box::new(analyzer));
    }

    /// Run all enabled analyzers
    pub async fn analyze_all(
        &self,
        input: &AnalysisInput,
        analysis_types: Option<Vec<AnalysisType>>,
    ) -> Result<AnalysisResults, AnalysisError> {
        let types_to_run = analysis_types.unwrap_or_else(|| self.analyzers.keys().cloned().collect());

        let mut results = AnalysisResults::default();

        // Hydrate detectors from CentralCloud when requested
        let mut hydrated_snapshot: Option<(std::collections::HashMap<patterns_store::types::PatternKind, Vec<patterns_store::types::PatternRecord>>, u64)> = None;
        if input.detection_options.use_learned_patterns {
            let mut meta = MetaRegistry::new();
            let _ = self.pattern_orchestrator.hydrate_from_central(&mut meta).await;
            // Try to export a snapshot from MetaRegistry (if CentralCloud provided data)
            if let Some(snap) = meta.export_patterns_snapshot().await {
                hydrated_snapshot = Some(snap);
            }
        }

        // Attach centralized PatternStore to options if requested
        let mut det_opts = input.detection_options.clone();
        if det_opts.use_learned_patterns {
            // Try to load cached patterns (encrypted redb). Fallback to empty store.
            let mut store = match PatternStore::load_default_cache().await {
                Ok(s) => s,
                Err(_) => PatternStore::new(),
            };
            // If we received a fresh snapshot from Central, replace and persist
            if let Some((map, version)) = hydrated_snapshot {
                store.replace_all(map, version).await;
            }
            let store = Arc::new(store);
            let _ = store.save_default_cache().await; // persist current snapshot (cache refresh if replaced)
            det_opts.pattern_store = Some(store);
        }

        // Run pattern detection (always included)
        if let Ok(pattern_results) = self.pattern_orchestrator.detect_all(
            &input.path,
            input.pattern_types.clone(),
            &det_opts,
        ).await {
            results.pattern_results = Some(pattern_results);
        }

        // Run specified analyzers in parallel
        let analyzer_futures = types_to_run.into_iter()
            .filter_map(|analysis_type| {
                self.analyzers.get(&analysis_type).map(|analyzer| {
                    let input = input.clone();
                    async move {
                        let result = analyzer.analyze(&input).await;
                        (analysis_type, result)
                    }
                })
            })
            .collect::<Vec<_>>();

        let analyzer_results = futures::future::join_all(analyzer_futures).await;

        for (analysis_type, result) in analyzer_results {
            match result {
                Ok(analysis_result) => {
                    results.analysis_results.insert(analysis_type, analysis_result);
                }
                Err(e) => {
                    results.errors.push(AnalysisErrorInfo {
                        analysis_type,
                        error: e.to_string(),
                    });
                }
            }
        }

        // Send learning data to CentralCloud
        self.send_learning_data(&results).await?;

        Ok(results)
    }

    /// Learn from analysis results
    pub async fn learn_all(&self, results: &AnalysisResults) -> Result<(), AnalysisError> {
        // Learn from pattern detection results
        if let Some(pattern_results) = &results.pattern_results {
            self.pattern_orchestrator.learn_all(pattern_results).await?;
        }

        // Learn from analysis results
        for (analysis_type, analysis_result) in &results.analysis_results {
            if let Some(analyzer) = self.analyzers.get(analysis_type) {
                analyzer.learn(analysis_result).await?;
            }
        }

        Ok(())
    }

    async fn send_learning_data(&self, _results: &AnalysisResults) -> Result<(), AnalysisError> {
        // TODO: Send aggregated learning data to CentralCloud via pgmq queues
        // Instead of HTTP calls, send messages to PostgreSQL queues that
        // ex_pgflow workflows will consume and forward to CentralCloud
        //
        // Flow:
        // 1. Rust NIF sends message to "centralcloud_learning" queue
        // 2. Elixir ex_pgflow workflow consumes message
        // 3. Workflow communicates with CentralCloud for consensus
        // 4. Results flow back through response queues if needed

        Ok(())
    }
}

/// Analyzer trait - all analyzers must implement this
#[async_trait]
pub trait Analyzer: Send + Sync {
    /// Analyze the given input
    async fn analyze(&self, input: &AnalysisInput) -> Result<AnalysisResult, AnalysisError>;

    /// Learn from analysis results
    async fn learn(&self, result: &AnalysisResult) -> Result<(), AnalysisError>;

    /// Get the analysis type
    fn analysis_type(&self) -> AnalysisType;

    /// Get human-readable description
    fn description(&self) -> &'static str;
}

/// Analysis types
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum AnalysisType {
    Feedback,
    Quality,
    Refactoring,
}

/// Analysis input
#[derive(Debug, Clone)]
pub struct AnalysisInput {
    pub path: std::path::PathBuf,
    pub pattern_types: Option<Vec<PatternType>>,
    pub detection_options: crate::analysis::architecture::DetectionOptions,
    pub analysis_options: AnalysisOptions,
    pub context: HashMap<String, serde_json::Value>,
}

/// Analysis options
#[derive(Debug, Clone, Default)]
pub struct AnalysisOptions {
    pub min_confidence: f64,
    pub include_details: bool,
    pub timeout_seconds: Option<u64>,
}

/// Analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub analysis_type: AnalysisType,
    pub score: f64,
    pub findings: Vec<AnalysisFinding>,
    pub recommendations: Vec<String>,
    pub metadata: HashMap<String, serde_json::Value>,
}

/// Analysis finding
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisFinding {
    pub category: String,
    pub severity: FindingSeverity,
    pub description: String,
    pub location: Option<String>,
    pub suggestion: Option<String>,
}

/// Finding severity levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FindingSeverity {
    Info,
    Low,
    Medium,
    High,
    Critical,
}

/// Overall analysis results
#[derive(Debug, Clone, Default)]
pub struct AnalysisResults {
    pub pattern_results: Option<HashMap<PatternType, Vec<PatternDetection>>>,
    pub analysis_results: HashMap<AnalysisType, AnalysisResult>,
    pub errors: Vec<AnalysisErrorInfo>,
}

/// Analysis error information
#[derive(Debug, Clone)]
pub struct AnalysisErrorInfo {
    pub analysis_type: AnalysisType,
    pub error: String,
}

/// Analysis error
#[derive(Debug, thiserror::Error)]
pub enum AnalysisError {
    #[error("Pattern detection error: {0}")]
    PatternDetection(#[from] crate::analysis::architecture::PatternError),

    #[error("Analysis failed: {0}")]
    AnalysisFailed(String),

    #[error("CentralCloud communication error: {0}")]
    CentralCloudError(String),

    #[error("Timeout: {0}")]
    Timeout(String),
}

// NIF interface functions that can be called from Elixir

/// Run full analysis orchestration (NIF function)
#[no_mangle]
pub extern "C" fn run_analysis_orchestration(
    _path: *const std::os::raw::c_char,
    _config_json: *const std::os::raw::c_char,
) -> *mut std::os::raw::c_char {
    // This would be the actual NIF implementation
    // In real implementation, this would:
    // 1. Parse inputs from Elixir
    // 2. Run async analysis orchestration
    // 3. Return results as JSON string

    // Placeholder implementation
    let result = r#"{"status": "success", "message": "Analysis orchestration completed"}"#;
    let c_string = std::ffi::CString::new(result).unwrap();
    c_string.into_raw()
}

/// Free NIF result string
///
/// # Safety
/// - `result` must be a valid pointer previously returned by this module
///   via `CString::into_raw`.
/// - It must not be freed elsewhere and must not be used after this call
///   (use-after-free).
/// - Passing an arbitrary or already-freed pointer is undefined behavior.
#[no_mangle]
pub unsafe extern "C" fn free_analysis_result(result: *mut std::os::raw::c_char) {
    if !result.is_null() {
        let _ = std::ffi::CString::from_raw(result);
    }
}