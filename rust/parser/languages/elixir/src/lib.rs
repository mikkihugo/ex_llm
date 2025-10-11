//! Elixir parser implemented with tree-sitter and the parser-framework traits.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor};

/// Elixir language parser backed by tree-sitter.
pub struct ElixirParser {
    parser: Mutex<Parser>,
}

impl ElixirParser {
    /// Create a new Elixir parser instance.
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_elixir::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for ElixirParser {
    fn default() -> Self {
        Self::new().expect("Elixir parser initialisation must succeed")
    }
}

impl LanguageParser for ElixirParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse Elixir code".into()))?;

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
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (call
              target: (identifier) @func_name
            ) @function

            (def
              name: (identifier) @func_name
            ) @function

            (defp
              name: (identifier) @func_name
            ) @function
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let captures = cursor.captures(&query, root, ast.source.as_bytes());

        let mut functions = Vec::new();
        for (m, _) in captures {
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
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (alias
              (identifier) @module
            ) @import

            (import
              (identifier) @module
            ) @import

            (require
              (identifier) @module
            ) @import
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let captures = cursor.captures(&query, root, ast.source.as_bytes());

        let mut imports = Vec::new();
        for (m, _) in captures {
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
            &tree_sitter_elixir::LANGUAGE.into(),
            r#"
            (comment) @comment
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let captures = cursor.captures(&query, root, ast.source.as_bytes());

        let mut comments = Vec::new();
        for (m, _) in captures {
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
        "elixir"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["ex", "exs"]
    }
}
