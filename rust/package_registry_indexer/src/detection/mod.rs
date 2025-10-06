//! Framework and Technology Detection Module
//!
//! Unified detection system with layered approach:
//! - Level 1: File/Config detection (instant, free)
//! - Level 2: Pattern matching (fast, cheap)
//! - Level 3: AST analysis (medium, moderate)
//! - Level 4: Fact validation (medium, moderate)
//! - Level 5: LLM analysis (slow, expensive, only when needed)
//!
//! All detection driven by JSON templates in templates/ directory.
//! Results stored in fact system and Postgres.

pub mod fact_storage;
pub mod file_detector;
pub mod npm_detector;
pub mod storage;
pub mod types;
pub mod layered_detector;

// Re-export specialized detectors (keep for specific use cases)
pub use file_detector::FileDetector;
pub use npm_detector::NpmDetector;
pub use storage::{TechnologyCache, TechnologyStorage};
pub use types::{
  DetectionMethod, DetectionMetrics, DetectionResult, EnhancedDetectionResult,
  FrameworkDetectionError, FrameworkInfo, FrameworkRecommendations,
  FrameworkSignature, LLMProvider, ToolchainLlmInterface,
};

// Primary detector - LayeredDetector
pub use layered_detector::{
  LayeredDetector, LayeredDetectionResult, DetectionLevel,
  DetectionTemplate, Evidence, SubTechnology,
};

// Alias for compatibility
pub use LayeredDetector as TechnologyDetector;
pub use LayeredDetector as FrameworkDetector;
