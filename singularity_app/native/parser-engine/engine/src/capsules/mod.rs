/// Contains modular capsule implementations for various languages and frameworks.
/// Capsules are reusable components that encapsulate language-specific parsing logic.
mod framework_adapter;
mod generic;
use std::sync::Arc;

use framework_adapter::FrameworkCapsule;

use crate::{LanguageCapsule, LanguageId, LanguageInfo};

#[cfg(feature = "lang-elixir")]
use elixir_parser::ElixirParser;
#[cfg(feature = "lang-gleam")]
use gleam_parser::GleamParser;
#[cfg(feature = "lang-javascript")]
use javascript_parser::JavascriptParser;
#[cfg(feature = "lang-python")]
use python_parser::{PythonParser, VERSION as PYTHON_VERSION};
#[cfg(feature = "lang-rust")]
use rust_parser::RustParser;
#[cfg(feature = "lang-typescript")]
use typescript_parser::TypescriptParser;

fn capsule_info(
    id: &str,
    display_name: &'static str,
    extensions: &[&'static str],
    aliases: &[&'static str],
) -> LanguageInfo {
    LanguageInfo {
        id: LanguageId::new(id),
        display_name,
        extensions: extensions.to_vec(),
        aliases: aliases.to_vec(),
    }
}

pub fn builtin_capsules() -> Vec<Arc<dyn LanguageCapsule>> {
    let mut capsules: Vec<Arc<dyn LanguageCapsule>> = Vec::new();

    #[cfg(feature = "lang-elixir")]
    capsules.push(Arc::new(FrameworkCapsule::new(
        capsule_info("elixir", "Elixir", &["ex", "exs"], &["elixir"]),
        ElixirParser::default(),
        None,
    )));

    #[cfg(feature = "lang-gleam")]
    capsules.push(Arc::new(FrameworkCapsule::new(
        capsule_info("gleam", "Gleam", &["gleam"], &["gleam"]),
        GleamParser::default(),
        None,
    )));

    #[cfg(feature = "lang-rust")]
    capsules.push(Arc::new(FrameworkCapsule::new(
        capsule_info("rust", "Rust", &["rs"], &["rust"]),
        RustParser::default(),
        None,
    )));

    #[cfg(feature = "lang-javascript")]
    capsules.push(Arc::new(FrameworkCapsule::new(
        capsule_info(
            "javascript",
            "JavaScript",
            &["js", "mjs", "cjs"],
            &["javascript", "js"],
        ),
        JavascriptParser::default(),
        None,
    )));

    #[cfg(feature = "lang-typescript")]
    capsules.push(Arc::new(FrameworkCapsule::new(
        capsule_info(
            "typescript",
            "TypeScript",
            &["ts", "tsx"],
            &["typescript", "ts"],
        ),
        TypescriptParser::default(),
        None,
    )));

    #[cfg(feature = "lang-python")]
    capsules.push(Arc::new(FrameworkCapsule::new(
        capsule_info("python", "Python", &["py"], &["python", "py"]),
        PythonParser::default(),
        Some(PYTHON_VERSION),
    )));

    capsules.push(Arc::new(generic::GenericCapsule::default()));

    capsules
}
