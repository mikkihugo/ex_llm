//! Pure computation layer for codebase analysis data
//!
//! This module provides pure computation functions for codebase analysis.
//! All data is passed in via parameters and returned as results.
//! No I/O operations - designed for NIF usage.

use crate::codebase::metadata::{CodebaseMetadata, FileAnalysis, CodebaseAnalysis};
use crate::codebase::vectors::CodeVector;
use crate::embeddings::{HybridCodeEmbedder, HybridEmbedding, HybridConfig, CodeMatch};
use anyhow::{Result, Context};
use std::collections::HashMap;

/// Pure computation codebase analyzer
/// 
/// This struct holds configuration and embedders for analysis.
/// All data operations are pure computation - no I/O.
pub struct CodebaseAnalyzer {
    /// Hybrid code embedder for semantic search
    embedder: Option<HybridCodeEmbedder>,
}

impl CodebaseAnalyzer {
    /// Create new analyzer with embedder
    pub fn new(embedder_config: Option<HybridConfig>) -> Result<Self> {
        let embedder = if let Some(config) = embedder_config {
            Some(HybridCodeEmbedder::new(config)?)
        } else {
            None
        };

        Ok(Self { embedder })
    }

    /// Analyze file and return analysis result
    /// 
    /// Pure computation - no I/O operations
    pub fn analyze_file(&self, file_analysis: &FileAnalysis) -> Result<CodebaseAnalysis> {
        // Perform analysis on the provided data
        let mut analysis = CodebaseAnalysis {
            file_path: file_analysis.file_path.clone(),
            language: file_analysis.language.clone(),
            file_size: file_analysis.file_size,
            line_count: file_analysis.line_count,
            functions: file_analysis.functions.clone(),
            classes: file_analysis.classes.clone(),
            imports: file_analysis.imports.clone(),
            exports: file_analysis.exports.clone(),
            symbols: file_analysis.symbols.clone(),
            quality_metrics: self.calculate_quality_metrics(file_analysis)?,
            complexity_metrics: self.calculate_complexity_metrics(file_analysis)?,
            security_analysis: self.analyze_security(file_analysis)?,
            performance_analysis: self.analyze_performance(file_analysis)?,
            architecture_patterns: self.detect_architecture_patterns(file_analysis)?,
            metadata: file_analysis.metadata.clone(),
        };

        Ok(analysis)
    }

    /// Generate embeddings for code content
    /// 
    /// Pure computation - uses provided embedder
    pub async fn generate_embeddings(&self, content: &str) -> Result<Option<Vec<f32>>> {
        if let Some(embedder) = &self.embedder {
            Ok(Some(embedder.embed_text(content).await?))
        } else {
            Ok(None)
        }
    }

    /// Semantic search within provided codebase data
    /// 
    /// Pure computation - searches through provided data
    pub async fn semantic_search(
        &self, 
        query: &str, 
        codebase_data: &[CodebaseMetadata],
        limit: usize
    ) -> Result<Vec<CodeMatch>> {
        if let Some(embedder) = &self.embedder {
            let query_embedding = embedder.embed_text(query).await?;
            
            let mut matches = Vec::new();
            for metadata in codebase_data {
                if let Some(embedding) = &metadata.vector_embedding {
                    let similarity = self.calculate_similarity(&query_embedding, embedding);
                    matches.push(CodeMatch {
                        path: metadata.path.clone(),
                        language: metadata.language.clone(),
                        file_type: metadata.file_type.clone(),
                        quality_score: metadata.quality_score,
                        similarity,
                    });
                }
            }
            
            // Sort by similarity and limit results
            matches.sort_by(|a, b| b.similarity.partial_cmp(&a.similarity).unwrap_or(std::cmp::Ordering::Equal));
            matches.truncate(limit);
            
            Ok(matches)
        } else {
            Err(anyhow::anyhow!("Embedder not initialized"))
        }
    }

    /// Process code chunks for RAG
    /// 
    /// Pure computation - processes provided chunks
    pub async fn process_code_chunks(
        &self, 
        file_path: &str, 
        content: &str,
        chunk_size: usize
    ) -> Result<Vec<CodeVector>> {
        let mut chunks = Vec::new();
        let lines: Vec<&str> = content.lines().collect();
        
        for (i, chunk_lines) in lines.chunks(chunk_size).enumerate() {
            let chunk_content = chunk_lines.join("\n");
            let embedding = if let Some(embedder) = &self.embedder {
                Some(embedder.embed_text(&chunk_content).await?)
            } else {
                None
            };
            
            chunks.push(CodeVector {
                chunk_type: "code".to_string(),
                content: chunk_content,
                embedding,
                metadata: HashMap::new(),
            });
        }
        
        Ok(chunks)
    }

    /// Calculate quality metrics for file analysis
    fn calculate_quality_metrics(&self, file_analysis: &FileAnalysis) -> Result<HashMap<String, f64>> {
        let mut metrics = HashMap::new();
        
        // Basic metrics
        metrics.insert("file_size".to_string(), file_analysis.file_size as f64);
        metrics.insert("line_count".to_string(), file_analysis.line_count as f64);
        metrics.insert("function_count".to_string(), file_analysis.functions.len() as f64);
        metrics.insert("class_count".to_string(), file_analysis.classes.len() as f64);
        
        // Complexity metrics
        let avg_function_length = if !file_analysis.functions.is_empty() {
            file_analysis.functions.iter()
                .map(|f| f.end_line - f.start_line)
                .sum::<usize>() as f64 / file_analysis.functions.len() as f64
        } else {
            0.0
        };
        metrics.insert("avg_function_length".to_string(), avg_function_length);
        
        // Quality score (simplified)
        let quality_score = if file_analysis.line_count > 0 {
            let complexity_penalty = if avg_function_length > 50.0 { 0.1 } else { 0.0 };
            let size_penalty = if file_analysis.file_size > 10000 { 0.1 } else { 0.0 };
            1.0 - complexity_penalty - size_penalty
        } else {
            0.0
        };
        metrics.insert("quality_score".to_string(), quality_score);
        
        Ok(metrics)
    }

    /// Calculate complexity metrics
    fn calculate_complexity_metrics(&self, file_analysis: &FileAnalysis) -> Result<HashMap<String, f64>> {
        let mut metrics = HashMap::new();
        
        // Cyclomatic complexity (simplified)
        let cyclomatic_complexity = file_analysis.functions.len() as f64 + 
            file_analysis.classes.len() as f64;
        metrics.insert("cyclomatic_complexity".to_string(), cyclomatic_complexity);
        
        // Cognitive complexity (simplified)
        let cognitive_complexity = file_analysis.functions.iter()
            .map(|f| (f.end_line - f.start_line) as f64)
            .sum::<f64>() / 10.0;
        metrics.insert("cognitive_complexity".to_string(), cognitive_complexity);
        
        Ok(metrics)
    }

    /// Analyze security aspects
    fn analyze_security(&self, file_analysis: &FileAnalysis) -> Result<HashMap<String, String>> {
        let mut security = HashMap::new();
        
        // Basic security checks
        if file_analysis.content.contains("password") || file_analysis.content.contains("secret") {
            security.insert("has_secrets".to_string(), "potential".to_string());
        }
        
        if file_analysis.content.contains("eval(") || file_analysis.content.contains("exec(") {
            security.insert("code_injection_risk".to_string(), "high".to_string());
        }
        
        if file_analysis.content.contains("TODO") || file_analysis.content.contains("FIXME") {
            security.insert("has_todos".to_string(), "info".to_string());
        }
        
        Ok(security)
    }

    /// Analyze performance aspects
    fn analyze_performance(&self, file_analysis: &FileAnalysis) -> Result<HashMap<String, String>> {
        let mut performance = HashMap::new();
        
        // Basic performance checks
        if file_analysis.content.contains("for ") && file_analysis.content.contains("for ") {
            performance.insert("has_loops".to_string(), "info".to_string());
        }
        
        if file_analysis.content.contains("async") || file_analysis.content.contains("await") {
            performance.insert("is_async".to_string(), "good".to_string());
        }
        
        if file_analysis.file_size > 5000 {
            performance.insert("large_file".to_string(), "warning".to_string());
        }
        
        Ok(performance)
    }

    /// Detect architecture patterns
    fn detect_architecture_patterns(&self, file_analysis: &FileAnalysis) -> Result<Vec<String>> {
        let mut patterns = Vec::new();
        
        // Pattern detection based on content analysis
        if file_analysis.content.contains("struct ") && file_analysis.content.contains("impl ") {
            patterns.push("struct_impl_pattern".to_string());
        }
        
        if file_analysis.content.contains("trait ") {
            patterns.push("trait_pattern".to_string());
        }
        
        if file_analysis.content.contains("async fn") {
            patterns.push("async_pattern".to_string());
        }
        
        if file_analysis.content.contains("match ") {
            patterns.push("pattern_matching".to_string());
        }
        
        Ok(patterns)
    }

    /// Calculate similarity between two embeddings
    fn calculate_similarity(&self, embedding1: &[f32], embedding2: &[f32]) -> f64 {
        if embedding1.len() != embedding2.len() {
            return 0.0;
        }
        
        let dot_product: f32 = embedding1.iter()
            .zip(embedding2.iter())
            .map(|(a, b)| a * b)
            .sum();
        
        let norm1: f32 = embedding1.iter().map(|x| x * x).sum::<f32>().sqrt();
        let norm2: f32 = embedding2.iter().map(|x| x * x).sum::<f32>().sqrt();
        
        if norm1 == 0.0 || norm2 == 0.0 {
            0.0
        } else {
            (dot_product / (norm1 * norm2)) as f64
        }
    }
}

impl Default for CodebaseAnalyzer {
    fn default() -> Self {
        Self { embedder: None }
    }
}
