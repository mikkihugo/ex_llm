//! TypeScript / TSX parser backed by tree-sitter.

use parser_core::{
    Comment, FunctionInfo, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Query, QueryCursor, StreamingIterator};

pub struct TypescriptParser {
    parser: Mutex<Parser>,
}

impl TypescriptParser {
    pub fn new() -> Result<Self, ParseError> {
        Ok(Self {
            parser: Mutex::new(Parser::new()),
        })
    }

    fn extract_text<'a>(node: Node<'a>, source: &'a str) -> &'a str {
        node.utf8_text(source.as_bytes()).unwrap_or_default()
    }
}

impl Default for TypescriptParser {
    fn default() -> Self {
        Self::new().expect("TypeScript parser initialisation must succeed")
    }
}

impl LanguageParser for TypescriptParser {
    fn parse(&self, content: &str) -> Result<AST, ParseError> {
        let mut parser = self.parser.lock().expect("parser mutex poisoned");
        parser
            .set_language(&tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into())
            .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;

        let mut tree = parser.parse(content, None);

        if tree
            .as_ref()
            .map(|t| t.root_node().has_error())
            .unwrap_or(true)
            && content.contains("<")
        {
            parser
                .set_language(&tree_sitter_typescript::LANGUAGE_TSX.into())
                .map_err(|err| ParseError::TreeSitterError(err.to_string()))?;
            tree = parser.parse(content, None);
        }

        let tree = tree
            .ok_or_else(|| ParseError::ParseError("failed to parse TypeScript/TSX code".into()))?;

        Ok(AST::new(tree, content.to_owned()))
    }

    fn get_metrics(&self, ast: &AST) -> Result<LanguageMetrics, ParseError> {
        let functions = self.get_functions(ast)?;
        let imports = self.get_imports(ast)?;
        let comments = self.get_comments(ast)?;

        // Use RCA for real complexity and accurate LOC metrics
        let (complexity_score, _sloc, ploc, cloc, blank_lines) =
            parser_core::calculate_rca_complexity(&ast.content, "typescript").unwrap_or((
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
        let language = &tree_sitter_typescript::LANGUAGE_TSX.into();
        let mut cursor = QueryCursor::new();
        let root = ast.tree.root_node();

        let mut functions = Vec::new();

        // Standard function declarations
        let fn_query = Query::new(
            language,
            r#"
            (function_declaration
              name: (identifier) @name
              parameters: (formal_parameters) @params
              return_type: (type_annotation)? @ret
              body: (statement_block) @body)
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut captures = cursor.captures(&fn_query, root, ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            let mut name = "";
            let mut params = "";
            let mut ret = "any";
            let mut body = "";
            let mut fn_node = None;

            for capture in m.captures {
                match capture.index {
                    0 => {
                        fn_node = Some(capture.node);
                    }
                    1 => name = Self::extract_text(capture.node, &ast.content),
                    2 => params = Self::extract_text(capture.node, &ast.content),
                    3 => ret = Self::extract_text(capture.node, &ast.content),
                    4 => body = Self::extract_text(capture.node, &ast.content),
                    _ => {}
                }
            }

            if let Some(node) = fn_node {
                let full_text = Self::extract_text(node, &ast.content);
                let is_async = full_text.trim_start().starts_with("async ");
                let is_generator = full_text.contains("function*") || body.contains("yield");
                let decorators = extract_decorators(node, &ast.content);
                let signature = if ret.is_empty() || ret == "any" {
                    format!("{}({})", name, params)
                } else {
                    format!("{}({}): {}", name, params, ret)
                };

                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some(ret.to_owned()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
                    decorators,
                    docstring: extract_jsdoc_ts(node, &ast.content),
                    is_async,
                    is_generator,
                    signature: Some(signature),
                    body: Some(body.to_owned()),
                });
            }
        }

        // Arrow functions
        let arrow_query = Query::new(
            language,
            r#"
            (lexical_declaration
              declarators: (variable_declarator
                name: (identifier) @name
                value: (arrow_function
                  parameters: (formal_parameters) @params
                  return_type: (type_annotation)? @ret
                  body: (_) @body))) @arrow_decl
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut captures = cursor.captures(&arrow_query, root, ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            let mut name = "";
            let mut params = "";
            let mut ret = "any";
            let mut body = "";
            let mut arrow_node = None;

            for capture in m.captures {
                match capture.index {
                    0 => arrow_node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.content),
                    2 => params = Self::extract_text(capture.node, &ast.content),
                    3 => ret = Self::extract_text(capture.node, &ast.content),
                    4 => body = Self::extract_text(capture.node, &ast.content),
                    _ => {}
                }
            }

            if let Some(node) = arrow_node {
                let full_text = Self::extract_text(node, &ast.content);
                let is_async =
                    full_text.trim_start().starts_with("async ") || full_text.contains("async (");
                let is_generator = body.contains("yield");
                let signature = if ret.is_empty() || ret == "any" {
                    format!("{}({})", name, params)
                } else {
                    format!("{}({}): {}", name, params, ret)
                };

                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some(ret.to_owned()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
                    decorators: Vec::new(),
                    docstring: extract_jsdoc_ts(node, &ast.content),
                    is_async,
                    is_generator,
                    signature: Some(signature),
                    body: Some(body.to_owned()),
                });
            }
        }

        // Class or object methods
        let method_query = Query::new(
            language,
            r#"
            (method_definition
                name: (property_identifier) @name
                parameters: (formal_parameters) @params
                return_type: (type_annotation)? @ret
                body: (statement_block) @body) @method
        "#,
        )
        .map_err(|err| ParseError::ParseError(err.to_string()))?;

        let mut captures = cursor.captures(&method_query, root, ast.content.as_bytes());
        while let Some((m, _)) = captures.next() {
            let mut name = "";
            let mut params = "";
            let mut ret = "any";
            let mut body = "";
            let mut method_node = None;

            for capture in m.captures {
                match capture.index {
                    0 => method_node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.content),
                    2 => params = Self::extract_text(capture.node, &ast.content),
                    3 => ret = Self::extract_text(capture.node, &ast.content),
                    4 => body = Self::extract_text(capture.node, &ast.content),
                    _ => {}
                }
            }

            if let Some(node) = method_node {
                let full_text = Self::extract_text(node, &ast.content);
                let is_async = full_text.trim_start().starts_with("async ");
                let is_generator = full_text.contains("*") || body.contains("yield");
                let decorators = extract_decorators(node, &ast.content);
                let signature = if ret.is_empty() || ret == "any" {
                    format!("{}({})", name, params)
                } else {
                    format!("{}({}): {}", name, params, ret)
                };

                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some(ret.to_owned()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
                    decorators,
                    docstring: extract_jsdoc_ts(node, &ast.content),
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
            &tree_sitter_typescript::LANGUAGE_TSX.into(),
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
            &tree_sitter_typescript::LANGUAGE_TSX.into(),
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
                let start = capture.node.start_position().row + 1;
                let kind = if text.trim_start().starts_with("/*") {
                    "block".to_string()
                } else {
                    "line".to_string()
                };
                comments.push(Comment {
                    content: text,
                    line: start as u32,
                    column: 0, // TODO: implement column counting
                    kind,
                });
            }
        }

        Ok(comments)
    }

    fn get_language(&self) -> &str {
        "typescript"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["ts", "tsx"]
    }
}

/// Extract JSDoc/TSDoc comment before a node
fn extract_jsdoc_ts(node: tree_sitter::Node, source: &str) -> Option<String> {
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

/// Extract TypeScript decorators from a node
fn extract_decorators(node: tree_sitter::Node, source: &str) -> Vec<String> {
    let mut decorators = Vec::new();

    // Look for decorator nodes before the function/method
    let mut current = node.prev_sibling();
    while let Some(sibling) = current {
        if sibling.kind() == "decorator" {
            if let Ok(text) = sibling.utf8_text(source.as_bytes()) {
                let decorator = text.trim().trim_start_matches('@').to_string();
                decorators.insert(0, decorator); // Insert at beginning to maintain order
            }
            current = sibling.prev_sibling();
        } else {
            break;
        }
    }

    decorators
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_tsx_component() {
        let parser = TypescriptParser::default();
        let source = r#"const Component: React.FC = () => <div className="greeting">Hello</div>;"#;

        let ast = parser.parse(source).expect("tsx parsing");
        let metrics = parser
            .get_metrics(&ast)
            .expect("metrics extraction for tsx");

        assert!(
            metrics.functions.len() >= 1,
            "expected at least one function in TSX source"
        );
    }
}
