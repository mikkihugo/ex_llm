//! Feature Analysis Module
//!
//! Analyzes code to extract features (functions, structs, APIs, etc.)
//! Uses existing parsers to understand code structure.
//!
//! This is NOT fact storage - this is code analysis!
//! Results are stored as facts in fact-system.

pub mod extractor;
pub mod rust_extractor;

pub use extractor::{ExtractedFeature, FeatureExtractor, FeatureType};
pub use rust_extractor::RustFeatureExtractor;
