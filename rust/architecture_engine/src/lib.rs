//! Unified Architecture Engine - Central hub for all architectural analysis
//!
//! This crate provides a unified interface for:
//! - Framework detection and pattern learning
//! - Package registry analysis and collection
//! - Technology detection and analysis
//! - Architectural pattern suggestions
//! - Integration with central PostgreSQL database
//! - Statistics and metrics collection
//!
//! All components are integrated and communicate with the central Elixir system
//! via NATS and direct database access.

// Rustler imports only needed for NIFs
// Removed unused: Encoder, Env, NifMap, NifResult, Term, Path

// Include all the existing modules
pub mod architecture;
pub mod code_evolution;
pub mod naming_conventions;
pub mod naming_core;
pub mod naming_languages;
pub mod naming_service;
pub mod naming_suggestions;
pub mod naming_utilities;
pub mod patterns;
pub mod technology_detection;
pub mod knowledge;
pub mod framework_detection;

// Package intelligence integration (detection + cache only - Elixir handles NATS proxy)
pub mod package_detection;
pub mod package_cache;

// Include the NIF module
#[cfg(feature = "nif")]
pub mod nif;

mod atoms {
    rustler::atoms! {
        ok,
    }
}

// Removed: FrameworkDetection struct - use framework_detection::Framework instead

fn slugify(input: &str) -> String {
    input
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() {
                c.to_ascii_lowercase()
            } else if c.is_whitespace() || matches!(c, '-' | '_' | '/' | '\\') {
                '-'
            } else {
                '-'
            }
        })
        .collect::<String>()
        .trim_matches('-')
        .replace("--", "-")
}

fn base_suggestions(kind: &str, description: &str, context: Option<&str>) -> Vec<String> {
    let mut suggestions = Vec::new();
    let base = slugify(description);

    if !base.is_empty() {
        suggestions.push(format!("{}-{}", base, kind));
        suggestions.push(format!("{}-{}-core", base, kind));
    }

    if let Some(ctx) = context.and_then(|c| {
        let slug = slugify(c);
        if slug.is_empty() {
            None
        } else {
            Some(slug)
        }
    }) {
        suggestions.push(format!("{}-{}-{}", ctx, base, kind));
    }

    if suggestions.is_empty() {
        suggestions.push(format!("default-{}", kind));
    }

    suggestions.sort();
    suggestions.dedup();
    suggestions
}

#[rustler::nif]
fn suggest_function_names(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("function", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_module_names(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("module", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_variable_names(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("variable", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_monorepo_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("monorepo", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_library_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("library", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_service_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("service", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_component_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("component", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_package_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("package", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_table_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("table", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_endpoint_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("endpoint", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_microservice_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("microservice", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_topic_name(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("topic", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_nats_subject(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("nats", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_kafka_topic(description: String, context: Option<String>) -> Vec<String> {
    base_suggestions("kafka", &description, context.as_deref())
}

#[rustler::nif]
fn suggest_names_for_architecture(
    description: String,
    architecture: String,
    context: Option<String>,
) -> Vec<String> {
    let base = slugify(&description);
    let arch = slugify(&architecture);
    let mut suggestions = Vec::new();

    if !base.is_empty() && !arch.is_empty() {
        suggestions.push(format!("{}-{}", base, arch));
        suggestions.push(format!("{}-{}", arch, base));
    }

    if let Some(ctx) = context.and_then(|c| {
        let slug = slugify(&c);
        if slug.is_empty() {
            None
        } else {
            Some(slug)
        }
    }) {
        suggestions.push(format!("{}-{}-{}", ctx, arch, base));
    }

    if suggestions.is_empty() {
        suggestions.push(if base.is_empty() { arch } else { base });
    }

    suggestions.sort();
    suggestions.dedup();
    suggestions
}

#[rustler::nif]
fn validate_naming_convention(name: String, element_type: String) -> bool {
    if name.trim().is_empty() {
        return false;
    }

    let valid_chars = name
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'));
    if !valid_chars {
        return false;
    }

    match element_type.as_str() {
        "function" | "module" | "variable" | "file" | "directory" | "class" | "interface" => true,
        _ => false,
    }
}

// Removed: Simple stub detect_frameworks - use framework_detection module instead
// The proper implementation is in src/framework_detection/mod.rs

rustler::init!(
    "Elixir.Singularity.ArchitectureEngine",
    [
        suggest_function_names,
        suggest_module_names,
        suggest_variable_names,
        validate_naming_convention,
        suggest_monorepo_name,
        suggest_library_name,
        suggest_service_name,
        suggest_component_name,
        suggest_package_name,
        suggest_table_name,
        suggest_endpoint_name,
        suggest_microservice_name,
        suggest_topic_name,
        suggest_nats_subject,
        suggest_kafka_topic,
        suggest_names_for_architecture,
        // detect_frameworks removed - use framework_detection module instead
    ]
);
