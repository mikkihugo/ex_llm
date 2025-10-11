//! TypeScript / TSX parser backed by tree-sitter.

use parser_framework::{
    Comment, Function, Import, LanguageMetrics, LanguageParser, ParseError, AST,
};
use std::sync::Mutex;
use tree_sitter::{Node, Parser, Query, QueryCursor};

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

        Ok(LanguageMetrics {
            lines_of_code: ast.source.lines().count(),
            functions_count: functions.len(),
            imports_count: imports.len(),
            comments_count: comments.len(),
            ..LanguageMetrics::default()
        })
    }

    fn get_functions(&self, ast: &AST) -> Result<Vec<Function>, ParseError> {
        let language = &tree_sitter_typescript::LANGUAGE_TSX.into();
        let mut cursor = QueryCursor::new();
        let root = ast.root();

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
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        for (m, _) in cursor.captures(&fn_query, root, ast.source.as_bytes()).into_iter() {
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
                    1 => name = Self::extract_text(capture.node, &ast.source),
                    2 => params = Self::extract_text(capture.node, &ast.source),
                    3 => ret = Self::extract_text(capture.node, &ast.source),
                    4 => body = Self::extract_text(capture.node, &ast.source),
                    _ => {}
                }
            }

            if let Some(node) = fn_node {
                functions.push(Function {
                    name: name.to_owned(),
                    parameters: params.to_owned(),
                    return_type: ret.to_owned(),
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
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        for (m, _) in cursor.captures(&arrow_query, root, ast.source.as_bytes()).into_iter() {
            let mut name = "";
            let mut params = "";
            let mut ret = "any";
            let mut body = "";
            let mut arrow_node = None;

            for capture in m.captures {
                match capture.index {
                    0 => arrow_node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.source),
                    2 => params = Self::extract_text(capture.node, &ast.source),
                    3 => ret = Self::extract_text(capture.node, &ast.source),
                    4 => body = Self::extract_text(capture.node, &ast.source),
                    _ => {}
                }
            }

            if let Some(node) = arrow_node {
                functions.push(Function {
                    name: name.to_owned(),
                    parameters: params.to_owned(),
                    return_type: ret.to_owned(),
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
        .map_err(|err| ParseError::QueryError(err.to_string()))?;

        for (m, _) in cursor.captures(&method_query, root, ast.source.as_bytes()).into_iter() {
            let mut name = "";
            let mut params = "";
            let mut ret = "any";
            let mut body = "";
            let mut method_node = None;

            for capture in m.captures {
                match capture.index {
                    0 => method_node = Some(capture.node),
                    1 => name = Self::extract_text(capture.node, &ast.source),
                    2 => params = Self::extract_text(capture.node, &ast.source),
                    3 => ret = Self::extract_text(capture.node, &ast.source),
                    4 => body = Self::extract_text(capture.node, &ast.source),
                    _ => {}
                }
            }

            if let Some(node) = method_node {
                functions.push(Function {
                    name: name.to_owned(),
                    parameters: params.to_owned(),
                    return_type: ret.to_owned(),
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
            &tree_sitter_typescript::LANGUAGE_TSX.into(),
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
            &tree_sitter_typescript::LANGUAGE_TSX.into(),
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
        "typescript"
    }

    fn get_extensions(&self) -> Vec<&str> {
        vec!["ts", "tsx"]
    }
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
            metrics.functions_count >= 1,
            "expected at least one function in TSX source"
        );
    }
}
