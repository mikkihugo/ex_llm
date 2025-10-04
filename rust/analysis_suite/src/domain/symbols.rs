//! Code symbols from parsing
//!
//! This module contains types representing parsed code symbols like functions,
//! structs, enums, and traits extracted from source code.

use serde::{Deserialize, Serialize};

/// Parsed code symbols stored in DAG nodes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeSymbols {
  /// Functions
  pub functions: Vec<FunctionSymbol>,
  /// Structs/classes
  pub structs: Vec<StructSymbol>,
  /// Enums
  pub enums: Vec<EnumSymbol>,
  /// Traits/interfaces
  pub traits: Vec<TraitSymbol>,
  /// Imports
  pub imports: Vec<String>,
  /// Exports
  pub exports: Vec<String>,
}

/// Function symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionSymbol {
  pub name: String,
  pub start_line: usize,
  pub end_line: usize,
  pub parameters: Vec<String>,
  pub return_type: Option<String>,
  pub is_async: bool,
  pub is_public: bool,
}

/// Struct/class symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructSymbol {
  pub name: String,
  pub start_line: usize,
  pub fields: Vec<String>,
  pub is_public: bool,
}

/// Enum symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnumSymbol {
  pub name: String,
  pub start_line: usize,
  pub variants: Vec<String>,
  pub is_public: bool,
}

/// Trait/interface symbol
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraitSymbol {
  pub name: String,
  pub start_line: usize,
  pub methods: Vec<String>,
  pub is_public: bool,
}
