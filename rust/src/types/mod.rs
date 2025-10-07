//! Common types used by both NIF and Server

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisRequest {
    pub codebase_path: String,
    pub analysis_types: Vec<String>,
    pub database_url: Option<String>,
    pub embedding_model: Option<String>,
    pub mode: Option<String>, // "nif" or "server"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub success: bool,
    pub technologies: Vec<TechnologyInfo>,
    pub dependencies: Vec<DependencyInfo>,
    pub quality_metrics: QualityMetrics,
    pub security_issues: Vec<SecurityIssue>,
    pub architecture_patterns: Vec<ArchitecturePattern>,
    pub embeddings: Vec<EmbeddingInfo>,
    pub database_written: bool,
    pub error: Option<String>,
    pub mode: String, // "nif" or "server"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TechnologyInfo {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f64,
    pub files: Vec<String>,
    pub category: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DependencyInfo {
    pub name: String,
    pub version: String,
    pub ecosystem: String,
    pub dependencies: Vec<String>,
    pub dev_dependencies: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityMetrics {
    pub complexity_score: f64,
    pub maintainability_score: f64,
    pub test_coverage: f64,
    pub code_duplication: f64,
    pub technical_debt: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityIssue {
    pub severity: String,
    pub category: String,
    pub description: String,
    pub file: String,
    pub line: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArchitecturePattern {
    pub pattern_type: String,
    pub confidence: f64,
    pub files: Vec<String>,
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddingInfo {
    pub file_path: String,
    pub embedding: Vec<f32>,
    pub similarity_score: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageAnalysisRequest {
    pub package_name: String,
    pub ecosystem: String,
    pub analysis_types: Vec<String>,
    pub database_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageAnalysisResult {
    pub success: bool,
    pub package_name: String,
    pub ecosystem: String,
    pub analysis: AnalysisResult,
    pub download_path: Option<String>,
    pub error: Option<String>,
}
