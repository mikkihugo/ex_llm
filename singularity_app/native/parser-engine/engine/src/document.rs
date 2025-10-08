use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::{ParseContext, SourceDescriptor};

/// Provides structures for representing parsed documents and their associated metadata.
/// Includes symbols, diagnostics, and statistics collected during parsing.

/// Lightweight representation of a parsed source document.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedDocument {
    pub descriptor: SourceDescriptor,
    pub metadata: ParsedDocumentMetadata,
    pub symbols: Vec<ParsedSymbol>,
    pub classes: Vec<ParsedClass>,
    pub enums: Vec<ParsedEnum>,
    pub docstrings: Vec<ParsedDocstring>,
    pub stats: ParserStats,
    pub diagnostics: Vec<String>,
}

impl ParsedDocument {
    pub fn new(descriptor: SourceDescriptor) -> Self {
        Self {
            descriptor,
            metadata: ParsedDocumentMetadata::default(),
            symbols: Vec::new(),
            classes: Vec::new(),
            enums: Vec::new(),
            docstrings: Vec::new(),
            stats: ParserStats::default(),
            diagnostics: Vec::new(),
        }
    }

    pub fn with_stats(mut self, stats: ParserStats) -> Self {
        self.stats = stats;
        self
    }
}

/// Additional metadata returned by the parser implementation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedDocumentMetadata {
    pub parser_version: Option<String>,
    pub analyzed_at: DateTime<Utc>,
    pub additional: serde_json::Value,
}

impl ParsedDocumentMetadata {
    pub fn new(parser_version: Option<String>) -> Self {
        Self {
            parser_version,
            analyzed_at: Utc::now(),
            additional: serde_json::Value::Null,
        }
    }
}

impl Default for ParsedDocumentMetadata {
    fn default() -> Self {
        Self::new(None)
    }
}

/// Summary statistics produced during parsing.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ParserStats {
    pub byte_length: usize,
    pub total_nodes: usize,
    pub total_tokens: usize,
    pub duration_ms: u64,
}

/// Minimal symbol representation shared across languages.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedSymbol {
    pub name: String,
    pub kind: String,
    pub range: Option<(u32, u32)>,
    pub signature: Option<String>,
}

impl ParsedSymbol {
    pub fn function(name: impl Into<String>, range: Option<(u32, u32)>) -> Self {
        Self {
            name: name.into(),
            kind: "function".to_string(),
            range,
            signature: None,
        }
    }
}

/// Summary information about a parsed class definition.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedClass {
    pub name: String,
    pub bases: Vec<String>,
    pub decorators: Vec<ParsedDecorator>,
    pub docstring: Option<String>,
    pub range: Option<(u32, u32)>,
}

/// Summary information about a parsed enumeration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedEnum {
    pub name: String,
    pub variants: Vec<ParsedEnumVariant>,
    pub decorators: Vec<ParsedDecorator>,
    pub docstring: Option<String>,
    pub range: Option<(u32, u32)>,
}

/// Represents a decorator applied to a symbol.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedDecorator {
    pub name: String,
    pub arguments: Vec<String>,
}

/// Represents an individual enumeration variant.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedEnumVariant {
    pub name: String,
    pub value: Option<String>,
    pub range: Option<(u32, u32)>,
}

/// Captures docstrings (for functions, classes, etc.).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedDocstring {
    pub owner: String,
    pub kind: String,
    pub value: String,
    pub range: Option<(u32, u32)>,
}

/// Helper for constructing placeholder documents during scaffolding.
#[allow(dead_code)]
pub fn placeholder_document(
    descriptor: SourceDescriptor,
    context: &ParseContext,
) -> ParsedDocument {
    let mut doc = ParsedDocument::new(descriptor);
    doc.metadata.additional = json!({
        "workspace": context.workspace_name,
        "root": context.root().display().to_string(),
    });
    doc
}
