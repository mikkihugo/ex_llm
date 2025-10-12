//! Bash/Shell parser implemented with tree-sitter and the parser-framework traits.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor, StreamingIterator};

/// Bash language parser backed by tree-sitter.
pub struct BashParser {
    parser: Mutex<Parser>,
}

impl BashParser {
    /// Create a new Bash parser instance.
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_bash::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for BashParser {
    fn default() -> Self {
        Self::new().expect("Bash parser initialisation must succeed")
    }
}

impl LanguageParser for BashParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse Bash script".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let comments = self.get_comments(ast)?;

        Ok(LanguageMetrics {
            lines_of_code: ast.source.lines().count(),
            functions_count: functions.len(),
            imports_count: 0,
            comments_count: comments.len(),
            ..LanguageMetrics::default()
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<Function>, ParseError> {
        let query = Query::new(
            &tree_sitter_bash::LANGUAGE.into(),
            r#"
            (function_definition
              name: (word) @func_name
            ) @function
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let mut captures = cursor.captures(&query, root, ast.source.as_bytes());

        let mut functions = Vec::new();
        while let Some(&(ref m, _)) = captures.next() {
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

    fn get_imports(&self, _ast: &AST) -> Result<Vec<Import>, ParseError> {
        // Bash has "source" statements but we'll keep it simple for now
        Ok(Vec::new())
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let query = Query::new(
            &tree_sitter_bash::LANGUAGE.into(),
            r#"
            (comment) @comment
            "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let mut captures = cursor.captures(&query, root, ast.source.as_bytes());

        let mut comments = Vec::new();
        while let Some(&(ref m, _)) = captures.next() {
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
        "bash"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["sh", "bash"]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_bash() {
        let parser = BashParser::new().unwrap();
        let content = r#"#!/bin/bash
function hello() {
    echo "Hello, World!"
}
"#;
        let result = parser.parse(content);
        assert!(result.is_ok());
    }

    #[test]
    fn test_bash_functions() {
        let parser = BashParser::new().unwrap();
        let content = r#"function test_func() {
    echo "test"
}
"#;
        let ast = parser.parse(content).unwrap();
        let functions = parser.get_functions(&ast).unwrap();
        assert_eq!(functions.len(), 1);
        assert_eq!(functions[0].name, "test_func");
    }
}
