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

        Ok(LanguageMetrics {
            lines_of_code: ast.content.lines().count() as u64,
            lines_of_comments: comments.len() as u64,
            blank_lines: 0, // TODO: implement blank line counting
            total_lines: ast.content.lines().count() as u64,
            functions: functions.len() as u64,
            classes: 0, // TODO: implement class counting
            complexity_score: 0.0, // TODO: implement complexity calculation
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
        while let Some(&(ref m, _)) = captures.next() {
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
                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some(ret.to_owned()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
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
                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some(ret.to_owned()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
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
                functions.push(FunctionInfo {
                    name: name.to_owned(),
                    parameters: params.split(',').map(|s| s.trim().to_string()).collect(),
                    return_type: Some(ret.to_owned()),
                    line_start: (node.start_position().row + 1) as u32,
                    line_end: (node.end_position().row + 1) as u32,
                    complexity: 0,
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
                let end = capture.node.end_position().row + 1;
                let kind = if text.trim_start().starts_with("/*") {
                    "block"
                } else {
                    "line"
                };
                comments.push(Comment {
                    content: text,
                    line: start as u32,
                    column: 0, // TODO: implement column counting
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
            metrics.functions.len() >= 1,
            "expected at least one function in TSX source"
        );
    }
}
