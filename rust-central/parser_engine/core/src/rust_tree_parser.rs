//! Pure Rust Tree Parser Framework
//!
//! Implements tree parsing for all languages using pure Rust.
//! No external dependencies - everything built from scratch.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Universal AST Node that can represent any language construct
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RustTreeNode {
    pub node_type: String,
    pub value: Option<String>,
    pub children: Vec<RustTreeNode>,
    pub start_line: usize,
    pub end_line: usize,
    pub start_column: usize,
    pub end_column: usize,
    pub metadata: HashMap<String, String>,
}

impl RustTreeNode {
    pub fn new(node_type: &str) -> Self {
        Self {
            node_type: node_type.to_string(),
            value: None,
            children: Vec::new(),
            start_line: 0,
            end_line: 0,
            start_column: 0,
            end_column: 0,
            metadata: HashMap::new(),
        }
    }

    pub fn with_value(mut self, value: &str) -> Self {
        self.value = Some(value.to_string());
        self
    }

    pub fn with_position(mut self, start_line: usize, end_line: usize, start_col: usize, end_col: usize) -> Self {
        self.start_line = start_line;
        self.end_line = end_line;
        self.start_column = start_col;
        self.end_column = end_col;
        self
    }

    pub fn add_child(mut self, child: RustTreeNode) -> Self {
        self.children.push(child);
        self
    }

    pub fn add_metadata(mut self, key: &str, value: &str) -> Self {
        self.metadata.insert(key.to_string(), value.to_string());
        self
    }
}

/// Language-specific tree parser trait
pub trait RustTreeParser {
    fn parse(&self, source: &str) -> Result<RustTreeNode, ParseError>;
    fn get_language(&self) -> &str;
}

/// Parse error for tree parsing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ParseError {
    SyntaxError { message: String, line: usize, column: usize },
    UnexpectedToken { expected: String, found: String, line: usize, column: usize },
    IncompleteParse { message: String },
    LanguageNotSupported { language: String },
}

impl std::fmt::Display for ParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ParseError::SyntaxError { message, line, column } => {
                write!(f, "Syntax error at line {}:{} - {}", line, column, message)
            }
            ParseError::UnexpectedToken { expected, found, line, column } => {
                write!(f, "Unexpected token at line {}:{} - expected '{}', found '{}'", line, column, expected, found)
            }
            ParseError::IncompleteParse { message } => {
                write!(f, "Incomplete parse: {}", message)
            }
            ParseError::LanguageNotSupported { language } => {
                write!(f, "Language '{}' is not supported", language)
            }
        }
    }
}

impl std::error::Error for ParseError {}

/// Token for parsing
#[derive(Debug, Clone, PartialEq)]
pub struct Token {
    pub token_type: TokenType,
    pub value: String,
    pub line: usize,
    pub column: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TokenType {
    // Keywords
    Keyword(String),
    
    // Identifiers
    Identifier,
    
    // Literals
    StringLiteral,
    NumberLiteral,
    BooleanLiteral,
    
    // Operators
    Operator(String),
    
    // Delimiters
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    Semicolon,
    Comma,
    Dot,
    
    // Special
    Newline,
    Whitespace,
    Comment,
    EOF,
}

/// Tokenizer for parsing source code
pub struct Tokenizer {
    source: String,
    position: usize,
    line: usize,
    column: usize,
}

impl Tokenizer {
    pub fn new(source: &str) -> Self {
        Self {
            source: source.to_string(),
            position: 0,
            line: 1,
            column: 1,
        }
    }

    pub fn peek(&self) -> Option<char> {
        self.source.chars().nth(self.position)
    }

    pub fn advance(&mut self) -> Option<char> {
        let ch = self.peek()?;
        self.position += 1;
        if ch == '\n' {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
        Some(ch)
    }

    pub fn skip_whitespace(&mut self) {
        while let Some(ch) = self.peek() {
            if ch.is_whitespace() && ch != '\n' {
                self.advance();
            } else {
                break;
            }
        }
    }

    pub fn read_identifier(&mut self) -> String {
        let mut result = String::new();
        while let Some(ch) = self.peek() {
            if ch.is_alphanumeric() || ch == '_' {
                result.push(self.advance().unwrap());
            } else {
                break;
            }
        }
        result
    }

    pub fn read_string_literal(&mut self) -> Result<String, ParseError> {
        let mut result = String::new();
        let quote = self.advance().unwrap(); // consume opening quote
        
        while let Some(ch) = self.peek() {
            if ch == quote {
                self.advance(); // consume closing quote
                return Ok(result);
            } else if ch == '\\' {
                self.advance(); // consume backslash
                if let Some(escaped) = self.advance() {
                    result.push(match escaped {
                        'n' => '\n',
                        't' => '\t',
                        'r' => '\r',
                        '\\' => '\\',
                        '"' => '"',
                        '\'' => '\'',
                        _ => escaped,
                    });
                }
            } else {
                result.push(self.advance().unwrap());
            }
        }
        
        Err(ParseError::IncompleteParse {
            message: "Unterminated string literal".to_string(),
        })
    }

    pub fn read_number(&mut self) -> String {
        let mut result = String::new();
        while let Some(ch) = self.peek() {
            if ch.is_ascii_digit() || ch == '.' || ch == 'e' || ch == 'E' || ch == '+' || ch == '-' {
                result.push(self.advance().unwrap());
            } else {
                break;
            }
        }
        result
    }
}