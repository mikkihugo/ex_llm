//! Architecture Analysis NIF
//!
//! Fast local framework detection using templates (no LLM calls).
//! Wraps the architecture analysis library for Elixir.

use rustler::{Encoder, Env, Error, Term};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

// Re-export from architecture lib
// (architecture lib needs to expose its types publicly)

#[derive(Debug, Serialize, Deserialize)]
pub struct FrameworkDetectionResult {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f32,
    pub detected_by: String,
    pub files: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ArchitectureAnalysisResult {
    pub frameworks: Vec<FrameworkDetectionResult>,
    pub build_tools: Vec<String>,
    pub languages: Vec<String>,
    pub patterns: Vec<String>,
}

rustler::init!("Elixir.Singularity.ArchitectureAnalyzer");

/// Detect frameworks in a directory using local templates only
#[rustler::nif]
fn detect_frameworks(path: String) -> Result<Vec<FrameworkDetectionResult>, Error> {
    let path_buf = PathBuf::from(path);

    // TODO: Call architecture lib functions here
    // For now, return mock data
    Ok(vec![
        FrameworkDetectionResult {
            name: "Phoenix".to_string(),
            version: Some("1.7".to_string()),
            confidence: 0.95,
            detected_by: "config_file".to_string(),
            files: vec!["mix.exs".to_string()],
        }
    ])
}

/// Full architecture analysis (frameworks + build tools + languages)
#[rustler::nif]
fn analyze_architecture(path: String) -> Result<ArchitectureAnalysisResult, Error> {
    let path_buf = PathBuf::from(path);

    // TODO: Call architecture lib functions here
    Ok(ArchitectureAnalysisResult {
        frameworks: vec![],
        build_tools: vec!["mix".to_string(), "cargo".to_string()],
        languages: vec!["elixir".to_string(), "rust".to_string()],
        patterns: vec![],
    })
}

/// Check if a file indicates a specific framework
#[rustler::nif]
fn matches_framework(file_path: String, framework_name: String) -> Result<bool, Error> {
    // TODO: Implement pattern matching
    Ok(false)
}
