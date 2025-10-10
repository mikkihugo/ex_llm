//! DSPy Prompt Engine
//! Local prompt optimization, template loading, and quality gates

// Modules are declared at the crate root level
// Re-export key types from the crate root
pub use crate::template_loader::TemplateLoader;
pub use crate::quality_gates::{QualityGateResult, QualityGateStatus};
pub use crate::linting_engine::LintingEngine;