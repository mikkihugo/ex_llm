//! Technology Detection Module - Production Quality
//!
//! Detects technologies (languages, databases, tools, libraries) from code patterns.
//! Pure computation NIF - receives patterns from Elixir, performs pattern matching, returns results.
//!
//! ```json
//! {
//!   "module": "architecture_engine::technology_detection",
//!   "layer": "nif",
//!   "purpose": "Detect technologies from code patterns using database-driven pattern matching",
//!   "nif_functions": ["detect_technologies (via nif.rs)"],
//!   "io_model": "Zero I/O - Elixir fetches DB patterns, Rust does pure computation",
//!   "related_modules": {
//!     "elixir": "Singularity.ArchitectureEngine.detect_technologies/2",
//!     "rust": ["framework_detection", "nif"],
//!     "database": "PostgreSQL technology_patterns table (via Elixir)"
//!   },
//!   "pattern_signals": ["file_extensions", "import_patterns", "config_files", "package_managers"],
//!   "confidence_algorithm": "Weighted sum: ext(0.5) + imports(0.4) + config(0.3) + pkg_mgr(0.2), scaled by success_rate",
//!   "technology_stack": ["Rust", "Rustler 0.34", "serde"]
//! }
//! ```
//!
//! ## Architecture Diagram
//!
//! ```mermaid
//! graph TB
//!     A[Elixir: detect_technologies/2] -->|1. Query PostgreSQL| B[(technology_patterns table)]
//!     B -->|2. patterns| C[Elixir: TechnologyDetectionRequest]
//!     C -->|3. NIF call| D[Rust: detect_technologies_with_central_integration]
//!     D -->|4. match patterns| E[Pattern Matcher]
//!     E -->|5. calculate confidence| F[Confidence Scorer]
//!     F -->|6. filter & sort| G[TechnologyDetectionResult]
//!     G -->|7. return to Elixir| H[Elixir: store results in DB]
//!
//!     style D fill:#FFB6C1
//!     style E fill:#98FB98
//!     style F fill:#87CEEB
//!     style B fill:#FFE4B5
//! ```
//!
//! ## Call Graph (YAML - Machine Readable)
//!
//! ```yaml
//! technology_detection:
//!   nif_exports:
//!     - detect_technologies_with_central_integration: "Main detection function (called via nif.rs)"
//!   structs:
//!     - TechnologyDetectionRequest: "NifStruct from Elixir with patterns and DB data"
//!     - KnownTechnology: "NifStruct for DB pattern (from PostgreSQL via Elixir)"
//!     - TechnologyDetectionResult: "NifStruct returned to Elixir"
//!   calls:
//!     - pattern_matcher: "Match file extensions, imports, config files"
//!     - confidence_scorer: "Calculate weighted confidence with success_rate"
//!     - dedup_and_sort: "Remove duplicates, sort by confidence"
//!   called_by:
//!     - "nif.rs::detect_technologies() - NIF entry point"
//!     - "Elixir: Singularity.ArchitectureEngine.detect_technologies/2"
//!   database:
//!     table: "technology_patterns (via Elixir query)"
//!     access: "Read-only via Elixir (no direct DB access from Rust)"
//! ```
//!
//! ## Anti-Patterns (DO NOT DO THIS!)
//!
//! - ❌ **DO NOT perform I/O in this module** - All DB queries, file reads happen in Elixir
//! - ❌ **DO NOT confuse with framework_detection** - Separate concerns: technologies vs frameworks
//! - ❌ **DO NOT create duplicate detection logic** - This is THE ONLY technology detection module
//! - ❌ **DO NOT use blocking operations** - NIFs block BEAM scheduler, keep computation fast
//! - ❌ **DO NOT panic in NIF functions** - Always return Result, panics crash BEAM VM
//! - ❌ **DO NOT collect external packages here** - Use central package intelligence service
//!
//! ## Search Keywords (for AI/vector search)
//!
//! technology detection, language detection, database detection, tool detection, library detection,
//! pattern matching, NIF, Rustler, code analysis, file extension matching, import pattern matching,
//! confidence scoring, weighted confidence, database-driven detection, PostgreSQL patterns,
//! self-learning detection, success rate tracking, Elixir NIF, BEAM scheduler, pure computation,
//! architecture engine, technology identification, ecosystem detection

pub mod analyzer;
pub mod detector;
pub mod patterns;

pub use analyzer::*;
pub use detector::*;
pub use patterns::*;

use serde::{Deserialize, Serialize};

/// Technology detection request
///
/// Receives code patterns and known technologies from Elixir (fetched from PostgreSQL).
/// Performs pure pattern matching computation.
#[derive(Debug, Serialize, Deserialize, rustler::NifStruct)]
#[module = "TechnologyDetectionRequest"]
pub struct TechnologyDetectionRequest {
    pub code_patterns: Vec<String>,              // Changed from 'patterns'
    pub known_technologies: Vec<KnownTechnology>, // NEW - from database
    pub context: String,
    pub confidence_threshold: f64,
}

/// Known technology from database
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "KnownTechnology"]
pub struct KnownTechnology {
    pub technology_name: String,
    pub technology_type: String,  // "language", "database", "library", "tool"
    pub version_pattern: String,
    pub file_extensions: Vec<String>,     // [".ex", ".exs"] for Elixir
    pub import_patterns: Vec<String>,     // ["import ", "alias "] for Elixir
    pub config_files: Vec<String>,        // ["mix.exs", "Cargo.toml"]
    pub package_managers: Vec<String>,    // ["mix", "cargo", "npm"]
    pub confidence_weight: f64,
    pub success_rate: f64,
    pub detection_count: i32,
}

/// Technology detection result
#[derive(Debug, Serialize, Deserialize, rustler::NifStruct)]
#[module = "TechnologyDetectionResult"]
pub struct TechnologyDetectionResult {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f64,
    pub detected_by: String,
    pub evidence: Vec<String>,
    pub pattern_id: Option<String>,
}
