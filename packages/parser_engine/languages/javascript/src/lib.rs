//! JavaScript parser backed by tree-sitter.

use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Query, QueryCursor, StreamingIterator};

pub struct JavascriptParser {
    parser: Mutex<Parser>,
}

impl JavascriptParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_javascript::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }

    fn extract_text<'a>(node: Node<'a>, source: &'a str) -> &'a str {
        node.utf8_text(source.as_bytes()).unwrap_or_default()
    }
}

impl Default for JavascriptParser {
    fn default() -> Self {
        Self::new().expect("JavaScript parser initialisation must succeed")
    }
}

impl LanguageParser for JavascriptParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        let tree = parser
            .parse(content, None)
            .ok_or_else(|| ParseError::ParseError("failed to parse JavaScript code".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "javascript").unwrap_or((
                1.0,
                ast.content.lines().count() as u64,
                ast.content.lines().count() as u64,
                comments.len() as u64,
                0,
            ));

        Ok(LanguageMetrics {
            lines_of_code: ploc.saturating_sub(blank_lines + cloc),
            lines_of_comments: cloc,
            blank_lines,
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: 0, // TODO: implement class counting
            imports: imports.len() as u64,
            complexity_score, // Real cyclomatic complexity from RCA!
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let language = &tree_sitter_javascript::LANGUAGE.into();
        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();

        let mut functions = Vec::new();

        let fn_query = Query::new(
            language,
            r#"
            (function_declaration
                name: (identifier) @name
                parameters: (formal_parameters) @params
                body: (statement_block) @body) @function
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut captures = cursor.captures(&fn_query, root, ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            let mut name = "";
            let mut params = "";
            let mut body = "";
            let mut node = None;

            for capture in m.captures {
                match capture.index {
                    0 => node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.content),
                    2 => params = Self::extract_text(capture.node, &ast.content),
                    3 => body = Self::extract_text(capture.node, &ast.content),
                    _ => {}
                }
            }

            if let Some(node) = node {
                let full_text = Self::extract_text(node, &ast.content);
                let is_async = full_text.trim_start().starts_with("async ");
                let is_generator = full_text.contains("function*") || body.contains("yield");
                let signature = format!("{}({})", name, params);

                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some("any".to_string()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
                    decorators: Vec::new(),
                    docstring: extract_jsdoc(node, &ast.content),
                    is_async,
                    is_generator,
                    signature: Some(signature),
                    body: Some(body.to_owned()),
                });
            }
        }

        let arrow_query = Query::new(
            language,
            r#"
            (variable_declarator
                name: (identifier) @name
                value: (arrow_function
                    parameters: (formal_parameters) @params
                    body: (_) @body)) @arrow
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut captures = cursor.captures(&arrow_query, root, ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            let mut name = "";
            let mut params = "";
            let mut body = "";
            let mut node = None;

            for capture in m.captures {
                match capture.index {
                    0 => node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.content),
                    2 => params = Self::extract_text(capture.node, &ast.content),
                    3 => body = Self::extract_text(capture.node, &ast.content),
                    _ => {}
                }
            }

            if let Some(node) = node {
                let full_text = Self::extract_text(node, &ast.content);
                let is_async = full_text.trim_start().starts_with("async ");
                let is_generator = body.contains("yield");
                let signature = format!("{}({})", name, params);

                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some("any".to_string()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
                    decorators: Vec::new(),
                    docstring: extract_jsdoc(node, &ast.content),
                    is_async,
                    is_generator,
                    signature: Some(signature),
                    body: Some(body.to_owned()),
                });
            }
        }

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let query = Query::new(
            &tree_sitter_javascript::LANGUAGE.into(),
            r#"
            (import_statement
                source: (string) @path) @import
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();
        let mut matches = cursor.matches(&query, root, ast.content.as_bytes());

        let mut imports = Vec::new();
        while let Some(m) = matches.next() {
            let mut path = "";
            let mut node = None;
            for capture in m.captures {
                if capture.index == 0 {
                    node = Some(capture.node);
                } else if capture.index == 1 {
                    path = Self::extract_text(capture.node, &ast.content);
                }
            }

            if let Some(node) = node {
                let clean_path = path.trim_matches(|c| c == '"' || c == '\'').to_owned();
                imports.push(Import {
                    module: clean_path,
                    items: Vec::new(),
                    line: (node.start_position().row + 1) as u32,
                });
            }
        }

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let query = Query::new(
            &tree_sitter_javascript::LANGUAGE.into(),
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
                let text = capture
                    .node
                    .utf8_text(ast.content.as_bytes())
                    .unwrap_or_default()
                    .to_owned();
                let position = capture.node.start_position();
                let kind = if text.trim_start().starts_with("/*") {
                    "block".to_string()
                } else {
                    "line".to_string()
                };
                comments.push(Comment {
                    content: text,
                    line: (position.row + 1) as u32,
                    column: (position.column + 1) as u32,
                    kind,
                });
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "javascript"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["js", "mjs", "cjs"]
    }
}

/// Extract JSDoc comment before a node
fn extract_jsdoc(node: tree_sitter::Node, source: &str) -> Option<String> {
    // Look for comment before the function
    if let Some(prev_sibling) = node.prev_sibling() {
        if prev_sibling.kind() == "comment" {
            let text = prev_sibling.utf8_text(source.as_bytes()).ok()?;
            if text.trim_start().starts_with("/**") {
                let cleaned = text
                    .trim()
                    .trim_start_matches("/**")
                    .trim_end_matches("*/")
                    .lines()
                    .map(|line| line.trim().trim_start_matches('*').trim())
                    .collect::<Vec<_>>()
                    .join("\n")
                    .trim()
                    .to_string();
                return Some(cleaned);
            }
        }
    }
    None
}
