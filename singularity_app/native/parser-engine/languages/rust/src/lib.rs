//! Rust parser backed by tree-sitter for use with the parser framework.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor};

pub struct RustParser {
    parser: Mutex<Parser>,
}

impl RustParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(unsafe { tree_sitter_rust::LANGUAGE() })
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

        Ok(LanguageMetrics {
            lines_of_code: ast.source.lines().count(),
            functions_count: functions.len(),
            imports_count: imports.len(),
            comments_count: comments.len(),
            ..LanguageMetrics::default()
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<Function>, ParseError> {
        let query = Query::new(
            unsafe { tree_sitter_rust::LANGUAGE() },
            r#"
            (function_item
                name: (identifier) @function_name
                parameters: (parameters) @parameters
                return_type: (type_identifier)? @return_type
                body: (block) @body) @function
        "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut functions = Vec::new();
        for m in matches {
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
                                .utf8_text(ast.source.as_bytes())
                                .unwrap_or_default(),
                        )
                    }
                    2 => {
                        params = Some(
                            capture
                                .node
                                .utf8_text(ast.source.as_bytes())
                                .unwrap_or_default(),
                        )
                    }
                    3 => {
                        return_type = Some(
                            capture
                                .node
                                .utf8_text(ast.source.as_bytes())
                                .unwrap_or_default(),
                        )
                    }
                    4 => body_range = Some(capture.node.byte_range()),
                    _ => {}
                }
            }

            if let (Some(name), Some(fn_node)) = (name, fn_node) {
                let start = fn_node.start_position().row + 1;
                let end = fn_node.end_position().row + 1;
                let body = body_range
                    .and_then(|range| ast.source.get(range.clone()))
                    .unwrap_or_default()
                    .to_owned();

                functions.push(Function {
                    name: name.to_owned(),
                    parameters: params.unwrap_or("").to_owned(),
                    return_type: return_type.unwrap_or("()").to_owned(),
                    start_line: start,
                    end_line: end,
                    body,
                    signature: None,
                    docstring: None,
                    decorators: Vec::new(),
                    is_async: false,
                    is_generator: false,
                });
            }
        }

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let query = Query::new(
            unsafe { tree_sitter_rust::LANGUAGE() },
            r#"
            (use_declaration
                argument: (_) @import_path) @import
        "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut imports = Vec::new();
        for m in matches {
            for capture in m.captures {
                if capture.index == 1 {
                    let path = capture
                        .node
                        .utf8_text(ast.source.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let end = capture.node.end_position().row + 1;
                    imports.push(Import {
                        path,
                        kind: "use".into(),
                        start_line: start,
                        end_line: end,
                        alias: None,
                    });
                }
            }
        }

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let query = Query::new(
            unsafe { tree_sitter_rust::LANGUAGE() },
            r#"
            (line_comment) @comment
            (block_comment) @comment
        "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut comments = Vec::new();
        for m in matches {
            for capture in m.captures {
                let text = capture
                    .node
                    .utf8_text(ast.source.as_bytes())
                    .unwrap_or_default()
                    .to_owned();
                let start = capture.node.start_position().row + 1;
                let end = capture.node.end_position().row + 1;
                let kind = if text.trim_start().starts_with("/*") {
                    "block"
                } else {
                    "line"
                };
                comments.push(Comment {
                    text,
                    kind: kind.into(),
                    start_line: start,
                    end_line: end,
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
