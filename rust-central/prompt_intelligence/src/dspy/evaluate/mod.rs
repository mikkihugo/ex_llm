//! # DSPy Evaluate: Core Evaluation Components
//!
//! This module serves as the entry point for DSPy's evaluation components.
//! It re-exports the `evaluator` module, which defines the traits and functionalities
//! for assessing the performance and quality of DSPy modules and predictions.
//!
//! Evaluation is a critical part of the DSPy optimization loop, providing feedback
//! that drives the self-improvement process of AI models.
//!
//! @category dspy-evaluate
//! @safe program
//! @mvp core
//! @complexity low
//! @since 1.0.0

pub mod evaluator;

pub use evaluator::*;
