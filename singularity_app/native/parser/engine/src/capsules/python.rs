use once_cell::sync::Lazy;
use serde_json::json;
use std::cell::RefCell;

use tree_sitter::{Language, Node, Parser, Tree};

const VERSION: &str = "python-tree-sitter-0.23";

static PYTHON_LANGUAGE: Lazy<Language> = Lazy::new(|| tree_sitter_python::LANGUAGE.into());

thread_local! {
    static PYTHON_PARSER: RefCell<Parser> = RefCell::new(Parser::new());
}

use crate::{
    LanguageCapsule, LanguageId, LanguageInfo, ParseContext, ParseOptions, ParsedDocument,
    ParsedDocumentMetadata, ParsedSymbol, ParserStats, Result, SourceDescriptor,
};

pub struct PythonCapsule {
    info: LanguageInfo,
}

impl PythonCapsule {
    pub fn new() -> Self {
        Self {
            info: LanguageInfo {
                id: LanguageId::new("python"),
                display_name: "Python",
                extensions: vec!["py"],
                aliases: vec!["python", "py"],
            },
        }
    }
}

impl Default for PythonCapsule {
    fn default() -> Self {
        Self::new()
    }
}

impl LanguageCapsule for PythonCapsule {
    fn info(&self) -> &LanguageInfo {
        &self.info
    }

    fn matches(&self, descriptor: &SourceDescriptor) -> bool {
        descriptor
            .extension()
            .map(|ext| self.info.matches_extension(ext))
            .unwrap_or(false)
            || descriptor
                .language
                .as_ref()
                .map(|lang| {
                    self.info
                        .aliases
                        .iter()
                        .any(|alias| alias.eq_ignore_ascii_case(lang))
                })
                .unwrap_or(false)
    }

    fn parse(
        &self,
        _context: &ParseContext,
        descriptor: &SourceDescriptor,
        source: &str,
        _options: &ParseOptions,
    ) -> Result<ParsedDocument> {
        let mut doc = ParsedDocument::new(descriptor.clone());
        doc.metadata = ParsedDocumentMetadata::new(Some(VERSION.to_string()));

        if let Some(tree) = parse_python(source) {
            let root = tree.root_node();
            let total_nodes = count_nodes(root);

            let functions = collect_symbols(&root, source, "function_definition", "function");
            let classes = collect_symbols(&root, source, "class_definition", "class");

            let mut symbols = Vec::new();
            symbols.extend(functions.iter().cloned());
            symbols.extend(classes.iter().cloned());

            doc.symbols = symbols;
            doc.stats = ParserStats {
                byte_length: source.len(),
                total_nodes,
                total_tokens: source.split_whitespace().count(),
                duration_ms: 0,
            };
            doc.metadata.additional = json!({
                "language": "python",
                "counts": {
                    "functions": functions.len(),
                    "classes": classes.len(),
                }
            });
        } else {
            doc.stats = ParserStats {
                byte_length: source.len(),
                total_nodes: 0,
                total_tokens: source.split_whitespace().count(),
                duration_ms: 0,
            };
            doc.diagnostics
                .push("Python capsule could not parse file with tree-sitter".to_string());
        }

        if source.contains("__main__") {
            doc.diagnostics
                .push("Contains __main__ entrypoint".to_string());
        }
        Ok(doc)
    }
}

fn parse_python(source: &str) -> Option<Tree> {
    PYTHON_PARSER.with(|parser| {
        let mut parser = parser.borrow_mut();
        parser.set_language(&*PYTHON_LANGUAGE).ok()?;
        parser.parse(source, None)
    })
}

fn collect_symbols(
    root: &Node,
    source: &str,
    target_kind: &str,
    symbol_kind: &str,
) -> Vec<ParsedSymbol> {
    let mut symbols = Vec::new();
    gather_symbols(*root, target_kind, source, symbol_kind, &mut symbols);
    symbols
}

fn gather_symbols(
    node: Node,
    target_kind: &str,
    source: &str,
    symbol_kind: &str,
    out: &mut Vec<ParsedSymbol>,
) {
    if node.kind() == target_kind {
        if let Some(symbol) = extract_symbol(node, source, symbol_kind) {
            out.push(symbol);
        }
    }
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        gather_symbols(child, target_kind, source, symbol_kind, out);
    }
}

fn extract_symbol(node: Node, source: &str, symbol_kind: &str) -> Option<ParsedSymbol> {
    let name_node = node.child_by_field_name("name")?;
    let name = name_node.utf8_text(source.as_bytes()).ok()?.to_string();
    let start = node.start_position().row as u32 + 1;
    let end = node.end_position().row as u32 + 1;
    Some(ParsedSymbol {
        name,
        kind: symbol_kind.to_string(),
        range: Some((start, end)),
        signature: None,
    })
}

fn count_nodes(node: Node) -> usize {
    let mut total = 1;
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        total += count_nodes(child);
    }
    total
}
