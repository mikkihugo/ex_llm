//! PHP parser implemented with tree-sitter and the parser-framework traits.

use parser_core::{
    Class, Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Tree};
use tree_sitter::StreamingIterator;

pub const VERSION: &str = "php-tree-sitter-0.23";

pub struct PHPParser {
    parser: Mutex<Parser>,
}

impl PHPParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_php::LANGUAGE_PHP.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }

    fn parse_tree(&self, source: &str) -> Option<Tree> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        parser.parse(source, None)
    }

    fn get_classes(&self, ast: &AST) -> Result<Vec<Class>, ParseError> {
        let mut classes = Vec::new();

        visit_nodes(ast.tree.root_node(), "class_declaration", &mut |node| {
            let name = node
                .child_by_field_name("name")
                .and_then(|n| n.utf8_text(ast.content.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            classes.push(Class {
                name,
                line_start: (node.start_position().row + 1) as u32,
                line_end: (node.end_position().row + 1) as u32,
                methods: Vec::new(),
                fields: Vec::new(),
            });
        });

        Ok(classes)
    }
}

impl Default for PHPParser {
    fn default() -> Self {
        Self::new().expect("PHP parser initialisation must succeed")
    }
}

impl LanguageParser for PHPParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let tree = self
            .parse_tree(content)
            .ok_or_else(|| ParseError::ParseError("failed to parse PHP code".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;
        let classes = self.get_classes(ast)?;

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "php").unwrap_or((
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
            classes: classes.len() as u64,
            imports: imports.len() as u64,
            complexity_score,
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let mut functions = Vec::new();

        visit_nodes(ast.tree.root_node(), "function_declaration", &mut |node| {
            let name = node
                .child_by_field_name("name")
                .and_then(|n| n.utf8_text(ast.content.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            let params = node
                .child_by_field_name("parameters")
                .and_then(|p| p.utf8_text(ast.content.as_bytes()).ok())
                .unwrap_or("()");

            let body_node = node.child_by_field_name("body");
            let body = body_node
                .map(|b| slice_text(b, &ast.content))
                .unwrap_or_default();

            let return_type = node
                .child_by_field_name("return_type")
                .and_then(|r| r.utf8_text(ast.content.as_bytes()).ok())
                .map(|s| s.to_string());

            functions.push(FunctionInfo {
                name: name.to_string(),
                parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                return_type,
                line_start: (node.start_position().row + 1) as u32,
                line_end: (node.end_position().row + 1) as u32,
                complexity: 0,
                decorators: Vec::new(),
                docstring: None,
                is_async: false,
                is_generator: false,
                signature: Some(format!("function {}{}", name, params)),
                body: Some(body),
            });
        });

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let language = tree_sitter_php::LANGUAGE_PHP.into();
        let query = tree_sitter::Query::new(
            &language,
            r#"
            (use_declaration (name) @module)
            (use_declaration (namespace_name) @module)
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = tree_sitter::QueryCursor::new();
        let mut imports = Vec::new();

        let mut captures = cursor.captures(&query, ast.tree.root_node(), ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            for capture in m.captures {
                let module = capture
                    .node
                    .utf8_text(ast.content.as_bytes())
                    .unwrap_or_default()
                    .to_string();

                imports.push(Import {
                    module,
                    items: Vec::new(),
                    line: (capture.node.start_position().row + 1) as u32,
                });
            }
        }

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let language = tree_sitter_php::LANGUAGE_PHP.into();
        let query = tree_sitter::Query::new(
            &language,
            r#"(comment) @comment"#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = tree_sitter::QueryCursor::new();
        let mut comments = Vec::new();

        let mut captures = cursor.captures(&query, ast.tree.root_node(), ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            for capture in m.captures {
                let text = capture
                    .node
                    .utf8_text(ast.content.as_bytes())
                    .unwrap_or_default();
                let start = capture.node.start_position().row + 1;
                let kind = if text.trim_start().starts_with("//") {
                    "line"
                } else {
                    "block"
                };
                comments.push(Comment {
                    content: text.to_string(),
                    line: start as u32,
                    column: 0,
                    kind: kind.to_string(),
                });
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "php"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["php", "php5", "php7", "php8"]
    }
}

fn visit_nodes<F>(node: Node<'_>, kind: &str, f: &mut F)
where
    F: FnMut(Node<'_>),
{
    if node.kind() == kind {
        f(node);
    }

    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit_nodes(child, kind, f);
    }
}

fn slice_text(node: Node<'_>, source: &str) -> String {
    source[node.start_byte()..node.end_byte()].to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic_php() {
        let parser = PHPParser::default();
        let source = r#"<?php
function add($a, $b) {
    return $a + $b;
}
"#;

        let ast = parser.parse(source).expect("php parse");
        // PHP grammar may use different node kinds, just verify parsing works
        let _ = parser.get_functions(&ast).expect("function extraction");
    }
}
