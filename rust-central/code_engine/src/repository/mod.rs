//! Repository Analysis Module
//!
//! Provides comprehensive repository structure analysis including:
//! - Workspace detection (monorepo vs single repo)
//! - Build system identification (Moon, Nx, Cargo, etc.)
//! - Package discovery and classification
//! - Tech stack detection
//! - Infrastructure discovery (NATS, Kafka, databases, etc.)
//! - Domain inference
//! - Architecture pattern detection

pub mod analyzer;
pub mod architecture;
pub mod domain_boundaries;
pub mod infrastructure;
pub mod packages;
pub mod techstack;
pub mod types;
pub mod workspace;

// Re-export main types
pub use analyzer::RepoAnalyzer;
pub use architecture::ArchitectureAnalyzer;
pub use domain_boundaries::DomainBoundaryAnalyzer;
pub use infrastructure::InfrastructureAnalyzer;
pub use packages::{Package, PackageDiscovery};
pub use techstack::TechStackAnalyzer;
pub use types::*;
pub use workspace::{BuildSystem, PackageManager, WorkspaceDetector, WorkspaceType};
