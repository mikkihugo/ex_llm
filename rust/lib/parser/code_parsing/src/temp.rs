//! Language definitions and detection for universal parser

use std::path::Path;
use std::fmt;

use serde::{Deserialize, Serialize};

/// Supported programming languages
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ProgrammingLanguage {
  // Existing languages
  JavaScript,
  TypeScript,
  Python,
  Rust,
  Go,

  // BEAM languages
  Erlang,
  Elixir,
  Gleam,

  // New languages we're adding
  Java,
  C,
  Cpp,
  CSharp,
  Swift,
  Kotlin,

  // Unknown/unsupported language
  Unknown,

  // Configuration and data formats
  Json,
  Yaml,
  Toml,
  Xml,

  // Language not recognized or not supported by the parser
  LanguageNotSupported,
}

impl fmt::Display for ProgrammingLanguage {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ProgrammingLanguage::JavaScript => write!(f, "javascript"),
            ProgrammingLanguage::TypeScript => write!(f, "typescript"),
            ProgrammingLanguage::Python => write!(f, "python"),
            ProgrammingLanguage::Rust => write!(f, "rust"),
            ProgrammingLanguage::Go => write!(f, "go"),
            ProgrammingLanguage::Erlang => write!(f, "erlang"),
            ProgrammingLanguage::Elixir => write!(f, "elixir"),
            ProgrammingLanguage::Gleam => write!(f, "gleam"),
            ProgrammingLanguage::Java => write!(f, "java"),
            ProgrammingLanguage::C => write!(f, "c"),
            ProgrammingLanguage::Cpp => write!(f, "cpp"),
            ProgrammingLanguage::CSharp => write!(f, "csharp"),
            ProgrammingLanguage::Swift => write!(f, "swift"),
            ProgrammingLanguage::Kotlin => write!(f, "kotlin"),
            ProgrammingLanguage::Unknown => write!(f, "unknown"),
            ProgrammingLanguage::Json => write!(f, "json"),
            ProgrammingLanguage::Yaml => write!(f, "yaml"),
            ProgrammingLanguage::Toml => write!(f, "toml"),
            ProgrammingLanguage::Xml => write!(f, "xml"),
            ProgrammingLanguage::LanguageNotSupported => write!(f, "unsupported"),
        }
    }
}

pub mod adapters;

impl ProgrammingLanguage {
  /// Detect language from file extension
  pub fn from_extension(extension: &str) -> Self {
    match extension.to_lowercase().as_str() {
      // JavaScript/TypeScript
      "js" | "jsx" | "mjs" | "cjs" => ProgrammingLanguage::JavaScript,
      "ts" | "tsx" | "mts" | "cts" => ProgrammingLanguage::TypeScript,

