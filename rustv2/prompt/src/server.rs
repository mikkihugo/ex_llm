//! DSPy Prompt Server
//! Central coordination, distributed learning, and template registry

// Modules are declared at the crate root level
// Re-export key types from the crate root
pub use crate::service::CentralDspyService;
pub use crate::global_optimizer::GlobalOptimizer;
pub use crate::template_registry::TemplateRegistry;