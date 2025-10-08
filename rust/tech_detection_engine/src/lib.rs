//! Technology and Framework Detector
//!
//! Multi-level detection system for identifying frameworks, languages, and technologies
//! in codebases and packages.
//!
//! ## Detection Methods (Fast → Slow)
//!
//! 1. **Config File Scanner** - Checks package.json, Cargo.toml, etc (instant)
//! 2. **Code Pattern Matcher** - Regex patterns against code (fast)
//! 3. **Tree-Sitter Parser** - AST analysis (medium)
//! 4. **Knowledge Base Lookup** - PostgreSQL cross-reference (medium)
//! 5. **AI Framework Identifier** - LLM analysis for unknowns (slow, expensive)
//!
//! ## Usage
//!
//! ```rust
//! use tech_detector::TechDetector;
//!
//! let detector = TechDetector::new().await?;
//! let results = detector.detect_frameworks_and_languages(codebase_path).await?;
//!
//! for framework in results.frameworks {
//!     println!("Found: {} (confidence: {})", framework.name, framework.confidence);
//! }
//! ```

pub mod tech_detector;
pub mod detection_methods;
pub mod detection_results;
pub mod template_loader;
pub mod ai_client;

// Re-exports
pub use tech_detector::TechDetector;
pub use detection_results::{
    DetectionResults,
    FrameworkDetection,
    LanguageDetection,
    DatabaseDetection,
    DetectionMethod,
};
