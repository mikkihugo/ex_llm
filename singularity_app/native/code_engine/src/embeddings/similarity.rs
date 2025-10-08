//! Similarity Metrics
//!
//! Copied from @primecode/neural-ml/pattern_recognition.rs

use super::EmbeddingError;
use anyhow::Result;

/// Similarity metric types
#[derive(Debug, Clone, Copy)]
pub enum SimilarityMetric {
    Cosine,
    Euclidean,
    Manhattan,
}

/// Similarity computation utilities
pub struct SimilarityMetrics;

impl SimilarityMetrics {
    /// Cosine similarity between two vectors (most common for embeddings)
    pub fn cosine_similarity(a: &[f32], b: &[f32]) -> Result<f32> {
        if a.len() != b.len() {
            return Err(EmbeddingError::DimensionMismatch {
                expected: a.len(),
                actual: b.len(),
            }
            .into());
        }

        let dot_product: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
        let norm_a: f32 = a.iter().map(|x| x * x).sum::<f32>().sqrt();
        let norm_b: f32 = b.iter().map(|x| x * x).sum::<f32>().sqrt();

        if norm_a < 1e-10 || norm_b < 1e-10 {
            Ok(0.0)
        } else {
            Ok(dot_product / (norm_a * norm_b))
        }
    }

    /// Euclidean distance (convert to similarity: 1 / (1 + distance))
    pub fn euclidean_distance(a: &[f32], b: &[f32]) -> Result<f32> {
        if a.len() != b.len() {
            return Err(EmbeddingError::DimensionMismatch {
                expected: a.len(),
                actual: b.len(),
            }
            .into());
        }

        let distance: f32 = a
            .iter()
            .zip(b.iter())
            .map(|(x, y)| (x - y).powi(2))
            .sum::<f32>()
            .sqrt();

        Ok(distance)
    }

    /// Manhattan distance
    pub fn manhattan_distance(a: &[f32], b: &[f32]) -> Result<f32> {
        if a.len() != b.len() {
            return Err(EmbeddingError::DimensionMismatch {
                expected: a.len(),
                actual: b.len(),
            }
            .into());
        }

        let distance: f32 = a.iter().zip(b.iter()).map(|(x, y)| (x - y).abs()).sum();
        Ok(distance)
    }

    /// Find top-k most similar vectors
    pub fn find_top_k(
        query: &[f32],
        candidates: &[Vec<f32>],
        k: usize,
        metric: SimilarityMetric,
    ) -> Result<Vec<(usize, f32)>> {
        let mut scored: Vec<(usize, f32)> = candidates
            .iter()
            .enumerate()
            .map(|(idx, candidate)| {
                let score = match metric {
                    SimilarityMetric::Cosine => {
                        Self::cosine_similarity(query, candidate).unwrap_or(0.0)
                    }
                    SimilarityMetric::Euclidean => {
                        let dist = Self::euclidean_distance(query, candidate).unwrap_or(f32::MAX);
                        1.0 / (1.0 + dist) // Convert distance to similarity
                    }
                    SimilarityMetric::Manhattan => {
                        let dist = Self::manhattan_distance(query, candidate).unwrap_or(f32::MAX);
                        1.0 / (1.0 + dist)
                    }
                };
                (idx, score)
            })
            .collect();

        // Sort by score descending
        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        // Take top k
        scored.truncate(k);

        Ok(scored)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cosine_similarity() {
        let a = vec![1.0, 2.0, 3.0];
        let b = vec![2.0, 4.0, 6.0]; // Parallel vectors
        let c = vec![-1.0, -2.0, -3.0]; // Anti-parallel

        let sim_ab = SimilarityMetrics::cosine_similarity(&a, &b).unwrap();
        let sim_ac = SimilarityMetrics::cosine_similarity(&a, &c).unwrap();

        assert!((sim_ab - 1.0).abs() < 1e-5); // Should be 1.0
        assert!((sim_ac + 1.0).abs() < 1e-5); // Should be -1.0
    }

    #[test]
    fn test_find_top_k() {
        let query = vec![1.0, 0.0, 0.0];
        let candidates = vec![
            vec![1.0, 0.0, 0.0], // Perfect match
            vec![0.8, 0.6, 0.0], // Close
            vec![0.0, 1.0, 0.0], // Orthogonal
        ];

        let results =
            SimilarityMetrics::find_top_k(&query, &candidates, 2, SimilarityMetric::Cosine)
                .unwrap();

        assert_eq!(results.len(), 2);
        assert_eq!(results[0].0, 0); // Index of perfect match
        assert!(results[0].1 > results[1].1); // Higher score
    }
}
