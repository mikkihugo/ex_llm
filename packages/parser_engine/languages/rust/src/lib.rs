//! Rust parser backed by tree-sitter for use with the parser framework.

use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use std::convert::Into;
use tree_sitter::{Parser, Query, QueryCursor, StreamingIterator};

pub struct RustParser {
    parser: Mutex<Parser>,
}

impl RustParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_rust::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for RustParser {
    fn default() -> Self {
        Self::new().expect("Rust parser initialisation must succeed")
    }
}

impl LanguageParser for RustParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse Rust code".into()))?;
        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "rust")
                .unwrap_or((1.0, ast.content.lines().count() as u64, ast.content.lines().count() as u64, comments.len() as u64, 0));

        Ok(LanguageMetrics {
            lines_of_code: ploc.saturating_sub(blank_lines + cloc),
            lines_of_comments: cloc,
            blank_lines,
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: 0, // Rust doesn't have classes (uses structs/impls)
            imports: imports.len() as u64,
            complexity_score, // Real cyclomatic complexity from RCA!
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_rust::LANGUAGE.into(),
            r#"
            (function_item
                name: (identifier) @function_name
                parameters: (parameters) @parameters
                return_type: (type_identifier)? @return_type
                body: (block) @body) @function
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut functions = Vec::new();
        let mut captures = cursor.captures(&query, root, ast.content.as_bytes());
        while let Some(&(ref m, _)) = captures.next() {
            let mut name = None;
            let mut params = None;
            let mut return_type = None;
            let mut body_range = None;
            let mut fn_node = None;

            for capture in m.captures {
                match capture.index {
                    0 => {
                        fn_node = Some(capture.node);
                        body_range = Some(capture.node.byte_range());
                    }
                    1 => {
                        name = Some(
                            capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default(),
                        )
                    }
                    2 => {
                        params = Some(
                            capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default(),
                        )
                    }
                    3 => {
                        return_type = Some(
                            capture
                                .node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default(),
                        )
                    }
                    4 => body_range = Some(capture.node.byte_range()),
                    _ => {}
                }
            }

            if let (Some(name), Some(fn_node)) = (name, fn_node) {
                let start = fn_node.start_position().row + 1;
                let _end = fn_node.end_position().row + 1;
                let body = body_range
                    .and_then(|range| ast.content.get(range.clone()))
                    .unwrap_or_default()
                    .to_owned();

                let full_text = fn_node.utf8_text(ast.content.as_bytes()).unwrap_or_default();
                let is_async = full_text.contains("async fn");
                let params_str = params.unwrap_or("");
                let ret_str = return_type.unwrap_or("()");
                let signature = if ret_str == "()" {
                    format!("{}({})", name, params_str)
                } else {
                    format!("{}({}) -> {}", name, params_str, ret_str)
                };

                // Extract doc comment (///)
                let docstring = extract_rust_doc_comment(fn_node, &ast.content);

                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params_str.split(',').map(|s| s.trim().to_owned()).collect(),
                    return_type: Some(ret_str.to_owned()),
                    line_start: start as u32,
                    line_end: _end as u32,
                    complexity: 1, // TODO: implement complexity calculation
                    decorators: Vec::new(), // Rust uses attributes, not decorators
                    docstring,
                    is_async,
                    is_generator: false, // Rust doesn't have generators (yet)
                    signature: Some(signature),
                    body: Some(body),
                });
            }
        }

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let query = Query::new(
            &tree_sitter_rust::LANGUAGE.into(),
            r#"
            (use_declaration
                argument: (_) @import_path) @import
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut captures = cursor.captures(&query, root, ast.content.as_bytes());

        let mut imports = Vec::new();
        while let Some(&(ref m, _)) = captures.next() {
            for capture in m.captures {
                if capture.index == 1 {
                    let path = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let _end = capture.node.end_position().row + 1;
                    imports.push(Import {
                        module: path,
                        items: Vec::new(),
                        line: start as u32,
                    });
                }
            }
        }

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let query = Query::new(
            &tree_sitter_rust::LANGUAGE.into(),
            r#"
            (line_comment) @comment
            (block_comment) @comment
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut captures = cursor.captures(&query, root, ast.content.as_bytes());

        let mut comments = Vec::new();
        while let Some(&(ref m, _)) = captures.next() {
            for capture in m.captures {
                let text = capture
                    .node
                    .utf8_text(ast.content.as_bytes())
                    .unwrap_or_default()
                    .to_owned();
                let start = capture.node.start_position().row + 1;
                let kind = if text.trim_start().starts_with("/*") {
                    "block".to_string()
                } else {
                    "line".to_string()
                };
                comments.push(Comment {
                    content: text,
                    line: start as u32,
                    column: (capture.node.start_position().column + 1) as u32,
                    kind,
                });
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "rust"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["rs"]
    }
}

/// Extract Rust doc comments (///) before a function
fn extract_rust_doc_comment(node: tree_sitter::Node, source: &str) -> Option<String> {
    let mut doc_lines = Vec::new();
    let mut current = node.prev_sibling();

    // Collect doc comments in reverse order
    while let Some(sibling) = current {
        if sibling.kind() == "line_comment" {
            if let Ok(text) = sibling.utf8_text(source.as_bytes()) {
                let trimmed = text.trim();
                if trimmed.starts_with("///") && !trimmed.starts_with("////") {
                    let content = trimmed.trim_start_matches("///").trim();
                    doc_lines.insert(0, content.to_string());
                    current = sibling.prev_sibling();
                    continue;
                }
            }
        }
        break;
    }

    if doc_lines.is_empty() {
        None
    } else {
        Some(doc_lines.join("\n"))
    }
}
