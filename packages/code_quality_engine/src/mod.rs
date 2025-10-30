//! Codebase Analysis Systems
//!
//! This module provides comprehensive codebase analysis capabilities including
//! code graph construction, semantic analysis, DAG-based relationship modeling,
//! quality analysis, metrics collection, pattern detection, and intelligent naming.
//!
//! # AI Coder Benefits
//!
//! - **Code Graph**: Understands code structure and dependencies
//! - **Semantic Analysis**: Provides semantic understanding of code
//! - **DAG Relationships**: Models file relationships and dependencies
//! - **Quality Analysis**: Analyzes code quality and complexity
//! - **Metrics Collection**: Collects comprehensive code metrics
//! - **CodePattern Detection**: Detects patterns and anti-patterns
//! - **Intelligent Naming**: Uses all systems for better naming suggestions
//! - **Learning System**: Learns from user feedback and corrections
//!
//! # Organization
//!
//! - **graph/**: Code graph construction and analysis
//! - **semantic/**: Semantic analysis and vector embeddings
//! - **dag/**: Directed Acyclic Graph for file relationships
//! - **quality/**: Code quality analysis and scoring
//! - **metrics/**: Code metrics and statistics collection
//! - **performance/**: Performance analysis and monitoring
//! - **refactoring/**: Refactoring analysis and suggestions
//! - **patterns/**: CodePattern and anti-pattern detection
//! - **evolution/**: Code evolution and history tracking
//! - **multilang/**: Cross-language analysis
//! - **architecture/**: Architectural pattern analysis
//! - **orchestrators/**: Analysis orchestration and coordination
//! - **infrastructure/**: Infrastructure pattern detection
//! - **registry/**: Meta registry and package knowledge
//! - **naming/**: Intelligent naming system with learning capabilities

pub mod types;
pub mod graph;
pub mod semantic;
pub mod dag;
pub mod quality;
pub mod metrics;
pub mod performance;
pub mod refactoring;
pub mod patterns;
pub mod evolution;
pub mod multilang;
pub mod architecture;
pub mod orchestrators;
pub mod infrastructure;
pub mod registry;
pub mod naming;

// Re-export main types for easy access
pub use types::*;
pub use graph::*;
pub use semantic::*;
pub use dag::*;
pub use quality::*;
pub use metrics::*;
pub use performance::*;
pub use refactoring::*;
pub use patterns::*;
pub use evolution::*;
pub use multilang::*;
pub use architecture::*;
pub use orchestrators::*;
pub use infrastructure::*;
pub use registry::*;
pub use naming::*;