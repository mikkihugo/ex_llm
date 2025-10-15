//! C++ parser implemented with tree-sitter.

use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Parser, Query, QueryCursor, StreamingIterator};

/// C++ language parser backed by tree-sitter.
pub struct CppParser {
    parser: Mutex<Parser>,
}

impl CppParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_cpp::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }
}

impl Default for CppParser {
    fn default() -> Self {
        Self::new().expect("C++ parser initialisation must succeed")
    }
}

impl LanguageParser for CppParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse C++ code".into()))?;
        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "cpp")
                .unwrap_or((1.0, ast.content.lines().count() as u64, ast.content.lines().count() as u64, comments.len() as u64, 0));

        Ok(LanguageMetrics {
            lines_of_code: ploc.saturating_sub(blank_lines + cloc),
            lines_of_comments: cloc,
            blank_lines,
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: 0, // C++ has classes but not parsed here
            complexity_score, // Real cyclomatic complexity from RCA!
            imports: imports.len() as u64
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let query = Query::new(
            &tree_sitter_cpp::LANGUAGE.into(),
            r#"
            (function_definition
                declarator: (function_declarator
                    declarator: (identifier) @function_name
                )
            ) @function
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut functions = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 1 {
                    let name = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let _end = capture.node.end_position().row + 1;
                    functions.push(FunctionInfo {
                        name,
                        parameters: Vec::new(),
                        return_type: None,
                        line_start: start as u32,
                        line_end: _end as u32,
                        complexity: 1, // TODO: implement complexity calculation
                        decorators: Vec::new(),
                        docstring: None,
                        is_async: false,
                        is_generator: false,
                        signature: None,
                        body: None,
                    });
                }
            }
        }

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let query = Query::new(
            &tree_sitter_cpp::LANGUAGE.into(),
            r#"
            (preproc_include
              path: (string_literal) @module
            ) @import
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut imports = Vec::new();
        while let Some(m) = matches.next() {
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
            &tree_sitter_cpp::LANGUAGE.into(),
            r#"
            (comment) @comment
            "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut comments = Vec::new();
        while let Some(m) = matches.next() {
            for capture in m.captures {
                if capture.index == 0 {
                    let text = capture
                        .node
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default()
                        .to_owned();
                    let start = capture.node.start_position().row + 1;
                    let _end = capture.node.end_position().row + 1;
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
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "cpp"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["cpp", "cc", "cxx", "hpp", "hxx", "h"]
    }
}
