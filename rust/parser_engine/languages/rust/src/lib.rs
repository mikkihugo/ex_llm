//! Rust parser backed by tree-sitter for use with the parser framework.

use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
    comprehensive_analysis::{
        ComprehensiveAnalyzer, ComprehensiveAnalysisConfig, ComprehensiveAnalysisResult,
    },
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

        Ok(LanguageMetrics {
            lines_of_code: ast.content.lines().count() as u64,
            lines_of_comments: comments.len() as u64,
            blank_lines: 0, // TODO: implement blank line counting
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: 0, // Rust doesn't have classes (uses structs/impls)
            complexity_score: 0.0, // TODO: implement complexity calculation
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
                let end = fn_node.end_position().row + 1;
                let body = body_range
                    .and_then(|range| ast.content.get(range.clone()))
                    .unwrap_or_default()
                    .to_owned();

                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.unwrap_or("").split(',').map(|s| s.trim().to_owned()).collect(),
                    return_type: Some(return_type.unwrap_or("()").to_owned()),
                    line_start: start as u32,
                    line_end: end as u32,
                    complexity: 1, // TODO: implement complexity calculation
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
                    let end = capture.node.end_position().row + 1;
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
                let end = capture.node.end_position().row + 1;
                let kind = if text.trim_start().starts_with("/*") {
                    "block"
                } else {
                    "line"
                };
                comments.push(Comment {
                    content: text,
                    line: start as u32,
                    column: (capture.node.start_position().column + 1) as u32,
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
