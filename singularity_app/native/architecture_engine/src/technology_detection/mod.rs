//! Technology Detection Module
//!
//! Detects and analyzes technologies, frameworks, libraries, and ecosystems used in codebases.
//! Provides technology-specific insights and recommendations.

pub mod analyzer;
pub mod detector;
pub mod patterns;

pub use analyzer::*;
pub use detector::*;
pub use patterns::*;

use serde::{Deserialize, Serialize};

/// Technology detection request
#[derive(Debug, Serialize, Deserialize, rustler::NifStruct)]
#[module = "TechnologyDetectionRequest"]
pub struct TechnologyDetectionRequest {
    pub patterns: Vec<String>,
    pub context: String,
    pub detection_methods: Vec<String>,
    pub confidence_threshold: f64,
}

/// Technology detection result
#[derive(Debug, Serialize, Deserialize, rustler::NifStruct)]
#[module = "TechnologyDetectionResult"]
pub struct TechnologyDetectionResult {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f64,
    pub detected_by: String,
    pub evidence: Vec<String>,
    pub pattern_id: Option<String>,
}
