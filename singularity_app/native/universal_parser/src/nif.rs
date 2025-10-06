//! NIF (Native Implemented Function) integration for Elixir
//!
//! This module provides Rustler NIFs to expose the universal parser framework
//! to Elixir, enabling high-performance code parsing and analysis.

use rustler::{Encoder, Env, Error, NifResult, Term};
use serde_json;
use std::collections::HashMap;

use crate::{
    dependencies::UniversalDependencies,
    errors::UniversalParserError,
    languages::ProgrammingLanguage,
    AnalysisResult,
};

/// NIF resource for UniversalDependencies
rustler::resource!(UniversalParserResource, Env, UniversalDependencies);

/// Initialize the universal parser NIF
#[rustler::nif]
fn init() -> NifResult<Term> {
    let deps = UniversalDependencies::new()
        .map_err(|e| Error::Term(Box::new(format!("Failed to initialize universal parser: {}", e))))?;
    
    let resource = UniversalParserResource::alloc(Env::current(), deps);
    Ok(resource.encode(Env::current()))
}

/// Analyze file content using universal parser
#[rustler::nif]
fn analyze_content(env: Env, resource: Term, content: String, file_path: String, language: String) -> NifResult<Term> {
    let deps = resource
        .get_resource::<UniversalParserResource>()
        .map_err(|_| Error::BadArg)?;
    
    let lang = parse_language(&language)?;
    
    // Use tokio runtime for async operations
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| Error::Term(Box::new(format!("Failed to create tokio runtime: {}", e))))?;
    
    let result = rt.block_on(async {
        deps.analyze_with_all_tools(&content, lang, &file_path).await
    });
    
    match result {
        Ok(analysis) => {
            let json = serde_json::to_string(&analysis)
                .map_err(|e| Error::Term(Box::new(format!("Failed to serialize result: {}", e))))?;
            Ok(json.encode(env))
        }
        Err(e) => Err(Error::Term(Box::new(format!("Analysis failed: {}", e))))
    }
}

/// Analyze file from filesystem
#[rustler::nif]
fn analyze_file(env: Env, resource: Term, file_path: String, language: String) -> NifResult<Term> {
    let deps = resource
        .get_resource::<UniversalParserResource>()
        .map_err(|_| Error::BadArg)?;
    
    let lang = parse_language(&language)?;
    
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| Error::Term(Box::new(format!("Failed to create tokio runtime: {}", e))))?;
    
    let result = rt.block_on(async {
        let content = tokio::fs::read_to_string(&file_path).await?;
        deps.analyze_with_all_tools(&content, lang, &file_path).await
    });
    
    match result {
        Ok(analysis) => {
            let json = serde_json::to_string(&analysis)
                .map_err(|e| Error::Term(Box::new(format!("Failed to serialize result: {}", e))))?;
            Ok(json.encode(env))
        }
        Err(e) => Err(Error::Term(Box::new(format!("File analysis failed: {}", e))))
    }
}

/// Get parser metadata
#[rustler::nif]
fn get_metadata(env: Env, resource: Term) -> NifResult<Term> {
    let deps = resource
        .get_resource::<UniversalParserResource>()
        .map_err(|_| Error::BadArg)?;
    
    let metadata = deps.get_parser_metadata();
    let json = serde_json::to_string(&metadata)
        .map_err(|e| Error::Term(Box::new(format!("Failed to serialize metadata: {}", e))))?;
    
    Ok(json.encode(env))
}

/// Get supported languages
#[rustler::nif]
fn supported_languages(env: Env, resource: Term) -> NifResult<Term> {
    let deps = resource
        .get_resource::<UniversalParserResource>()
        .map_err(|_| Error::BadArg)?;
    
    let languages = deps.get_supported_languages();
    let json = serde_json::to_string(&languages)
        .map_err(|e| Error::Term(Box::new(format!("Failed to serialize languages: {}", e))))?;
    
    Ok(json.encode(env))
}

/// Parse programming language from string
fn parse_language(lang_str: &str) -> Result<ProgrammingLanguage, Error> {
    match lang_str.to_lowercase().as_str() {
        "elixir" => Ok(ProgrammingLanguage::Elixir),
        "erlang" => Ok(ProgrammingLanguage::Erlang),
        "gleam" => Ok(ProgrammingLanguage::Gleam),
        "rust" => Ok(ProgrammingLanguage::Rust),
        "python" => Ok(ProgrammingLanguage::Python),
        "javascript" => Ok(ProgrammingLanguage::JavaScript),
        "typescript" => Ok(ProgrammingLanguage::TypeScript),
        "go" => Ok(ProgrammingLanguage::Go),
        "java" => Ok(ProgrammingLanguage::Java),
        "csharp" | "c#" => Ok(ProgrammingLanguage::CSharp),
        "c" => Ok(ProgrammingLanguage::C),
        "cpp" | "c++" => Ok(ProgrammingLanguage::Cpp),
        "php" => Ok(ProgrammingLanguage::Php),
        "ruby" => Ok(ProgrammingLanguage::Ruby),
        "swift" => Ok(ProgrammingLanguage::Swift),
        "kotlin" => Ok(ProgrammingLanguage::Kotlin),
        "scala" => Ok(ProgrammingLanguage::Scala),
        "haskell" => Ok(ProgrammingLanguage::Haskell),
        "clojure" => Ok(ProgrammingLanguage::Clojure),
        "lua" => Ok(ProgrammingLanguage::Lua),
        "perl" => Ok(ProgrammingLanguage::Perl),
        "r" => Ok(ProgrammingLanguage::R),
        "matlab" => Ok(ProgrammingLanguage::Matlab),
        "julia" => Ok(ProgrammingLanguage::Julia),
        "dart" => Ok(ProgrammingLanguage::Dart),
        "zig" => Ok(ProgrammingLanguage::Zig),
        "nim" => Ok(ProgrammingLanguage::Nim),
        "crystal" => Ok(ProgrammingLanguage::Crystal),
        "ocaml" => Ok(ProgrammingLanguage::Ocaml),
        "fsharp" | "f#" => Ok(ProgrammingLanguage::FSharp),
        "vb" | "vb.net" => Ok(ProgrammingLanguage::Vb),
        "powershell" => Ok(ProgrammingLanguage::Powershell),
        "bash" | "shell" => Ok(ProgrammingLanguage::Bash),
        "sql" => Ok(ProgrammingLanguage::Sql),
        "html" => Ok(ProgrammingLanguage::Html),
        "css" => Ok(ProgrammingLanguage::Css),
        "xml" => Ok(ProgrammingLanguage::Xml),
        "yaml" | "yml" => Ok(ProgrammingLanguage::Yaml),
        "json" => Ok(ProgrammingLanguage::Json),
        "toml" => Ok(ProgrammingLanguage::Toml),
        "ini" => Ok(ProgrammingLanguage::Ini),
        "markdown" | "md" => Ok(ProgrammingLanguage::Markdown),
        "dockerfile" => Ok(ProgrammingLanguage::Dockerfile),
        "makefile" => Ok(ProgrammingLanguage::Makefile),
        "cmake" => Ok(ProgrammingLanguage::Cmake),
        "gradle" => Ok(ProgrammingLanguage::Gradle),
        "maven" => Ok(ProgrammingLanguage::Maven),
        "sbt" => Ok(ProgrammingLanguage::Sbt),
        "cargo" => Ok(ProgrammingLanguage::Cargo),
        "mix" => Ok(ProgrammingLanguage::Mix),
        "rebar" => Ok(ProgrammingLanguage::Rebar),
        "hex" => Ok(ProgrammingLanguage::Hex),
        "npm" => Ok(ProgrammingLanguage::Npm),
        "yarn" => Ok(ProgrammingLanguage::Yarn),
        "pip" => Ok(ProgrammingLanguage::Pip),
        "composer" => Ok(ProgrammingLanguage::Composer),
        "gem" => Ok(ProgrammingLanguage::Gem),
        "go_mod" | "gomod" => Ok(ProgrammingLanguage::GoMod),
        "pom" => Ok(ProgrammingLanguage::Pom),
        "gradle" => Ok(ProgrammingLanguage::Gradle),
        "sbt" => Ok(ProgrammingLanguage::Sbt),
        "cargo" => Ok(ProgrammingLanguage::Cargo),
        "mix" => Ok(ProgrammingLanguage::Mix),
        "rebar" => Ok(ProgrammingLanguage::Rebar),
        "hex" => Ok(ProgrammingLanguage::Hex),
        "npm" => Ok(ProgrammingLanguage::Npm),
        "yarn" => Ok(ProgrammingLanguage::Yarn),
        "pip" => Ok(ProgrammingLanguage::Pip),
        "composer" => Ok(ProgrammingLanguage::Composer),
        "gem" => Ok(ProgrammingLanguage::Gem),
        "go_mod" | "gomod" => Ok(ProgrammingLanguage::GoMod),
        "pom" => Ok(ProgrammingLanguage::Pom),
        _ => Err(Error::Term(Box::new(format!("Unsupported language: {}", lang_str))))
    }
}

/// NIF module definition
rustler::init!(
    "Elixir.Singularity.UniversalParserNif",
    [
        init,
        analyze_content,
        analyze_file,
        get_metadata,
        supported_languages
    ],
    load = load
);

fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(UniversalParserResource, env);
    true
}