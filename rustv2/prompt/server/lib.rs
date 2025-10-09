//! DSPy Prompt Server
//! Central coordination, distributed learning, and template registry

pub mod service;
pub mod global_optimizer;
pub mod template_registry;

// Re-export shared data types from engine
pub use engine::dspy_data::*;

// Re-export key types
pub use service::CentralDspyService;
pub use global_optimizer::GlobalOptimizer;
pub use template_registry::TemplateRegistry;