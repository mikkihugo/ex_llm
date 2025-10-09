//! Package Analysis Server
//!
//! Code analysis and snippet extraction.
//! Handles package tarball downloading, code parsing with universal_parser, 
//! API extraction, vector embeddings, and template management.

use anyhow::Result;
use serde::{Deserialize, Serialize};

pub mod engine;
pub mod embedding;
pub mod extractor;
pub mod template;
pub mod template_validator;
pub mod prompts;
pub mod nats_service;

/// Analysis server configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisConfig {
    pub temp_dir: String,
    pub embedding_model: String,
    pub max_file_size: usize,
    pub supported_languages: Vec<String>,
}

/// Package analysis server
pub struct PackageAnalysisServer {
    config: AnalysisConfig,
    engine: engine::EngineFact,
    embedding_generator: embedding::EmbeddingGenerator,
}

impl PackageAnalysisServer {
    pub fn new(config: AnalysisConfig) -> Self {
        Self {
            config,
            engine: engine::EngineFact::new(),
            embedding_generator: embedding::EmbeddingGenerator::new(),
        }
    }

    /// Analyze package code
    pub async fn analyze_package(&self, package_path: &str) -> Result<AnalysisResult> {
        // Extract code snippets
        let snippets = extractor::extract_code_snippets(package_path).await?;
        
        // Generate embeddings
        let embeddings = self.embedding_generator.generate_embeddings(&snippets).await?;
        
        // Analyze with engine
        let analysis = self.engine.analyze_code(&snippets).await?;
        
        Ok(AnalysisResult {
            snippets,
            embeddings,
            analysis,
        })
    }

    /// Generate templates for package
    pub async fn generate_templates(&self, package_name: &str, ecosystem: &str) -> Result<Vec<template::Template>> {
        template::generate_package_templates(package_name, ecosystem).await
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub snippets: Vec<extractor::CodeSnippet>,
    pub embeddings: Vec<Vec<f32>>,
    pub analysis: engine::CodeAnalysis,
}

impl Default for AnalysisConfig {
    fn default() -> Self {
        Self {
            temp_dir: "./temp/analysis".to_string(),
            embedding_model: "sentence-transformers/all-MiniLM-L6-v2".to_string(),
            max_file_size: 10 * 1024 * 1024, // 10MB
            supported_languages: vec![
                "rust".to_string(),
                "javascript".to_string(),
                "python".to_string(),
                "elixir".to_string(),
                "gleam".to_string(),
            ],
        }
    }
}
