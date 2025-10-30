//! JSON parser implemented with tree-sitter and the parser-framework traits.

use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::Parser;

/// JSON language parser backed by tree-sitter.
pub struct JsonParser {
    parser: Mutex<Parser>,
}

impl JsonParser {
    /// Create a new JSON parser instance.
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_json::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for JsonParser {
    fn default() -> Self {
        Self::new().expect("JSON parser initialisation must succeed")
    }
}

impl LanguageParser for JsonParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse JSON".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        // JSON doesn't have traditional code metrics, but we can count objects/arrays
        Ok(LanguageMetrics {
            lines_of_code: ast.content.lines().count() as u64,
            lines_of_comments: 0, // JSON doesn't have comments
            blank_lines: 0,       // TODO: implement blank line counting
            total_lines: ast.content.lines().count() as u64,
            functions: 0,          // JSON doesn't have functions
            classes: 0,            // JSON doesn't have classes
            imports: 0,            // JSON doesn't have imports
            complexity_score: 0.0, // TODO: implement complexity calculation
        })
    }

    fn get_functions(&self, _ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        // JSON has no functions
        Ok(Vec::new())
    }

    fn get_imports(&self, _ast: &AST) -> Result<Vec<Import>, ParseError> {
        // JSON has no imports
        Ok(Vec::new())
    }

    fn get_comments(&self, _ast: &AST) -> Result<Vec<Comment>, ParseError> {
        // Standard JSON has no comments (though some parsers support them)
        Ok(Vec::new())
    }

    fn get_language(&self) -> &str {
        "json"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["json"]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_json() {
        let parser = JsonParser::new().unwrap();
        let content = r#"{"key": "value", "number": 42}"#;
        let result = parser.parse(content);
        assert!(result.is_ok());
    }

    #[test]
    fn test_json_metrics() {
        let parser = JsonParser::new().unwrap();
        let content = r#"{
            "name": "test",
            "version": "1.0.0"
        }"#;
        let ast = parser.parse(content).unwrap();
        let metrics = parser.get_metrics(&ast).unwrap();
        assert_eq!(metrics.lines_of_code, 4);
        assert_eq!(metrics.functions, 0);
    }
}
