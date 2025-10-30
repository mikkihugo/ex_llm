//! Clojure parser implemented with tree-sitter and the parser-framework traits.

use parser_core::{
    Class, Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Tree};
use tree_sitter::StreamingIterator;

pub const VERSION: &str = "clojure-tree-sitter-0.1";

pub struct ClojureParser {
    parser: Mutex<Parser>,
}

impl ClojureParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        let language = tree_sitter_clojure::LANGUAGE.into();
        parser
            .set_language(&language)
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }

    fn parse_tree(&self, source: &str) -> Option<Tree> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        parser.parse(source, None)
    }

    #[allow(dead_code)]
    fn get_classes(&self, _ast: &AST) -> Result<Vec<Class>, ParseError> {
        // Clojure is functional - no classes
        Ok(Vec::new())
    }
}

impl Default for ClojureParser {
    fn default() -> Self {
        Self::new().expect("Clojure parser initialisation must succeed")
    }
}

impl LanguageParser for ClojureParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let tree = self
            .parse_tree(content)
            .ok_or_else(|| ParseError::ParseError("failed to parse Clojure code".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;

        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "clojure").unwrap_or((
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
            classes: 0, // Clojure doesn't use classes
            imports: imports.len() as u64,
            complexity_score,
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let mut functions = Vec::new();

        visit_nodes(ast.tree.root_node(), "list_lit", &mut |node| {
            // Check if this is a defn (function definition)
            if let Some(first) = node.named_child(0) {
                if first.kind() == "sym_lit" {
                    let symbol = first
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default();

                    if symbol == "defn" {
                        if let Some(name_node) = node.named_child(1) {
                            let name = name_node
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .to_string();

                            let params = if let Some(params_node) = node.named_child(2) {
                                if params_node.kind() == "vec_lit" {
                                    params_node
                                        .utf8_text(ast.content.as_bytes())
                                        .unwrap_or("[]")
                                        .to_string()
                                } else {
                                    "[]".to_string()
                                }
                            } else {
                                "[]".to_string()
                            };

                            functions.push(FunctionInfo {
                                name: name.clone(),
                                parameters: Vec::new(),
                                return_type: None,
                                line_start: (node.start_position().row + 1) as u32,
                                line_end: (node.end_position().row + 1) as u32,
                                complexity: 0,
                                decorators: Vec::new(),
                                docstring: None,
                                is_async: false,
                                is_generator: false,
                                signature: Some(format!("(defn {} {})", name, params)),
                                body: Some(slice_text(node, &ast.content)),
                            });
                        }
                    }
                }
            }
        });

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let mut imports = Vec::new();

        visit_nodes(ast.tree.root_node(), "list_lit", &mut |node| {
            if let Some(first) = node.named_child(0) {
                if first.kind() == "sym_lit" {
                    let symbol = first
                        .utf8_text(ast.content.as_bytes())
                        .unwrap_or_default();

                    if symbol == "require" || symbol == "use" {
                        if let Some(arg) = node.named_child(1) {
                            let module = arg
                                .utf8_text(ast.content.as_bytes())
                                .unwrap_or_default()
                                .trim_matches(|c| c == '\'' || c == ':')
                                .to_string();

                            imports.push(Import {
                                module,
                                items: Vec::new(),
                                line: (node.start_position().row + 1) as u32,
                            });
                        }
                    }
                }
            }
        });

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let language = &tree_sitter_clojure::LANGUAGE.into();
        let query = tree_sitter::Query::new(language, r#"(comment) @comment"#)
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
                comments.push(Comment {
                    content: text.to_string(),
                    line: (capture.node.start_position().row + 1) as u32,
                    column: 0,
                    kind: "line".to_string(),
                });
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "clojure"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["clj", "cljs", "cljc", "edn"]
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
    fn parses_basic_function() {
        let parser = ClojureParser::default();
        let source = r#"
(defn add [a b]
  (+ a b))
"#;

        let ast = parser.parse(source).expect("clojure parse");
        let functions = parser.get_functions(&ast).expect("function extraction");

        assert_eq!(functions.len(), 1);
        assert_eq!(functions[0].name, "add");
    }
}
