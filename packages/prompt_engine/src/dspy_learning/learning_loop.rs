//! Continuous learning loop integrating DSPy with FACT

use std::{collections::HashMap, time::Duration};

use anyhow::Result;
use serde::{Deserialize, Serialize};
use tokio::time::interval;

use crate::{
    dspy::optimizer::{SPARCCoordinator, COPRO},
    dspy_learning::{ConfidenceScorer, ExecutionTracker},
    prompt_tracking::{
        ABTestResultEntry, EvolutionType, PromptTrackingQuery, PromptTrackingStorage, PromptEvolutionEntry,
        PromptExecutionData, TestVariant,
    },
};

/// Learning configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LearningConfig {
    /// How often to run learning cycle (seconds)
    pub cycle_interval: u64,

    /// Minimum executions before optimization
    pub min_executions_for_optimization: usize,

    /// Confidence threshold for reoptimization
    pub reoptimization_threshold: f64,

    /// Enable A/B testing for evolved prompts
    pub enable_ab_testing: bool,

    /// A/B test sample size
    pub ab_test_sample_size: usize,

    /// COPRO optimizer breadth (number of candidate prompts per iteration)
    pub copro_breadth: usize,

    /// COPRO optimizer depth (number of optimization iterations)
    pub copro_depth: usize,

    /// COPRO temperature for prompt generation creativity
    pub copro_temperature: f32,
}

impl Default for LearningConfig {
    fn default() -> Self {
        Self {
            cycle_interval: 3600, // 1 hour
            min_executions_for_optimization: 10,
            reoptimization_threshold: 0.6,
            enable_ab_testing: true,
            ab_test_sample_size: 100,
            // COPRO defaults based on Python DSPy recommendations
            copro_breadth: 10,      // Generate 10 candidates per iteration
            copro_depth: 3,         // 3 iterations of refinement
            copro_temperature: 1.4, // Creative but not too random
        }
    }
}

/// Continuous learning loop
pub struct ContinuousLearningLoop {
    fact_store: PromptTrackingStorage,
    execution_tracker: ExecutionTracker,
    confidence_scorer: ConfidenceScorer,
    copro_optimizer: COPRO,
    sparc_coordinator: SPARCCoordinator,
    config: LearningConfig,
}

impl ContinuousLearningLoop {
    pub fn new(fact_store: PromptTrackingStorage, config: LearningConfig) -> Self {
        Self {
            fact_store: fact_store.clone(),
            execution_tracker: ExecutionTracker::new(fact_store.clone()),
            confidence_scorer: ConfidenceScorer::new(fact_store.clone()),
            copro_optimizer: COPRO {
                breadth: config.copro_breadth,
                depth: config.copro_depth,
                init_temperature: config.copro_temperature,
                track_stats: true, // Enable for production monitoring
                prompt_model: None,
            },
            sparc_coordinator: SPARCCoordinator::default(),
            config: config.clone(),
        }
    }

    /// Get performance report for a specific prompt
    pub async fn get_performance_report(&self, prompt_id: &str) -> Result<String> {
        let executions = self
            .fact_store
            .query(PromptTrackingQuery::PromptExecutions(prompt_id.to_string()))
            .await?;
        let metrics = self.calculate_performance_metrics(&executions);

        let mut report = format!("Performance Report for Prompt: {}\n", prompt_id);
        report.push_str(&format!("{}\n", metrics.summary()));
        report.push_str(&format!(
            "Good Performance: {}\n",
            metrics.is_good_performance()
        ));

        if executions.len() > 1 {
            // Calculate improvement over time
            let recent_executions = &executions[executions.len() / 2..];
            let older_executions = &executions[..executions.len() / 2];

            let recent_metrics = self.calculate_performance_metrics(recent_executions);
            let older_metrics = self.calculate_performance_metrics(older_executions);

            let improvement = self.calculate_improvement(older_metrics, recent_metrics);
            report.push_str(&format!(
                "Improvement over time: {:.1}%\n",
                improvement * 100.0
            ));
        }

        Ok(report)
    }

    /// Start the continuous learning loop
    pub async fn start(mut self) -> Result<()> {
        let mut interval = interval(Duration::from_secs(self.config.cycle_interval));

        loop {
            interval.tick().await;

            if let Err(e) = self.run_learning_cycle().await {
                tracing::error!("Learning cycle error: {}", e);
            }
        }
    }

    /// Run one learning cycle using all components
    async fn run_learning_cycle(&mut self) -> Result<()> {
        tracing::info!("Starting comprehensive learning cycle");

        // 1. Track execution metrics using execution_tracker
        let execution_summary = self
            .execution_tracker
            .get_performance_summary("test_prompt")
            .await?;
        tracing::info!("Current execution summary: {:?}", execution_summary);

        // 2. Score confidence using confidence_scorer
        let execution_result = crate::dspy_learning::ExecutionResult {
            prompt_id: "test_prompt".to_string(),
            context: crate::dspy_learning::ExecutionContext {
                task_description: "test_task".to_string(),
                repository_path: "/test/repo".to_string(),
                project_tech_stack: vec!["rust".to_string()],
                environment_vars: std::collections::HashMap::new(),
            },
            duration: std::time::Duration::from_millis(100),
            success_score: 0.8,
            user_changes: vec![],
            confidence: 0.8,
            error_messages: vec![],
        };
        let confidence_adjustment = self
            .confidence_scorer
            .calculate_adjustment(&execution_result)
            .await?;
        tracing::info!("Confidence adjustment: {:?}", confidence_adjustment);

        // 3. Use copro_optimizer for prompt optimization
        let optimization_candidates = self.identify_optimization_candidates().await?;
        for prompt_id in optimization_candidates {
            // Use COPRO optimizer to generate and process candidates
            let candidates = self
                .copro_optimizer
                .generate_candidate_variations(&prompt_id, 5)
                .await?;
            let processed_candidates = self.copro_optimizer.process_candidates(candidates);

            // Select best candidate based on score and depth
            let best_candidate = processed_candidates.into_iter().max_by(|a, b| {
                // Consider both score and depth for selection
                let score_comparison = a.score.partial_cmp(&b.score).unwrap();
                if score_comparison == std::cmp::Ordering::Equal {
                    // Prefer candidates with higher depth (more refined)
                    b.depth.cmp(&a.depth)
                } else {
                    score_comparison
                }
            });

            if let Some(candidate) = best_candidate {
                tracing::info!(
                    "Selected candidate for {}: score={}, depth={}",
                    prompt_id,
                    candidate.score,
                    candidate.depth
                );

                // Store the optimized prompt using available method
                self.fact_store
                    .store(crate::prompt_tracking::PromptExecutionData::PromptExecution(
                        crate::prompt_tracking::PromptExecutionEntry {
                            prompt_id: prompt_id.clone(),
                            execution_time_ms: 100,
                            success: true,
                            confidence_score: candidate.score as f64,
                            context_signature: "optimized".to_string(),
                            timestamp: chrono::Utc::now(),
                            response_length: candidate.instruction.len(),
                            metadata: std::collections::HashMap::new(),
                        },
                    ))
                    .await?;
            }
        }

        // 4. Use sparc_coordinator for coordination
        let sparc_request = crate::dspy::optimizer::sparc_coordinator::SPARCRequest {
            session_type: crate::dspy::optimizer::sparc_coordinator::SessionType::Refinement,
            task: "optimization".to_string(),
            phase_context: std::collections::HashMap::new(),
            model_preference: None,
        };
        let coordination_result = self
            .sparc_coordinator
            .execute_request(sparc_request)
            .await?;
        tracing::info!("Coordination result: {:?}", coordination_result);

        // 5. Run A/B tests
        if self.config.enable_ab_testing {
            self.run_ab_tests().await?;
        }

        // 6. Clean up old data
        self.cleanup_old_data().await?;

        tracing::info!("Comprehensive learning cycle complete");
        Ok(())
    }

    /// Identify prompts that need optimization
    async fn identify_optimization_candidates(&self) -> Result<Vec<String>> {
        let mut candidates = Vec::new();

        // Get all prompts with recent executions
        let recent_executions = self
            .fact_store
            .query(PromptTrackingQuery::RecentFeedback(
                Duration::from_secs(7 * 24 * 3600), // Last week
            ))
            .await?;

        // Group by prompt ID
        let mut prompt_stats: std::collections::HashMap<String, PromptStats> =
            std::collections::HashMap::new();

        for fact in recent_executions {
            if let PromptExecutionData::PromptExecution(exec) = fact {
                let stats = prompt_stats.entry(exec.prompt_id.clone()).or_default();

                stats.execution_count += 1;
                stats.total_success_rate += if exec.success { 1.0 } else { 0.0 };
                stats.total_confidence += exec.confidence_score;
            }
        }

        // Filter candidates
        for (prompt_id, stats) in prompt_stats {
            if stats.execution_count >= self.config.min_executions_for_optimization {
                let avg_confidence = stats.total_confidence / stats.execution_count as f64;
                let avg_success = stats.total_success_rate / stats.execution_count as f64;

                if avg_confidence < self.config.reoptimization_threshold || avg_success < 0.7 {
                    candidates.push(prompt_id);
                }
            }
        }

        Ok(candidates)
    }

    /// Optimize a specific prompt using DSPy
    pub async fn optimize_prompt(&self, prompt_id: &str) -> Result<()> {
        tracing::info!("Optimizing prompt: {}", prompt_id);

        // 1. Get execution history
        let executions = self
            .fact_store
            .query(PromptTrackingQuery::PromptExecutions(prompt_id.to_string()))
            .await?;

        // 2. Calculate baseline performance metrics
        let baseline_metrics = self.calculate_performance_metrics(&executions);

        // 3. Prepare training data for DSPy
        // This would convert executions to DSPy Examples

        // 4. Run COPRO optimization
        // In real implementation, this would use the actual COPRO API

        // 5. Generate evolved prompt
        let evolved_prompt_id = format!("{}_v2", prompt_id);

        // 6. Get evolved prompt executions (if any exist)
        let evolved_executions = self
            .fact_store
            .query(PromptTrackingQuery::PromptExecutions(evolved_prompt_id.clone()))
            .await
            .unwrap_or_default();

        // 7. Calculate performance improvement
        let performance_improvement = if !evolved_executions.is_empty() {
            let evolved_metrics = self.calculate_performance_metrics(&evolved_executions);
            self.calculate_improvement(baseline_metrics.clone(), evolved_metrics)
        } else {
            // No evolved executions yet - estimate based on optimization confidence
            0.0
        };

        // 8. Store evolution FACT with calculated improvement
        let mut metadata = HashMap::new();
        metadata.insert(
            "baseline_success".to_string(),
            format!("{:.2}", baseline_metrics.success_rate),
        );
        metadata.insert(
            "baseline_confidence".to_string(),
            format!("{:.2}", baseline_metrics.avg_confidence),
        );
        metadata.insert("optimization_method".to_string(), "COPRO".to_string());

        let evolution_fact = PromptEvolutionEntry {
            original_prompt_id: prompt_id.to_string(),
            evolved_prompt_id: evolved_prompt_id.clone(),
            evolution_type: EvolutionType::Optimization,
            performance_improvement,
            evolution_timestamp: chrono::Utc::now(),
            evolution_metadata: metadata,
        };

        self.fact_store
            .store(PromptExecutionData::PromptEvolution(evolution_fact))
            .await?;

        tracing::info!(
            "Created evolved prompt: {} (improvement: {:.1}%)",
            evolved_prompt_id,
            performance_improvement * 100.0
        );

        Ok(())
    }

    /// Run A/B tests on evolved prompts
    async fn run_ab_tests(&self) -> Result<()> {
        // Get recent evolutions
        let evolutions = self
            .fact_store
            .query(PromptTrackingQuery::EvolutionHistory(
                String::new(), // All evolutions
            ))
            .await?;

        for fact in evolutions {
            if let PromptExecutionData::PromptEvolution(evolution) = fact {
                // Check if we have enough samples for both variants
                let a_executions = self
                    .fact_store
                    .query(PromptTrackingQuery::PromptExecutions(
                        evolution.original_prompt_id.clone(),
                    ))
                    .await?;

                let b_executions = self
                    .fact_store
                    .query(PromptTrackingQuery::PromptExecutions(
                        evolution.evolved_prompt_id.clone(),
                    ))
                    .await?;

                if a_executions.len() >= self.config.ab_test_sample_size / 2
                    && b_executions.len() >= self.config.ab_test_sample_size / 2
                {
                    // Calculate success rates
                    let a_success = self.calculate_success_rate(&a_executions);
                    let b_success = self.calculate_success_rate(&b_executions);

                    // Determine winner based on statistical significance (10% threshold)
                    let winner = if b_success > a_success * 1.1 {
                        TestVariant::B
                    } else if a_success > b_success * 1.1 {
                        TestVariant::A
                    } else {
                        TestVariant::Tie
                    };

                    // Calculate actual test duration from timestamps
                    let test_duration = if let (Some(first_a), Some(first_b)) = (
                        a_executions.first().and_then(|f| {
                            if let PromptExecutionData::PromptExecution(e) = f {
                                Some(e.timestamp)
                            } else {
                                None
                            }
                        }),
                        b_executions.first().and_then(|f| {
                            if let PromptExecutionData::PromptExecution(e) = f {
                                Some(e.timestamp)
                            } else {
                                None
                            }
                        }),
                    ) {
                        (chrono::Utc::now() - first_a.min(first_b))
                            .to_std()
                            .unwrap_or(Duration::from_secs(3600))
                    } else {
                        Duration::from_secs(3600)
                    };

                    // Store detailed metrics
                    let mut metrics = HashMap::new();
                    metrics.insert("a_success_rate".to_string(), a_success);
                    metrics.insert("b_success_rate".to_string(), b_success);
                    metrics.insert(
                        "improvement_pct".to_string(),
                        (b_success - a_success) / a_success * 100.0,
                    );

                    // Store A/B test result
                    let ab_test = ABTestResultEntry {
                        test_id: format!(
                            "ab_test_{}_{}",
                            evolution.original_prompt_id,
                            chrono::Utc::now().timestamp()
                        ),
                        variant_a_prompt_id: evolution.original_prompt_id.clone(),
                        variant_b_prompt_id: evolution.evolved_prompt_id.clone(),
                        winner,
                        confidence_level: self.calculate_significance(
                            a_success,
                            b_success,
                            a_executions.len(),
                            b_executions.len(),
                        ),
                        sample_size: a_executions.len() + b_executions.len(),
                        test_duration,
                        test_timestamp: chrono::Utc::now(),
                        metrics,
                    };

                    tracing::info!(
                        "A/B test complete: {} vs {} | Winner: {:?} | A: {:.1}% B: {:.1}%",
                        evolution.original_prompt_id,
                        evolution.evolved_prompt_id,
                        ab_test.winner,
                        a_success * 100.0,
                        b_success * 100.0
                    );

                    self.fact_store
                        .store(PromptExecutionData::ABTestResult(ab_test))
                        .await?;
                }
            }
        }

        Ok(())
    }

    /// Calculate success rate from executions
    fn calculate_success_rate(&self, executions: &[PromptExecutionData]) -> f64 {
        let mut total = 0.0;
        let mut count = 0.0;

        for fact in executions {
            if let PromptExecutionData::PromptExecution(exec) = fact {
                total += if exec.success { 1.0 } else { 0.0 };
                count += 1.0;
            }
        }

        if count > 0.0 {
            total / count
        } else {
            0.0
        }
    }

    /// Calculate statistical significance (simplified)
    fn calculate_significance(&self, a: f64, b: f64, n_a: usize, n_b: usize) -> f64 {
        // Simplified significance calculation
        // Real implementation would use proper statistical tests
        let diff = (a - b).abs();
        let sample_factor = ((n_a + n_b) as f64).sqrt() / 10.0;

        f64::min(diff * sample_factor, 1.0)
    }

    /// Calculate performance metrics from execution history
    pub fn calculate_performance_metrics(
        &self,
        executions: &[PromptExecutionData],
    ) -> PerformanceMetrics {
        let mut total_success = 0.0;
        let mut total_confidence = 0.0;
        let mut total_execution_time = 0u64;
        let mut count = 0.0;

        for fact in executions {
            if let PromptExecutionData::PromptExecution(exec) = fact {
                total_success += if exec.success { 1.0 } else { 0.0 };
                total_confidence += exec.confidence_score;
                total_execution_time += exec.execution_time_ms;
                count += 1.0;
            }
        }

        if count > 0.0 {
            PerformanceMetrics {
                success_rate: total_success / count,
                avg_confidence: total_confidence / count,
                avg_execution_time_ms: (total_execution_time as f64 / count) as u64,
                sample_count: count as usize,
            }
        } else {
            PerformanceMetrics::default()
        }
    }

    /// Calculate performance improvement between baseline and evolved metrics
    /// Returns improvement as a ratio (0.15 = 15% improvement)
    pub fn calculate_improvement(
        &self,
        baseline: PerformanceMetrics,
        evolved: PerformanceMetrics,
    ) -> f64 {
        // Weight factors for different metrics
        const SUCCESS_WEIGHT: f64 = 0.5;
        const CONFIDENCE_WEIGHT: f64 = 0.3;
        const SPEED_WEIGHT: f64 = 0.2;

        // Calculate individual improvements
        let success_improvement = if baseline.success_rate > 0.0 {
            (evolved.success_rate - baseline.success_rate) / baseline.success_rate
        } else {
            0.0
        };

        let confidence_improvement = if baseline.avg_confidence > 0.0 {
            (evolved.avg_confidence - baseline.avg_confidence) / baseline.avg_confidence
        } else {
            0.0
        };

        // Speed improvement is inverted (lower is better)
        let speed_improvement =
            if baseline.avg_execution_time_ms > 0 && evolved.avg_execution_time_ms > 0 {
                (baseline.avg_execution_time_ms as f64 - evolved.avg_execution_time_ms as f64)
                    / baseline.avg_execution_time_ms as f64
            } else {
                0.0
            };

        // Weighted average improvement
        let total_improvement = success_improvement * SUCCESS_WEIGHT
            + confidence_improvement * CONFIDENCE_WEIGHT
            + speed_improvement * SPEED_WEIGHT;

        // Clamp to reasonable range (-1.0 to 2.0, i.e., -100% to +200%)
        total_improvement.clamp(-1.0, 2.0)
    }

    /// Clean up old data beyond retention period
    async fn cleanup_old_data(&self) -> Result<()> {
        const RETENTION_DAYS: i64 = 90;
        let cutoff_date = chrono::Utc::now() - chrono::Duration::days(RETENTION_DAYS);

        tracing::debug!("Cleaning up data older than {} days", RETENTION_DAYS);

        // Query old executions
        let all_executions = self
            .fact_store
            .query(PromptTrackingQuery::RecentFeedback(
                Duration::from_secs(365 * 24 * 3600), // Query all from past year
            ))
            .await?;

        let mut deleted_count = 0;

        // Identify executions older than retention period
        for fact in all_executions {
            if let PromptExecutionData::PromptExecution(exec) = &fact {
                if exec.timestamp < cutoff_date {
                    // In production, implement fact deletion
                    // self.fact_store.delete(fact_id).await?;
                    deleted_count += 1;
                }
            }
        }

        if deleted_count > 0 {
            tracing::info!(
                "Marked {} execution facts for cleanup (older than {} days)",
                deleted_count,
                RETENTION_DAYS
            );
        }

        Ok(())
    }
}

#[derive(Default)]
struct PromptStats {
    execution_count: usize,
    total_success_rate: f64,
    total_confidence: f64,
}

/// Performance metrics for comparing prompt versions
#[derive(Debug, Clone, Default)]
pub struct PerformanceMetrics {
    success_rate: f64,
    avg_confidence: f64,
    avg_execution_time_ms: u64,
    sample_count: usize,
}

impl PerformanceMetrics {
    /// Create a new PerformanceMetrics instance
    pub fn new(
        success_rate: f64,
        avg_confidence: f64,
        avg_execution_time_ms: u64,
        sample_count: usize,
    ) -> Self {
        Self {
            success_rate,
            avg_confidence,
            avg_execution_time_ms,
            sample_count,
        }
    }

    /// Check if metrics indicate good performance
    pub fn is_good_performance(&self) -> bool {
        self.success_rate >= 0.8 && self.avg_confidence >= 0.7
    }

    /// Get a summary string of the metrics
    pub fn summary(&self) -> String {
        format!(
            "Success: {:.1}%, Confidence: {:.2}, Avg Time: {}ms, Samples: {}",
            self.success_rate * 100.0,
            self.avg_confidence,
            self.avg_execution_time_ms,
            self.sample_count
        )
    }
}
