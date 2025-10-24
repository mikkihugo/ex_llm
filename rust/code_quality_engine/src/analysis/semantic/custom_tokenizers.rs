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
    // Use keyword-based tokenization for Rust
    self.tokenize_with_keywords(content, &[
      "fn", "struct", "enum", "trait", "impl", "pub", "async", "await",
      "mod", "use", "let", "mut", "const", "static", "type", "if", "else",
      "for", "while", "loop", "match", "return", "yield", "break", "continue"
    ])
  }

  fn tokenize_python(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract Python identifiers and keywords
    self.tokenize_with_keywords(content, &[
      "def", "class", "async", "await", "import", "from", "if", "elif", "else",
      "for", "while", "with", "try", "except", "finally", "return", "yield",
      "break", "continue", "pass", "lambda", "global", "nonlocal"
    ])
  }

  fn tokenize_typescript(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract TypeScript/JavaScript identifiers
    self.tokenize_with_keywords(content, &[
      "function", "async", "await", "class", "interface", "type", "enum",
      "import", "export", "const", "let", "var", "if", "else", "for",
      "while", "do", "switch", "case", "return", "break", "continue",
      "default", "static", "public", "private", "protected", "readonly"
    ])
  }

  fn tokenize_javascript(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract JavaScript identifiers
    self.tokenize_with_keywords(content, &[
      "function", "async", "await", "class", "import", "export", "const", "let",
      "var", "if", "else", "for", "while", "do", "switch", "case", "default",
      "return", "break", "continue", "try", "catch", "finally", "throw", "new",
      "this", "super", "static", "extends", "implements"
    ])
  }

  fn tokenize_java(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract Java identifiers and keywords
    self.tokenize_with_keywords(content, &[
      "class", "interface", "enum", "public", "private", "protected", "static",
      "final", "abstract", "synchronized", "volatile", "transient", "native",
      "strictfp", "extends", "implements", "new", "throw", "throws", "try",
      "catch", "finally", "if", "else", "for", "while", "do", "switch", "case",
      "return", "break", "continue", "default"
    ])
  }

  fn tokenize_go(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract Go identifiers and keywords
    self.tokenize_with_keywords(content, &[
      "func", "type", "struct", "interface", "import", "package", "const",
      "var", "if", "else", "for", "range", "switch", "case", "default",
      "return", "break", "continue", "goto", "fallthrough", "defer", "go",
      "chan", "select", "map", "make", "new", "len", "cap", "append", "copy"
    ])
  }

  fn tokenize_c_cpp(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract C/C++ identifiers
    self.tokenize_with_keywords(content, &[
      "int", "float", "double", "char", "void", "bool", "struct", "union",
      "enum", "class", "template", "namespace", "using", "typedef", "define",
      "ifdef", "ifndef", "endif", "if", "else", "for", "while", "do", "switch",
      "case", "default", "return", "break", "continue", "goto", "static",
      "const", "volatile", "inline", "virtual", "public", "private", "protected"
    ])
  }

  fn tokenize_csharp(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract C# identifiers
    self.tokenize_with_keywords(content, &[
      "class", "struct", "interface", "enum", "delegate", "namespace", "using",
      "public", "private", "protected", "internal", "static", "readonly",
      "volatile", "const", "abstract", "sealed", "partial", "async", "await",
      "if", "else", "for", "foreach", "while", "do", "switch", "case", "default",
      "return", "break", "continue", "throw", "try", "catch", "finally", "yield",
      "new", "this", "base", "virtual", "override", "abstract", "is", "as"
    ])
  }

  fn tokenize_elixir(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract Elixir identifiers and keywords
    self.tokenize_with_keywords(content, &[
      "def", "defp", "defm", "defmodule", "defstruct", "defexception", "defprotocol",
      "defimpl", "if", "unless", "case", "cond", "for", "try", "catch", "rescue",
      "after", "receive", "import", "alias", "require", "use", "when", "do", "end",
      "and", "or", "not", "in", "fn", "quote", "unquote", "unquote_splicing"
    ])
  }

  fn tokenize_erlang(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract Erlang identifiers and keywords
    self.tokenize_with_keywords(content, &[
      "module", "export", "import", "function", "case", "if", "of", "when", "try",
      "catch", "after", "receive", "send", "spawn", "link", "monitor", "record",
      "include", "define", "ifdef", "ifndef", "endif", "error", "warning"
    ])
  }

  fn tokenize_gleam(&self, content: &str) -> Result<Vec<DataToken>> {
    // Extract Gleam identifiers and keywords
    self.tokenize_with_keywords(content, &[
      "pub", "fn", "type", "const", "assert", "let", "case", "try", "use", "import",
      "as", "assert_equal", "panic", "todo", "result", "option", "ok", "error",
      "nil", "true", "false", "list", "string", "int", "float", "bool"
    ])
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

  /// Helper to tokenize with language-specific keywords
  fn tokenize_with_keywords(&self, content: &str, keywords: &[&str]) -> Result<Vec<DataToken>> {
    let mut tokens = Vec::new();

    // Split on code delimiters (expanded set for better tokenization)
    for part in content.split(&[' ', '\t', '\n', '_', '-', '.', '/', '\\', ':', ';', '(', ')', '[', ']', '{', '}', ',', '"', '\'', '`', '=', '+', '-', '*', '/', '%', '<', '>', '!', '&', '|', '^'][..]) {
      let cleaned = part.chars().filter(|c| c.is_alphanumeric()).collect::<String>().to_lowercase();

      if cleaned.len() > 1 && !cleaned.chars().all(|c| c.is_numeric()) {
        let token_type = if keywords.contains(&cleaned.as_str()) {
          TokenType::Keyword
        } else {
          self.classify_token(&cleaned)
        };

        let weight = match token_type {
          TokenType::Keyword => 0.5,
          TokenType::FunctionName => 1.0,
          TokenType::ClassName => 0.9,
          TokenType::VariableName => 0.7,
          _ => 0.1,
        };

        tokens.push(DataToken {
          text: cleaned,
          token_type,
          weight,
          context: "language-specific".to_string(),
        });
      }
    }

    Ok(tokens)
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

/// Semantic tokenizer wrapper for multi-language support
///
/// Provides language-specific tokenization via the factory pattern.
/// Used for semantic analysis of code in various programming languages.
pub struct SemanticTokenizer {
  language: String,
  tokenizer: Box<dyn CustomTokenizer>,
}

impl SemanticTokenizer {
  /// Create a new semantic tokenizer for the given language
  pub fn new(language: &str) -> Self {
    // For semantic tokenization, we use code tokenization with language context
    let data_type = DataType::Code {
      language: language.to_string(),
      content: String::new(),
    };
    let tokenizer = TokenizerFactory::create_tokenizer(&data_type);

    Self {
      language: language.to_string(),
      tokenizer,
    }
  }

  /// Tokenize content in the specified language
  pub fn tokenize(&self, content: &str) -> Result<Vec<DataToken>> {
    let data = DataType::Code {
      language: self.language.clone(),
      content: content.to_string(),
    };
    self.tokenizer.tokenize(&data)
  }

  /// Extract semantic keywords from content
  pub fn extract_keywords(&self, content: &str) -> Result<Vec<String>> {
    let data = DataType::Code {
      language: self.language.clone(),
      content: content.to_string(),
    };
    self.tokenizer.extract_keywords(&data)
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_code_tokenizer_rust() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "rust".to_string(), content: "fn get_user_name() -> String { user.name }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    // Should contain "fn", "get_user_name", etc.
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty(), "Should have keyword tokens");
  }

  #[test]
  fn test_code_tokenizer_python() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "python".to_string(), content: "def calculate_total(items): return sum(items)".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_typescript() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "typescript".to_string(), content: "function greet(name: string): void { console.log(name); }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_javascript() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "javascript".to_string(), content: "const getValue = (key) => data[key];".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_java() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "java".to_string(), content: "public class User { private String name; }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_go() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "go".to_string(), content: "func main() { fmt.Println(\"Hello\") }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_csharp() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "csharp".to_string(), content: "public class Program { static void Main() { } }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_elixir() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "elixir".to_string(), content: "defmodule User do def get_name(user), do: user.name end".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_erlang() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "erlang".to_string(), content: "-module(hello). -export([world/0]). world() -> ok.".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_gleam() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "gleam".to_string(), content: "pub fn main() { let x = 42 x }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
  }

  #[test]
  fn test_code_tokenizer_cpp() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "c++".to_string(), content: "int main() { return 0; }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();
    assert!(!tokens.is_empty());
    let keyword_tokens: Vec<_> = tokens.iter().filter(|t| matches!(t.token_type, TokenType::Keyword)).collect();
    assert!(!keyword_tokens.is_empty());
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

  #[test]
  fn test_tokenizer_factory() {
    let code_data = DataType::Code { language: "rust".to_string(), content: "fn test() {}".to_string() };
    let tokenizer = TokenizerFactory::create_tokenizer(&code_data);
    let tokens = tokenizer.tokenize(&code_data).unwrap();
    assert!(!tokens.is_empty());
  }

  #[test]
  fn test_keyword_weights() {
    let tokenizer = CodeTokenizer::new();
    let data = DataType::Code { language: "rust".to_string(), content: "fn main() -> i32 { let x = 42; x }".to_string() };

    let tokens = tokenizer.tokenize(&data).unwrap();

    // Verify weight distribution
    let keyword_weights: Vec<f32> = tokens.iter()
      .filter(|t| matches!(t.token_type, TokenType::Keyword))
      .map(|t| t.weight)
      .collect();

    // Keywords should have weight 0.5
    for weight in keyword_weights {
      assert_eq!(weight, 0.5);
    }
  }
}
