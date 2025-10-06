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

      // Python
      "py" | "pyi" | "pyw" | "pyx" | "pyz" => ProgrammingLanguage::Python,

      // Rust
      "rs" => ProgrammingLanguage::Rust,

      // Go
      "go" => ProgrammingLanguage::Go,

      // BEAM languages
      "erl" | "hrl" => ProgrammingLanguage::Erlang,
      "ex" | "exs" => ProgrammingLanguage::Elixir,
      "gleam" => ProgrammingLanguage::Gleam,

      // Java
      "java" => ProgrammingLanguage::Java,

      // C/C++
      "c" | "h" => ProgrammingLanguage::C,
      "cpp" | "cxx" | "cc" | "c++" | "hpp" | "hxx" | "hh" | "h++" => ProgrammingLanguage::Cpp,

      // C#
      "cs" | "csx" => ProgrammingLanguage::CSharp,

      // Swift
      "swift" => ProgrammingLanguage::Swift,

      // Kotlin
      "kt" | "kts" => ProgrammingLanguage::Kotlin,

      // Configuration formats
      "json" => ProgrammingLanguage::Json,
      "yaml" | "yml" => ProgrammingLanguage::Yaml,
      "toml" => ProgrammingLanguage::Toml,
      "xml" | "xhtml" | "html" | "htm" => ProgrammingLanguage::Xml,

      _ => ProgrammingLanguage::LanguageNotSupported,
    }
  }

  /// Get file extensions for this language
  pub fn extensions(&self) -> &[&str] {
    match self {
      ProgrammingLanguage::JavaScript => &["js", "jsx", "mjs", "cjs"],
      ProgrammingLanguage::TypeScript => &["ts", "tsx", "mts", "cts"],
      ProgrammingLanguage::Python => &["py", "pyi", "pyw", "pyx", "pyz"],
      ProgrammingLanguage::Rust => &["rs"],
      ProgrammingLanguage::Go => &["go"],
      ProgrammingLanguage::Erlang => &["erl", "hrl"],
      ProgrammingLanguage::Elixir => &["ex", "exs"],
      ProgrammingLanguage::Gleam => &["gleam"],
      ProgrammingLanguage::Java => &["java"],
      ProgrammingLanguage::C => &["c", "h"],
      ProgrammingLanguage::Cpp => &["cpp", "cxx", "cc", "c++", "hpp", "hxx", "hh", "h++"],
      ProgrammingLanguage::CSharp => &["cs", "csx"],
      ProgrammingLanguage::Swift => &["swift"],
      ProgrammingLanguage::Kotlin => &["kt", "kts"],
      ProgrammingLanguage::Json => &["json"],
      ProgrammingLanguage::Yaml => &["yaml", "yml"],
      ProgrammingLanguage::Toml => &["toml"],
      ProgrammingLanguage::Xml => &["xml", "xhtml", "html", "htm"],
      ProgrammingLanguage::Unknown => &[],
      ProgrammingLanguage::LanguageNotSupported => &[],
    }
  }

  /// Get the tokei language type for this language
  pub fn to_tokei_language(&self) -> Option<tokei::LanguageType> {
    match self {
      ProgrammingLanguage::JavaScript => Some(tokei::LanguageType::JavaScript),
      ProgrammingLanguage::TypeScript => Some(tokei::LanguageType::TypeScript),
      ProgrammingLanguage::Python => Some(tokei::LanguageType::Python),
      ProgrammingLanguage::Rust => Some(tokei::LanguageType::Rust),
      ProgrammingLanguage::Go => Some(tokei::LanguageType::Go),
      ProgrammingLanguage::Erlang => Some(tokei::LanguageType::Erlang),
      ProgrammingLanguage::Elixir => Some(tokei::LanguageType::Elixir),
      ProgrammingLanguage::Java => Some(tokei::LanguageType::Java),
      ProgrammingLanguage::C => Some(tokei::LanguageType::C),
      ProgrammingLanguage::Cpp => Some(tokei::LanguageType::Cpp),
      ProgrammingLanguage::CSharp => Some(tokei::LanguageType::CSharp),
      ProgrammingLanguage::Swift => Some(tokei::LanguageType::Swift),
      ProgrammingLanguage::Kotlin => Some(tokei::LanguageType::Kotlin),
      ProgrammingLanguage::Json => Some(tokei::LanguageType::Json),
      ProgrammingLanguage::Yaml => Some(tokei::LanguageType::Yaml),
      ProgrammingLanguage::Toml => Some(tokei::LanguageType::Toml),
      ProgrammingLanguage::Xml => Some(tokei::LanguageType::Xml),
      ProgrammingLanguage::Gleam | ProgrammingLanguage::Unknown | ProgrammingLanguage::LanguageNotSupported => None,
    }
  }

  /// RCA integration is disabled in this build
  pub fn to_rca_language(&self) -> Option<()> {
    None
  }

  /// Check if this language supports tree-sitter parsing
  pub fn supports_tree_sitter(&self) -> bool {
    matches!(
      self,
      ProgrammingLanguage::JavaScript
        | ProgrammingLanguage::TypeScript
        | ProgrammingLanguage::Python
        | ProgrammingLanguage::Rust
        | ProgrammingLanguage::Go
        | ProgrammingLanguage::Erlang
        | ProgrammingLanguage::Elixir
        | ProgrammingLanguage::Gleam
        | ProgrammingLanguage::Java
        | ProgrammingLanguage::C
        | ProgrammingLanguage::Cpp
        | ProgrammingLanguage::CSharp
        | ProgrammingLanguage::Swift
        | ProgrammingLanguage::Kotlin
    )
  }

  /// Get tree-sitter language function name
  pub fn tree_sitter_language_fn(&self) -> Option<&'static str> {
    match self {
      ProgrammingLanguage::JavaScript => Some("tree_sitter_javascript"),
      ProgrammingLanguage::TypeScript => Some("tree_sitter_typescript"),
      ProgrammingLanguage::Python => Some("tree_sitter_python"),
      ProgrammingLanguage::Rust => Some("tree_sitter_rust"),
      ProgrammingLanguage::Go => Some("tree_sitter_go"),
      ProgrammingLanguage::Erlang => Some("tree_sitter_erlang"),
      ProgrammingLanguage::Elixir => Some("tree_sitter_elixir"),
      ProgrammingLanguage::Gleam => Some("tree_sitter_gleam"),
      ProgrammingLanguage::Java => Some("tree_sitter_java"),
      ProgrammingLanguage::C => Some("tree_sitter_c"),
      ProgrammingLanguage::Cpp => Some("tree_sitter_cpp"),
      ProgrammingLanguage::CSharp => Some("tree_sitter_c_sharp"),
      ProgrammingLanguage::Swift => Some("tree_sitter_swift"),
      ProgrammingLanguage::Kotlin => Some("tree_sitter_kotlin"),
      _ => None,
    }
  }

  /// Check if this is a compiled language
  pub fn is_compiled(&self) -> bool {
    matches!(
      self,
      ProgrammingLanguage::Rust
        | ProgrammingLanguage::Go
        | ProgrammingLanguage::Java
        | ProgrammingLanguage::C
        | ProgrammingLanguage::Cpp
        | ProgrammingLanguage::CSharp
        | ProgrammingLanguage::Swift
        | ProgrammingLanguage::Kotlin
        | ProgrammingLanguage::Erlang
        | ProgrammingLanguage::Elixir
        | ProgrammingLanguage::Gleam
    )
  }

  /// Check if this language supports package managers
  pub fn has_package_manager(&self) -> bool {
    !matches!(self, ProgrammingLanguage::C | ProgrammingLanguage::LanguageNotSupported)
  }

  /// Get common package manager files for this language
  pub fn package_files(&self) -> &[&str] {
    match self {
      ProgrammingLanguage::JavaScript | ProgrammingLanguage::TypeScript => &["package.json", "yarn.lock", "pnpm-lock.yaml"],
      ProgrammingLanguage::Python => &["requirements.txt", "pyproject.toml", "setup.py", "Pipfile"],
      ProgrammingLanguage::Rust => &["Cargo.toml", "Cargo.lock"],
      ProgrammingLanguage::Go => &["go.mod", "go.sum"],
      ProgrammingLanguage::Erlang => &["rebar.config", "rebar.lock"],
      ProgrammingLanguage::Elixir => &["mix.exs", "mix.lock"],
      ProgrammingLanguage::Gleam => &["gleam.toml"],
      ProgrammingLanguage::Java => &["pom.xml", "build.gradle", "build.gradle.kts"],
      ProgrammingLanguage::CSharp => &["*.csproj", "*.sln", "packages.config"],
      ProgrammingLanguage::Swift => &["Package.swift", "Package.resolved"],
      ProgrammingLanguage::Kotlin => &["build.gradle.kts", "pom.xml"],
      _ => &[],
    }
  }
}

/// Language detection utilities
pub struct LanguageDetector;

impl LanguageDetector {
  /// Detect language from file path
  pub fn detect_from_path<P: AsRef<Path>>(path: P) -> ProgrammingLanguage {
    let path = path.as_ref();

    if let Some(extension) = path.extension() {
      if let Some(ext_str) = extension.to_str() {
        return ProgrammingLanguage::from_extension(ext_str);
      }
    }

    // Fallback to filename detection for special cases
    if let Some(filename) = path.file_name().and_then(|n| n.to_str()) {
      match filename {
        "Cargo.toml" | "Cargo.lock" => ProgrammingLanguage::Toml,
        "package.json" => ProgrammingLanguage::Json,
        "go.mod" | "go.sum" => ProgrammingLanguage::Go,
        "mix.exs" => ProgrammingLanguage::Elixir,
        "rebar.config" => ProgrammingLanguage::Erlang,
        "gleam.toml" => ProgrammingLanguage::Toml,
        _ => ProgrammingLanguage::LanguageNotSupported,
      }
    } else {
      ProgrammingLanguage::LanguageNotSupported
    }
  }

  /// Detect language from file content (heuristic-based)
  pub fn detect_from_content(content: &str, fallback: ProgrammingLanguage) -> ProgrammingLanguage {
    let first_few_lines: String = content.lines().take(10).collect::<Vec<_>>().join("\n");

    // Check for shebangs
    if first_few_lines.starts_with("#!/usr/bin/env python") || first_few_lines.starts_with("#!/usr/bin/python") {
      return ProgrammingLanguage::Python;
    }

    if first_few_lines.starts_with("#!/usr/bin/env node") || first_few_lines.starts_with("#!/usr/bin/node") {
      return ProgrammingLanguage::JavaScript;
    }

    // Language-specific keywords/patterns
    if content.contains("package main") && content.contains("func main()") {
      return ProgrammingLanguage::Go;
    }

    if content.contains("fn main()") && content.contains("use std::") {
      return ProgrammingLanguage::Rust;
    }

    if content.contains("public static void main") && content.contains("class ") {
      return ProgrammingLanguage::Java;
    }

    if content.contains("using System") && content.contains("namespace ") {
      return ProgrammingLanguage::CSharp;
    }

    if content.contains("defmodule ") && content.contains("do") {
      return ProgrammingLanguage::Elixir;
    }

    if content.contains("-module(") && content.contains("-export([") {
      return ProgrammingLanguage::Erlang;
    }

    // Fallback to provided language
    fallback
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_language_detection_from_extension() {
    assert_eq!(ProgrammingLanguage::from_extension("rs"), ProgrammingLanguage::Rust);
    assert_eq!(ProgrammingLanguage::from_extension("py"), ProgrammingLanguage::Python);
    assert_eq!(ProgrammingLanguage::from_extension("js"), ProgrammingLanguage::JavaScript);
    assert_eq!(ProgrammingLanguage::from_extension("ts"), ProgrammingLanguage::TypeScript);
    assert_eq!(ProgrammingLanguage::from_extension("go"), ProgrammingLanguage::Go);
    assert_eq!(ProgrammingLanguage::from_extension("java"), ProgrammingLanguage::Java);
    assert_eq!(ProgrammingLanguage::from_extension("cpp"), ProgrammingLanguage::Cpp);
    assert_eq!(ProgrammingLanguage::from_extension("unknown"), ProgrammingLanguage::LanguageNotSupported);
  }

  #[test]
  fn test_language_extensions() {
    assert!(ProgrammingLanguage::Rust.extensions().contains(&"rs"));
    assert!(ProgrammingLanguage::Python.extensions().contains(&"py"));
    assert!(ProgrammingLanguage::JavaScript.extensions().contains(&"js"));
    assert!(ProgrammingLanguage::Cpp.extensions().contains(&"cpp"));
  }

  #[test]
  fn test_tokei_language_mapping() {
    assert_eq!(ProgrammingLanguage::Rust.to_tokei_language(), Some(tokei::LanguageType::Rust));
    assert_eq!(ProgrammingLanguage::Python.to_tokei_language(), Some(tokei::LanguageType::Python));
    assert_eq!(ProgrammingLanguage::LanguageNotSupported.to_tokei_language(), None);
  }

  #[test]
  fn test_tree_sitter_support() {
    assert!(ProgrammingLanguage::Rust.supports_tree_sitter());
    assert!(ProgrammingLanguage::Python.supports_tree_sitter());
    assert!(ProgrammingLanguage::Java.supports_tree_sitter());
    assert!(!ProgrammingLanguage::LanguageNotSupported.supports_tree_sitter());
  }

  #[test]
  fn test_language_detector() {
    assert_eq!(LanguageDetector::detect_from_path("test.rs"), ProgrammingLanguage::Rust);
    assert_eq!(LanguageDetector::detect_from_path("main.go"), ProgrammingLanguage::Go);
    assert_eq!(LanguageDetector::detect_from_path("App.java"), ProgrammingLanguage::Java);
    assert_eq!(LanguageDetector::detect_from_path("Cargo.toml"), ProgrammingLanguage::Toml);
  }

  #[test]
  fn test_content_detection() {
    let rust_content = "fn main() {\n    use std::collections::HashMap;\n}";
    assert_eq!(LanguageDetector::detect_from_content(rust_content, ProgrammingLanguage::LanguageNotSupported), ProgrammingLanguage::Rust);

    let go_content = "package main\n\nfunc main() {\n    fmt.Println(\"Hello\")\n}";
    assert_eq!(LanguageDetector::detect_from_content(go_content, ProgrammingLanguage::LanguageNotSupported), ProgrammingLanguage::Go);
  }
}
