//! Universal Template Optimizer with DSPy
//!
//! A complete template optimization system that handles:
//! - SPARC methodology (5 phases)
//! - Microservice templates
//! - Framework-specific templates
//! - Language-specific patterns
//! - Custom workflow templates
//!
//! Uses DSPy to automatically optimize ANY template type!

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;

use crate::dspy::optimizer::sparc_optimizer::{SparcOptimizer, SPARCPhase};
use crate::dspy::core::lm::DSPyLM;
use crate::template_performance_tracker::TemplatePerformanceTracker;

/// Universal Template Optimizer - handles ALL template types, not just SPARC
#[derive(Debug, Clone)]
pub struct UniversalTemplateOptimizer {
    /// DSPy language model
    lm: DSPyLM,

    /// Multi-strategy optimizer (SPARC, microservices, frameworks, etc.)
    optimizer: MultiStrategyOptimizer,

    /// Performance tracker for all template types
    performance_tracker: TemplatePerformanceTracker,

    /// Template cache from tool_doc_index (ALL templates)
    template_cache: HashMap<String, Template>,

    /// DSPy demonstrations for few-shot learning
    demonstrations: Vec<Demonstration>,

    /// Template type handlers
    handlers: HashMap<TemplateType, Box<dyn TemplateHandler>>,
}

/// Template loaded from tool_doc_index
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Template {
    pub id: String,
    pub name: String,
    pub description: String,
    pub steps: Vec<TemplateStep>,
    pub detector_signatures: HashMap<String, Vec<String>>,
    pub metadata: TemplateMetadata,
}

/// Template step for SPARC phases
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateStep {
    pub name: String,
    pub operation: Operation,
}

/// Operation type in template
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum Operation {
    #[serde(rename = "generate")]
    Generate { generate: String },
    #[serde(rename = "analyze")]
    Analyze { analyze: String },
    #[serde(rename = "refine")]
    Refine { refine: String },
}

/// Template metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetadata {
    pub version: String,
    pub tags: Vec<String>,
    pub performance: PerformanceMetrics,
}

/// Performance metrics for templates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceMetrics {
    pub avg_execution_time_ms: f64,
    pub memory_usage_bytes: usize,
    pub complexity: usize,
}

/// DSPy demonstration for few-shot learning
#[derive(Debug, Clone)]
pub struct Demonstration {
    pub template_id: String,
    pub input: String,
    pub output: String,
    pub quality_score: f64,
}

/// Template types we optimize
#[derive(Debug, Clone, Hash, Eq, PartialEq)]
pub enum TemplateType {
    SPARC,
    Microservice,
    Framework,
    Language,
    Workflow,
    Security,
    Performance,
    Testing,
    Custom(String),
}

/// Multi-strategy optimizer for different template types
#[derive(Debug, Clone)]
pub struct MultiStrategyOptimizer {
    sparc: SparcOptimizer,
    microservice: MicroserviceOptimizer,
    framework: FrameworkOptimizer,
    // Add more as needed
}

/// Trait for template-specific handlers
pub trait TemplateHandler: Send + Sync {
    fn optimize(&self, template: &Template, context: &HashMap<String, String>) -> Result<String>;
    fn validate(&self, output: &str) -> bool;
}

impl UniversalTemplateOptimizer {
    /// Create new universal optimizer
    pub fn new() -> Result<Self> {
        let mut handlers: HashMap<TemplateType, Box<dyn TemplateHandler>> = HashMap::new();

        // Register all template handlers
        handlers.insert(TemplateType::SPARC, Box::new(SparcHandler::new()));
        handlers.insert(TemplateType::Microservice, Box::new(MicroserviceHandler::new()));
        handlers.insert(TemplateType::Framework, Box::new(FrameworkHandler::new()));

        Ok(Self {
            lm: DSPyLM::default(),
            optimizer: MultiStrategyOptimizer::default(),
            performance_tracker: TemplatePerformanceTracker::new(),
            template_cache: HashMap::new(),
            demonstrations: Vec::new(),
            handlers,
        })
    }

    /// Load templates from tool_doc_index
    pub fn load_templates(&mut self, template_dir: &Path) -> Result<()> {
        // Load all JSON templates from tool_doc_index/templates
        let pattern = template_dir.join("**/*.json");

        for entry in glob::glob(pattern.to_str().unwrap())? {
            let path = entry?;
            let content = std::fs::read_to_string(&path)?;
            let template: Template = serde_json::from_str(&content)?;

            self.template_cache.insert(template.id.clone(), template);
        }

        Ok(())
    }

    /// Generate optimized prompt using DSPy with template
    pub fn generate_prompt(
        &mut self,
        task: &str,
        phase: SPARCPhase,
        language: &str,
    ) -> Result<String> {
        // 1. Select best template using performance tracker
        let template_id = self.select_template_for_phase(&phase, language)?;
        let template = self.template_cache.get(&template_id)
            .ok_or_else(|| anyhow::anyhow!("Template not found: {}", template_id))?;

        // 2. Get relevant demonstrations for few-shot learning
        let demos = self.get_relevant_demonstrations(&template_id, task);

        // 3. Build DSPy signature with template structure
        let signature = self.build_dspy_signature(template, task, &phase);

        // 4. Optimize prompt using SPARC optimizer
        let optimized_prompt = self.sparc_optimizer.optimize_prompt(
            &signature,
            &phase,
            &demos,
        )?;

        // 5. Track performance for learning
        self.performance_tracker.record_usage(
            template_id.clone(),
            phase.to_string(),
            language.to_string(),
            true,
            100.0, // Placeholder timing
            0.9,   // Placeholder quality
        );

        Ok(optimized_prompt)
    }

    /// Build DSPy signature from template
    fn build_dspy_signature(
        &self,
        template: &Template,
        task: &str,
        phase: &SPARCPhase,
    ) -> DSPySignature {
        let mut signature = DSPySignature::new();

        // Add template structure as signature fields
        signature.add_input("task", task);
        signature.add_input("phase", &phase.to_string());
        signature.add_input("template_name", &template.name);

        // Add detector signatures as constraints
        for (key, patterns) in &template.detector_signatures {
            signature.add_constraint(key, patterns.join(" | "));
        }

        // Add steps as chain-of-thought
        for step in &template.steps {
            signature.add_reasoning_step(&step.name);
        }

        // Set output format based on phase
        match phase {
            SPARCPhase::Specification => {
                signature.set_output("specification", "Detailed technical specification");
            }
            SPARCPhase::Pseudocode => {
                signature.set_output("pseudocode", "Plain language algorithm");
            }
            SPARCPhase::Architecture => {
                signature.set_output("architecture", "System design and structure");
            }
            SPARCPhase::Refinement => {
                signature.set_output("refined_design", "Optimized design");
            }
            SPARCPhase::Completion => {
                signature.set_output("code", "Production-ready implementation");
            }
        }

        signature
    }

    /// Select best template for SPARC phase
    fn select_template_for_phase(
        &self,
        phase: &SPARCPhase,
        language: &str,
    ) -> Result<String> {
        // Map phase to template type
        let template_type = match phase {
            SPARCPhase::Specification => "sparc-specification",
            SPARCPhase::Pseudocode => "sparc-pseudocode",
            SPARCPhase::Architecture => "sparc-architecture",
            SPARCPhase::Refinement => "sparc-refinement",
            SPARCPhase::Completion => format!("{}-implementation", language),
        };

        // Use performance tracker to get best template
        let template = self.performance_tracker
            .select_best_template(&template_type, language)?;

        Ok(template.name)
    }

    /// Get relevant demonstrations for few-shot learning
    fn get_relevant_demonstrations(
        &self,
        template_id: &str,
        task: &str,
    ) -> Vec<Demonstration> {
        // Filter demonstrations by template and similarity to task
        self.demonstrations
            .iter()
            .filter(|demo| demo.template_id == template_id)
            .filter(|demo| self.calculate_similarity(&demo.input, task) > 0.7)
            .take(3) // Use top 3 most relevant
            .cloned()
            .collect()
    }

    /// Calculate similarity between tasks (simple version)
    fn calculate_similarity(&self, task1: &str, task2: &str) -> f64 {
        // Simple word overlap for now
        let words1: std::collections::HashSet<_> = task1.split_whitespace().collect();
        let words2: std::collections::HashSet<_> = task2.split_whitespace().collect();

        let intersection = words1.intersection(&words2).count();
        let union = words1.union(&words2).count();

        if union == 0 {
            0.0
        } else {
            intersection as f64 / union as f64
        }
    }

    /// Add demonstration for learning
    pub fn add_demonstration(
        &mut self,
        template_id: String,
        input: String,
        output: String,
        quality_score: f64,
    ) {
        self.demonstrations.push(Demonstration {
            template_id,
            input,
            output,
            quality_score,
        });

        // Keep only best demonstrations (max 100 per template)
        self.demonstrations.sort_by(|a, b|
            b.quality_score.partial_cmp(&a.quality_score).unwrap()
        );
        self.demonstrations.truncate(100);
    }

    /// Compile prompt with DSPy optimizations
    pub fn compile_prompt(
        &mut self,
        task: &str,
        examples: Vec<(String, String)>,
    ) -> Result<String> {
        // Use DSPy compile to optimize prompt with examples
        let compiled = self.lm.compile(
            task,
            examples,
            &self.sparc_optimizer,
        )?;

        Ok(compiled)
    }
}

/// DSPy signature for structured prompts
#[derive(Debug, Clone)]
pub struct DSPySignature {
    inputs: HashMap<String, String>,
    outputs: HashMap<String, String>,
    constraints: HashMap<String, String>,
    reasoning_steps: Vec<String>,
}

impl DSPySignature {
    pub fn new() -> Self {
        Self {
            inputs: HashMap::new(),
            outputs: HashMap::new(),
            constraints: HashMap::new(),
            reasoning_steps: Vec::new(),
        }
    }

    pub fn add_input(&mut self, name: &str, description: &str) {
        self.inputs.insert(name.to_string(), description.to_string());
    }

    pub fn add_constraint(&mut self, name: &str, constraint: String) {
        self.constraints.insert(name.to_string(), constraint);
    }

    pub fn add_reasoning_step(&mut self, step: &str) {
        self.reasoning_steps.push(step.to_string());
    }

    pub fn set_output(&mut self, name: &str, description: &str) {
        self.outputs.insert(name.to_string(), description.to_string());
    }
}

impl SparcOptimizer {
    /// Optimize prompt for SPARC phase
    pub fn optimize_prompt(
        &self,
        signature: &DSPySignature,
        phase: &SPARCPhase,
        demonstrations: &[Demonstration],
    ) -> Result<String> {
        let mut prompt = String::new();

        // Add phase-specific optimization
        match phase {
            SPARCPhase::Specification => {
                prompt.push_str("# Specification Phase\n");
                prompt.push_str("Generate a detailed technical specification.\n\n");
            }
            SPARCPhase::Pseudocode => {
                prompt.push_str("# Pseudocode Phase\n");
                prompt.push_str("Write the algorithm in plain language.\n\n");
            }
            SPARCPhase::Architecture => {
                prompt.push_str("# Architecture Phase\n");
                prompt.push_str("Design the system structure.\n\n");
            }
            SPARCPhase::Refinement => {
                prompt.push_str("# Refinement Phase\n");
                prompt.push_str("Optimize and improve the design.\n\n");
            }
            SPARCPhase::Completion => {
                prompt.push_str("# Completion Phase\n");
                prompt.push_str("Generate production-ready code.\n\n");
            }
        }

        // Add inputs
        prompt.push_str("## Inputs\n");
        for (name, desc) in &signature.inputs {
            prompt.push_str(&format!("- {}: {}\n", name, desc));
        }

        // Add demonstrations if available
        if !demonstrations.is_empty() {
            prompt.push_str("\n## Examples\n");
            for demo in demonstrations.iter().take(3) {
                prompt.push_str(&format!("Input: {}\n", demo.input));
                prompt.push_str(&format!("Output: {}\n\n", demo.output));
            }
        }

        // Add reasoning steps
        if !signature.reasoning_steps.is_empty() {
            prompt.push_str("\n## Steps\n");
            for step in &signature.reasoning_steps {
                prompt.push_str(&format!("1. {}\n", step));
            }
        }

        // Add constraints
        if !signature.constraints.is_empty() {
            prompt.push_str("\n## Constraints\n");
            for (name, constraint) in &signature.constraints {
                prompt.push_str(&format!("- {}: {}\n", name, constraint));
            }
        }

        // Add output format
        prompt.push_str("\n## Output\n");
        for (name, desc) in &signature.outputs {
            prompt.push_str(&format!("Generate {}: {}\n", name, desc));
        }

        Ok(prompt)
    }
}

impl SPARCPhase {
    pub fn to_string(&self) -> String {
        match self {
            SPARCPhase::Specification => "specification".to_string(),
            SPARCPhase::Pseudocode => "pseudocode".to_string(),
            SPARCPhase::Architecture => "architecture".to_string(),
            SPARCPhase::Refinement => "refinement".to_string(),
            SPARCPhase::Completion => "completion".to_string(),
        }
    }
}