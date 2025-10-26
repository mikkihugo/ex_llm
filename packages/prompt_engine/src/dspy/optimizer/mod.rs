//! # DSPy Optimizer: Core Optimization Components
//!
//! This module defines the core components for optimizing DSPy modules. It re-exports
//! specific optimizers, such as `copro`, and defines the fundamental `Optimizer` trait.
//!
//! The `Optimizer` trait provides a standardized interface for compiling and improving
//! DSPy modules based on a given training set. This is where the self-improving aspect
//! of DSPy comes into play, as optimizers iteratively refine module behavior to enhance
//! performance and quality.
//!
//! @category dspy-optimizer
//! @safe program
//! @mvp core
//! @complexity medium
//! @since 1.0.0

pub mod copro;
pub mod dynamic_templates;
pub mod sparc_coordinator;
pub mod sparc_optimizer;

use anyhow::Result;
pub use copro::*;
pub use dynamic_templates::*;
pub use sparc_coordinator::*;
pub use sparc_optimizer::*;

use crate::{
    dspy::{
        core::{Module, Optimizable},
        evaluate::Evaluator,
    },
    dspy_data::{Example, Prediction},
};

/// Modern DSPy Optimizer trait matching real framework capabilities
///
/// Real DSPy optimizers like MIPROv2, BootstrapFinetune, and COPRO provide:
/// - Multi-stage optimization (bootstrapping, proposal, search)
/// - Metric-based evaluation and selection
/// - State serialization and resumption
/// - Composable optimizer chains (BetterTogether pattern)
/// - Automatic instruction and demonstration generation
///
/// @category dspy-trait
/// @safe program
/// @mvp core
/// @complexity high
/// @since 2.0.0
pub trait Teleprompter: Send + Sync {
    /// Compile and optimize a DSPy program (matches real DSPy API)
    fn compile<M>(
        &mut self,
        program: M,
        trainset: Vec<Example>,
    ) -> impl std::future::Future<Output = Result<M>> + Send
    where
        M: Module + Clone;

    /// Get optimizer name for logging and state management
    fn name(&self) -> &str;

    /// Serialize optimizer state for resumption
    fn dump_state(&self) -> Result<serde_json::Value>;

    /// Load optimizer state from previous session
    fn load_state(&mut self, state: serde_json::Value) -> Result<()>;
}

/// Legacy optimizer trait for backwards compatibility
#[allow(async_fn_in_trait)]
pub trait Optimizer {
    async fn compile<M>(&self, module: &mut M, trainset: Vec<Example>) -> Result<()>
    where
        M: Module + Optimizable + Evaluator;
}

/// Metric function type for evaluating program performance
pub type MetricFn = Box<dyn Fn(&Example, &Prediction) -> f64 + Send + Sync>;

/// Optimization configuration matching real DSPy patterns
#[derive(Debug, Clone)]
pub struct OptimizationConfig {
    pub max_bootstrapped_demos: usize,
    pub max_labeled_demos: usize,
    pub num_candidate_programs: usize,
    pub num_threads: usize,
    pub minibatch_size: usize,
    pub minibatch_full_eval_steps: usize,
    pub auto_mode: String, // "light", "medium", "heavy"
}

impl Default for OptimizationConfig {
    fn default() -> Self {
        Self {
            max_bootstrapped_demos: 4,
            max_labeled_demos: 4,
            num_candidate_programs: 10,
            num_threads: 4,
            minibatch_size: 40,
            minibatch_full_eval_steps: 4,
            auto_mode: "medium".to_string(),
        }
    }
}
