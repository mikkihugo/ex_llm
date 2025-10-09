use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkKnowledge {
    pub name: String,
    pub category: String,
    pub ecosystem: String,
    pub detector_signatures: DetectorSignatures,
    pub detection_rules: DetectionRules,
    pub llm_support: LLMSupport,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectorSignatures {
    pub package_names: Vec<String>,
    pub file_extensions: Vec<String>,
    pub patterns: Vec<String>,
    pub config_files: Vec<String>,
    pub directory_patterns: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionRules {
    pub multi_signal_detection: MultiSignalDetection,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MultiSignalDetection {
    pub minimum_confidence: f64,
    pub signals: Vec<Signal>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Signal {
    pub signal_type: String,
    pub weight: f64,
    pub check: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LLMSupport {
    pub analysis_prompts: serde_json::Value,
    pub prompt_bits: PromptBits,
    pub code_snippets: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptBits {
    pub context: String,
    pub best_practices: Vec<String>,
    pub common_mistakes: Vec<String>,
}

/// Loads framework knowledge from PostgreSQL knowledge_artifacts table
pub async fn load_framework_knowledge() -> Result<Vec<FrameworkKnowledge>> {
    // TODO: Query PostgreSQL
    // SELECT * FROM knowledge_artifacts WHERE artifact_type = 'framework_metadata'

    // For now, return empty vec
    // In production, this queries the Living Knowledge Base
    Ok(vec![])
}

/// Queries framework by name
pub async fn get_framework(name: &str) -> Result<Option<FrameworkKnowledge>> {
    // TODO: Query PostgreSQL by name
    Ok(None)
}

/// Searches frameworks semantically using embeddings
pub async fn search_frameworks(query: &str, limit: usize) -> Result<Vec<FrameworkKnowledge>> {
    // TODO: Use pgvector for semantic search
    // SELECT *, embedding <-> query_embedding AS distance
    // FROM knowledge_artifacts
    // WHERE artifact_type = 'framework_metadata'
    // ORDER BY distance LIMIT $1
    Ok(vec![])
}
