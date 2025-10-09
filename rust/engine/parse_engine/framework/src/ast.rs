//! Common AST types and structures

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Language-agnostic AST node
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AST {
    pub language: String,
    pub root: ASTNode,
    pub metadata: HashMap<String, serde_json::Value>,
}

/// Generic AST node
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ASTNode {
    pub node_type: String,
    pub text: String,
    pub start_byte: usize,
    pub end_byte: usize,
    pub start_point: Point,
    pub end_point: Point,
    pub children: Vec<ASTNode>,
    pub properties: HashMap<String, serde_json::Value>,
}

/// Source position
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Point {
    pub row: usize,
    pub column: usize,
}

/// Function definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Function {
    pub name: String,
    pub parameters: Vec<Parameter>,
    pub return_type: Option<String>,
    pub start_point: Point,
    pub end_point: Point,
    pub visibility: Visibility,
    pub is_async: bool,
    pub is_static: bool,
    pub doc_comment: Option<String>,
}

/// Function parameter
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Parameter {
    pub name: String,
    pub param_type: Option<String>,
    pub default_value: Option<String>,
    pub is_optional: bool,
}

/// Import statement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Import {
    pub module: String,
    pub items: Vec<ImportItem>,
    pub alias: Option<String>,
    pub is_relative: bool,
    pub start_point: Point,
    pub end_point: Point,
}

/// Import item
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportItem {
    pub name: String,
    pub alias: Option<String>,
    pub is_wildcard: bool,
}

/// Comment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Comment {
    pub text: String,
    pub comment_type: CommentType,
    pub start_point: Point,
    pub end_point: Point,
    pub is_documentation: bool,
}

/// Comment type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CommentType {
    SingleLine,
    MultiLine,
    Documentation,
}

/// Visibility modifier
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Visibility {
    Public,
    Private,
    Protected,
    Internal,
    Package,
}