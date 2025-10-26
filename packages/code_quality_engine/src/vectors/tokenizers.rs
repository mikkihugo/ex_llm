//! Custom Tokenizers Optimized for Each Data Type
//!
//! Each data type gets its own optimized tokenization strategy:
//! - Code: Uses parser crates for AST-based tokenization
//! - Prompts: Section-based tokenization for prompt structure
//! - Facts: Entity-relationship tokenization
//! - Snippets: Context-aware tokenization
//! - Sessions: Path and metadata tokenization

use std::collections::HashMap;

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Data type for tokenization
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DataType {
  Code { language: String, content: String },
  Prompt { sections: Vec<String>, variables: Vec<String> },
  Fact { entities: Vec<String>, relationships: Vec<String> },
  Snippet { context: String, content: String },
  Session { project_path: String, metadata: HashMap<String, String> },
}

/// Token extracted from data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataToken {
  pub text: String,
  pub token_type: TokenType,
  pub weight: f32,     // Importance weight for vectorization
  pub context: String, // Additional context
}

/// Types of tokens
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TokenType {
  // Code tokens
  FunctionName,
  ClassName,
  VariableName,
  Keyword,
  StringLiteral,
  Comment,

  // Prompt tokens
  SectionHeader,
  Variable,
  Instruction,
  Example,

  // Fact tokens
  Entity,
  Relationship,
  Metric,
  Timestamp,

  // Snippet tokens
  ContextKeyword,
  CodeBlock,
  Description,

  // Session tokens
  ProjectPath,
  FileExtension,
  Metadata,
}

/// Custom tokenizer trait
pub trait CustomTokenizer {
  fn tokenize(&self, data: &DataType) -> Result<Vec<DataToken>>;
  fn extract_keywords(&self, data: &DataType) -> Result<Vec<String>>;
  fn calculate_weights(&self, tokens: &[DataToken]) -> Vec<f32>;
}

/// Code tokenizer using parser crates
pub struct CodeTokenizer {
  // Will use our parser crates for language-specific tokenization
}

impl CodeTokenizer {
  pub fn new() -> Self {
    Self {}
  }
}

impl CustomTokenizer for CodeTokenizer {
  fn tokenize(&self, data: &DataType) -> Result<Vec<DataToken>> {
    match data {
      DataType::Code { language, content } => self.tokenize_code(language, content),
      _ => Err(anyhow::anyhow!("Expected Code data type")),
    }
  }

  fn extract_keywords(&self, data: &DataType) -> Result<Vec<String>> {
    let tokens = self.tokenize(data)?;
    Ok(
      tokens
        .into_iter()
        .filter(|token| matches!(token.token_type, TokenType::FunctionName | TokenType::ClassName | TokenType::VariableName))
        .map(|token| token.text)
        .collect(),
    )
  }

  fn calculate_weights(&self, tokens: &[DataToken]) -> Vec<f32> {
    tokens
      .iter()
      .map(|token| match token.token_type {
        TokenType::FunctionName => 1.0,
        TokenType::ClassName => 0.9,
        TokenType::VariableName => 0.7,
        TokenType::Keyword => 0.5,
        TokenType::StringLiteral => 0.3,
        TokenType::Comment => 0.2,
        _ => 0.1,
      })
      .collect()
  }
}

impl CodeTokenizer {
  fn tokenize_code(&self, language: &str, content: &str) -> Result<Vec<DataToken>> {
    // ALL parsers now use universal-parser trait for consistency
    match language {
      // All parsers use PolyglotCodeParser trait
      "rust" => self.tokenize_rust(content),               // syn-based + universal trait
      "typescript" => self.tokenize_typescript(content),   // oxc-based + universal trait
      "javascript" => self.tokenize_javascript(content),   // oxc-based + universal trait
      "python" => self.tokenize_python(content),           // universal-parser
      "java" => self.tokenize_java(content),               // universal-parser
      "go" => self.tokenize_go(content),                   // universal-parser
      "c" | "cpp" | "c++" => self.tokenize_c_cpp(content), // universal-parser
      "csharp" | "c#" => self.tokenize_csharp(content),    // universal-parser

      // BEAM languages (all use universal-parser)
      "elixir" => self.tokenize_elixir(content), // universal-parser
      "erlang" => self.tokenize_erlang(content), // universal-parser
      "gleam" => self.tokenize_gleam(content),   // universal-parser

      _ => self.tokenize_generic(content),
    }
  }

  fn tokenize_rust(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use rust-parser crate (syn-based + PolyglotCodeParser trait) for proper Rust tokenization
    // For now, use improved text-based tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_python(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use python-parser crate (PolyglotCodeParser trait) for proper Python tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_typescript(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use typescript-parser crate (oxc-based + PolyglotCodeParser trait) for proper TypeScript tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_javascript(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use javascript-parser crate (oxc-based + PolyglotCodeParser trait) for proper JavaScript tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_java(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use java-parser crate (PolyglotCodeParser trait) for proper Java tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_go(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use go-parser crate (universal-parser) for proper Go tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_c_cpp(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use c-cpp-parser crate (universal-parser) for proper C/C++ tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_csharp(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use csharp-parser crate (universal-parser) for proper C# tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_elixir(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use elixir-parser crate (universal-parser) for proper Elixir tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_erlang(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use erlang-parser crate (universal-parser) for proper Erlang tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_gleam(&self, content: &str) -> Result<Vec<DataToken>> {
    // TODO: Use gleam-parser crate (universal-parser) for proper Gleam tokenization
    self.tokenize_generic(content)
  }

  fn tokenize_generic(&self, content: &str) -> Result<Vec<DataToken>> {
    let mut tokens = Vec::new();

    // Split on code delimiters
    for part in content.split(&[' ', '_', '-', '.', '/', '\\', ':', ';', '(', ')', '[', ']', '{', '}']) {
      let cleaned = part.chars().filter(|c| c.is_alphanumeric()).collect::<String>().to_lowercase();

      if cleaned.len() > 1 && !cleaned.chars().all(|c| c.is_numeric()) {
        let token_type = self.classify_token(&cleaned);
        tokens.push(DataToken { text: cleaned, token_type, weight: 1.0, context: "generic".to_string() });
      }
    }

    Ok(tokens)
  }

  fn classify_token(&self, token: &str) -> TokenType {
    // Simple classification based on patterns
    if token.starts_with("get") || token.starts_with("set") || token.starts_with("is") {
      TokenType::FunctionName
    } else if token.chars().next().map_or(false, |c| c.is_uppercase()) {
      TokenType::ClassName
    } else if ["if", "for", "while", "class", "function", "return"].contains(&token) {
      TokenType::Keyword
    } else {
      TokenType::VariableName
    }
  }
}

/// Prompt tokenizer for prompt structure
pub struct PromptTokenizer {
  // Optimized for prompt sections, variables, instructions
}

impl PromptTokenizer {
  pub fn new() -> Self {
    Self {}
  }
}

impl CustomTokenizer for PromptTokenizer {
  fn tokenize(&self, data: &DataType) -> Result<Vec<DataToken>> {
    match data {
      DataType::Prompt { sections, variables } => self.tokenize_prompt(sections, variables),
      _ => Err(anyhow::anyhow!("Expected Prompt data type")),
    }
  }

  fn extract_keywords(&self, data: &DataType) -> Result<Vec<String>> {
    let tokens = self.tokenize(data)?;
    Ok(tokens.into_iter().filter(|token| matches!(token.token_type, TokenType::SectionHeader | TokenType::Variable)).map(|token| token.text).collect())
  }

  fn calculate_weights(&self, tokens: &[DataToken]) -> Vec<f32> {
    tokens
      .iter()
      .map(|token| match token.token_type {
        TokenType::SectionHeader => 1.0,
        TokenType::Variable => 0.9,
        TokenType::Instruction => 0.8,
        TokenType::Example => 0.6,
        _ => 0.3,
      })
      .collect()
  }
}

impl PromptTokenizer {
  fn tokenize_prompt(&self, sections: &[String], variables: &[String]) -> Result<Vec<DataToken>> {
    let mut tokens = Vec::new();

    // Tokenize sections
    for section in sections {
      tokens.push(DataToken { text: section.clone(), token_type: TokenType::SectionHeader, weight: 1.0, context: "section".to_string() });
    }

    // Tokenize variables
    for variable in variables {
      tokens.push(DataToken { text: variable.clone(), token_type: TokenType::Variable, weight: 0.9, context: "variable".to_string() });
    }

    Ok(tokens)
  }
}

/// Fact tokenizer for entity-relationship data
pub struct FactTokenizer {
  // Optimized for facts, entities, relationships, metrics
}

impl FactTokenizer {
  pub fn new() -> Self {
    Self {}
  }
}

impl CustomTokenizer for FactTokenizer {
  fn tokenize(&self, data: &DataType) -> Result<Vec<DataToken>> {
    match data {
      DataType::Fact { entities, relationships } => self.tokenize_fact(entities, relationships),
      _ => Err(anyhow::anyhow!("Expected Fact data type")),
    }
  }

  fn extract_keywords(&self, data: &DataType) -> Result<Vec<String>> {
    let tokens = self.tokenize(data)?;
    Ok(tokens.into_iter().filter(|token| matches!(token.token_type, TokenType::Entity | TokenType::Relationship)).map(|token| token.text).collect())
  }

  fn calculate_weights(&self, tokens: &[DataToken]) -> Vec<f32> {
    tokens
      .iter()
      .map(|token| match token.token_type {
        TokenType::Entity => 1.0,
        TokenType::Relationship => 0.9,
        TokenType::Metric => 0.8,
        TokenType::Timestamp => 0.5,
        _ => 0.3,
      })
      .collect()
  }
}

impl FactTokenizer {
  fn tokenize_fact(&self, entities: &[String], relationships: &[String]) -> Result<Vec<DataToken>> {
    let mut tokens = Vec::new();

    // Tokenize entities
    for entity in entities {
      tokens.push(DataToken { text: entity.clone(), token_type: TokenType::Entity, weight: 1.0, context: "entity".to_string() });
    }

    // Tokenize relationships
    for relationship in relationships {
      tokens.push(DataToken { text: relationship.clone(), token_type: TokenType::Relationship, weight: 0.9, context: "relationship".to_string() });
    }

    Ok(tokens)
  }
}

/// Snippet tokenizer for context-aware tokenization
pub struct SnippetTokenizer {
  // Optimized for code snippets with context
}

impl SnippetTokenizer {
  pub fn new() -> Self {
    Self {}
  }
}

impl CustomTokenizer for SnippetTokenizer {
  fn tokenize(&self, data: &DataType) -> Result<Vec<DataToken>> {
    match data {
      DataType::Snippet { context, content } => self.tokenize_snippet(context, content),
      _ => Err(anyhow::anyhow!("Expected Snippet data type")),
    }
  }

  fn extract_keywords(&self, data: &DataType) -> Result<Vec<String>> {
    let tokens = self.tokenize(data)?;
    Ok(tokens.into_iter().filter(|token| matches!(token.token_type, TokenType::ContextKeyword | TokenType::CodeBlock)).map(|token| token.text).collect())
  }

  fn calculate_weights(&self, tokens: &[DataToken]) -> Vec<f32> {
    tokens
      .iter()
      .map(|token| match token.token_type {
        TokenType::ContextKeyword => 1.0,
        TokenType::CodeBlock => 0.9,
        TokenType::Description => 0.7,
        _ => 0.5,
      })
      .collect()
  }
}

impl SnippetTokenizer {
  fn tokenize_snippet(&self, context: &str, content: &str) -> Result<Vec<DataToken>> {
    let mut tokens = Vec::new();

    // Tokenize context
    for word in context.split_whitespace() {
      tokens.push(DataToken { text: word.to_lowercase(), token_type: TokenType::ContextKeyword, weight: 1.0, context: "context".to_string() });
    }

    // Tokenize content
    for word in content.split_whitespace() {
      tokens.push(DataToken { text: word.to_lowercase(), token_type: TokenType::CodeBlock, weight: 0.9, context: "content".to_string() });
    }

    Ok(tokens)
  }
}

/// Session tokenizer for project metadata
pub struct SessionTokenizer {
  // Optimized for project paths, file extensions, metadata
}

impl SessionTokenizer {
  pub fn new() -> Self {
    Self {}
  }
}

impl CustomTokenizer for SessionTokenizer {
  fn tokenize(&self, data: &DataType) -> Result<Vec<DataToken>> {
    match data {
      DataType::Session { project_path, metadata } => self.tokenize_session(project_path, metadata),
      _ => Err(anyhow::anyhow!("Expected Session data type")),
    }
  }

  fn extract_keywords(&self, data: &DataType) -> Result<Vec<String>> {
    let tokens = self.tokenize(data)?;
    Ok(tokens.into_iter().filter(|token| matches!(token.token_type, TokenType::ProjectPath | TokenType::FileExtension)).map(|token| token.text).collect())
  }

  fn calculate_weights(&self, tokens: &[DataToken]) -> Vec<f32> {
    tokens
      .iter()
      .map(|token| match token.token_type {
        TokenType::ProjectPath => 1.0,
        TokenType::FileExtension => 0.8,
        TokenType::Metadata => 0.6,
        _ => 0.3,
      })
      .collect()
  }
}

impl SessionTokenizer {
  fn tokenize_session(&self, project_path: &str, metadata: &HashMap<String, String>) -> Result<Vec<DataToken>> {
    let mut tokens = Vec::new();

    // Tokenize project path
    for part in project_path.split('/') {
      if !part.is_empty() {
        tokens.push(DataToken { text: part.to_lowercase(), token_type: TokenType::ProjectPath, weight: 1.0, context: "path".to_string() });
      }
    }

    // Tokenize metadata
    for (key, value) in metadata {
      tokens.push(DataToken { text: key.clone(), token_type: TokenType::Metadata, weight: 0.6, context: "metadata".to_string() });

      tokens.push(DataToken { text: value.clone(), token_type: TokenType::Metadata, weight: 0.6, context: "metadata".to_string() });
    }

    Ok(tokens)
  }
}

/// Tokenizer factory for creating appropriate tokenizers
pub struct TokenizerFactory;

impl TokenizerFactory {
  pub fn create_tokenizer(data_type: &DataType) -> Box<dyn CustomTokenizer> {
    match data_type {
      DataType::Code { .. } => Box::new(CodeTokenizer::new()),
      DataType::Prompt { .. } => Box::new(PromptTokenizer::new()),
      DataType::Fact { .. } => Box::new(FactTokenizer::new()),
      DataType::Snippet { .. } => Box::new(SnippetTokenizer::new()),
      DataType::Session { .. } => Box::new(SessionTokenizer::new()),
    }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_code_tokenizer() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "rust".to_string(), content: "fn get_user_name() -> String { user.name }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
  }

  #[test]
  fn test_prompt_tokenizer() {
    let tokenizer = PromptTokenizer::new();
    let data = DataType::Prompt { sections: vec!["Authentication".to_string()], variables: vec!["user_id".to_string()] };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert_eq!(tokens.len(), 2);
  }

  #[test]
  fn test_fact_tokenizer() {
    let tokenizer = FactTokenizer::new();
    let data = DataType::Fact { entities: vec!["User".to_string()], relationships: vec!["has_profile".to_string()] };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert_eq!(tokens.len(), 2);
  }
}
