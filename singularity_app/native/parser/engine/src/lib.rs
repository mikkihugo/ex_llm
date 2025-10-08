//! Parser Engine Core
//!
//! Provides shared registry, discovery, and capsule abstractions for language-agnostic parsing.
//! The crate does not embed specific parser implementations but offers the infrastructure required
//! by both the Rust API and Elixir NIF entrypoints.

mod descriptor;
mod discovery;
mod document;
mod error;
mod language;
mod manager;
mod registry;

#[cfg(feature = "nif")]
pub mod nif;

pub mod capsules;

pub use capsules::builtin_capsules;
pub use descriptor::{ParseContext, SourceDescriptor, SourceKind};
pub use discovery::{discover_sources, DiscoveryOptions};
pub use document::{ParsedDocument, ParsedDocumentMetadata, ParsedSymbol, ParserStats};
pub use error::{ParserError, ParserErrorKind};
pub use language::{LanguageCapsule, LanguageId, LanguageInfo, ParseOptions};
pub use manager::UniversalParser;
pub use registry::{CapsuleHandle, ParserRegistry, ParserRegistryBuilder};

/// Type alias for fallible results within the core crate.
pub type Result<T> = std::result::Result<T, ParserError>;

/// Ensure all engines use the same tree-sitter versions and query definitions.
#[cfg(feature = "tree-sitter")] // Conditional compilation for tree-sitter
pub mod tree_sitter_shared {
    pub use tree_sitter::{Node, Parser, Query, QueryCursor};
    pub fn shared_parser() -> Parser {
        let mut parser = Parser::new();
        parser
    }
}
