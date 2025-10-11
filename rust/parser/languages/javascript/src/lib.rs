//! JavaScript parser backed by tree-sitter.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Query, QueryCursor};

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

        Ok(LanguageMetrics {
            lines_of_code: ast.source.lines().count(),
            functions_count: functions.len(),
            imports_count: imports.len(),
            comments_count: comments.len(),
            ..LanguageMetrics::default()
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<Function>, ParseError> {
        let language = &tree_sitter_javascript::LANGUAGE.into();
        let mut cursor = QueryCursor::new();
        let root = ast.root();

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
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        for (m, _) in cursor.captures(&fn_query, root, ast.source.as_bytes()).into_iter() {
            let mut name = "";
            let mut params = "";
            let mut body = "";
            let mut node = None;

            for capture in m.captures {
                match capture.index {
                    0 => node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.source),
                    2 => params = Self::extract_text(capture.node, &ast.source),
                    3 => body = Self::extract_text(capture.node, &ast.source),
                    _ => {}
                }
            }

            if let Some(node) = node {
                functions.push(Function {
                    name: name.to_owned(),
                    parameters: params.to_owned(),
                    return_type: "any".into(),
                    start_line: node.start_position().row + 1,
                    end_line: node.end_position().row + 1,
                    body: body.to_owned(),
                    signature: None,
                    docstring: None,
                    decorators: Vec::new(),
                    is_async: false,
                    is_generator: false,
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
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        for (m, _) in cursor.captures(&arrow_query, root, ast.source.as_bytes()).into_iter() {
            let mut name = "";
            let mut params = "";
            let mut body = "";
            let mut node = None;

            for capture in m.captures {
                match capture.index {
                    0 => node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.source),
                    2 => params = Self::extract_text(capture.node, &ast.source),
                    3 => body = Self::extract_text(capture.node, &ast.source),
                    _ => {}
                }
            }

            if let Some(node) = node {
                functions.push(Function {
                    name: name.to_owned(),
                    parameters: params.to_owned(),
                    return_type: "any".into(),
                    start_line: node.start_position().row + 1,
                    end_line: node.end_position().row + 1,
                    body: body.to_owned(),
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
            &tree_sitter_javascript::LANGUAGE.into(),
            r#"
            (import_statement
                source: (string) @path) @import
        "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut imports = Vec::new();
        for (m, _) in matches.into_iter() {
            let mut path = "";
            let mut node = None;
            for capture in m.captures {
                if capture.index == 0 {
                    node = Some(capture.node);
                } else if capture.index == 1 {
                    path = Self::extract_text(capture.node, &ast.source);
                }
            }

            if let Some(node) = node {
                let clean_path = path.trim_matches(|c| c == '"' || c == '\'').to_owned();
                imports.push(Import {
                    path: clean_path,
                    kind: "import".into(),
                    start_line: node.start_position().row + 1,
                    end_line: node.end_position().row + 1,
                    alias: None,
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
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = QueryCursor::new();
        let root = ast.root();
        let matches = cursor.matches(&query, root, ast.source.as_bytes());

        let mut comments = Vec::new();
        for (m, _) in matches.into_iter() {
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
        "javascript"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["js", "mjs", "cjs"]
    }
}
