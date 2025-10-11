//! DSPy-powered prompt selection with neural similarity matching

use std::collections::HashMap;

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::{
    dspy_learning::PromptEmbedder,
    prompt_bits::database::StoredPromptBit as PromptBit,
    prompt_tracking::{ContextSignatureFact, FactQuery, FactStorage, PromptFactType},
};

/// Selected prompt with confidence and reasoning
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SelectedPrompt {
    pub prompt_bit: PromptBit,
    pub confidence: f64,
    pub reasoning: String,
    pub similar_executions: Vec<String>,
    /// Similarity scores with other candidates (if ML available)
    pub similarity_scores: Option<Vec<(String, f64)>>,
}

/// Repository context for prompt selection
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RepositoryContext {
    pub workspace_type: String,
    pub build_system: String,
    pub languages: Vec<String>,
    pub frameworks: Vec<String>,
    pub databases: Vec<String>,
    pub directory_structure: Vec<String>,
}

/// Task description for prompt selection
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub description: String,
    pub category: String,
    pub complexity: f64,
    pub requirements: Vec<String>,
}

/// DSPy-powered prompt selector with neural embeddings
pub struct PromptSelector {
    fact_store: FactStorage,
    /// Prompt embedder for similarity matching (optional, requires ml-analysis feature)
    embedder: Option<PromptEmbedder>,
}

impl PromptSelector {
    /// Create new prompt selector with optional neural embeddings
    pub fn new(fact_store: FactStorage) -> Self {
        // Initialize embedder with 128-dimensional embeddings
        let embedder = Some(PromptEmbedder::new(128));

        Self {
            fact_store,
            embedder,
        }
    }

    /// Select optimal prompt for task and context (with neural similarity if available)
    pub async fn select_optimal_prompt(
        &mut self,
        task: &Task,
        context: &RepositoryContext,
        candidates: Vec<PromptBit>,
    ) -> Result<SelectedPrompt> {
        // 1. Generate context signature
        let signature = self.analyze_context(task, context).await?;

        // 2. Query similar successful executions
        let similar_executions = self
            .fact_store
            .query(FactQuery::Similar(signature.clone()))
            .await?;

        // 3. Score each candidate based on historical performance
        let mut scored_candidates = Vec::new();
        for candidate in candidates {
            let score = self
                .score_candidate(&candidate, &signature, &similar_executions)
                .await?;
            scored_candidates.push((candidate, score));
        }

        // 4. Sort by score and select best
        scored_candidates.sort_by(|a, b| b.1.confidence.partial_cmp(&a.1.confidence).unwrap());

        if let Some((best_prompt, score)) = scored_candidates.first() {
            // 5. Generate reasoning using Chain of Thought
            let reasoning = self
                .generate_reasoning(task, context, best_prompt, &similar_executions)
                .await?;

            // Calculate similarity scores with other candidates if embedder available
            let similarity_scores = if let Some(embedder) = &mut self.embedder {
                let mut scores = Vec::new();
                for (candidate, _) in &scored_candidates {
                    if candidate.id != best_prompt.id {
                        match embedder.similarity(&best_prompt.content, &candidate.content) {
                            Ok(sim) => scores.push((candidate.id.clone(), sim)),
                            Err(_) => continue,
                        }
                    }
                }
                // Sort by similarity descending
                scores.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
                Some(scores.into_iter().take(5).collect()) // Top 5 similar
            } else {
                None
            };

            Ok(SelectedPrompt {
                prompt_bit: best_prompt.clone(),
                confidence: score.confidence,
                reasoning,
                similar_executions: similar_executions
                    .iter()
                    .filter_map(|f| {
                        if let PromptFactType::PromptExecution(exec) = f {
                            Some(exec.prompt_id.clone())
                        } else {
                            None
                        }
                    })
                    .collect(),
                similarity_scores,
            })
        } else {
            Err(anyhow::anyhow!("No suitable prompts found"))
        }
    }

    /// Analyze context to create signature
    async fn analyze_context(
        &self,
        task: &Task,
        context: &RepositoryContext,
    ) -> Result<ContextSignatureFact> {
        // Create feature vector for ML matching
        let _feature_vector = [
            // Encode task features
            task.complexity,
            task.requirements.len() as f64,
            // Encode context features
            context.languages.len() as f64,
            context.frameworks.len() as f64,
            context.databases.len() as f64,
        ];

        // Build repository fingerprint
        let fingerprint = format!(
            "{}-{}-{}",
            context.workspace_type,
            context.build_system,
            context.languages.join(",")
        );

        Ok(ContextSignatureFact {
            signature_hash: fingerprint,
            project_tech_stack: [
                context.languages.clone(),
                context.frameworks.clone(),
                context.databases.clone(),
            ]
            .concat(),
            project_type: task.category.clone(),
            complexity_level: task.complexity,
            created_at: chrono::Utc::now(),
            metadata: HashMap::new(),
        })
    }

    /// Score a candidate prompt
    async fn score_candidate(
        &self,
        candidate: &PromptBit,
        signature: &ContextSignatureFact,
        similar_executions: &[PromptFactType],
    ) -> Result<ScoredPrompt> {
        let mut score = ScoredPrompt {
            prompt_id: candidate.id.clone(),
            historical_score: 0.0,
            relevance_score: 0.0,
            confidence: 0.0,
        };

        // Calculate historical performance
        let mut total_success = 0.0;
        let mut count = 0.0;

        for fact in similar_executions {
            if let PromptFactType::PromptExecution(exec) = fact {
                if exec.prompt_id == candidate.id {
                    total_success += if exec.success { 1.0 } else { 0.0 };
                    count += 1.0;
                }
            }
        }

        if count > 0.0 {
            score.historical_score = total_success / count;
        } else {
            // No history, use base confidence
            score.historical_score = candidate.metadata.confidence;
        }

        // Calculate relevance based on tech stack match
        let candidate_tech: Vec<_> = self.extract_tech_from_prompt(candidate);
        let signature_tech = &signature.project_tech_stack;

        let matching_tech = candidate_tech
            .iter()
            .filter(|t| signature_tech.contains(t))
            .count();

        score.relevance_score = if !candidate_tech.is_empty() {
            matching_tech as f64 / candidate_tech.len() as f64
        } else {
            0.5 // Neutral if no tech specified
        };

        // Calculate overall confidence
        score.confidence = score.historical_score * 0.6 + score.relevance_score * 0.4;

        Ok(score)
    }

    /// Extract technology mentions from prompt
    fn extract_tech_from_prompt(&self, prompt: &PromptBit) -> Vec<String> {
        // Simple extraction - would be more sophisticated in production
        let mut tech = Vec::new();

        let content_lower = prompt.content.to_lowercase();

        // Check for common technologies
        let known_tech = [
            "rust",
            "typescript",
            "javascript",
            "python",
            "react",
            "nextjs",
            "express",
            "postgres",
            "mongodb",
            "redis",
            "kafka",
            "nats",
        ];

        for t in &known_tech {
            if content_lower.contains(t) {
                tech.push(t.to_string());
            }
        }

        tech
    }

    /// Generate reasoning for prompt selection
    async fn generate_reasoning(
        &self,
        task: &Task,
        context: &RepositoryContext,
        selected: &PromptBit,
        similar_executions: &[PromptFactType],
    ) -> Result<String> {
        // Use Chain of Thought to generate reasoning
        let mut reasoning = format!(
            "Selected prompt '{}' for task '{}' because:\n",
            selected.id, task.description
        );

        // Add historical performance reason
        let exec_count = similar_executions
            .iter()
            .filter(|f| {
                if let PromptFactType::PromptExecution(exec) = f {
                    exec.prompt_id == selected.id
                } else {
                    false
                }
            })
            .count();

        if exec_count > 0 {
            reasoning.push_str(&format!(
                "- It has been successfully used {} times in similar contexts\n",
                exec_count
            ));
        }

        // Add tech stack match reason
        let prompt_tech = self.extract_tech_from_prompt(selected);
        let matching_tech: Vec<_> = prompt_tech
            .iter()
            .filter(|t| {
                context.languages.contains(t)
                    || context.frameworks.contains(t)
                    || context.databases.contains(t)
            })
            .collect();

        if !matching_tech.is_empty() {
            reasoning.push_str(&format!(
                "- It matches your tech stack: {}\n",
                matching_tech
                    .iter()
                    .map(|t| t.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            ));
        }

        // Add confidence reason
        reasoning.push_str(&format!(
            "- Confidence level: {:.1}%",
            selected.metadata.confidence * 100.0
        ));

        Ok(reasoning)
    }

    /// Score and rank prompts based on multiple criteria
    pub async fn score_prompts(&self, prompt_ids: Vec<String>) -> Result<Vec<ScoredPrompt>> {
        let mut scored_prompts = Vec::new();

        for prompt_id in prompt_ids {
            // Get historical performance
            let historical_score = self
                .get_historical_performance(&prompt_id)
                .await
                .unwrap_or(0.5);

            // Get relevance score (simplified)
            let relevance_score = self.calculate_relevance(&prompt_id).await.unwrap_or(0.5);

            // Get confidence score
            let confidence = self.calculate_confidence(&prompt_id).await.unwrap_or(0.5);

            let scored_prompt =
                ScoredPrompt::new(prompt_id, historical_score, relevance_score, confidence);
            scored_prompts.push(scored_prompt);
        }

        // Sort by overall score
        scored_prompts.sort_by(|a, b| b.overall_score().partial_cmp(&a.overall_score()).unwrap());

        Ok(scored_prompts)
    }

    /// Get historical performance score for a prompt
    async fn get_historical_performance(&self, _prompt_id: &str) -> Result<f64> {
        // Simplified implementation - in real scenario would query execution history
        Ok(0.8) // Placeholder
    }

    /// Calculate relevance score for a prompt
    async fn calculate_relevance(&self, _prompt_id: &str) -> Result<f64> {
        // Simplified implementation - in real scenario would analyze context
        Ok(0.7) // Placeholder
    }

    /// Calculate confidence score for a prompt
    async fn calculate_confidence(&self, _prompt_id: &str) -> Result<f64> {
        // Simplified implementation - in real scenario would analyze execution confidence
        Ok(0.9) // Placeholder
    }
}

/// Scored prompt for ranking
#[derive(Debug, Clone)]
pub struct ScoredPrompt {
    prompt_id: String,
    historical_score: f64,
    relevance_score: f64,
    confidence: f64,
}

impl ScoredPrompt {
    /// Create a new scored prompt
    pub fn new(
        prompt_id: String,
        historical_score: f64,
        relevance_score: f64,
        confidence: f64,
    ) -> Self {
        Self {
            prompt_id,
            historical_score,
            relevance_score,
            confidence,
        }
    }

    /// Get the prompt ID
    pub fn prompt_id(&self) -> &str {
        &self.prompt_id
    }

    /// Calculate overall score
    pub fn overall_score(&self) -> f64 {
        (self.historical_score * 0.4) + (self.relevance_score * 0.4) + (self.confidence * 0.2)
    }

    /// Get a summary of the scored prompt
    pub fn summary(&self) -> String {
        format!(
            "Prompt {}: Historical={:.2}, Relevance={:.2}, Confidence={:.2}, Overall={:.2}",
            self.prompt_id,
            self.historical_score,
            self.relevance_score,
            self.confidence,
            self.overall_score()
        )
    }
}
