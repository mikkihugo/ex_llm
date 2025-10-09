//! Minimal architecture engine NIF implementation.
//!
//! The original Rust crate that backed `Singularity.ArchitectureEngine` was only
//! partially committed and referenced many missing types. To keep the Elixir
//! side compiling (and to provide deterministic behaviour) we replace it with a
//! lightweight implementation that focuses on deterministic, purely functional
//! name generation. The functions exposed here satisfy the NIF interface
//! expected by `lib/singularity/architecture_engine.ex`.

use rustler::{Encoder, Env, NifMap, NifResult, Term};
use std::path::Path;

mod atoms {
    rustler::atoms! {
        ok,
    }
}

#[derive(NifMap)]
struct FrameworkDetection {
    name: String,
    confidence: f64,
    evidence: Vec<String>,
}

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

#[rustler::nif]
fn detect_frameworks<'a>(env: Env<'a>, codebase_path: String) -> NifResult<Term<'a>> {
    let root = Path::new(&codebase_path);
    let mut frameworks: Vec<FrameworkDetection> = Vec::new();

    if root.join("mix.exs").exists() {
        frameworks.push(FrameworkDetection {
            name: "elixir".to_string(),
            confidence: 0.9,
            evidence: vec!["mix.exs file found".to_string()],
        });

        if root.join("lib").join("web").exists() {
            frameworks.push(FrameworkDetection {
                name: "phoenix".to_string(),
                confidence: 0.95,
                evidence: vec!["lib/web directory".to_string(), "mix.exs".to_string()],
            });
        }

        if root.join("lib").join("repo.ex").exists() {
            frameworks.push(FrameworkDetection {
                name: "ecto".to_string(),
                confidence: 0.9,
                evidence: vec!["lib/repo.ex file".to_string(), "mix.exs".to_string()],
            });
        }
    }

    if root.join("package.json").exists() {
        frameworks.push(FrameworkDetection {
            name: "nodejs".to_string(),
            confidence: 0.9,
            evidence: vec!["package.json file found".to_string()],
        });
    }

    if root.join("Cargo.toml").exists() {
        frameworks.push(FrameworkDetection {
            name: "rust".to_string(),
            confidence: 0.9,
            evidence: vec!["Cargo.toml file found".to_string()],
        });
    }

    Ok((atoms::ok(), frameworks).encode(env))
}

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
        detect_frameworks,
    ]
);
