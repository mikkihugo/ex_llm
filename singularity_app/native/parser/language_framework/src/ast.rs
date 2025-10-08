//! Common AST types and structures

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// High-level wrapper around a tree-sitter tree and original source.
#[derive(Debug, Clone)]
pub struct AST {
    tree: tree_sitter::Tree,
    pub source: String,
}

impl AST {
    /// Create a new AST instance from a tree-sitter tree and its source text.
    pub fn new(tree: tree_sitter::Tree, source: String) -> Self {
        Self { tree, source }
    }

    /// Borrow the underlying tree-sitter tree.
    pub fn tree(&self) -> &tree_sitter::Tree {
        &self.tree
    }

    /// Convenience accessor for the root node of the tree.
    pub fn root(&self) -> tree_sitter::Node<'_> {
        self.tree.root_node()
    }
}

/// Language-agnostic AST node
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
    pub parameters: String,
    pub return_type: String,
    pub start_line: usize,
    pub end_line: usize,
    pub body: String,
}

/// Import statement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Import {
    pub path: String,
    pub kind: String,
    pub start_line: usize,
    pub end_line: usize,
}

/// Comment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Comment {
    pub text: String,
    pub kind: String,
    pub start_line: usize,
    pub end_line: usize,
}
