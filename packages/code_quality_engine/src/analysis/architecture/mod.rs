//! Architecture Pattern Detection Engine
//!
//! Config-driven pattern detection for frameworks, technologies, and service architectures.
//! Integrates with CentralCloud for cross-instance pattern learning and consensus.

use std::collections::HashMap;
use std::path::Path;
use serde::{Deserialize, Serialize};
use async_trait::async_trait;
use std::sync::Arc;

/// Pattern detection result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternDetection {
    pub name: String,
    pub pattern_type: String,
    pub confidence: f64,
    pub description: Option<String>,
    pub metadata: HashMap<String, serde_json::Value>,
}

/// Pattern detector trait - all detectors must implement this
#[async_trait]
pub trait PatternDetector: Send + Sync {
    /// Detect patterns in the given path
    async fn detect(&self, path: &Path, opts: &DetectionOptions) -> Result<Vec<PatternDetection>, PatternError>;

    /// Learn from detection results
    async fn learn_pattern(&self, result: &PatternDetection) -> Result<(), PatternError>;

    /// Get the pattern type this detector handles
    fn pattern_type(&self) -> PatternType;

    /// Get human-readable description
    fn description(&self) -> &'static str;
}

/// Detection options
#[derive(Clone, Default)]
pub struct DetectionOptions {
    pub min_confidence: f64,
    pub max_results: Option<usize>,
    pub use_learned_patterns: bool,
    pub max_depth: usize,
    /// Optional centralized pattern store (hydrated from CentralCloud)
    pub pattern_store: Option<Arc<patterns_store::PatternStore>>,
}

impl std::fmt::Debug for DetectionOptions {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DetectionOptions")
            .field("min_confidence", &self.min_confidence)
            .field("max_results", &self.max_results)
            .field("use_learned_patterns", &self.use_learned_patterns)
            .field("max_depth", &self.max_depth)
            .field(
                "pattern_store",
                &self.pattern_store.as_ref().map(|_| "<pattern_store>")
            )
            .finish()
    }
}

/// Pattern types supported by the system
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum PatternType {
    Framework,
    Technology,
    ServiceArchitecture,
    Infrastructure,
}

/// Pattern detection error
#[derive(Debug, thiserror::Error)]
pub enum PatternError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Pattern detection failed: {0}")]
    DetectionFailed(String),

    #[error("Invalid pattern type: {0}")]
    InvalidPatternType(String),

    #[error("CentralCloud communication error: {0}")]
    CentralCloudError(String),
}

/// Pattern detector registry - manages all available detectors
pub struct PatternDetectorRegistry {
    detectors: HashMap<PatternType, Box<dyn PatternDetector>>,
}

impl PatternDetectorRegistry {
    pub fn new() -> Self {
        Self {
            detectors: HashMap::new(),
        }
    }

    /// Register a detector for a pattern type
    pub fn register<D: PatternDetector + 'static>(&mut self, detector: D) {
        let pattern_type = detector.pattern_type();
        self.detectors.insert(pattern_type, Box::new(detector));
    }

    /// Get a detector for a pattern type
    pub fn get_detector(&self, pattern_type: PatternType) -> Option<&dyn PatternDetector> {
        self.detectors.get(&pattern_type).map(|d| d.as_ref())
    }

    /// Get all registered pattern types
    pub fn registered_types(&self) -> Vec<PatternType> {
        self.detectors.keys().cloned().collect()
    }
}

/// Pattern detector orchestrator - coordinates all pattern detection
pub struct PatternDetectorOrchestrator {
    registry: PatternDetectorRegistry,
}

impl PatternDetectorOrchestrator {
    pub fn new(registry: PatternDetectorRegistry) -> Self {
        Self { registry }
    }

    /// TODO(minimal): Hydrate detectors from CentralCloud via MetaRegistry.
    /// In production, detectors should pull versioned patterns here and cache them.
    pub async fn hydrate_from_central(
        &self,
        meta: &mut crate::registry::MetaRegistry,
    ) -> Result<(), PatternError> {
        meta
            .sync_with_centralcloud()
            .await
            .map_err(|e| PatternError::CentralCloudError(e.to_string()))
    }

    /// Detect patterns using all enabled detectors
    pub async fn detect_all(
        &self,
        path: &Path,
        pattern_types: Option<Vec<PatternType>>,
        opts: &DetectionOptions,
    ) -> Result<HashMap<PatternType, Vec<PatternDetection>>, PatternError> {
        let types_to_run = pattern_types.unwrap_or_else(|| self.registry.registered_types());

        let mut results = HashMap::new();

        for pattern_type in types_to_run {
            if let Some(detector) = self.registry.get_detector(pattern_type) {
                let patterns = detector.detect(path, opts).await?;
                results.insert(pattern_type, patterns);
            }
        }

        Ok(results)
    }

    /// Learn from detection results across all detectors
    pub async fn learn_all(
        &self,
        results: &HashMap<PatternType, Vec<PatternDetection>>,
    ) -> Result<(), PatternError> {
        for (pattern_type, patterns) in results {
            if let Some(detector) = self.registry.get_detector(*pattern_type) {
                for pattern in patterns {
                    detector.learn_pattern(pattern).await?;
                }
            }
        }

        Ok(())
    }
}

impl Default for PatternDetectorRegistry {
    fn default() -> Self {
        Self::new()
    }
}