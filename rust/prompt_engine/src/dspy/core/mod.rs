//! # DSPy Core: Fundamental Abstractions and Components
//!
//! This module serves as the central hub for the core abstractions and fundamental components
//! of the DSPy framework. It re-exports key modules that define how DSPy interacts with
//! language models, structures AI tasks, and manages settings.
//!
//! The modules re-exported here form the backbone of DSPy's declarative approach to LLM programming,
//! enabling the definition of AI model signatures, the creation of optimizable modules, and the
//! management of language model settings.
//!
//! @category dspy-core
//! @safe program
//! @mvp core
//! @complexity low
//! @since 1.0.0

pub mod lm;
pub mod module;
pub mod settings;
pub mod signature;

pub use lm::*;
pub use module::*;
pub use settings::*;
pub use signature::*;
