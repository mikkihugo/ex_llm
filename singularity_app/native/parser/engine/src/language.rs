use serde::{Deserialize, Serialize};
use std::fmt;

use crate::{ParseContext, ParsedDocument, Result, SourceDescriptor};

/// Unique identifier for a language capsule.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct LanguageId(pub String);

impl LanguageId {
    pub fn new(id: impl Into<String>) -> Self {
        Self(id.into())
    }
}

impl fmt::Display for LanguageId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// Options that influence parsing behaviour.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ParseOptions {
    pub collect_symbols: bool,
    pub collect_comments: bool,
    pub max_bytes: Option<usize>,
}

/// Static metadata about a language.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageInfo {
    pub id: LanguageId,
    pub display_name: &'static str,
    pub extensions: Vec<&'static str>,
    pub aliases: Vec<&'static str>,
}

impl LanguageInfo {
    pub fn matches_extension(&self, ext: &str) -> bool {
        self.extensions
            .iter()
            .any(|candidate| candidate.eq_ignore_ascii_case(ext))
    }
}

/// Shared interface implemented by each language capsule.
pub trait LanguageCapsule: Send + Sync {
    fn info(&self) -> &LanguageInfo;
    fn matches(&self, descriptor: &SourceDescriptor) -> bool;
    fn parse(
        &self,
        context: &ParseContext,
        descriptor: &SourceDescriptor,
        source: &str,
        options: &ParseOptions,
    ) -> Result<ParsedDocument>;
}
