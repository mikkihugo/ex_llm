//! Rustler NIF bridge for PatternRegistry access.
//!
//! Enables Rust engines (code_quality_engine, parser_engine, linting_engine) to query
//! the Elixir PatternRegistry without embedding all pattern knowledge in Rust.
//!
//! Each Rust engine can:
//! 1. Query patterns by language/framework/category
//! 2. Apply patterns to AST/code
//! 3. Record pattern matches for Genesis feedback loop
//!
//! # Architecture
//!
//! ```text
//! Rust Engine (code_quality_engine, parser_engine)
//!     ↓
//! PatternRegistryNIF (this crate - Rustler NIF)
//!     ↓
//! Elixir PatternRegistry (query layer)
//!     ↓
//! PostgreSQL knowledge_artifacts (storage)
//! ```

use rustler::Env;

/// Get patterns for a specific programming language.
#[rustler::nif]
fn get_patterns_for_language(_language: String) -> Vec<String> {
    // Placeholder - will call Elixir PatternRegistry.find_by_language(language)
    // Returns list of pattern JSON strings
    vec![]
}

/// Get patterns for a specific framework.
#[rustler::nif]
fn get_patterns_for_framework(_framework: String) -> Vec<String> {
    // Placeholder - will call Elixir PatternRegistry.find_by_framework(framework)
    // Returns list of pattern JSON strings
    vec![]
}

/// Get patterns for a specific category.
#[rustler::nif]
fn get_patterns_for_category(category: String) -> Result<Vec<String>, String> {
    // Validate category
    let valid_categories = vec!["security", "compliance", "language", "package", "architecture", "framework"];
    if !valid_categories.contains(&category.as_str()) {
        return Err(format!("Invalid category: {}", category));
    }
    // Placeholder - will call Elixir PatternRegistry.find_by_category(category)
    // Returns list of pattern JSON strings
    Ok(vec![])
}

/// Record a pattern match.
#[rustler::nif]
fn record_pattern_match(pattern_id: String, _metadata: String) -> Result<String, String> {
    // Validate pattern_id
    if pattern_id.is_empty() {
        return Err("pattern_id cannot be empty".to_string());
    }
    // Placeholder - will call Elixir PatternRegistry.record_match(pattern_id, opts)
    Ok("ok".to_string())
}

rustler::init!("Elixir.Singularity.CodeQuality.PatternRegistryNIF");
