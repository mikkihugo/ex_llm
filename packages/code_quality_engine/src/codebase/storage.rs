//! Pure computation layer for codebase analysis
//!
//! This module provides pure computation functions for analyzing code structure.
//! All data is passed in via parameters and returned as results - NO I/O operations.
//! Designed for NIF usage where Elixir handles all database/storage operations.

use anyhow::Result;
use std::collections::HashMap;

/// Pure computation codebase analyzer
///
/// Provides analysis functions that operate on data passed from Elixir.
/// NO database access, NO file I/O - pure computation only.
#[derive(Debug, Clone, Default)]
pub struct CodebaseAnalyzer;

impl CodebaseAnalyzer {
    /// Create new analyzer (stateless - no configuration needed)
    pub fn new() -> Self {
        Self
    }

    /// Calculate quality metrics from code structure
    ///
    /// Pure computation - takes structured data, returns metrics
    pub fn calculate_quality_metrics(
        &self,
        file_size: usize,
        line_count: usize,
        function_count: usize,
        class_count: usize,
    ) -> Result<HashMap<String, f64>> {
        let mut metrics = HashMap::new();

        // Basic metrics
        metrics.insert("file_size".to_string(), file_size as f64);
        metrics.insert("line_count".to_string(), line_count as f64);
        metrics.insert("function_count".to_string(), function_count as f64);
        metrics.insert("class_count".to_string(), class_count as f64);

        // Calculated metrics
        let avg_function_length = if function_count > 0 {
            line_count as f64 / function_count as f64
        } else {
            0.0
        };
        metrics.insert("avg_function_length".to_string(), avg_function_length);

        // Quality score (simplified heuristic)
        let complexity_penalty = if avg_function_length > 50.0 { 0.1 } else { 0.0 };
        let size_penalty = if file_size > 10000 { 0.1 } else { 0.0 };
        let quality_score = 1.0 - complexity_penalty - size_penalty;
        metrics.insert("quality_score".to_string(), quality_score);

        Ok(metrics)
    }

    /// Calculate complexity metrics from code structure
    ///
    /// Pure computation - uses cyclomatic complexity heuristics
    pub fn calculate_complexity_metrics(
        &self,
        function_count: usize,
        class_count: usize,
        line_count: usize,
    ) -> Result<HashMap<String, f64>> {
        let mut metrics = HashMap::new();

        // Cyclomatic complexity (simplified)
        let cyclomatic_complexity = function_count as f64 + class_count as f64;
        metrics.insert("cyclomatic_complexity".to_string(), cyclomatic_complexity);

        // Cognitive complexity (simplified - based on LOC)
        let cognitive_complexity = line_count as f64 / 10.0;
        metrics.insert("cognitive_complexity".to_string(), cognitive_complexity);

        Ok(metrics)
    }

    /// Calculate cosine similarity between two embedding vectors
    ///
    /// Pure computation - standard cosine similarity algorithm
    pub fn calculate_similarity(&self, embedding1: &[f32], embedding2: &[f32]) -> f32 {
        if embedding1.len() != embedding2.len() || embedding1.is_empty() {
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
            dot_product / (norm1 * norm2)
        }
    }

    /// Rank search results by similarity scores
    ///
    /// Pure computation - sorts and limits results
    pub fn rank_by_similarity(
        &self,
        mut results: Vec<(String, f32)>,  // (path, similarity)
        limit: usize,
    ) -> Vec<(String, f32)> {
        results.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        results.truncate(limit);
        results
    }
}

// ============================================================================
// Legacy Compatibility - Graph Module Re-exports
// ============================================================================
//
// NOTE: Database operations removed - Elixir handles all storage via PostgreSQL.
// Rust NIFs only perform pure computation.

/// Legacy graph module compatibility
///
/// Re-exports types from the correct locations for backwards compatibility
/// with code that used the old `crate::storage::graph` path.
pub mod graph {
    // Re-export graph types from codebase module
    pub use crate::codebase::{CodeGraph as Graph, GraphNode, GraphEdge, GraphMetrics};
    pub use crate::codebase::{FileDAG, DAGStats};

    // Re-export ComplexityMetrics from domain module
    pub use crate::domain::ComplexityMetrics;

    // Note: GraphHandle requires the graph module which is currently disabled
    // If needed, it can be imported directly from where it's defined
}
