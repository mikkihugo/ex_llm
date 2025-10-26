use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use super::errors::AstGrepError;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pattern {
    pub(crate) pattern: String,
    #[serde(default)]
    pub(crate) constraints: HashMap<String, String>,
    #[serde(default)]
    flags: PatternFlags,
}

impl Pattern {
    pub fn new(pattern: impl Into<String>) -> Self {
        Self {
            pattern: pattern.into(),
            constraints: HashMap::new(),
            flags: PatternFlags::default(),
        }
    }

    pub fn as_str(&self) -> &str {
        &self.pattern
    }

    pub fn with_constraint(mut self, metavar: impl Into<String>, constraint: impl Into<String>) -> Self {
        self.constraints.insert(metavar.into(), constraint.into());
        self
    }

    pub fn with_flags(mut self, flags: PatternFlags) -> Self {
        self.flags = flags;
        self
    }

    pub fn validate(&self) -> Result<(), AstGrepError> {
        if self.pattern.trim().is_empty() {
            return Err(AstGrepError::UnsupportedFlag("pattern cannot be empty".into()));
        }

        if self.flags.whole_word {
            return Err(AstGrepError::UnsupportedFlag(
                "whole-word matching is not supported yet".into(),
            ));
        }
        if !self.flags.case_sensitive {
            return Err(AstGrepError::UnsupportedFlag(
                "case-insensitive matching is not supported yet".into(),
            ));
        }
        if self.flags.multiline || self.flags.dotall || self.flags.extended {
            return Err(AstGrepError::UnsupportedFlag(
                "regex-style multiline/dotall/extended flags are not supported".into(),
            ));
        }

        let mut depth = 0i32;
        for ch in self.pattern.chars() {
            match ch {
                '{' => depth += 1,
                '}' => {
                    depth -= 1;
                    if depth < 0 {
                        return Err(AstGrepError::UnsupportedFlag("unbalanced pattern braces".into()));
                    }
                }
                _ => {}
            }
        }
        if depth != 0 {
            return Err(AstGrepError::UnsupportedFlag("unbalanced pattern braces".into()));
        }

        Ok(())
    }

    pub fn metavariables(&self) -> Vec<String> {
        let mut vars = Vec::new();
        let mut chars = self.pattern.chars().peekable();
        while let Some(ch) = chars.next() {
            if ch == '$' {
                let mut name = String::new();
                while let Some(&next) = chars.peek() {
                    if next.is_alphanumeric() || next == '_' {
                        name.push(chars.next().unwrap());
                    } else {
                        break;
                    }
                }
                if !name.is_empty() {
                    vars.push(name);
                }
            }
        }
        vars
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PatternFlags {
    pub case_sensitive: bool,
    pub whole_word: bool,
    pub multiline: bool,
    pub dotall: bool,
    pub extended: bool,
}

/// Options for AST transformations (search and replace operations).
///
/// Controls how code is transformed during pattern-based replacements, including
/// preservation of formatting, comments, and other code properties.
///
/// # Examples
///
/// ```
/// use parser_core::ast_grep::{AstGrep, Pattern, TransformOptions};
///
/// let mut engine = AstGrep::new("javascript").unwrap();
/// let pattern = Pattern::new("console.log($VAR)");
/// let replacement = Pattern::new("logger.debug($VAR)");
///
/// // Preserve whitespace and comments during replacement
/// let mut options = TransformOptions::default();
/// options.preserve_whitespace = true;
/// options.preserve_comments = true;
///
/// let code = "  console.log(x);  // Log x value";
/// let result = engine.replace_with_options(code, &pattern, &replacement, &options).unwrap();
/// // Result: "  logger.debug(x);  // Log x value"
/// // Note: Indentation and comment are preserved!
/// ```
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TransformOptions {
    /// Maximum number of replacements to perform.
    ///
    /// When `Some(n)`, only the first `n` matches will be replaced.
    /// When `None`, all matches are replaced.
    ///
    /// # Example
    ///
    /// ```
    /// # use parser_core::ast_grep::TransformOptions;
    /// let mut options = TransformOptions::default();
    /// options.max_replacements = Some(5);  // Replace only first 5 occurrences
    /// ```
    pub max_replacements: Option<usize>,

    /// Preserve leading whitespace/indentation from the original code.
    ///
    /// When `true`, the replacement will maintain the same indentation level
    /// as the original matched code. This is essential for maintaining code
    /// readability and style consistency in whitespace-sensitive languages.
    ///
    /// **Implementation:** Detects leading whitespace in the matched text and
    /// applies it to each line of the replacement text.
    ///
    /// # Example
    ///
    /// ```
    /// // Original:
    /// //     console.log(x);
    /// // With preserve_whitespace = true:
    /// //     logger.debug(x);  (indentation preserved)
    /// // With preserve_whitespace = false:
    /// // logger.debug(x);      (no indentation)
    /// ```
    pub preserve_whitespace: bool,

    /// Preserve trailing comments from the original code.
    ///
    /// When `true`, any end-of-line comments in the matched code will be
    /// appended to the replacement. This prevents losing important code
    /// documentation during refactoring.
    ///
    /// **Implementation:** Detects trailing comments (e.g., `// comment` or `/* comment */`)
    /// and appends them to the replacement with appropriate spacing.
    ///
    /// # Example
    ///
    /// ```
    /// // Original:
    /// // console.log(x);  // Debug statement
    /// // With preserve_comments = true:
    /// // logger.debug(x);  // Debug statement
    /// // With preserve_comments = false:
    /// // logger.debug(x);
    /// ```
    pub preserve_comments: bool,

    /// Dry run mode - don't actually perform replacements.
    ///
    /// When `true`, the replacement operation will validate patterns and
    /// count matches but will not modify the source code. Useful for
    /// previewing changes before applying them.
    ///
    /// **Note:** Currently a placeholder - not yet implemented in the engine.
    ///
    /// # Example
    ///
    /// ```
    /// # use parser_core::ast_grep::TransformOptions;
    /// let mut options = TransformOptions::default();
    /// options.dry_run = true;  // Preview changes without modifying code
    /// ```
    pub dry_run: bool,

    /// Include the original code as a backup comment.
    ///
    /// When `true`, the original matched code will be added as a comment
    /// above the replacement. Useful for code reviews and debugging.
    ///
    /// **Implementation:** Adds a multi-line comment block with the original
    /// code, preserving indentation.
    ///
    /// # Example
    ///
    /// ```
    /// // With backup_original = true:
    /// // /* Original code:
    /// //  * console.log(x);
    /// //  */
    /// // logger.debug(x);
    /// ```
    pub backup_original: bool,
}

impl TransformOptions {
    /// Create options with both whitespace and comment preservation enabled.
    ///
    /// This is the recommended configuration for most refactoring operations,
    /// as it maintains code formatting and documentation.
    ///
    /// # Example
    ///
    /// ```
    /// # use parser_core::ast_grep::TransformOptions;
    /// let options = TransformOptions::preserve_all();
    /// assert!(options.preserve_whitespace);
    /// assert!(options.preserve_comments);
    /// ```
    pub fn preserve_all() -> Self {
        Self {
            preserve_whitespace: true,
            preserve_comments: true,
            ..Default::default()
        }
    }

    /// Create options for safe refactoring with backup.
    ///
    /// Enables preservation and adds backup comments for safety.
    ///
    /// # Example
    ///
    /// ```
    /// # use parser_core::ast_grep::TransformOptions;
    /// let options = TransformOptions::safe_refactor();
    /// assert!(options.preserve_whitespace);
    /// assert!(options.preserve_comments);
    /// assert!(options.backup_original);
    /// ```
    pub fn safe_refactor() -> Self {
        Self {
            preserve_whitespace: true,
            preserve_comments: true,
            backup_original: true,
            ..Default::default()
        }
    }
}
