use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;

#[cfg(feature = "nif")]
use rustler::{Encoder, Env, Term};

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

#[cfg(feature = "nif")]
impl Encoder for ParsedDocument {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("descriptor", self.descriptor.encode(env))
            .put("metadata", self.metadata.encode(env))
            .put("symbols", self.symbols.encode(env))
            .put("classes", self.classes.encode(env))
            .put("enums", self.enums.encode(env))
            .put("docstrings", self.docstrings.encode(env))
            .put("stats", self.stats.encode(env))
            .put("diagnostics", self.diagnostics.encode(env));

        map.build()
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

#[cfg(feature = "nif")]
impl Encoder for ParsedDocumentMetadata {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("parser_version", self.parser_version.encode(env))
            .put("analyzed_at", self.analyzed_at.encode(env))
            .put("additional", self.additional.encode(env));

        map.build()
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

#[cfg(feature = "nif")]
impl Encoder for ParserStats {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("byte_length", self.byte_length.encode(env))
            .put("total_nodes", self.total_nodes.encode(env))
            .put("total_tokens", self.total_tokens.encode(env))
            .put("duration_ms", self.duration_ms.encode(env));

        map.build()
    }
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

#[cfg(feature = "nif")]
impl Encoder for ParsedSymbol {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("name", self.name.encode(env))
            .put("kind", self.kind.encode(env))
            .put("range", self.range.encode(env))
            .put("signature", self.signature.encode(env));

        map.build()
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

// Encoder implementations for all remaining structs
#[cfg(feature = "nif")]
impl Encoder for ParsedClass {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("name", self.name.encode(env))
            .put("bases", self.bases.encode(env))
            .put("decorators", self.decorators.encode(env))
            .put("docstring", self.docstring.encode(env))
            .put("range", self.range.encode(env));

        map.build()
    }
}

#[cfg(feature = "nif")]
impl Encoder for ParsedEnum {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("name", self.name.encode(env))
            .put("variants", self.variants.encode(env))
            .put("decorators", self.decorators.encode(env))
            .put("docstring", self.docstring.encode(env))
            .put("range", self.range.encode(env));

        map.build()
    }
}

#[cfg(feature = "nif")]
impl Encoder for ParsedEnumVariant {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("name", self.name.encode(env))
            .put("value", self.value.encode(env))
            .put("range", self.range.encode(env));

        map.build()
    }
}

#[cfg(feature = "nif")]
impl Encoder for ParsedDecorator {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("name", self.name.encode(env))
            .put("arguments", self.arguments.encode(env));

        map.build()
    }
}

#[cfg(feature = "nif")]
impl Encoder for ParsedDocstring {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = rustler::types::map::MapIterator::new(env)
            .ok()
            .unwrap();

        let mut map = map
            .put("owner", self.owner.encode(env))
            .put("kind", self.kind.encode(env))
            .put("value", self.value.encode(env))
            .put("range", self.range.encode(env));

        map.build()
    }
}
