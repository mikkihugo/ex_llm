use crate::{
    LanguageCapsule, LanguageId, LanguageInfo, ParseContext, ParseOptions, ParsedDocument,
    ParsedDocumentMetadata, ParsedSymbol, ParserStats, Result, SourceDescriptor,
};

pub struct GenericCapsule {
    info: LanguageInfo,
}

impl GenericCapsule {
    fn new() -> Self {
        Self {
            info: LanguageInfo {
                id: LanguageId::new("generic"),
                display_name: "Generic Source",
                extensions: vec!["txt", "md"],
                aliases: vec!["generic"],
            },
        }
    }
}

impl Default for GenericCapsule {
    fn default() -> Self {
        Self::new()
    }
}

impl LanguageCapsule for GenericCapsule {
    fn info(&self) -> &LanguageInfo {
        &self.info
    }

    fn matches(&self, descriptor: &SourceDescriptor) -> bool {
        descriptor
            .extension()
            .map(|ext| self.info.matches_extension(ext))
            .unwrap_or(true)
    }

    fn parse(
        &self,
        _context: &ParseContext,
        descriptor: &SourceDescriptor,
        source: &str,
        _options: &ParseOptions,
    ) -> Result<ParsedDocument> {
        let mut doc = ParsedDocument::new(descriptor.clone());
        doc.metadata = ParsedDocumentMetadata::new(Some("generic-0.1.0".to_string()));
        doc.stats = ParserStats {
            byte_length: source.len(),
            total_nodes: 0,
            total_tokens: source.split_whitespace().count(),
            duration_ms: 0,
        };
        if let Some(first_line) = source.lines().next() {
            doc.symbols.push(ParsedSymbol {
                name: first_line.trim().chars().take(32).collect(),
                kind: "heading".to_string(),
                range: Some((1, first_line.len() as u32)),
                signature: None,
            });
        }
        doc.diagnostics
            .push("Generic capsule used fallback parsing".to_string());
        Ok(doc)
    }
}
