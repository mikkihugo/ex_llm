use std::sync::Arc;

use parser_framework::{Comment, Function, Import, LanguageParser, ParseError as FrameworkError};
use serde_json::json;
use tree_sitter::Node;

use crate::{
    LanguageCapsule, LanguageId, LanguageInfo, ParseContext, ParseOptions, ParsedDocument,
    ParsedDocumentMetadata, ParsedSymbol, ParserError, ParserErrorKind, ParserStats, Result,
    SourceDescriptor,
};

/// Adapter that wraps a `parser_framework::LanguageParser` and exposes it as a [`LanguageCapsule`].
pub struct FrameworkCapsule<P: LanguageParser + 'static> {
    info: LanguageInfo,
    parser: Arc<P>,
    parser_version: Option<&'static str>,
}

impl<P: LanguageParser + 'static> FrameworkCapsule<P> {
    pub fn new(info: LanguageInfo, parser: P, parser_version: Option<&'static str>) -> Self {
        Self {
            info,
            parser: Arc::new(parser),
            parser_version,
        }
    }

    fn convert_error(&self, err: FrameworkError) -> ParserError {
        match err {
            FrameworkError::IoError(e) => ParserError::Io(e),
            FrameworkError::TreeSitterError(msg) => {
                self.capsule_failure(ParserErrorKind::TreeSitter, msg)
            }
            FrameworkError::QueryError(msg) => self.capsule_failure(ParserErrorKind::Query, msg),
            FrameworkError::ParseError(msg) => self.capsule_failure(ParserErrorKind::Parse, msg),
            FrameworkError::UnsupportedLanguage(msg) => {
                self.capsule_failure(ParserErrorKind::Unsupported, msg)
            }
            FrameworkError::InvalidAstStructure(msg) => {
                self.capsule_failure(ParserErrorKind::InvalidAst, msg)
            }
            FrameworkError::Utf8Error(err) => {
                self.capsule_failure(ParserErrorKind::Utf8, err.to_string())
            }
            FrameworkError::JsonError(err) => {
                self.capsule_failure(ParserErrorKind::Json, err.to_string())
            }
        }
    }

    fn to_symbols(functions: &[Function]) -> Vec<ParsedSymbol> {
        functions
            .iter()
            .map(|function| {
                let signature = match (
                    function.parameters.trim().is_empty(),
                    function.return_type.trim().is_empty(),
                ) {
                    (true, true) => None,
                    (_, true) => Some(format!("({})", function.parameters)),
                    (true, false) => Some(format!("-> {}", function.return_type)),
                    (false, false) => Some(format!(
                        "({}) -> {}",
                        function.parameters, function.return_type
                    )),
                };

                ParsedSymbol {
                    name: function.name.clone(),
                    kind: "function".to_string(),
                    range: Some((function.start_line as u32, function.end_line as u32)),
                    signature,
                }
            })
            .collect()
    }

    fn additional_metadata(
        &self,
        metrics: &parser_framework::LanguageMetrics,
        imports: &[Import],
        comments: Option<&[Comment]>,
    ) -> serde_json::Value {
        let mut map = serde_json::Map::new();
        map.insert("language".to_string(), json!(self.info.id.0));
        map.insert("metrics".to_string(), json!(metrics));
        if !imports.is_empty() {
            map.insert("imports".to_string(), json!(imports));
        }
        if let Some(comments) = comments {
            map.insert("comments".to_string(), json!(comments));
        } else {
            map.insert("comments_collected".to_string(), json!(false));
        }
        serde_json::Value::Object(map)
    }

    fn capsule_failure(&self, kind: ParserErrorKind, message: impl Into<String>) -> ParserError {
        ParserError::CapsuleFailure {
            language: self.info.display_name.to_string(),
            kind,
            message: message.into(),
        }
    }

    /// Lightweight helper to parse symbols from source code.
    pub fn parse_symbols(&self, source: &str) -> Result<Vec<ParsedSymbol>> {
        let ast = self.parser.parse(source)?;
        let functions = ast.functions();
        Ok(Self::to_symbols(&functions))
    }
}

impl<P: LanguageParser + 'static> LanguageCapsule for FrameworkCapsule<P> {
    fn info(&self) -> &LanguageInfo {
        &self.info
    }

    fn matches(&self, descriptor: &SourceDescriptor) -> bool {
        if let Some(lang) = descriptor.language.as_ref() {
            if self
                .info
                .aliases
                .iter()
                .any(|alias| alias.eq_ignore_ascii_case(lang))
            {
                return true;
            }
        }

        descriptor
            .extension()
            .map(|ext| self.info.matches_extension(ext))
            .unwrap_or(false)
    }

    fn parse(
        &self,
        _context: &ParseContext,
        descriptor: &SourceDescriptor,
        source: &str,
        options: &ParseOptions,
    ) -> Result<ParsedDocument> {
        if let Some(max) = options.max_bytes {
            if source.len() > max {
                return Err(self.capsule_failure(
                    ParserErrorKind::TooLarge,
                    format!("file exceeds configured parser limit of {} bytes", max),
                ));
            }
        }

        let ast = self.parser.parse(source).map_err(|err| self.convert_error(err))?;

        let metrics = self
            .parser
            .get_metrics(&ast)
            .map_err(|err| self.convert_error(err))?;

        let imports = self
            .parser
            .get_imports(&ast)
            .map_err(|err| self.convert_error(err))?;

        let functions = if options.collect_symbols {
            self.parser
                .get_functions(&ast)
                .map_err(|err| self.convert_error(err))?
        } else {
            Vec::new()
        };

        let maybe_comments = if options.collect_comments {
            Some(
                self.parser
                    .get_comments(&ast)
                    .map_err(|err| self.convert_error(err))?,
            )
        } else {
            None
        };

        let symbols = if options.collect_symbols {
            Self::to_symbols(&functions)
        } else {
            Vec::new()
        };

        let mut doc = ParsedDocument::new(descriptor.clone());
        doc.metadata = ParsedDocumentMetadata::new(self.parser_version.map(|s| s.to_string()));
        doc.metadata.additional =
            self.additional_metadata(&metrics, &imports, maybe_comments.as_deref());

        doc.symbols = symbols;
        doc.stats = ParserStats {
            byte_length: source.len(),
            total_nodes: count_nodes(ast.root()) as usize,
            total_tokens: source.split_whitespace().count(),
            duration_ms: 0,
        };

        doc.diagnostics = Vec::new();

        Ok(doc)
    }
}

fn count_nodes(node: Node<'_>) -> usize {
    let mut total = 1;
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        total += count_nodes(child);
    }
    total
}
