//! YAML parser implemented with tree-sitter and the parser-framework traits.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::Parser;

/// YAML language parser backed by tree-sitter.
pub struct YamlParser {
    parser: Mutex<Parser>,
}

impl YamlParser {
    /// Create a new YAML parser instance.
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_yaml::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for YamlParser {
    fn default() -> Self {
        Self::new().expect("YAML parser initialisation must succeed")
    }
}

impl LanguageParser for YamlParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse YAML".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let comments = self.get_comments(ast)?;

        Ok(LanguageMetrics {
            lines_of_code: ast.source.lines().count(),
            functions_count: 0,
            imports_count: 0,
            comments_count: comments.len(),
            ..LanguageMetrics::default()
        })
    }

    fn get_functions(&self, _ast: &AST) -> Result<Vec<Function>, ParseError> {
        // YAML has no functions
        Ok(Vec::new())
    }

    fn get_imports(&self, _ast: &AST) -> Result<Vec<Import>, ParseError> {
        // YAML has no imports
        Ok(Vec::new())
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        use tree_sitter::{Query, QueryCursor, StreamingIterator};

        let query = Query::new(
            &tree_sitter_yaml::LANGUAGE.into(),
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
        "yaml"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["yaml", "yml"]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_yaml() {
        let parser = YamlParser::new().unwrap();
        let content = "key: value\nnumber: 42";
        let result = parser.parse(content);
        assert!(result.is_ok());
    }
}
