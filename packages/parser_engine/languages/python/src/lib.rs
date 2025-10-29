//! Python parser implemented with tree-sitter and the parser-framework traits.

use parser_core::{
    Class, Comment, Decorator, EnumVariant, FunctionInfo, Import, LanguageMetrics, LanguageParser,
    ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, StreamingIterator, Tree};

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
        visit_nodes(ast.tree.root_node(), "class_definition", &mut |node| {
            let name = node
                .child_by_field_name("name")
                .and_then(|n| n.utf8_text(ast.content.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            let bases = extract_bases(node, &ast.content);
            let _decorators = collect_python_decorators(node, &ast.content);
            let body_node = node.child_by_field_name("body");
            let _body = body_node
                .map(|b| slice_text(b, &ast.content))
                .unwrap_or_default();
            let _docstring = body_node.and_then(|b| extract_docstring_from_block(b, &ast.content));
            let variants = body_node
                .map(|b| collect_enum_variants(b, &ast.content))
                .unwrap_or_default();
            let is_enum = bases.iter().any(|base| {
                base.rsplit('.')
                    .next()
                    .map(|p| p == "Enum")
                    .unwrap_or(false)
            });

            let class = Class {
                name: name.clone(),
                line_start: (node.start_position().row + 1) as u32,
                line_end: (node.end_position().row + 1) as u32,
                methods: Vec::new(), // TODO: implement method extraction
                fields: Vec::new(),  // TODO: implement field extraction
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

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "python").unwrap_or((
                1.0,
                ast.content.lines().count() as u64,
                ast.content.lines().count() as u64,
                comments.len() as u64,
                0,
            ));

        Ok(LanguageMetrics {
            lines_of_code: ploc.saturating_sub(blank_lines + cloc), // Physical - (blank + comments)
            lines_of_comments: cloc,
            blank_lines,
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: class_infos.len() as u64,
            imports: imports.len() as u64,
            complexity_score, // Real cyclomatic complexity from RCA!
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<FunctionInfo>, ParseError> {
        let mut functions = Vec::new();

        visit_nodes(ast.tree.root_node(), "function_definition", &mut |node| {
            let name = node
                .child_by_field_name("name")
                .and_then(|n| n.utf8_text(ast.content.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            let params = node
                .child_by_field_name("parameters")
                .and_then(|p| p.utf8_text(ast.content.as_bytes()).ok())
                .unwrap_or("()");

            let return_type = node
                .child_by_field_name("return_type")
                .and_then(|r| r.utf8_text(ast.content.as_bytes()).ok())
                .unwrap_or_default()
                .to_string();

            let body_node = node.child_by_field_name("body");
            let body = body_node
                .map(|b| slice_text(b, &ast.content))
                .unwrap_or_default();
            let docstring = body_node.and_then(|b| extract_docstring_from_block(b, &ast.content));
            let decorators = collect_python_decorators(node, &ast.content);
            let is_async = is_async_function(node, &ast.content);
            let is_generator = is_generator_body(&body);
            let signature = Some(build_signature(&name, params, &return_type));

            functions.push(FunctionInfo {
                name: name.to_string(),
                parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                return_type: Some(return_type.clone()),
                line_start: (node.start_position().row + 1) as u32,
                line_end: (node.end_position().row + 1) as u32,
                complexity: 0,
                decorators: decorators.iter().map(|d| d.name.clone()).collect(),
                docstring,
                is_async,
                is_generator,
                signature,
                body: Some(body),
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
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut cursor = tree_sitter::QueryCursor::new();
        let mut imports = Vec::new();

        let mut captures = cursor.captures(&query, ast.tree.root_node(), ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            let mut module = "";
            let mut node_ref: Option<Node> = None;

            for capture in m.captures {
                match capture.index {
                    0 | 2 => {
                        module = capture
                            .node
                            .utf8_text(ast.content.as_bytes())
                            .unwrap_or_default();
                    }
                    1 | 3 => {
                        node_ref = Some(capture.node);
                    }
                    _ => {}
                }
            }

            if let Some(node) = node_ref {
                imports.push(Import {
                    module: module.to_string(),
                    items: Vec::new(),
                    line: (node.start_position().row + 1) as u32,
                });
            }
        }

        Ok(imports)
    }

    fn get_comments(&self, ast: &AST) -> Result<Vec<Comment>, ParseError> {
        let language = &tree_sitter_python::LANGUAGE.into();
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
                let start = capture.node.start_position().row + 1;
                comments.push(Comment {
                    content: text.to_string(),
                    line: start as u32,
                    column: 0,                // TODO: implement column counting
                    kind: "line".to_string(), // Python comments are always line comments
                });
            }
        }

        Ok(comments)
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
#[allow(dead_code)]
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
                        decorators.push(Decorator {
                            name,
                            line: 0,
                            arguments,
                        });
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
                            line: (assignment.start_position().row + 1) as u32,
                        });
                    }
                }
            }
        }
    }
    variants
}
