//! Ruby parser implemented with tree-sitter and the parser-framework traits.

use parser_core::{
    Class, Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError,
    AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Tree};
use tree_sitter::StreamingIterator;

pub const VERSION: &str = "ruby-tree-sitter-0.21";

pub struct RubyParser {
    parser: Mutex<Parser>,
}

impl RubyParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_ruby::language())
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

        visit_nodes(ast.tree.root_node(), "class", &mut |node| {
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

impl Default for RubyParser {
    fn default() -> Self {
        Self::new().expect("Ruby parser initialisation must succeed")
    }
}

impl LanguageParser for RubyParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let tree = self
            .parse_tree(content)
            .ok_or_else(|| ParseError::ParseError("failed to parse Ruby code".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;
        let classes = self.get_classes(ast)?;

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "ruby").unwrap_or((
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

        visit_nodes(ast.tree.root_node(), "method", &mut |node| {
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

            functions.push(FunctionInfo {
                name: name.to_string(),
                parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                return_type: None,
                line_start: (node.start_position().row + 1) as u32,
                line_end: (node.end_position().row + 1) as u32,
                complexity: 0,
                decorators: Vec::new(),
                docstring: None,
                is_async: false,
                is_generator: false,
                signature: Some(format!("def {}{}", name, params)),
                body: Some(body),
            });
        });

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let language = tree_sitter_ruby::language();
        let query = tree_sitter::Query::new(
            &language,
            r#"
            (require (string) @module)
            (require_relative (string) @module)
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = tree_sitter::QueryCursor::new();
        let mut imports = Vec::new();

        let mut captures = cursor.captures(&query, ast.tree.root_node(), ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            for capture in m.captures {
                let text = capture
                    .node
                    .utf8_text(ast.content.as_bytes())
                    .unwrap_or_default();
                let module = clean_string_literal(text);
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
        let language = tree_sitter_ruby::language();
        let query = tree_sitter::Query::new(&language, r#"(comment) @comment"#)
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
                comments.push(Comment {
                    content: text.to_string(),
                    line: start as u32,
                    column: 0,
                    kind: "line".to_string(),
                });
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "ruby"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["rb"]
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

fn clean_string_literal(literal: &str) -> String {
    let mut s = literal.trim();
    while let Some(first) = s.chars().next() {
        if !first.is_alphanumeric() && first != '_' {
            s = &s[1..];
        } else {
            break;
        }
    }

    for quote in ["\"", "'", "%q(", "%Q("] {
        if s.starts_with(quote) {
            let end_quote = if quote == "%q(" || quote == "%Q(" {
                ")"
            } else {
                quote
            };

            if s.ends_with(end_quote) && s.len() >= quote.len() + end_quote.len() {
                return s[quote.len()..s.len() - end_quote.len()].to_string();
            }
        }
    }
    s.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic_method() {
        let parser = RubyParser::default();
        let source = r#"
def add(a, b)
  a + b
end
"#;

        let ast = parser.parse(source).expect("ruby parse");
        let functions = parser.get_functions(&ast).expect("function extraction");

        assert_eq!(functions.len(), 1);
        let func = &functions[0];
        assert_eq!(func.name, "add");
    }
}
