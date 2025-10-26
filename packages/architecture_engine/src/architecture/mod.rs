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

use serde::{Deserialize, Serialize};

/// Architectural suggestion request
#[derive(Debug, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ArchitecturalSuggestionRequest"]
pub struct ArchitecturalSuggestionRequest {
    pub patterns: Vec<String>,
    pub context: String,
    pub suggestion_types: Vec<String>,
    pub confidence_threshold: f64,
}

/// Architectural suggestion result
#[derive(Debug, Serialize, Deserialize, rustler::NifStruct)]
#[module = "ArchitecturalSuggestion"]
pub struct ArchitecturalSuggestion {
    pub name: String,
    pub description: String,
    pub confidence: f64,
    pub suggested_by: String,
    pub evidence: Vec<String>,
    pub pattern_id: Option<String>,
}
