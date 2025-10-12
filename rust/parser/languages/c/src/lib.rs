//! C parser implemented with tree-sitter.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor, StreamingIterator};

/// C language parser backed by tree-sitter.
pub struct CParser {
    parser: Mutex<Parser>,
}

impl CParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_c::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for CParser {
    fn default() -> Self {
        Self::new().expect("C parser initialisation must succeed")
    }
}

impl LanguageParser for CParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse C code".into()))?;
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
            &tree_sitter_c::LANGUAGE.into(),
            r#"
            (function_definition
                declarator: (function_declarator
                    declarator: (identifier) @function_name
                )
            ) @function
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let mut matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut functions = Vec::new();
        while let Some(m) = matches.next() {
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
            &tree_sitter_c::LANGUAGE.into(),
            r#"
            (preproc_include
              path: (string_literal) @module
            ) @import
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let mut matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut imports = Vec::new();
        while let Some(m) = matches.next() {
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
                        kind: "include".into(),
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
            &tree_sitter_c::LANGUAGE.into(),
            r#"
            (comment) @comment
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let mut matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut comments = Vec::new();
        while let Some(m) = matches.next() {
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
        "c"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["c", "h"]
    }
}
