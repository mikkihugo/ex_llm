#![cfg(feature = "nif")]

/// Provides NIF bindings for integrating the parser engine with Elixir.
/// Includes functions for parsing files and directory trees.

use std::path::{Path, PathBuf};
use std::sync::{Arc, OnceLock};

use rustler::types::atom::ok;
use rustler::{Encoder, Env, Error as NifError, NifResult, Term};
use serde::Serialize;

use crate::{
    builtin_capsules, DiscoveryOptions, ParseContext, ParsedDocument, ParserRegistry,
    UniversalParser,
};

static REGISTRY: OnceLock<Arc<ParserRegistry>> = OnceLock::new();
static PARSER: OnceLock<UniversalParser> = OnceLock::new();

#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_file<'a>(env: Env<'a>, path: String) -> NifResult<Term<'a>> {
    let parser = parser();
    let path_buf = PathBuf::from(&path);
    let context = parse_context_for_path(&path_buf);

    let document = parser
        .parse_file(&context, &path_buf)
        .map_err(|_| NifError::RaiseAtom("parse_failed"))?;

    let json = serde_json::to_string(&SerializeDocument(&document))
        .map_err(|_| NifError::RaiseAtom("encode_failed"))?;
    Ok((ok(), json).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_tree<'a>(env: Env<'a>, root: String) -> NifResult<Term<'a>> {
    let parser = parser();
    let root_path = PathBuf::from(&root);
    let context = ParseContext::new(&root_path);
    let documents = parser
        .parse_tree(&context, &root_path, &DiscoveryOptions::default())
        .map_err(|_| NifError::RaiseAtom("parse_failed"))?;

    let json = serde_json::to_string(&SerializeDocuments(&documents))
        .map_err(|_| NifError::RaiseAtom("encode_failed"))?;
    Ok((ok(), json).encode(env))
}

fn registry() -> &'static Arc<ParserRegistry> {
    REGISTRY.get_or_init(|| {
        let builder = builtin_capsules()
            .into_iter()
            .fold(ParserRegistry::builder(), |builder, capsule| {
                builder.register_capsule(capsule)
            });
        Arc::new(builder.build())
    })
}

fn parser() -> &'static UniversalParser {
    PARSER.get_or_init(|| UniversalParser::new(Arc::clone(registry())))
}

fn parse_context_for_path(path: &Path) -> ParseContext {
    let root = path.parent().unwrap_or_else(|| Path::new("."));
    ParseContext::new(root)
}

struct SerializeDocument<'a>(&'a ParsedDocument);

impl<'a> Serialize for SerializeDocument<'a> {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        self.0.serialize(serializer)
    }
}

struct SerializeDocuments<'a>(&'a [ParsedDocument]);

impl<'a> Serialize for SerializeDocuments<'a> {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        self.0.serialize(serializer)
    }
}

rustler::init!("Elixir.Singularity.UniversalParser");
