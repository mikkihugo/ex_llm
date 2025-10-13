//! Naming utilities for intelligent code naming
//!
//! Provides case conversion utilities without dependencies to avoid circular references.

/// Intelligent naming utilities
pub struct NamingUtilities {}

impl NamingUtilities {
    /// Create new naming utilities
    pub fn new() -> Self {
        Self {}
    }

    /// Validate function name according to language conventions
    pub fn validate_function_name(&self, name: &str) -> bool {
        // Default: snake_case functions
        self.is_snake_case(name)
    }

    /// Validate function name for specific language
    pub fn validate_function_name_for_language(&self, name: &str, language: &str) -> bool {
        match language.to_lowercase().as_str() {
            "elixir" | "ex" | "exs" => self.is_snake_case(name),
            "rust" | "rs" => self.is_snake_case(name),
            "typescript" | "ts" | "tsx" => self.is_camel_case(name),
            "javascript" | "js" | "jsx" => self.is_camel_case(name),
            "gleam" => self.is_snake_case(name),
            "go" | "golang" => self.is_camel_case(name),
            "python" | "py" => self.is_snake_case(name),
            _ => self.is_snake_case(name),
        }
    }

    /// Convert to snake_case
    ///
    /// # Examples
    /// ```
    /// # use architecture_engine::naming_utilities::NamingUtilities;
    /// let utils = NamingUtilities::new();
    /// assert_eq!(utils.to_snake_case("UserAccount"), "user_account");
    /// assert_eq!(utils.to_snake_case("HTTPResponse"), "http_response");
    /// ```
    pub fn to_snake_case(&self, input: &str) -> String {
        let mut result = String::new();
        let mut prev_lowercase = false;

        for (i, ch) in input.chars().enumerate() {
            if ch.is_uppercase() {
                if i > 0 && prev_lowercase {
                    result.push('_');
                }
                result.push(ch.to_lowercase().next().unwrap());
                prev_lowercase = false;
            } else if ch == '-' || ch == ' ' {
                result.push('_');
                prev_lowercase = false;
            } else {
                result.push(ch);
                prev_lowercase = ch.is_lowercase();
            }
        }
        result
    }

    /// Convert to kebab-case
    ///
    /// # Examples
    /// ```
    /// # use architecture_engine::naming_utilities::NamingUtilities;
    /// let utils = NamingUtilities::new();
    /// assert_eq!(utils.to_kebab_case("UserAccount"), "user-account");
    /// assert_eq!(utils.to_kebab_case("HTTPResponse"), "http-response");
    /// ```
    pub fn to_kebab_case(&self, input: &str) -> String {
        self.to_snake_case(input).replace('_', "-")
    }

    /// Convert to PascalCase
    ///
    /// # Examples
    /// ```
    /// # use architecture_engine::naming_utilities::NamingUtilities;
    /// let utils = NamingUtilities::new();
    /// assert_eq!(utils.to_pascal_case("user_account"), "UserAccount");
    /// assert_eq!(utils.to_pascal_case("http-response"), "HttpResponse");
    /// ```
    pub fn to_pascal_case(&self, input: &str) -> String {
        let snake = self.to_snake_case(input);
        snake.split('_')
            .map(|word| {
                let mut chars = word.chars();
                match chars.next() {
                    Some(first) => first.to_uppercase().chain(chars).collect(),
                    None => String::new(),
                }
            })
            .collect()
    }

    /// Convert to camelCase
    ///
    /// # Examples
    /// ```
    /// # use architecture_engine::naming_utilities::NamingUtilities;
    /// let utils = NamingUtilities::new();
    /// assert_eq!(utils.to_camel_case("user_account"), "userAccount");
    /// assert_eq!(utils.to_camel_case("http-response"), "httpResponse");
    /// ```
    pub fn to_camel_case(&self, input: &str) -> String {
        let pascal = self.to_pascal_case(input);
        let mut chars = pascal.chars();
        match chars.next() {
            Some(first) => first.to_lowercase().chain(chars).collect(),
            None => String::new(),
        }
    }

    /// Check if name is valid snake_case
    fn is_snake_case(&self, name: &str) -> bool {
        !name.is_empty() &&
        name.chars().all(|c| c.is_lowercase() || c.is_numeric() || c == '_') &&
        !name.starts_with('_') && !name.ends_with('_')
    }

    /// Check if name is valid camelCase
    fn is_camel_case(&self, name: &str) -> bool {
        !name.is_empty() &&
        name.chars().next().map_or(false, |c| c.is_lowercase()) &&
        name.chars().all(|c| c.is_alphanumeric()) &&
        name.contains(|c: char| c.is_uppercase())
    }
}

impl Default for NamingUtilities {
    fn default() -> Self {
        Self::new()
    }
}
