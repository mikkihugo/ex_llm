//! Framework and Technology Detection Module
//!
//! Integrated framework detection system that combines:
//! - NPM package analysis
//! - File pattern detection
//! - LLM-powered analysis
//! - Storage and caching
//!
//! All detection results are stored in the unified FACT storage system.

pub mod detector;
pub mod fact_storage;
pub mod file_detector;
pub mod npm_detector;
pub mod storage;
pub mod types;

// Re-export main types
pub use file_detector::FileDetector;
pub use npm_detector::NpmDetector;
pub use storage::{TechnologyCache, TechnologyStorage};
pub use types::{
  DetectionMethod, DetectionMetrics, DetectionResult, EnhancedDetectionResult,
  FrameworkDetectionError, FrameworkInfo, FrameworkRecommendations,
  FrameworkSignature, LLMProvider, ToolchainLlmInterface,
};

// Re-export the main detector for backward compatibility
pub use detector::TechnologyDetector;
pub use TechnologyDetector as FrameworkDetector;
