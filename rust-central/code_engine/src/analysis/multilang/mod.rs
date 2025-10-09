//! Cross-Language Analysis
//!
//! Provides cross-language analysis capabilities for multi-language projects
//! including language-specific naming rules and polyglot suggestions.
//!
//! # AI Coder Benefits
//!
//! - **Multi-language Support**: Consistent naming across languages
//! - **Language-specific Rules**: Names that follow language conventions
//! - **Polyglot Awareness**: Names that work well in multi-language projects
//! - **Cross-language CodePatterns**: Consistent patterns across languages

pub mod cross_language_patterns;
pub mod language_analyzer;
pub mod language_specific_rules;

// Re-export main types
pub use cross_language_patterns::*;
pub use language_analyzer::*;
pub use language_specific_rules::*;
