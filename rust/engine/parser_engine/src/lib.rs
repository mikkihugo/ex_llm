//! Parser Engine Core
//!
//! Provides shared registry, discovery, and capsule abstractions for language-agnostic parsing.
//! The crate does not embed specific parser implementations but offers the infrastructure required
//! by both the Rust API and Elixir NIF entrypoints.
//!
//! ## Key Features
//! - **Capsules**: Modular, reusable components for language-specific parsing logic.
//! - **Discovery**: Mechanisms to locate and manage source files for parsing.
//! - **Registry**: Centralized management of parser instances and their configurations.
//! - **Error Handling**: Comprehensive error types for robust parsing workflows.
//!
//! ## Usage
//! This crate is designed to be used as a core library for building language-agnostic parsers.
//! Example usage is provided inline with the relevant functions and types.
//!
//! # Metadata
//! - Purpose: Core library for language-agnostic parsing.
//! - Dependencies: `serde`, `chrono`, `tree-sitter`.
//! - Tags: parser, registry, discovery, capsules, error handling.
//! - Integration Points: Used by Elixir NIFs and Rust-based tools for parsing.

mod descriptor; // Handles source descriptors and parsing contexts.
mod discovery; // Implements source discovery mechanisms.
mod document; // Defines parsed document structures and metadata.
mod error; // Provides error types and utilities for the parser engine.
mod language; // Manages language-specific parsing options and metadata.
mod manager; // Coordinates parsing operations across multiple sources.
mod registry; // Centralized registry for managing parser instances.

#[cfg(feature = "nif")]
pub mod nif; // Exposes NIF bindings for Elixir integration.

pub mod capsules; // Contains reusable capsule implementations.

// Re-exported items for external use.
/// Built-in capsules for common languages and frameworks.
pub use capsules::builtin_capsules;
/// Context and metadata for parsing operations.
pub use descriptor::{ParseContext, SourceDescriptor, SourceKind};
/// Utilities for discovering source files.
pub use discovery::{discover_sources, DiscoveryOptions};
/// Structures representing parsed documents and their metadata.
pub use document::{
    ParsedClass, ParsedDecorator, ParsedDocstring, ParsedDocument, ParsedDocumentMetadata,
    ParsedEnum, ParsedEnumVariant, ParsedSymbol, ParserStats,
};
/// Comprehensive error types for the parser engine.
pub use error::{ParserError, ParserErrorKind};
/// Language-specific parsing options and metadata.
pub use language::{LanguageCapsule, LanguageId, LanguageInfo, ParseOptions};
/// High-level manager for coordinating parsing operations.
pub use manager::UniversalParser;
/// Centralized registry for managing parser instances and configurations.
pub use registry::{CapsuleHandle, ParserRegistry, ParserRegistryBuilder};

/// Template metadata parser utilities.
pub use template_meta_parser::{
    TemplateCatalog, TemplateDocument, TemplateManifest, TemplateParser, TemplateSummary,
};

/// Type alias for fallible results within the core crate.
///
/// This alias is used throughout the crate to standardize error handling.
/// Example:
/// ```rust
/// let result: Result<()> = some_parsing_function();
/// match result {
///     Ok(_) => println!("Parsing succeeded"),
///     Err(e) => eprintln!("Parsing failed: {}", e),
/// }
/// ```
pub type Result<T> = std::result::Result<T, ParserError>;
