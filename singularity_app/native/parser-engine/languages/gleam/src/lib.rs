//! Gleam parser implemented with tree-sitter.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor};

/// Gleam language parser backed by tree-sitter.
pub struct GleamParser {
    parser: Mutex<Parser>,
}

impl GleamParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(unsafe { tree_sitter_gleam::LANGUAGE() })
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for GleamParser {
    fn default() -> Self {
        Self::new().expect("Gleam parser initialisation must succeed")
    }
}

impl LanguageParser for GleamParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse Gleam code".into()))?;
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
            unsafe { tree_sitter_gleam::LANGUAGE() },
            r#"
            (function
              name: (identifier) @func_name
            ) @function
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut functions = Vec::new();
        for m in matches {
            for capture in m.captures {
                if capture.index == 1 {
                    let name = capture
                        .node
                        .utf8_text(ast.source.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let end = capture.node.end_position().row + 1;
                    functions.push(Function {
                        name,
                        parameters: String::new(),
                        return_type: String::new(),
                        start_line: start,
                        end_line: end,
                        body: String::new(),
                        signature: None,
                        docstring: None,
                        decorators: Vec::new(),
                        is_async: false,
                        is_generator: false,
                    });
                }
            }
        }

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let query = Query::new(
            unsafe { tree_sitter_gleam::LANGUAGE() },
            r#"
            (import
              name: (identifier) @module
            ) @import
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
                        kind: "import".into(),
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
            unsafe { tree_sitter_gleam::LANGUAGE() },
            r#"
            (comment) @comment
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut comments = Vec::new();
        for m in matches {
            for capture in m.captures {
                if capture.index == 0 {
                    let text = capture
                        .node
                        .utf8_text(ast.source.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let end = capture.node.end_position().row + 1;
                    comments.push(Comment {
                        text,
                        kind: "line".into(),
                        start_line: start,
                        end_line: end,
                    });
                }
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "gleam"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["gleam"]
    }
}
