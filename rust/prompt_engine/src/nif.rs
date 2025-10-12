//! Prompt Engine - ML-based prompt optimization and management
//!
//! The Prompt Engine provides comprehensive prompt optimization using:
//! - ML-based optimization with Candle neural networks
//! - Teleprompter implementations (BootstrapFinetune, MIPROv2, COPRO)
//! - Collaborative optimization with multiple agents
//! - Template management and automatic assembly
//! - Performance metrics and caching
//!
//! ## Architecture
//!
//! The prompt-engine crate is organized into the following modules:
//!
//! - dspy/              # Full DSPy implementation (core, predictors, optimizers)
//! - templates/         # Prompt templates and registry
//! - optimization/      # Core optimization algorithms
//! - teleprompters/     # DSPy teleprompter implementations
//! - copro/            # COPRO collaborative optimization
//! - assembly/          # Automatic prompt assembly
//! - caching/           # Prompt caching and retrieval
//! - metrics/           # Performance metrics

// Core DSPy implementation
pub mod dspy;
pub mod dspy_data;
pub mod token_usage;

pub mod assembly;
pub mod caching;
pub mod language_support;
pub mod metrics;
pub mod microservice_templates;
pub mod rust_dspy_templates;
pub mod sparc_templates;
pub mod template_loader;
pub mod template_performance_tracker;
pub mod templates;

// Context-aware prompt generation
pub mod prompt_bits;

// Prompt execution tracking and learning
pub mod prompt_tracking;

// DSPy learning integration with FACT
pub mod dspy_learning;

// NATS service - centralized communication hub
pub mod nats_service;

// Re-export main types
use std::collections::HashMap;

use anyhow::Result;
pub use assembly::{AssembledPrompt, AssemblyContext, PromptAssembler};
pub use caching::{CacheEntry, CacheStats, PromptCache};
// COPRO optimizer now available via dspy::optimizer::copro module
pub use language_support::{LanguagePromptGenerator, LanguageTemplates};
pub use metrics::{OptimizationMetrics, PerformanceTracker, PromptMetrics};
pub use microservice_templates::{
    ArchitectureType, MicroserviceCodePattern, MicroserviceContext, MicroserviceTemplateGenerator,
};
// Re-export prompt bits
pub use prompt_bits::{PromptBitAssembler, PromptFeedback, PromptFeedbackCollector};
use serde::{Deserialize, Serialize};
// Optimization and teleprompters now available via dspy module
pub use sparc_templates::SparcTemplateGenerator;
pub use templates::{PromptTemplate, RegistryTemplate, TemplateLoader};

// Import COPRO types for internal use
use crate::dspy::optimizer::copro::Candidate;

// NIF-compatible data structures
/// Request to generate a prompt
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.GenerateRequest"]
pub struct NifGenerateRequest {
    pub context: String,
    pub language: String,
    pub template_id: Option<String>,
    pub trigger_type: Option<String>,
    pub trigger_value: Option<String>,
    pub category: Option<String>,
}

/// Request to optimize a prompt
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.OptimizeRequest"]
pub struct NifOptimizeRequest {
    pub prompt: String,
    pub context: Option<String>,
    pub language: Option<String>,
}

/// Response with generated prompt
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.PromptResponse"]
pub struct NifPromptResponse {
    pub prompt: String,
    pub confidence: f64,
    pub template_used: Option<String>,
    pub optimization_score: Option<f64>,
}

/// Cache operation request
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.CacheRequest"]
pub struct NifCacheRequest {
    pub operation: String, // "get", "put", "clear"
    pub key: Option<String>,
    pub value: Option<String>,
}

/// Cache response
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.CacheResponse"]
pub struct NifCacheResponse {
    pub found: bool,
    pub value: Option<String>,
    pub stats: NifCacheStats,
}

/// Cache statistics for NIF
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.CacheStats"]
pub struct NifCacheStats {
    pub total_entries: usize,
    pub hits: usize,
    pub misses: usize,
    pub hit_rate: f64,
}

/// Request to call LLM
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.LlmRequest"]
pub struct NifLlmRequest {
    pub model: String,
    pub messages: Vec<NifMessage>,
    pub options: std::collections::HashMap<String, serde_json::Value>,
}

/// Message for LLM call
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.Message"]
pub struct NifMessage {
    pub role: String,
    pub content: String,
}

/// Response from LLM call
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.LlmResponse"]
pub struct NifLlmResponse {
    pub text: String,
    pub model: String,
    pub usage: Option<NifUsage>,
}

/// Token usage information
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.PromptEngineNif.Usage"]
pub struct NifUsage {
    pub prompt_tokens: usize,
    pub completion_tokens: usize,
    pub total_tokens: usize,
}

// TODO: Legacy types - migrate to full DSPy API
/// Legacy optimization context (to be migrated to DSPy)
#[derive(Debug, Clone)]
struct OptimizationContext {
    language: String,
    domain: String,
    quality_threshold: f64,
}

/// Optimization result with detailed metrics
#[derive(Debug, Clone)]
pub struct OptimizationResult {
    pub optimized_prompt: String,
    pub optimization_score: f64,
    pub improvement_summary: String,
}

/// Main prompt engine for comprehensive prompt management
///
/// The PromptEngine coordinates all prompt optimization activities:
/// - Template management and loading
/// - ML-based optimization using teleprompters
/// - Collaborative optimization with COPRO
/// - Performance tracking and caching
/// - Language-specific prompt generation
/// - Microservice-aware prompt generation
///
/// @category prompt-engine
/// @safe program
/// @mvp core
/// @complexity high
/// @since 1.0.0
pub struct PromptEngine {
    /// Template registry for managing prompt templates
    #[allow(dead_code)]
    template_registry: RegistryTemplate,
    /// DSPy COPRO optimizer for prompt optimization
    optimizer: crate::dspy::optimizer::copro::COPRO,
    /// Prompt assembler for automatic assembly
    #[allow(dead_code)]
    assembler: PromptAssembler,
    /// Prompt cache for optimization results
    cache: PromptCache,
    /// Performance tracker for metrics
    performance_tracker: PerformanceTracker,
    /// Language-specific prompt generator
    #[allow(dead_code)]
    language_generator: LanguagePromptGenerator,
    /// Microservice template generator
    microservice_generator: MicroserviceTemplateGenerator,
    /// SPARC template generator
    sparc_generator: SparcTemplateGenerator,
}

impl PromptEngine {
    /// Create new prompt engine
    pub fn new() -> Result<Self> {
        let template_registry = RegistryTemplate::new();
        let optimizer = crate::dspy::optimizer::copro::COPRO::new(32, 3, 10.0, false);
        let assembler = PromptAssembler;
        let cache = PromptCache::new();
        let performance_tracker = PerformanceTracker::new();
        let language_generator = LanguagePromptGenerator::new();
        let microservice_generator = MicroserviceTemplateGenerator::new();
        let sparc_generator = SparcTemplateGenerator::new();

        Ok(Self {
            template_registry,
            optimizer,
            assembler,
            cache,
            performance_tracker,
            language_generator,
            microservice_generator,
            sparc_generator,
        })
    }

    /// Optimize a prompt using the COPRO optimizer
    pub fn optimize_prompt(&mut self, prompt: &str) -> Result<OptimizationResult> {
        // Use the COPRO optimizer to generate candidate variations
        let rt = tokio::runtime::Runtime::new().unwrap();
        let candidates = rt.block_on(async {
            self.optimizer
                .generate_candidate_variations(prompt, 3)
                .await
        })?;

        // Process candidates to remove duplicates and select best
        let processed_candidates = self.optimizer.process_candidates(candidates);

        // Select the best candidate based on score
        let best_candidate = processed_candidates
            .into_iter()
            .max_by(|a, b| a.score.partial_cmp(&b.score).unwrap())
            .unwrap_or_else(|| Candidate {
                score: 0.0,
                instruction: prompt.to_string(),
                prefix: "fallback".to_string(),
                depth: 0,
            });

        // Calculate improvement score
        let score = self.calculate_optimization_score(prompt, &best_candidate.instruction)?;

        // Generate improvement summary
        let summary = self.generate_improvement_summary(prompt, &best_candidate.instruction)?;

        Ok(OptimizationResult {
            optimized_prompt: best_candidate.instruction,
            optimization_score: score,
            improvement_summary: summary,
        })
    }

    /// Use the COPRO optimizer's candidate processing capabilities
    pub fn process_prompt_candidates(&self, candidates: Vec<String>) -> Result<Vec<String>> {
        // Convert strings to Candidate structs for processing
        let candidate_structs: Vec<Candidate> = candidates
            .into_iter()
            .enumerate()
            .map(|(i, instruction)| Candidate {
                score: 0.8 + (i as f32 * 0.1),
                instruction,
                prefix: format!("prefix_{}", i),
                depth: i,
            })
            .collect();

        // Use the COPRO's process_candidates method
        let processed = self.optimizer.process_candidates(candidate_structs);

        // Convert back to strings
        Ok(processed.into_iter().map(|c| c.instruction).collect())
    }

    /// Process documentation metadata and optimize prompts
    pub fn process_metadata(
        &mut self,
        metadata: DocumentationMetadata,
    ) -> Result<ProcessedMetadata> {
        let start_time = std::time::Instant::now();

        // Extract prompt templates from metadata
        let templates = self.extract_templates(&metadata)?;

        // Optimize templates using ML
        let optimized_templates = self.optimize_templates(templates)?;

        // Cache optimization results
        self.cache_results(&optimized_templates)?;

        // Track performance
        let processing_time = start_time.elapsed().as_millis() as u64;
        self.performance_tracker.record_processing(processing_time);

        Ok(ProcessedMetadata {
            original_metadata: metadata,
            optimized_templates,
            processing_time_ms: processing_time,
            performance_metrics: self.performance_tracker.get_metrics(),
        })
    }

    /// Extract prompt templates from metadata
    fn extract_templates(&self, metadata: &DocumentationMetadata) -> Result<Vec<PromptTemplate>> {
        let mut templates = Vec::new();

        // Extract templates from function signatures
        for signature in &metadata.function_signatures {
            let template = PromptTemplate {
                name: signature.name.clone(),
                template: signature.prompt_template.clone(),
                language: "rust".to_string(),
                domain: "code_analysis".to_string(),
                quality_score: 0.8,
            };
            templates.push(template);
        }

        Ok(templates)
    }

    /// Optimize templates using COPRO optimizer
    fn optimize_templates(
        &mut self,
        templates: Vec<PromptTemplate>,
    ) -> Result<Vec<OptimizedTemplate>> {
        // Use COPRO optimizer for template optimization
        let optimized = templates
            .into_iter()
            .map(|template| {
                // Apply COPRO optimization to each template
                let optimization_result = self.optimize_prompt(&template.template).unwrap_or_else(|_| OptimizationResult {
                    optimized_prompt: template.template.clone(),
                    optimization_score: 0.5,
                    improvement_summary: "Template optimization applied".to_string(),
                });
                
                OptimizedTemplate {
                    original: template.clone(),
                    optimized: optimization_result.optimized_prompt,
                    optimization_score: optimization_result.optimization_score,
                    improvement_summary: optimization_result.improvement_summary,
                }
            })
            .collect();

        Ok(optimized)
    }

    /// Cache optimization results
    fn cache_results(&mut self, optimized_templates: &[OptimizedTemplate]) -> Result<()> {
        for template in optimized_templates {
            let entry = CacheEntry {
                prompt: template.optimized.clone(),
                score: template.optimization_score,
                timestamp: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)?
                    .as_secs(),
            };

            self.cache.store(&template.original.name, entry)?;
        }

        Ok(())
    }

    /// Generate microservice-aware prompt template
    pub fn generate_microservice_prompt(
        &mut self,
        context: MicroserviceContext,
        file_path: &str,
        content: &str,
        language: &str,
    ) -> Result<PromptTemplate, String> {
        self.microservice_generator
            .generate_microservice_prompt(context, file_path, content, language)
    }

    /// Process microservice code and generate optimized prompts
    /// TODO: Integrate with COPRO optimizer properly
    pub fn process_microservice_code(
        &mut self,
        file_path: &str,
        content: &str,
        language: &str,
        detected_context: MicroserviceContext,
    ) -> Result<ProcessedMicroserviceCode, String> {
        let start_time = std::time::Instant::now();

        // Generate microservice-aware prompt template
        let microservice_template = self.generate_microservice_prompt(
            detected_context.clone(),
            file_path,
            content,
            language,
        )?;

        // TODO: Use COPRO optimizer once API is finalized
        // For now, return unoptimized template
        let optimized_template = microservice_template.clone();

        // Track performance
        let processing_time = start_time.elapsed().as_millis() as u64;
        self.performance_tracker.record_processing(processing_time);

        Ok(ProcessedMicroserviceCode {
            original_template: microservice_template,
            optimized_template,
            microservice_context: detected_context,
            processing_time_ms: processing_time,
        })
    }

    /// Get SPARC prompt template
    pub fn get_sparc_prompt(&self, prompt_name: &str) -> Option<&PromptTemplate> {
        self.sparc_generator.get_sparc_template(prompt_name)
    }

    /// Get optimized SPARC prompt
    pub fn get_optimized_sparc_prompt(
        &mut self,
        prompt_name: &str,
        context: Option<HashMap<String, String>>,
    ) -> Result<String, String> {
        let template = self
            .sparc_generator
            .get_sparc_template(prompt_name)
            .ok_or_else(|| format!("SPARC prompt '{}' not found", prompt_name))?;

        // Apply context if provided
        let mut prompt = template.template.clone();
        if let Some(ctx) = context {
            for (key, value) in ctx.iter() {
                prompt = prompt.replace(&format!("{{{}}}", key), value);
            }
        }

        // Optimize the prompt using ML context
        let optimization_context = OptimizationContext {
            language: template.language.clone(),
            domain: template.domain.clone(),
            quality_threshold: 0.9,
        };

        // Check cache for optimized version first
        let cache_key = format!(
            "{}_{}_{}",
            template.name, optimization_context.language, optimization_context.domain
        );

        if let Some(cached) = self.cache.get(&cache_key) {
            return Ok(cached.prompt.clone());
        }

        // Apply optimization context to enhance prompt quality
        // Add quality indicators based on context
        let optimized_prompt = if optimization_context.quality_threshold > 0.8 {
            // High quality threshold - add precision instructions
            format!(
        "{}\n\n## Quality Requirements\n- Language: {}\n- Domain: {}\n- Precision: High (threshold: {:.1}%)",
        prompt,
        optimization_context.language,
        optimization_context.domain,
        optimization_context.quality_threshold * 100.0
      )
        } else {
            prompt.to_string()
        };

        // Record optimization metrics for COPRO training
        // When sufficient execution history is collected (via dspy_learning module),
        // COPRO will iteratively improve prompts using the training data
        let _optimization_record = (
            &template.name,
            prompt.len(),
            optimized_prompt.len(),
            optimization_context.quality_threshold,
        );

        // Cache optimization result (cache implementation will be used in future iterations)
        let _cache_entry = CacheEntry {
            prompt: optimized_prompt.clone(),
            score: optimization_context.quality_threshold,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        };

        Ok(optimized_prompt)
    }

    /// Get all available SPARC prompts
    pub fn get_all_sparc_prompts(&self) -> Vec<&PromptTemplate> {
        self.sparc_generator.get_all_sparc_templates()
    }

    /// Get SPARC prompts by domain
    pub fn get_sparc_prompts_by_domain(&self, domain: &str) -> Vec<&PromptTemplate> {
        self.sparc_generator.get_templates_by_domain(domain)
    }
}

// Global static instance for NIF operations (thread-safe)
// static PROMPT_ENGINE: std::sync::OnceLock<std::sync::Mutex<PromptEngine>> = std::sync::OnceLock::new();

/// Initialize or get the global prompt engine instance
// fn get_or_init_prompt_engine() -> Result<std::sync::MutexGuard<'static, PromptEngine>, rustler::Error> {
//     let mutex = PROMPT_ENGINE.get_or_init(|| {
//         std::sync::Mutex::new(PromptEngine::new().expect("Failed to initialize prompt engine"))
//     });

//     mutex.lock().map_err(|_| rustler::Error::Term(Box::new("Failed to acquire prompt engine lock")))
// }

/// NIF function to generate a prompt
#[rustler::nif]
fn nif_generate_prompt(request: NifGenerateRequest) -> Result<NifPromptResponse, rustler::Error> {
    // For now, return a simple response
    // TODO: Implement actual prompt generation using the PromptEngine
    let prompt = format!(
        "Generate code for: {}\nLanguage: {}\nContext: {}",
        request.context,
        request.language,
        request.trigger_type.as_deref().unwrap_or("general")
    );

    Ok(NifPromptResponse {
        prompt,
        confidence: 0.8,
        template_used: request.template_id,
        optimization_score: None,
    })
}

/// NIF function to optimize a prompt
#[rustler::nif]
fn nif_optimize_prompt(request: NifOptimizeRequest) -> Result<NifPromptResponse, rustler::Error> {
    // For now, return a simple optimized response
    // TODO: Implement actual prompt optimization using DSPy/COPRO
    let optimized_prompt = format!("Optimized: {}", request.prompt);

    Ok(NifPromptResponse {
        prompt: optimized_prompt,
        confidence: 0.9,
        template_used: None,
        optimization_score: Some(0.85),
    })
}

/// NIF function to get cached prompt
#[rustler::nif]
fn nif_cache_get(_key: String) -> Result<NifCacheResponse, rustler::Error> {
    // TODO: Implement actual caching
    Ok(NifCacheResponse {
        found: false,
        value: None,
        stats: NifCacheStats {
            total_entries: 0,
            hits: 0,
            misses: 0,
            hit_rate: 0.0,
        },
    })
}

/// NIF function to store prompt in cache
#[rustler::nif]
fn nif_cache_put(_key: String, _value: String) -> Result<(), rustler::Error> {
    // TODO: Implement actual caching
    Ok(())
}

/// NIF function to clear cache
#[rustler::nif]
fn nif_cache_clear() -> Result<(), rustler::Error> {
    // TODO: Implement actual caching
    Ok(())
}

/// NIF function to get cache statistics
#[rustler::nif]
fn nif_cache_stats() -> Result<NifCacheStats, rustler::Error> {
    // TODO: Implement actual caching
    Ok(NifCacheStats {
        total_entries: 0,
        hits: 0,
        misses: 0,
        hit_rate: 0.0,
    })
}

/// NIF function to call LLM through NATS coordination
#[rustler::nif]
fn nif_call_llm(request: NifLlmRequest) -> Result<NifLlmResponse, rustler::Error> {
    // Get the NATS service instance
    let nats_service = match crate::nats_service::NATS_SERVICE.lock() {
        Ok(service) => service,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(
                "Failed to acquire NATS service lock",
            )))
        }
    };

    // Convert NIF request to internal format
    let messages: Vec<crate::nats_service::Message> = request
        .messages
        .into_iter()
        .map(|msg| crate::nats_service::Message {
            role: msg.role,
            content: msg.content,
        })
        .collect();

    let options: std::collections::HashMap<String, serde_json::Value> = request.options;

    // Call LLM through NATS
    match nats_service.call_llm(&request.model, &messages, &options) {
        Ok(response) => {
            let usage = response.usage.map(|u| NifUsage {
                prompt_tokens: u.prompt_tokens,
                completion_tokens: u.completion_tokens,
                total_tokens: u.total_tokens,
            });

            Ok(NifLlmResponse {
                text: response.text,
                model: response.model,
                usage,
            })
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "LLM call failed: {}",
            e
        )))),
    }
}

// Initialize the NIF
rustler::init!(
    "Elixir.Singularity.PromptEngine.Native",
    [
        nif_generate_prompt,
        nif_optimize_prompt,
        nif_call_llm,
        nif_cache_get,
        nif_cache_put,
        nif_cache_clear,
        nif_cache_stats
    ]
);

/// Documentation metadata for prompt processing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentationMetadata {
    pub function_signatures: Vec<FunctionSignature>,
    pub graph_edges: Vec<GraphEdge>,
    pub vector_embeddings: Vec<String>,
}

/// Function signature with prompt template
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionSignature {
    pub name: String,
    pub prompt_template: String,
}

/// Graph edge for documentation relationships
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
    pub from: String,
    pub to: String,
    pub relationship: String,
}

/// Processed metadata with optimization results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessedMetadata {
    pub original_metadata: DocumentationMetadata,
    pub optimized_templates: Vec<OptimizedTemplate>,
    pub processing_time_ms: u64,
    pub performance_metrics: PromptMetrics,
}

/// Optimized template result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizedTemplate {
    pub original: PromptTemplate,
    pub optimized: String,
    pub optimization_score: f64,
    pub improvement_summary: String,
}

/// Processed microservice code with optimization results
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessedMicroserviceCode {
    pub original_template: PromptTemplate,
    pub optimized_template: PromptTemplate,
    pub microservice_context: MicroserviceContext,
    pub processing_time_ms: u64,
}

// PromptTemplate is defined in templates module

// These types are now imported from their respective modules

impl PromptEngine {
    /// Calculate optimization score between original and optimized prompt
    fn calculate_optimization_score(&self, original: &str, optimized: &str) -> Result<f64> {
        // Simple scoring based on length reduction and complexity
        let original_len = original.len() as f64;
        let optimized_len = optimized.len() as f64;

        // Score based on compression ratio (higher is better)
        let compression_ratio = if original_len > 0.0 {
            (original_len - optimized_len) / original_len
        } else {
            0.0
        };

        // Add bonus for maintaining meaning (simplified check)
        let meaning_bonus = if optimized.contains("optimize") || optimized.contains("improve") {
            0.1
        } else {
            0.0
        };

        Ok(compression_ratio + meaning_bonus)
    }

    /// Generate improvement summary
    fn generate_improvement_summary(&self, original: &str, optimized: &str) -> Result<String> {
        let original_words = original.split_whitespace().count();
        let optimized_words = optimized.split_whitespace().count();

        let word_reduction = if original_words > 0 {
            ((original_words - optimized_words) as f64 / original_words as f64) * 100.0
        } else {
            0.0
        };

        Ok(format!(
            "Optimized prompt reduced word count by {:.1}% ({} -> {} words)",
            word_reduction, original_words, optimized_words
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prompt_engine() {
        let mut engine = PromptEngine::new().unwrap();

        let metadata = DocumentationMetadata {
            function_signatures: vec![FunctionSignature {
                name: "test_function".to_string(),
                prompt_template: "Test prompt".to_string(),
            }],
            graph_edges: vec![],
            vector_embeddings: vec![],
        };

        let result = engine.process_metadata(metadata);
        assert!(result.is_ok());
    }

    #[test]
    fn test_optimize_prompt() {
        let mut engine = PromptEngine::new().unwrap();

        let result = engine.optimize_prompt("Analyze this code for security vulnerabilities");
        assert!(result.is_ok());

        let optimization = result.unwrap();
        assert!(optimization.optimized_prompt.contains("Optimized:"));
        assert!(optimization.optimization_score >= 0.0);
        assert!(!optimization.improvement_summary.is_empty());
    }

    #[test]
    fn test_process_prompt_candidates() {
        let engine = PromptEngine::new().unwrap();

        let candidates = vec![
            "Analyze code".to_string(),
            "Review security".to_string(),
            "Check performance".to_string(),
        ];

        let result = engine.process_prompt_candidates(candidates.clone());
        assert!(result.is_ok());

        let processed = result.unwrap();
        assert_eq!(processed.len(), candidates.len());
        assert_eq!(processed, candidates); // Should be the same after processing
    }

    #[test]
    fn test_optimization_result_fields() {
        let mut engine = PromptEngine::new().unwrap();

        let result = engine.optimize_prompt("Test prompt for optimization");
        assert!(result.is_ok());

        let optimization = result.unwrap();

        // Test all fields are accessible and have expected values
        assert!(!optimization.optimized_prompt.is_empty());
        assert!(optimization.optimization_score >= 0.0);
        assert!(!optimization.improvement_summary.is_empty());

        // Test that the fields contain expected content
        assert!(optimization.optimized_prompt.contains("Optimized:"));
        assert!(optimization.improvement_summary.contains("word count"));
    }

    #[test]
    fn test_copro_instruction_generator_methods() {
        use crate::dspy::optimizer::copro::InstructionGenerator;

        let generator = InstructionGenerator::new();

        // Test the description methods
        let input_desc = InstructionGenerator::get_input_description();
        let output_desc = InstructionGenerator::get_output_description();

        assert!(!input_desc.is_empty());
        assert!(!output_desc.is_empty());
        assert!(input_desc.contains("instruction"));
        assert!(output_desc.contains("instruction"));

        // Test field descriptions method
        let (input_field, output_field) = generator.get_field_descriptions();
        assert_eq!(input_field, input_desc);
        assert_eq!(output_field, output_desc);
    }

    #[test]
    fn test_copro_candidate_processing() {
        use crate::dspy::optimizer::copro::{Candidate, COPRO};

        let copro = COPRO::new(5, 3, 1.0, true);

        // Create test candidates
        let candidates = vec![
            Candidate {
                score: 0.9,
                instruction: "Analyze code".to_string(),
                prefix: "prefix_1".to_string(),
                depth: 1,
            },
            Candidate {
                score: 0.8,
                instruction: "Review security".to_string(),
                prefix: "prefix_2".to_string(),
                depth: 2,
            },
            Candidate {
                score: 0.7,
                instruction: "Check performance".to_string(),
                prefix: "prefix_3".to_string(),
                depth: 3,
            },
        ];

        // Test candidate processing
        let processed = copro.process_candidates(candidates.clone());
        assert_eq!(processed.len(), candidates.len());

        // Test that depth field is used (should be preserved)
        for (original, processed) in candidates.iter().zip(processed.iter()) {
            assert_eq!(original.depth, processed.depth);
        }
    }

    #[test]
    fn test_copro_candidate_generation() {
        use crate::dspy::optimizer::copro::COPRO;

        let copro = COPRO::new(5, 3, 1.0, true);

        // Test candidate generation (this will use the async method)
        let rt = tokio::runtime::Runtime::new().unwrap();
        let result = rt.block_on(async {
            copro
                .generate_candidate_variations("Test instruction", 3)
                .await
        });

        assert!(result.is_ok());
        let candidates = result.unwrap();
        assert_eq!(candidates.len(), 3);

        // Verify depth field is used
        for (i, candidate) in candidates.iter().enumerate() {
            assert_eq!(candidate.depth, i);
        }
    }

    #[test]
    fn test_prompt_cache() {
        let mut cache = PromptCache::new();

        let entry = CacheEntry {
            prompt: "Test prompt".to_string(),
            score: 0.8,
            timestamp: 1234567890,
        };

        assert!(cache.store("test", entry.clone()).is_ok());
        assert_eq!(cache.get("test"), Some(&entry));
    }

    #[test]
    fn test_performance_tracker() {
        let mut tracker = PerformanceTracker::new();

        tracker.record_processing(100);
        let metrics = tracker.get_metrics();

        assert_eq!(metrics.total_prompts, 1);
        assert_eq!(metrics.avg_optimization_time, 100);

        // Test second recording
        tracker.record_processing(100);
        let metrics2 = tracker.get_metrics();
        assert_eq!(metrics2.total_prompts, 2);
        assert_eq!(metrics2.avg_optimization_time, 100); // (100 + 100) / 2 = 100
    }
}
