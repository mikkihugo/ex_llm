//! Index Store for Codebase Analysis
//!
//! This module provides indexing capabilities for codebase analysis.
//! It stores searchable indexes for symbols, functions, and classes.

use std::{collections::HashMap, path::PathBuf};

use serde::{Deserialize, Serialize};

/// Index store for codebase analysis
#[derive(Debug, Clone, Default)]
pub struct IndexStorage {
  /// Symbol index
  pub symbol_index: HashMap<String, Vec<SymbolEntry>>,
  /// Function index
  pub function_index: HashMap<String, Vec<FunctionEntry>>,
  /// Class index
  pub class_index: HashMap<String, Vec<ClassEntry>>,
  /// Type index
  pub type_index: HashMap<String, Vec<TypeEntry>>,
}

/// Symbol entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SymbolEntry {
  /// Symbol name
  pub name: String,
  /// File path
  pub file_path: PathBuf,
  /// Line number
  pub line_number: usize,
  /// Column number
  pub column_number: usize,
  /// Symbol type
  pub symbol_type: SymbolType,
}

/// Function entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionEntry {
  /// Function name
  pub name: String,
  /// File path
  pub file_path: PathBuf,
  /// Line number
  pub line_number: usize,
  /// Function signature
  pub signature: String,
  /// Return type
  pub return_type: Option<String>,
  /// Parameters
  pub parameters: Vec<Parameter>,
}

/// Class entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClassEntry {
  /// Class name
  pub name: String,
  /// File path
  pub file_path: PathBuf,
  /// Line number
  pub line_number: usize,
  /// Base classes
  pub base_classes: Vec<String>,
  /// Methods
  pub methods: Vec<String>,
  /// Properties
  pub properties: Vec<String>,
}

/// Type entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeEntry {
  /// Type name
  pub name: String,
  /// File path
  pub file_path: PathBuf,
  /// Line number
  pub line_number: usize,
  /// Type kind
  pub type_kind: TypeKind,
}

/// Symbol type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SymbolType {
  /// Variable
  Variable,
  /// Function
  Function,
  /// Class
  Class,
  /// Type
  Type,
  /// Constant
  Constant,
  /// Module
  Module,
}

/// Parameter
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Parameter {
  /// Parameter name
  pub name: String,
  /// Parameter type
  pub param_type: String,
  /// Is optional
  pub is_optional: bool,
}

/// Type kind
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TypeKind {
  /// Primitive type
  Primitive,
  /// User-defined type
  UserDefined,
  /// Generic type
  Generic,
  /// Union type
  Union,
  /// Interface
  Interface,
}

impl IndexStorage {
  /// Create a new index store
  pub fn new() -> Self {
    Self::default()
  }

  /// Add a symbol to the index
  pub fn add_symbol(&mut self, name: String, file_path: PathBuf, line_number: usize, column_number: usize, symbol_type: SymbolType) {
    let entry = SymbolEntry { name: name.clone(), file_path, line_number, column_number, symbol_type };

    self.symbol_index.entry(name).or_insert_with(Vec::new).push(entry);
  }

  /// Add a function to the index
  pub fn add_function(
    &mut self,
    name: String,
    file_path: PathBuf,
    line_number: usize,
    signature: String,
    return_type: Option<String>,
    parameters: Vec<Parameter>,
  ) {
    let entry = FunctionEntry { name: name.clone(), file_path, line_number, signature, return_type, parameters };

    self.function_index.entry(name).or_insert_with(Vec::new).push(entry);
  }

  /// Add a class to the index
  pub fn add_class(&mut self, name: String, file_path: PathBuf, line_number: usize, base_classes: Vec<String>, methods: Vec<String>, properties: Vec<String>) {
    let entry = ClassEntry { name: name.clone(), file_path, line_number, base_classes, methods, properties };

    self.class_index.entry(name).or_insert_with(Vec::new).push(entry);
  }

  /// Add a type to the index
  pub fn add_type(&mut self, name: String, file_path: PathBuf, line_number: usize, type_kind: TypeKind) {
    let entry = TypeEntry { name: name.clone(), file_path, line_number, type_kind };

    self.type_index.entry(name).or_insert_with(Vec::new).push(entry);
  }

  /// Search for symbols by name
  pub fn search_symbols(&self, name: &str) -> Option<&Vec<SymbolEntry>> {
    self.symbol_index.get(name)
  }

  /// Search for functions by name
  pub fn search_functions(&self, name: &str) -> Option<&Vec<FunctionEntry>> {
    self.function_index.get(name)
  }

  /// Search for classes by name
  pub fn search_classes(&self, name: &str) -> Option<&Vec<ClassEntry>> {
    self.class_index.get(name)
  }

  /// Search for types by name
  pub fn search_types(&self, name: &str) -> Option<&Vec<TypeEntry>> {
    self.type_index.get(name)
  }
}
