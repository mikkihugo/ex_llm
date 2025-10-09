//! Python parser implemented with tree-sitter and the parser-framework traits.

use parser_framework::{
    Class, Comment, Decorator, Enum, EnumVariant, Function, Import, LanguageMetrics,
    LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Query, QueryCursor, Tree};

pub const VERSION: &str = "python-tree-sitter-0.23";

pub struct PythonParser {
    parser: Mutex<Parser>,
}

impl PythonParser {
    pub fn new() -> Result<Self, ParseError> {
        let mut parser = Parser::new();
        parser
            .set_language(&tree_sitter_python::LANGUAGE.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
        Ok(Self {
            parser: Mutex::new(parser),
        })
    }

    fn parse_tree(&self, source: &str) -> Option<Tree> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        parser.parse(source, None)
    }

    fn build_class_info(&self, ast: &AST) -> Vec<ClassInfo> {
        let mut infos = Vec::new();
        visit_nodes(ast.root(), "class_definition", &mut |node| {
            let name = node
                .child_by_field_name("name")
                .and_then(|n| n.utf8_text(ast.source.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            let bases = extract_bases(node, &ast.source);
            let decorators = collect_python_decorators(node, &ast.source);
            let body_node = node.child_by_field_name("body");
            let body = body_node
                .map(|b| slice_text(b, &ast.source))
                .unwrap_or_default();
            let docstring = body_node.and_then(|b| extract_docstring_from_block(b, &ast.source));
            let variants = body_node
                .map(|b| collect_enum_variants(b, &ast.source))
                .unwrap_or_default();
            let is_enum = bases.iter().any(|base| {
                base.rsplit('.')
                    .next()
                    .map(|p| p == "Enum")
                    .unwrap_or(false)
            });

            let class = Class {
                name: name.clone(),
                bases: bases.clone(),
                decorators: decorators.clone(),
                docstring: docstring.clone(),
                start_line: node.start_position().row + 1,
                end_line: node.end_position().row + 1,
                body,
            };

            infos.push(ClassInfo {
                class,
                enum_variants: variants,
                is_enum,
            });
        });

        infos
    }
}

impl Default for PythonParser {
    fn default() -> Self {
        Self::new().expect("Python parser initialisation must succeed")
    }
}

impl LanguageParser for PythonParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let tree = self
            .parse_tree(content)
            .ok_or_else(|| ParseError::ParseError("failed to parse Python code".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;
        let class_infos = self.build_class_info(ast);
        let enums = self.get_enums(ast)?;

        let docstring_count = functions.iter().filter(|f| f.docstring.is_some()).count()
            + class_infos
                .iter()
                .filter(|info| info.class.docstring.is_some())
                .count();

        Ok(LanguageMetrics {
            lines_of_code: ast.source.lines().count(),
            functions_count: functions.len(),
            imports_count: imports.len(),
            comments_count: comments.len(),
            classes_count: class_infos.len(),
            enums_count: enums.len(),
            docstrings_count: docstring_count,
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<Function>, ParseError> {
        let mut functions = Vec::new();

        visit_nodes(ast.root(), "function_definition", &mut |node| {
            let name = node
                .child_by_field_name("name")
                .and_then(|n| n.utf8_text(ast.source.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            let params = node
                .child_by_field_name("parameters")
                .and_then(|p| p.utf8_text(ast.source.as_bytes()).ok())
                .unwrap_or("()");

            let return_type = node
                .child_by_field_name("return_type")
                .and_then(|r| r.utf8_text(ast.source.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            let body_node = node.child_by_field_name("body");
            let body = body_node
                .map(|b| slice_text(b, &ast.source))
                .unwrap_or_default();
            let docstring = body_node.and_then(|b| extract_docstring_from_block(b, &ast.source));
            let decorators = collect_python_decorators(node, &ast.source);
            let is_async = is_async_function(node, &ast.source);
            let is_generator = is_generator_body(&body);
            let signature = Some(build_signature(&name, &params, &return_type));

            functions.push(Function {
                name: name.to_string(),
                parameters: params.to_string(),
                return_type: return_type.clone(),
                start_line: node.start_position().row + 1,
                end_line: node.end_position().row + 1,
                body,
                signature,
                docstring,
                decorators,
                is_async,
                is_generator,
            });
        });

        Ok(functions)
    }

    fn get_imports(&self, ast: &AST) -> Result<Vec<Import>, ParseError> {
        let language = &tree_sitter_python::LANGUAGE.into();
        let query = tree_sitter::Query::new(
            language,
            r#"
            (import_statement
                name: (dotted_name) @module) @import

            (import_from_statement
                module_name: (dotted_name)? @module) @from_import
        "#,
        )
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = tree_sitter::QueryCursor::new();
        let mut imports = Vec::new();

        for m in cursor.matches(&query, ast.root(), ast.source.as_bytes()) {
            let mut module = "";
            let mut kind = "import";
            let mut node_ref: Option<Node> = None;

            for capture in m.captures {
                match capture.index {
                    0 | 2 => {
                        module = capture
                            .node
                            .utf8_text(ast.source.as_bytes())
                            .unwrap_or_default();
                    }
                    1 => {
                        kind = "import";
                        node_ref = Some(capture.node);
                    }
                    3 => {
                        kind = "from";
                        node_ref = Some(capture.node);
                    }
                    _ => {}
                }
            }

            if let Some(node) = node_ref {
                imports.push(Import {
                    path: module.to_string(),
                    kind: kind.to_string(),
                    start_line: node.start_position().row + 1,
                    end_line: node.end_position().row + 1,
                    alias: None,
                });
            }
        }

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let language = &tree_sitter_python::LANGUAGE.into();
        let query = tree_sitter::Query::new(language, r#"(comment) @comment"#)
            .map_err(|err| ParseError::QueryError(err.to_string()))?;

        let mut cursor = tree_sitter::QueryCursor::new();
        let mut comments = Vec::new();

        for m in cursor.matches(&query, ast.root(), ast.source.as_bytes()) {
            for capture in m.captures {
                let text = capture
                    .node
                    .utf8_text(ast.source.as_bytes())
                    .unwrap_or_default();
                let start = capture.node.start_position().row + 1;
                let end = capture.node.end_position().row + 1;
                comments.push(Comment {
                    text: text.to_string(),
                    kind: "line".to_string(),
                    start_line: start,
                    end_line: end,
                });
            }
        }

        Ok(comments)
    }

    fn get_classes(&self, ast: &AST) -> Result<Vec<Class>, ParseError> {
        Ok(self
            .build_class_info(ast)
            .into_iter()
            .map(|info| info.class)
            .collect())
    }

    fn get_enums(&self, ast: &AST) -> Result<Vec<Enum>, ParseError> {
        let infos = self.build_class_info(ast);
        let mut enums = Vec::new();
        for info in infos {
            if info.is_enum {
                let ClassInfo {
                    class,
                    enum_variants,
                    is_enum: _,
                } = info;
                enums.push(Enum {
                    name: class.name,
                    variants: enum_variants,
                    decorators: class.decorators,
                    docstring: class.docstring,
                    start_line: class.start_line,
                    end_line: class.end_line,
                });
            }
        }
        Ok(enums)
    }

    fn get_language(&self) -> &str {
        "python"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["py"]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic_function_with_docstring() {
        let parser = PythonParser::default();
        let source = r#"
async def add(a, b):
    """Adds two numbers together."""
    return a + b
"#;

        let ast = parser.parse(source).expect("python parse");
        let functions = parser.get_functions(&ast).expect("function extraction");

        assert_eq!(functions.len(), 1);
        let func = &functions[0];
        assert!(func.is_async);
        assert!(func.signature.as_deref().unwrap().starts_with("add"));
        assert_eq!(
            func.docstring.as_deref(),
            Some("Adds two numbers together.")
        );
    }
}

/// Holder for class data and enums extracted from those classes.
struct ClassInfo {
    class: Class,
    enum_variants: Vec<EnumVariant>,
    is_enum: bool,
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

fn extract_docstring_from_block(body: Node<'_>, source: &str) -> Option<String> {
    let mut cursor = body.walk();
    for child in body.named_children(&mut cursor) {
        match child.kind() {
            "expression_statement" => {
                if let Some(expr) = child.named_child(0) {
                    if matches!(expr.kind(), "string" | "concatenated_string") {
                        let raw = expr.utf8_text(source.as_bytes()).ok()?;
                        return Some(clean_string_literal(raw));
                    }
                }
                return None;
            }
            "pass_statement" => continue,
            _ => break,
        }
    }
    None
}

fn clean_string_literal(literal: &str) -> String {
    let mut s = literal.trim();
    while let Some(first) = s.chars().next() {
        if first.is_ascii_alphabetic() {
            s = &s[1..];
        } else {
            break;
        }
    }

    for quote in ["\"\"\"", "'''", "\"", "'"] {
        if s.starts_with(quote) && s.ends_with(quote) && s.len() >= quote.len() * 2 {
            return s[quote.len()..s.len() - quote.len()].to_string();
        }
    }
    s.to_string()
}

fn collect_python_decorators(node: Node<'_>, source: &str) -> Vec<Decorator> {
    let mut decorators = Vec::new();
    if let Some(parent) = node.parent() {
        if parent.kind() == "decorated_definition" {
            let mut cursor = parent.walk();
            for child in parent.named_children(&mut cursor) {
                if child.kind() == "decorator" {
                    if let Ok(text) = child.utf8_text(source.as_bytes()) {
                        let text = text.trim().trim_start_matches('@');
                        let (name, arguments) = parse_decorator_text(text);
                        decorators.push(Decorator { name, arguments });
                    }
                }
            }
        }
    }
    decorators
}

fn parse_decorator_text(text: &str) -> (String, Vec<String>) {
    if let Some(idx) = text.find('(') {
        let name = text[..idx].trim().to_string();
        let inner = text[idx + 1..].trim_end_matches(')').trim();
        let arguments = if inner.is_empty() {
            Vec::new()
        } else {
            inner
                .split(',')
                .map(|arg| arg.trim().to_string())
                .filter(|arg| !arg.is_empty())
                .collect()
        };
        (name, arguments)
    } else {
        (text.trim().to_string(), Vec::new())
    }
}

fn is_async_function(node: Node<'_>, source: &str) -> bool {
    if let Some(first_child) = node.named_child(0) {
        if first_child.kind() == "identifier" {
            let prefix = slice_text(node, source);
            return prefix.trim_start().starts_with("async def");
        }
    }
    slice_text(node, source)
        .trim_start()
        .starts_with("async def")
}

fn is_generator_body(body: &str) -> bool {
    body.contains("yield")
}

fn build_signature(name: &str, params: &str, return_type: &str) -> String {
    let params = if params.is_empty() {
        "()".to_string()
    } else {
        params.to_string()
    };
    if return_type.trim().is_empty() {
        format!("{name}{params}")
    } else {
        format!("{name}{params} -> {}", return_type.trim())
    }
}

fn extract_bases(node: Node<'_>, source: &str) -> Vec<String> {
    if let Some(args) = node.child_by_field_name("arguments") {
        return split_arguments(slice_text(args, source));
    }

    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        if child.kind() == "argument_list" {
            return split_arguments(slice_text(child, source));
        }
    }

    Vec::new()
}

fn split_arguments(text: String) -> Vec<String> {
    let stripped = text.trim().trim_matches(|c| c == '(' || c == ')').trim();
    if stripped.is_empty() {
        return Vec::new();
    }
    stripped
        .split(',')
        .map(|base| base.trim().to_string())
        .filter(|base| !base.is_empty())
        .collect()
}

fn collect_enum_variants(body: Node<'_>, source: &str) -> Vec<EnumVariant> {
    let mut cursor = body.walk();
    let mut variants = Vec::new();
    for child in body.named_children(&mut cursor) {
        if child.kind() == "expression_statement" {
            if let Some(assignment) = child.named_child(0) {
                if assignment.kind() == "assignment" {
                    let mut assign_cursor = assignment.walk();
                    let mut name: Option<String> = None;
                    let mut value: Option<String> = None;
                    let mut first = true;
                    for part in assignment.named_children(&mut assign_cursor) {
                        if first {
                            name = part
                                .utf8_text(source.as_bytes())
                                .ok()
                                .map(|s| s.trim().to_string());
                            first = false;
                        } else {
                            value = part
                                .utf8_text(source.as_bytes())
                                .ok()
                                .map(|s| s.trim().to_string());
                            break;
                        }
                    }
                    if let Some(name) = name {
                        variants.push(EnumVariant {
                            name,
                            value,
                            start_line: assignment.start_position().row + 1,
                            end_line: assignment.end_position().row + 1,
                        });
                    }
                }
            }
        }
    }
    variants
}
