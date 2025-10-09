//! Architecture Analysis Module
//!
//! Analyzes architectural patterns, design principles, and code organization.
//! Integrates with fact-system for architectural knowledge and patterns.

pub mod detector;
pub mod patterns;
pub mod principles;

// Specific re-exports to avoid conflicts
pub use detector::{
    ArchitecturalPatternType, ArchitectureAnalysis, ArchitectureAnalysisPattern,
    ArchitectureMetadata, ArchitectureRecommendation, ArchitectureViolation, DesignPrinciple,
    PatternLocation,
};

pub use patterns::{ArchitecturalPatternAnalysis, PatternComponent, PatternRelationship};

pub use principles::*;
