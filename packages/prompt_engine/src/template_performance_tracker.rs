//! Template Performance Tracker for Prompt Engine
//!
//! Integrates with HTDAG to track which templates perform best
//! and automatically optimize prompt selection.

use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

use crate::sparc_templates::SparcTemplateGenerator;
use crate::PromptTemplate;

/// Type alias for template performance data key: (template_id, task_type, language)
type TemplateKey = (String, String, String);

/// Performance metrics for a template
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetrics {
    pub template_id: String,
    pub task_type: String,
    pub language: String,
    pub success_rate: f64,
    pub avg_generation_time_ms: f64,
    pub quality_score: f64,
    pub usage_count: usize,
    pub last_used: DateTime<Utc>,
    pub feedback_scores: Vec<f64>,
}

/// Template performance tracker integrated with HTDAG
pub struct TemplatePerformanceTracker {
    /// Performance data indexed by (template_id, task_type, language)
    performance_data: Arc<RwLock<HashMap<TemplateKey, TemplateMetrics>>>,

    /// Template rankings for quick lookup
    template_rankings: Arc<RwLock<Vec<(String, f64)>>>,

    /// SPARC template generator
    sparc_generator: SparcTemplateGenerator,

    /// Learning rate for exponential moving average
    alpha: f64,
}

impl Default for TemplatePerformanceTracker {
    fn default() -> Self {
        Self::new()
    }
}

impl TemplatePerformanceTracker {
    pub fn new() -> Self {
        Self {
            performance_data: Arc::new(RwLock::new(HashMap::new())),
            template_rankings: Arc::new(RwLock::new(Vec::new())),
            sparc_generator: SparcTemplateGenerator::new(),
            alpha: 0.3, // Weight for new data
        }
    }

    /// Select best template based on performance history
    pub fn select_best_template(&self, task_type: &str, language: &str) -> Result<PromptTemplate> {
        let data = self.performance_data.read().unwrap();

        // Find templates matching task type and language
        let mut candidates: Vec<(&String, f64)> = data
            .iter()
            .filter(|((_, tt, lang), _)| tt == task_type && lang == language)
            .map(|((template_id, _, _), metrics)| (template_id, self.calculate_score(metrics)))
            .collect();

        // Sort by score descending
        candidates.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

        // Get best template or fall back to default
        let template_id = candidates
            .first()
            .map(|(id, _)| (*id).clone())
            .unwrap_or_else(|| self.get_default_template(task_type, language));

        // Load the template
        self.load_template(&template_id, language)
    }

    /// Record template usage and performance
    pub fn record_usage(
        &self,
        template_id: String,
        task_type: String,
        language: String,
        success: bool,
        generation_time_ms: f64,
        quality_score: f64,
    ) {
        let mut data = self.performance_data.write().unwrap();
        let key = (template_id.clone(), task_type, language);

        // Avoid moving `key` into the entry; clone for use inside the closure
        let metrics = data.entry(key.clone()).or_insert_with(|| TemplateMetrics {
            template_id,
            task_type: key.1.clone(),
            language: key.2.clone(),
            success_rate: 0.0,
            avg_generation_time_ms: 0.0,
            quality_score: 0.0,
            usage_count: 0,
            last_used: Utc::now(),
            feedback_scores: Vec::new(),
        });

        // Update with exponential moving average
        metrics.success_rate = (1.0 - self.alpha) * metrics.success_rate
            + self.alpha * (if success { 1.0 } else { 0.0 });
        metrics.avg_generation_time_ms =
            (1.0 - self.alpha) * metrics.avg_generation_time_ms + self.alpha * generation_time_ms;
        metrics.quality_score =
            (1.0 - self.alpha) * metrics.quality_score + self.alpha * quality_score;
        metrics.usage_count += 1;
        metrics.last_used = Utc::now();

        if metrics.feedback_scores.len() > 100 {
            metrics.feedback_scores.remove(0);
        }
        metrics.feedback_scores.push(quality_score);

        // Update rankings
        drop(data); // Release lock
        self.update_rankings();
    }

    /// Get template with performance metadata injected
    pub fn get_template_with_metadata(
        &self,
        template_id: &str,
        task_context: &HashMap<String, String>,
    ) -> Result<String> {
        let lang = task_context
            .get("language")
            .cloned()
            .unwrap_or_else(|| "unknown".to_string());
        let template = self.load_template(template_id, &lang)?;
        let metrics = self.get_metrics(template_id);

        // Build enhanced prompt with performance context
        let mut enhanced_prompt = format!(
            "# Template: {} (Performance Score: {:.2})\n",
            template.name,
            metrics
                .as_ref()
                .map(|m| self.calculate_score(m))
                .unwrap_or(0.5)
        );

        // Add task context
        if !task_context.is_empty() {
            enhanced_prompt.push_str("\n## Context\n");
            for (key, value) in task_context {
                enhanced_prompt.push_str(&format!("- {}: {}\n", key, value));
            }
        }

        // Add template content
        enhanced_prompt.push_str("\n## Template\n");
        enhanced_prompt.push_str(&template.template);

        // Add performance hints if available
        if let Some(metrics) = metrics {
            if metrics.usage_count > 5 {
                enhanced_prompt.push_str(&format!(
                    "\n## Performance Hints\n\
                    - Success Rate: {:.1}%\n\
                    - Avg Generation Time: {:.0}ms\n\
                    - Quality Score: {:.2}/1.0\n",
                    metrics.success_rate * 100.0,
                    metrics.avg_generation_time_ms,
                    metrics.quality_score
                ));
            }
        }

        Ok(enhanced_prompt)
    }

    /// Integrate with SPARC phases
    pub fn get_sparc_phase_template(
        &self,
        phase: &str,
        task_type: &str,
        language: &str,
    ) -> Result<String> {
        // Map SPARC phase to template
        let template_id = match phase {
            "specification" => "sparc_specification",
            "pseudocode" => "sparc_pseudocode",
            "architecture" => "sparc_architecture",
            "refinement" => "sparc_refinement",
            "completion" => "sparc_completion",
            _ => "sparc_generic",
        };

        // Get template with performance optimization
        let template =
            self.select_best_template(&format!("{}_{}", template_id, task_type), language)?;

        // Add SPARC-specific context
        let mut context = HashMap::new();
        context.insert("phase".to_string(), phase.to_string());
        context.insert("task_type".to_string(), task_type.to_string());
        context.insert("language".to_string(), language.to_string());

        self.get_template_with_metadata(&template.name, &context)
    }

    // Private helper methods

    fn calculate_score(&self, metrics: &TemplateMetrics) -> f64 {
        let weights = (0.3, 0.3, 0.2, 0.1, 0.1); // (success, quality, speed, recency, usage)

        // Normalize speed (faster is better, max 10 seconds)
        let speed_score = 1.0 - (metrics.avg_generation_time_ms / 10000.0).min(1.0);

        // Recency score (exponential decay over 30 days)
        let days_ago = (Utc::now() - metrics.last_used).num_days() as f64;
        let recency_score = (-days_ago / 30.0).exp();

        // Usage score (logarithmic growth)
        let usage_score = ((metrics.usage_count as f64 + 1.0).ln() / 10.0).min(1.0);

        weights.0 * metrics.success_rate
            + weights.1 * metrics.quality_score
            + weights.2 * speed_score
            + weights.3 * recency_score
            + weights.4 * usage_score
    }

    fn update_rankings(&self) {
        let data = self.performance_data.read().unwrap();
        let mut rankings: Vec<(String, f64)> = data
            .iter()
            .map(|((template_id, _, _), metrics)| {
                (template_id.clone(), self.calculate_score(metrics))
            })
            .collect();

        rankings.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

        let mut rankings_lock = self.template_rankings.write().unwrap();
        *rankings_lock = rankings;
    }

    fn get_default_template(&self, task_type: &str, language: &str) -> String {
        match (task_type, language) {
            ("nats_consumer", "rust") => "rust-nats-consumer".to_string(),
            ("api_endpoint", "rust") => "rust-api-endpoint".to_string(),
            ("microservice", _) => "microservice-generic".to_string(),
            _ => "generic-template".to_string(),
        }
    }

    fn load_template(&self, template_id: &str, language: &str) -> Result<PromptTemplate> {
        // Load from SPARC generator or template registry
        Ok(PromptTemplate {
            name: template_id.to_string(),
            template: self
                .sparc_generator
                .get_template(template_id)
                .unwrap_or_else(|| format!("Template {} not found", template_id)),
            language: language.to_string(),
            domain: "sparc".to_string(),
            quality_score: 0.8,
        })
    }

    fn get_metrics(&self, template_id: &str) -> Option<TemplateMetrics> {
        let data = self.performance_data.read().unwrap();
        data.iter()
            .find(|((tid, _, _), _)| tid == template_id)
            .map(|(_, metrics)| metrics.clone())
    }
}

impl SparcTemplateGenerator {
    /// Resolve SPARC template via package_registry_indexer registry (generated + DB-backed)
    pub fn get_template(&self, template_id: &str) -> Option<String> {
        // Use package_registry_indexer's registry which loads generated AI templates
        #[cfg(feature = "with-package-indexer")]
        {
            let registry = package_registry_indexer::RegistryTemplate::new();
            registry
                .get(template_id)
                .and_then(|t| t.template_content.clone())
        }
        #[cfg(not(feature = "with-package-indexer"))]
        {
            // Fallback: return a basic template based on template_id when package indexer is not available
            match template_id {
                "sparc_specification" => Some("# SPARC Specification Template\n\n## Requirements\n- [ ] Functional requirements\n- [ ] Non-functional requirements\n- [ ] Constraints\n\n## Analysis\n- [ ] Domain analysis\n- [ ] Risk assessment\n- [ ] Success criteria".to_string()),
                "sparc_pseudocode" => Some("# SPARC Pseudocode Template\n\n## Algorithm Overview\n[High-level algorithm description]\n\n## Step-by-step Logic\n1. [Step 1]\n2. [Step 2]\n3. [Step 3]\n\n## Edge Cases\n- [Edge case 1]\n- [Edge case 2]".to_string()),
                "sparc_architecture" => Some("# SPARC Architecture Template\n\n## System Components\n- [ ] Component 1\n- [ ] Component 2\n- [ ] Component 3\n\n## Data Flow\n[Describe data flow between components]\n\n## Technology Stack\n- [ ] Language: \n- [ ] Framework: \n- [ ] Database: ".to_string()),
                "sparc_refinement" => Some("# SPARC Refinement Template\n\n## Code Structure\n[Describe the code organization]\n\n## Implementation Details\n- [ ] Function 1\n- [ ] Function 2\n- [ ] Error handling\n\n## Testing Strategy\n- [ ] Unit tests\n- [ ] Integration tests".to_string()),
                "sparc_completion" => Some("# SPARC Completion Template\n\n## Final Implementation\n[Complete code implementation]\n\n## Documentation\n- [ ] Code comments\n- [ ] README updates\n- [ ] API documentation\n\n## Deployment\n- [ ] Deployment steps\n- [ ] Configuration\n- [ ] Monitoring".to_string()),
                _ => Some(format!("# Generic SPARC Template\n\nTemplate ID: {}\n\n## Overview\n[Template content for {} phase]\n\n## Implementation\n[Implementation details here]", template_id, template_id)),
            }
        }
    }
}
